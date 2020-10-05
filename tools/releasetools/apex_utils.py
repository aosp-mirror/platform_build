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
import shutil
import zipfile

import common

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

APEX_PAYLOAD_IMAGE = 'apex_payload.img'


class ApexInfoError(Exception):
  """An Exception raised during Apex Information command."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexSigningError(Exception):
  """An Exception raised during Apex Payload signing."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexApkSigner(object):
  """Class to sign the apk files in a apex payload image and repack the apex"""

  def __init__(self, apex_path, key_passwords, codename_to_api_level_map):
    self.apex_path = apex_path
    if not key_passwords:
      self.key_passwords = dict()
    else:
      self.key_passwords = key_passwords
    self.codename_to_api_level_map = codename_to_api_level_map

  def ProcessApexFile(self, apk_keys, payload_key, signing_args=None):
    """Scans and signs the apk files and repack the apex

    Args:
      apk_keys: A dict that holds the signing keys for apk files.

    Returns:
      The repacked apex file containing the signed apk files.
    """
    list_cmd = ['deapexer', 'list', self.apex_path]
    entries_names = common.RunAndCheckOutput(list_cmd).split()
    apk_entries = [name for name in entries_names if name.endswith('.apk')]

    # No need to sign and repack, return the original apex path.
    if not apk_entries:
      logger.info('No apk file to sign in %s', self.apex_path)
      return self.apex_path

    for entry in apk_entries:
      apk_name = os.path.basename(entry)
      if apk_name not in apk_keys:
        raise ApexSigningError('Failed to find signing keys for apk file {} in'
                               ' apex {}.  Use "-e <apkname>=" to specify a key'
                               .format(entry, self.apex_path))
      if not any(dirname in entry for dirname in ['app/', 'priv-app/',
                                                  'overlay/']):
        logger.warning('Apk path does not contain the intended directory name:'
                       ' %s', entry)

    payload_dir, has_signed_apk = self.ExtractApexPayloadAndSignApks(
        apk_entries, apk_keys)
    if not has_signed_apk:
      logger.info('No apk file has been signed in %s', self.apex_path)
      return self.apex_path

    return self.RepackApexPayload(payload_dir, payload_key, signing_args)

  def ExtractApexPayloadAndSignApks(self, apk_entries, apk_keys):
    """Extracts the payload image and signs the containing apk files."""
    payload_dir = common.MakeTempDir()
    extract_cmd = ['deapexer', 'extract', self.apex_path, payload_dir]
    common.RunAndCheckOutput(extract_cmd)

    has_signed_apk = False
    for entry in apk_entries:
      apk_path = os.path.join(payload_dir, entry)
      assert os.path.exists(self.apex_path)

      key_name = apk_keys.get(os.path.basename(entry))
      if key_name in common.SPECIAL_CERT_STRINGS:
        logger.info('Not signing: %s due to special cert string', apk_path)
        continue

      logger.info('Signing apk file %s in apex %s', apk_path, self.apex_path)
      # Rename the unsigned apk and overwrite the original apk path with the
      # signed apk file.
      unsigned_apk = common.MakeTempFile()
      os.rename(apk_path, unsigned_apk)
      common.SignFile(unsigned_apk, apk_path, key_name, self.key_passwords.get(key_name),
                      codename_to_api_level_map=self.codename_to_api_level_map)
      has_signed_apk = True
    return payload_dir, has_signed_apk

  def RepackApexPayload(self, payload_dir, payload_key, signing_args=None):
    """Rebuilds the apex file with the updated payload directory."""
    apex_dir = common.MakeTempDir()
    # Extract the apex file and reuse its meta files as repack parameters.
    common.UnzipToDir(self.apex_path, apex_dir)
    arguments_dict = {
        'manifest': os.path.join(apex_dir, 'apex_manifest.pb'),
        'build_info': os.path.join(apex_dir, 'apex_build_info.pb'),
        'key': payload_key,
    }
    for filename in arguments_dict.values():
      assert os.path.exists(filename), 'file {} not found'.format(filename)

    # The repack process will add back these files later in the payload image.
    for name in ['apex_manifest.pb', 'apex_manifest.json', 'lost+found']:
      path = os.path.join(payload_dir, name)
      if os.path.isfile(path):
        os.remove(path)
      elif os.path.isdir(path):
        shutil.rmtree(path)

    # TODO(xunchang) the signing process can be improved by using
    # '--unsigned_payload_only'. But we need to parse the vbmeta earlier for
    # the signing arguments, e.g. algorithm, salt, etc.
    payload_img = os.path.join(apex_dir, APEX_PAYLOAD_IMAGE)
    generate_image_cmd = ['apexer', '--force', '--payload_only',
                          '--do_not_check_keyname', '--apexer_tool_path',
                          os.getenv('PATH')]
    for key, val in arguments_dict.items():
      generate_image_cmd.extend(['--' + key, val])

    # Add quote to the signing_args as we will pass
    # --signing_args "--signing_helper_with_files=%path" to apexer
    if signing_args:
      generate_image_cmd.extend(['--signing_args', '"{}"'.format(signing_args)])

    # optional arguments for apex repacking
    manifest_json = os.path.join(apex_dir, 'apex_manifest.json')
    if os.path.exists(manifest_json):
      generate_image_cmd.extend(['--manifest_json', manifest_json])
    generate_image_cmd.extend([payload_dir, payload_img])
    if OPTIONS.verbose:
      generate_image_cmd.append('-v')
    common.RunAndCheckOutput(generate_image_cmd)

    # Add the payload image back to the apex file.
    common.ZipDelete(self.apex_path, APEX_PAYLOAD_IMAGE)
    with zipfile.ZipFile(self.apex_path, 'a') as output_apex:
      common.ZipWrite(output_apex, payload_img, APEX_PAYLOAD_IMAGE,
                      compress_type=zipfile.ZIP_STORED)
    return self.apex_path


