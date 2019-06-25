#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
import os.path
import re
import shlex
import sys
import zipfile

import common

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS


class ApexInfoError(Exception):
  """An Exception raised during Apex Information command."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexSigningError(Exception):
  """An Exception raised during Apex Payload signing."""

  def __init__(self, message):
    Exception.__init__(self, message)


def SignApexPayload(payload_file, payload_key_path, payload_key_name, algorithm,
                    salt, signing_args=None):
  """Signs a given payload_file with the payload key."""
  # Add the new footer. Old footer, if any, will be replaced by avbtool.
  cmd = ['avbtool', 'add_hashtree_footer',
         '--do_not_generate_fec',
         '--algorithm', algorithm,
         '--key', payload_key_path,
         '--prop', 'apex.key:{}'.format(payload_key_name),
         '--image', payload_file,
         '--salt', salt]
  if signing_args:
    cmd.extend(shlex.split(signing_args))

  try:
    common.RunAndCheckOutput(cmd)
  except common.ExternalError as e:
    raise ApexSigningError(
        'Failed to sign APEX payload {} with {}:\n{}'.format(
            payload_file, payload_key_path, e))

  # Verify the signed payload image with specified public key.
  logger.info('Verifying %s', payload_file)
  VerifyApexPayload(payload_file, payload_key_path)


def VerifyApexPayload(payload_file, payload_key):
  """Verifies the APEX payload signature with the given key."""
  cmd = ['avbtool', 'verify_image', '--image', payload_file,
         '--key', payload_key]
  try:
    common.RunAndCheckOutput(cmd)
  except common.ExternalError as e:
    raise ApexSigningError(
        'Failed to validate payload signing for {} with {}:\n{}'.format(
            payload_file, payload_key, e))


def ParseApexPayloadInfo(payload_path):
  """Parses the APEX payload info.

  Args:
    payload_path: The path to the payload image.

  Raises:
    ApexInfoError on parsing errors.

  Returns:
    A dict that contains payload property-value pairs. The dict should at least
    contain Algorithm, Salt and apex.key.
  """
  if not os.path.exists(payload_path):
    raise ApexInfoError('Failed to find image: {}'.format(payload_path))

  cmd = ['avbtool', 'info_image', '--image', payload_path]
  try:
    output = common.RunAndCheckOutput(cmd)
  except common.ExternalError as e:
    raise ApexInfoError(
        'Failed to get APEX payload info for {}:\n{}'.format(
            payload_path, e))

  # Extract the Algorithm / Salt / Prop info from payload (i.e. an image signed
  # with avbtool). For example,
  # Algorithm:                SHA256_RSA4096
  PAYLOAD_INFO_PATTERN = (
      r'^\s*(?P<key>Algorithm|Salt|Prop)\:\s*(?P<value>.*?)$')
  payload_info_matcher = re.compile(PAYLOAD_INFO_PATTERN)

  payload_info = {}
  for line in output.split('\n'):
    line_info = payload_info_matcher.match(line)
    if not line_info:
      continue

    key, value = line_info.group('key'), line_info.group('value')

    if key == 'Prop':
      # Further extract the property key-value pair, from a 'Prop:' line. For
      # example,
      #   Prop: apex.key -> 'com.android.runtime'
      # Note that avbtool writes single or double quotes around values.
      PROPERTY_DESCRIPTOR_PATTERN = r'^\s*(?P<key>.*?)\s->\s*(?P<value>.*?)$'

      prop_matcher = re.compile(PROPERTY_DESCRIPTOR_PATTERN)
      prop = prop_matcher.match(value)
      if not prop:
        raise ApexInfoError(
            'Failed to parse prop string {}'.format(value))

      prop_key, prop_value = prop.group('key'), prop.group('value')
      if prop_key == 'apex.key':
        # avbtool dumps the prop value with repr(), which contains single /
        # double quotes that we don't want.
        payload_info[prop_key] = prop_value.strip('\"\'')

    else:
      payload_info[key] = value

  # Sanity check.
  for key in ('Algorithm', 'Salt', 'apex.key'):
    if key not in payload_info:
      raise ApexInfoError(
          'Failed to find {} prop in {}'.format(key, payload_path))

  return payload_info


def SignApex(apex_data, payload_key, container_key, container_pw,
             codename_to_api_level_map, signing_args=None):
  """Signs the current APEX with the given payload/container keys.

  Args:
    apex_data: Raw APEX data.
    payload_key: The path to payload signing key (w/ extension).
    container_key: The path to container signing key (w/o extension).
    container_pw: The matching password of the container_key, or None.
    codename_to_api_level_map: A dict that maps from codename to API level.
    signing_args: Additional args to be passed to the payload signer.

  Returns:
    The path to the signed APEX file.
  """
  apex_file = common.MakeTempFile(prefix='apex-', suffix='.apex')
  with open(apex_file, 'wb') as apex_fp:
    apex_fp.write(apex_data)

  APEX_PAYLOAD_IMAGE = 'apex_payload.img'
  APEX_PUBKEY = 'apex_pubkey'

  # 1a. Extract and sign the APEX_PAYLOAD_IMAGE entry with the given
  # payload_key.
  payload_dir = common.MakeTempDir(prefix='apex-payload-')
  with zipfile.ZipFile(apex_file) as apex_fd:
    payload_file = apex_fd.extract(APEX_PAYLOAD_IMAGE, payload_dir)

  payload_info = ParseApexPayloadInfo(payload_file)
  SignApexPayload(
      payload_file,
      payload_key,
      payload_info['apex.key'],
      payload_info['Algorithm'],
      payload_info['Salt'],
      signing_args)

  # 1b. Update the embedded payload public key.
  payload_public_key = common.ExtractAvbPublicKey(payload_key)

  common.ZipDelete(apex_file, APEX_PAYLOAD_IMAGE)
  common.ZipDelete(apex_file, APEX_PUBKEY)
  apex_zip = zipfile.ZipFile(apex_file, 'a')
  common.ZipWrite(apex_zip, payload_file, arcname=APEX_PAYLOAD_IMAGE)
  common.ZipWrite(apex_zip, payload_public_key, arcname=APEX_PUBKEY)
  common.ZipClose(apex_zip)

  # 2. Align the files at page boundary (same as in apexer).
  aligned_apex = common.MakeTempFile(prefix='apex-container-', suffix='.apex')
  common.RunAndCheckOutput(['zipalign', '-f', '4096', apex_file, aligned_apex])

  # 3. Sign the APEX container with container_key.
  signed_apex = common.MakeTempFile(prefix='apex-container-', suffix='.apex')

  # Specify the 4K alignment when calling SignApk.
  extra_signapk_args = OPTIONS.extra_signapk_args[:]
  extra_signapk_args.extend(['-a', '4096'])

  common.SignFile(
      aligned_apex,
      signed_apex,
      container_key,
      container_pw,
      codename_to_api_level_map=codename_to_api_level_map,
      extra_signapk_args=extra_signapk_args)

  return signed_apex
