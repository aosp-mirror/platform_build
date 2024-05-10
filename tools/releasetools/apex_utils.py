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

import apex_manifest
import common
from common import UnzipTemp, RunAndCheckOutput, MakeTempFile, OPTIONS

import ota_metadata_pb2


logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

APEX_PAYLOAD_IMAGE = 'apex_payload.img'

APEX_PUBKEY = 'apex_pubkey'


class ApexInfoError(Exception):
  """An Exception raised during Apex Information command."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexSigningError(Exception):
  """An Exception raised during Apex Payload signing."""

  def __init__(self, message):
    Exception.__init__(self, message)


class ApexApkSigner(object):
  """Class to sign the apk files and other files in an apex payload image and repack the apex"""

  def __init__(self, apex_path, key_passwords, codename_to_api_level_map, avbtool=None, sign_tool=None):
    self.apex_path = apex_path
    if not key_passwords:
      self.key_passwords = dict()
    else:
      self.key_passwords = key_passwords
    self.codename_to_api_level_map = codename_to_api_level_map
    self.debugfs_path = os.path.join(
        OPTIONS.search_path, "bin", "debugfs_static")
    self.fsckerofs_path = os.path.join(
        OPTIONS.search_path, "bin", "fsck.erofs")
    self.avbtool = avbtool if avbtool else "avbtool"
    self.sign_tool = sign_tool

  def ProcessApexFile(self, apk_keys, payload_key, signing_args=None):
    """Scans and signs the payload files and repack the apex

    Args:
      apk_keys: A dict that holds the signing keys for apk files.

    Returns:
      The repacked apex file containing the signed apk files.
    """
    if not os.path.exists(self.debugfs_path):
      raise ApexSigningError(
          "Couldn't find location of debugfs_static: " +
          "Path {} does not exist. ".format(self.debugfs_path) +
          "Make sure bin/debugfs_static can be found in -p <path>")
    list_cmd = ['deapexer', '--debugfs_path', self.debugfs_path,
                'list', self.apex_path]
    entries_names = common.RunAndCheckOutput(list_cmd).split()
    apk_entries = [name for name in entries_names if name.endswith('.apk')]

    # No need to sign and repack, return the original apex path.
    if not apk_entries and self.sign_tool is None:
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

    payload_dir, has_signed_content = self.ExtractApexPayloadAndSignContents(
        apk_entries, apk_keys, payload_key, signing_args)
    if not has_signed_content:
      logger.info('No contents has been signed in %s', self.apex_path)
      return self.apex_path

    return self.RepackApexPayload(payload_dir, payload_key, signing_args)

  def ExtractApexPayloadAndSignContents(self, apk_entries, apk_keys, payload_key, signing_args):
    """Extracts the payload image and signs the containing apk files."""
    if not os.path.exists(self.debugfs_path):
      raise ApexSigningError(
          "Couldn't find location of debugfs_static: " +
          "Path {} does not exist. ".format(self.debugfs_path) +
          "Make sure bin/debugfs_static can be found in -p <path>")
    if not os.path.exists(self.fsckerofs_path):
      raise ApexSigningError(
          "Couldn't find location of fsck.erofs: " +
          "Path {} does not exist. ".format(self.fsckerofs_path) +
          "Make sure bin/fsck.erofs can be found in -p <path>")
    payload_dir = common.MakeTempDir()
    extract_cmd = ['deapexer', '--debugfs_path', self.debugfs_path,
                   '--fsckerofs_path', self.fsckerofs_path,
                   'extract',
                   self.apex_path, payload_dir]
    common.RunAndCheckOutput(extract_cmd)

    has_signed_content = False
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
      common.SignFile(
          unsigned_apk, apk_path, key_name, self.key_passwords.get(key_name),
          codename_to_api_level_map=self.codename_to_api_level_map)
      has_signed_content = True

    if self.sign_tool:
      logger.info('Signing payload contents in apex %s with %s', self.apex_path, self.sign_tool)
      # Pass avbtool to the custom signing tool
      cmd = [self.sign_tool, '--avbtool', self.avbtool]
      # Pass signing_args verbatim which will be forwarded to avbtool (e.g. --signing_helper=...)
      if signing_args:
        cmd.extend(['--signing_args', '"{}"'.format(signing_args)])
      cmd.extend([payload_key, payload_dir])
      common.RunAndCheckOutput(cmd)
      has_signed_content = True

    return payload_dir, has_signed_content

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
        shutil.rmtree(path, ignore_errors=True)

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
      generate_image_cmd.extend(
          ['--signing_args', '"{}"'.format(signing_args)])

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
    with zipfile.ZipFile(self.apex_path, 'a', allowZip64=True) as output_apex:
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

  # Validation check.
  for key in ('Algorithm', 'Salt', 'apex.key', 'Hash Algorithm'):
    if key not in payload_info:
      raise ApexInfoError(
          'Failed to find {} prop in {}'.format(key, payload_path))

  return payload_info


def SignUncompressedApex(avbtool, apex_file, payload_key, container_key,
                         container_pw, apk_keys, codename_to_api_level_map,
                         no_hashtree, signing_args=None, sign_tool=None):
  """Signs the current uncompressed APEX with the given payload/container keys.

  Args:
    apex_file: Uncompressed APEX file.
    payload_key: The path to payload signing key (w/ extension).
    container_key: The path to container signing key (w/o extension).
    container_pw: The matching password of the container_key, or None.
    apk_keys: A dict that holds the signing keys for apk files.
    codename_to_api_level_map: A dict that maps from codename to API level.
    no_hashtree: Don't include hashtree in the signed APEX.
    signing_args: Additional args to be passed to the payload signer.
    sign_tool: A tool to sign the contents of the APEX.

  Returns:
    The path to the signed APEX file.
  """
  # 1. Extract the apex payload image and sign the files (e.g. APKs). Repack
  # the apex file after signing.
  apk_signer = ApexApkSigner(apex_file, container_pw,
                             codename_to_api_level_map,
                             avbtool, sign_tool)
  apex_file = apk_signer.ProcessApexFile(apk_keys, payload_key, signing_args)

  # 2a. Extract and sign the APEX_PAYLOAD_IMAGE entry with the given
  # payload_key.
  payload_dir = common.MakeTempDir(prefix='apex-payload-')
  with zipfile.ZipFile(apex_file) as apex_fd:
    payload_file = apex_fd.extract(APEX_PAYLOAD_IMAGE, payload_dir)
    zip_items = apex_fd.namelist()

  payload_info = ParseApexPayloadInfo(avbtool, payload_file)
  if no_hashtree is None:
    no_hashtree = payload_info.get("Tree Size", 0) == 0
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
  apex_zip = zipfile.ZipFile(apex_file, 'a', allowZip64=True)
  common.ZipWrite(apex_zip, payload_file, arcname=APEX_PAYLOAD_IMAGE)
  common.ZipWrite(apex_zip, payload_public_key, arcname=APEX_PUBKEY)
  common.ZipClose(apex_zip)

  # 3. Sign the APEX container with container_key.
  signed_apex = common.MakeTempFile(prefix='apex-container-', suffix='.apex')

  # Specify the 4K alignment when calling SignApk.
  extra_signapk_args = OPTIONS.extra_signapk_args[:]
  extra_signapk_args.extend(['-a', '4096', '--align-file-size'])

  password = container_pw.get(container_key) if container_pw else None
  common.SignFile(
      apex_file,
      signed_apex,
      container_key,
      password,
      codename_to_api_level_map=codename_to_api_level_map,
      extra_signapk_args=extra_signapk_args)

  return signed_apex


def SignCompressedApex(avbtool, apex_file, payload_key, container_key,
                       container_pw, apk_keys, codename_to_api_level_map,
                       no_hashtree, signing_args=None, sign_tool=None):
  """Signs the current compressed APEX with the given payload/container keys.

  Args:
    apex_file: Raw uncompressed APEX data.
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
  debugfs_path = os.path.join(OPTIONS.search_path, 'bin', 'debugfs_static')

  # 1. Decompress original_apex inside compressed apex.
  original_apex_file = common.MakeTempFile(prefix='original-apex-',
                                           suffix='.apex')
  # Decompression target path should not exist
  os.remove(original_apex_file)
  common.RunAndCheckOutput(['deapexer', '--debugfs_path', debugfs_path,
                            'decompress', '--input', apex_file,
                            '--output', original_apex_file])

  # 2. Sign original_apex
  signed_original_apex_file = SignUncompressedApex(
      avbtool,
      original_apex_file,
      payload_key,
      container_key,
      container_pw,
      apk_keys,
      codename_to_api_level_map,
      no_hashtree,
      signing_args,
      sign_tool)

  # 3. Compress signed original apex.
  compressed_apex_file = common.MakeTempFile(prefix='apex-container-',
                                             suffix='.capex')
  common.RunAndCheckOutput(['apex_compression_tool',
                            'compress',
                            '--apex_compression_tool_path', os.getenv('PATH'),
                            '--input', signed_original_apex_file,
                            '--output', compressed_apex_file])

  # 4. Sign the APEX container with container_key.
  signed_apex = common.MakeTempFile(prefix='apex-container-', suffix='.capex')

  password = container_pw.get(container_key) if container_pw else None
  common.SignFile(
      compressed_apex_file,
      signed_apex,
      container_key,
      password,
      codename_to_api_level_map=codename_to_api_level_map,
      extra_signapk_args=OPTIONS.extra_signapk_args)

  return signed_apex