def SignApexPayload(avbtool, payload_file, payload_key_path, payload_key_name,
                    algorithm, salt, hash_algorithm, no_hashtree, signing_args=None):
  """Signs a given payload_file with the payload key."""
  # Add the new footer. Old footer, if any, will be replaced by avbtool.
  cmd = [avbtool, 'add_hashtree_footer',
         '--do_not_generate_fec',
         '--algorithm', algorithm,
         '--key', payload_key_path,
         '--prop', 'apex.key:{}'.format(payload_key_name),
         '--image', payload_file,
         '--salt', salt,
         '--hash_algorithm', hash_algorithm]
  if no_hashtree:
    cmd.append('--no_hashtree')
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
  VerifyApexPayload(avbtool, payload_file, payload_key_path, no_hashtree)


def VerifyApexPayload(avbtool, payload_file, payload_key, no_hashtree=False):
  """Verifies the APEX payload signature with the given key."""
  cmd = [avbtool, 'verify_image', '--image', payload_file,
         '--key', payload_key]
  if no_hashtree:
    cmd.append('--accept_zeroed_hashtree')
  try:
    common.RunAndCheckOutput(cmd)
  except common.ExternalError as e:
    raise ApexSigningError(
        'Failed to validate payload signing for {} with {}:\n{}'.format(
            payload_file, payload_key, e))


def ParseApexPayloadInfo(avbtool, payload_path):
  """Parses the APEX payload info.

  Args:
    avbtool: The AVB tool to use.
    payload_path: The path to the payload image.

  Raises:
    ApexInfoError on parsing errors.

  Returns:
    A dict that contains payload property-value pairs. The dict should at least
    contain Algorithm, Salt, Tree Size and apex.key.
  """
  if not os.path.exists(payload_path):
    raise ApexInfoError('Failed to find image: {}'.format(payload_path))

  cmd = [avbtool, 'info_image', '--image', payload_path]
  try:
    output = common.RunAndCheckOutput(cmd)
  except common.ExternalError as e:
    raise ApexInfoError(
        'Failed to get APEX payload info for {}:\n{}'.format(
            payload_path, e))

  # Extract the Algorithm / Hash Algorithm / Salt / Prop info / Tree size from
  # payload (i.e. an image signed with avbtool). For example,
  # Algorithm:                SHA256_RSA4096
  PAYLOAD_INFO_PATTERN = (
      r'^\s*(?P<key>Algorithm|Hash Algorithm|Salt|Prop|Tree Size)\:\s*(?P<value>.*?)$')
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
  for key in ('Algorithm', 'Salt', 'apex.key', 'Hash Algorithm'):
    if key not in payload_info:
      raise ApexInfoError(
          'Failed to find {} prop in {}'.format(key, payload_path))

  return payload_info


