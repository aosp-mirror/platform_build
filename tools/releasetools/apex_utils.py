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

import common

logger = logging.getLogger(__name__)


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
    raise ApexSigningError, \
        'Failed to sign APEX payload {} with {}:\n{}'.format(
            payload_file, payload_key_path, e), sys.exc_info()[2]

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
    raise ApexSigningError, \
        'Failed to validate payload signing for {} with {}:\n{}'.format(
            payload_file, payload_key, e), sys.exc_info()[2]


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
    raise ApexInfoError, \
        'Failed to get APEX payload info for {}:\n{}'.format(
            payload_path, e), sys.exc_info()[2]

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