def SignApex(avbtool, apex_data, payload_key, container_key, container_pw,
             apk_keys, codename_to_api_level_map,
             no_hashtree, signing_args=None, sign_tool=None):
  """Signs the current APEX with the given payload/container keys.

  Args:
    apex_file: Path to apex file path.
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
  apex_file = common.MakeTempFile(prefix='apex-container-', suffix='.apex')
  with open(apex_file, 'wb') as output_fp:
    output_fp.write(apex_data)

  debugfs_path = os.path.join(OPTIONS.search_path, 'bin', 'debugfs_static')
  cmd = ['deapexer', '--debugfs_path', debugfs_path,
         'info', '--print-type', apex_file]

  try:
    apex_type = common.RunAndCheckOutput(cmd).strip()
    if apex_type == 'UNCOMPRESSED':
      return SignUncompressedApex(
          avbtool,
          apex_file,
          payload_key=payload_key,
          container_key=container_key,
          container_pw=container_pw,
          codename_to_api_level_map=codename_to_api_level_map,
          no_hashtree=no_hashtree,
          apk_keys=apk_keys,
          signing_args=signing_args,
          sign_tool=sign_tool)
    elif apex_type == 'COMPRESSED':
      return SignCompressedApex(
          avbtool,
          apex_file,
          payload_key=payload_key,
          container_key=container_key,
          container_pw=container_pw,
          codename_to_api_level_map=codename_to_api_level_map,
          no_hashtree=no_hashtree,
          apk_keys=apk_keys,
          signing_args=signing_args,
          sign_tool=sign_tool)
    else:
      # TODO(b/172912232): support signing compressed apex
      raise ApexInfoError('Unsupported apex type {}'.format(apex_type))

  except common.ExternalError as e:
    raise ApexInfoError(
        'Failed to get type for {}:\n{}'.format(apex_file, e))


def GetApexInfoFromTargetFiles(input_file):
  """
  Get information about APEXes stored in the input_file zip

  Args:
    input_file: The filename of the target build target-files zip or directory.

  Return:
    A list of ota_metadata_pb2.ApexInfo() populated using the APEX stored in
    each partition of the input_file
  """

  # Extract the apex files so that we can run checks on them
  if not isinstance(input_file, str):
    raise RuntimeError("must pass filepath to target-files zip or directory")
  apex_infos = []
  for partition in ['system', 'system_ext', 'product', 'vendor']:
    apex_infos.extend(GetApexInfoForPartition(input_file, partition))
  return apex_infos


def GetApexInfoForPartition(input_file, partition):
  apex_subdir = os.path.join(partition.upper(), 'apex')
  if os.path.isdir(input_file):
    tmp_dir = input_file
  else:
    tmp_dir = UnzipTemp(input_file, [os.path.join(apex_subdir, '*')])
  target_dir = os.path.join(tmp_dir, apex_subdir)

  # Partial target-files packages for vendor-only builds may not contain
  # a system apex directory.
  if not os.path.exists(target_dir):
    logger.info('No APEX directory at path: %s', target_dir)
    return []

  apex_infos = []

  debugfs_path = "debugfs"
  if OPTIONS.search_path:
    debugfs_path = os.path.join(OPTIONS.search_path, "bin", "debugfs_static")

  deapexer = 'deapexer'
  if OPTIONS.search_path:
    deapexer_path = os.path.join(OPTIONS.search_path, "bin", "deapexer")
    if os.path.isfile(deapexer_path):
      deapexer = deapexer_path

  for apex_filename in sorted(os.listdir(target_dir)):
    apex_filepath = os.path.join(target_dir, apex_filename)
    if not os.path.isfile(apex_filepath) or \
            not zipfile.is_zipfile(apex_filepath):
      logger.info("Skipping %s because it's not a zipfile", apex_filepath)
      continue
    apex_info = ota_metadata_pb2.ApexInfo()
    # Open the apex file to retrieve information
    manifest = apex_manifest.fromApex(apex_filepath)
    apex_info.package_name = manifest.name
    apex_info.version = manifest.version
    # Check if the file is compressed or not
    apex_type = RunAndCheckOutput([
        deapexer, "--debugfs_path", debugfs_path,
        'info', '--print-type', apex_filepath]).rstrip()
    if apex_type == 'COMPRESSED':
      apex_info.is_compressed = True
    elif apex_type == 'UNCOMPRESSED':
      apex_info.is_compressed = False
    else:
      raise RuntimeError('Not an APEX file: ' + apex_type)

    # Decompress compressed APEX to determine its size
    if apex_info.is_compressed:
      decompressed_file_path = MakeTempFile(prefix="decompressed-",
                                            suffix=".apex")
      # Decompression target path should not exist
      os.remove(decompressed_file_path)
      RunAndCheckOutput([deapexer, 'decompress', '--input', apex_filepath,
                         '--output', decompressed_file_path])
      apex_info.decompressed_size = os.path.getsize(decompressed_file_path)

    apex_infos.append(apex_info)

  return apex_infos