def SignApex(avbtool, apex_data, payload_key, container_key, container_pw,
             apk_keys, codename_to_api_level_map,
             no_hashtree, signing_args=None):
  """Signs the current APEX with the given payload/container keys.

  Args:
    apex_data: Raw APEX data.
    payload_key: The path to payload signing key (w/ extension).
    container_key: The path to container signing key (w/o extension).
    container_pw: The matching password of the container_key, or None.
    apk_keys: A dict that holds the signing keys for apk files.
    codename_to_api_level_map: A dict that maps from codename to API level.
    no_hashtree: Don't include hashtree in the signed APEX.
    signing_args: Additional args to be passed to the payload signer.

  Returns:
    The path to the signed APEX file.
  """
  apex_file = common.MakeTempFile(prefix='apex-', suffix='.apex')
  with open(apex_file, 'wb') as apex_fp:
    apex_fp.write(apex_data)

  APEX_PUBKEY = 'apex_pubkey'

  # 1. Extract the apex payload image and sign the containing apk files. Repack
  # the apex file after signing.
  apk_signer = ApexApkSigner(apex_file, container_pw,
                             codename_to_api_level_map)
  apex_file = apk_signer.ProcessApexFile(apk_keys, payload_key, signing_args)

  # 2a. Extract and sign the APEX_PAYLOAD_IMAGE entry with the given
  # payload_key.
  payload_dir = common.MakeTempDir(prefix='apex-payload-')
  with zipfile.ZipFile(apex_file) as apex_fd:
    payload_file = apex_fd.extract(APEX_PAYLOAD_IMAGE, payload_dir)
    zip_items = apex_fd.namelist()

  payload_info = ParseApexPayloadInfo(avbtool, payload_file)
  SignApexPayload(
      avbtool,
      payload_file,
      payload_key,
      payload_info['apex.key'],
      payload_info['Algorithm'],
      payload_info['Salt'],
      payload_info['Hash Algorithm'],
      no_hashtree,
      signing_args)

  # 2b. Update the embedded payload public key.
  payload_public_key = common.ExtractAvbPublicKey(avbtool, payload_key)
  common.ZipDelete(apex_file, APEX_PAYLOAD_IMAGE)
  if APEX_PUBKEY in zip_items:
    common.ZipDelete(apex_file, APEX_PUBKEY)
  apex_zip = zipfile.ZipFile(apex_file, 'a')
  common.ZipWrite(apex_zip, payload_file, arcname=APEX_PAYLOAD_IMAGE)
  common.ZipWrite(apex_zip, payload_public_key, arcname=APEX_PUBKEY)
  common.ZipClose(apex_zip)

  # 3. Align the files at page boundary (same as in apexer).
  aligned_apex = common.MakeTempFile(prefix='apex-container-', suffix='.apex')
  common.RunAndCheckOutput(['zipalign', '-f', '4096', apex_file, aligned_apex])

  # 4. Sign the APEX container with container_key.
  signed_apex = common.MakeTempFile(prefix='apex-container-', suffix='.apex')

  # Specify the 4K alignment when calling SignApk.
  extra_signapk_args = OPTIONS.extra_signapk_args[:]
  extra_signapk_args.extend(['-a', '4096'])

  common.SignFile(
      aligned_apex,
      signed_apex,
      container_key,
      container_pw.get(container_key),
      codename_to_api_level_map=codename_to_api_level_map,
      extra_signapk_args=extra_signapk_args)

  return signed_apex
