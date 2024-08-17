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

"""
Check VINTF compatibility from a target files package.

Usage: check_target_files_vintf target_files

target_files can be a ZIP file or an extracted target files directory.
"""

import json
import logging
import os
import shutil
import subprocess
import sys
import zipfile

import apex_utils
import common
from apex_manifest import ParseApexManifest

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

# Keys are paths that VINTF searches. Must keep in sync with libvintf's search
# paths (VintfObject.cpp).
# These paths are stored in different directories in target files package, so
# we have to search for the correct path and tell checkvintf to remap them.
# Look for TARGET_COPY_OUT_* variables in board_config.mk for possible paths for
# each partition.
DIR_SEARCH_PATHS = {
    '/system': ('SYSTEM',),
    '/vendor': ('VENDOR', 'SYSTEM/vendor'),
    '/product': ('PRODUCT', 'SYSTEM/product'),
    '/odm': ('ODM', 'VENDOR/odm', 'SYSTEM/vendor/odm'),
    '/system_ext': ('SYSTEM_EXT', 'SYSTEM/system_ext'),
    # vendor_dlkm, odm_dlkm, and system_dlkm does not have VINTF files.
}

UNZIP_PATTERN = ['META/*', '*/build.prop']


def GetDirmap(input_tmp):
  dirmap = {}
  for device_path, target_files_rel_paths in DIR_SEARCH_PATHS.items():
    for target_files_rel_path in target_files_rel_paths:
      target_files_path = os.path.join(input_tmp, target_files_rel_path)
      if os.path.isdir(target_files_path):
        dirmap[device_path] = target_files_path
        break
    if device_path not in dirmap:
      raise ValueError("Can't determine path for device path " + device_path +
                       ". Searched the following:" +
                       ("\n".join(target_files_rel_paths)))
  return dirmap


def GetArgsForSkus(info_dict):
  odm_skus = info_dict.get('vintf_odm_manifest_skus', '').strip().split()
  if info_dict.get('vintf_include_empty_odm_sku', '') == "true" or not odm_skus:
    odm_skus += ['']

  vendor_skus = info_dict.get('vintf_vendor_manifest_skus', '').strip().split()
  if info_dict.get('vintf_include_empty_vendor_sku', '') == "true" or \
      not vendor_skus:
    vendor_skus += ['']

  return [['--property', 'ro.boot.product.hardware.sku=' + odm_sku,
           '--property', 'ro.boot.product.vendor.sku=' + vendor_sku]
          for odm_sku in odm_skus for vendor_sku in vendor_skus]


def GetArgsForShippingApiLevel(info_dict):
  shipping_api_level = info_dict['vendor.build.prop'].GetProp(
      'ro.product.first_api_level')
  if not shipping_api_level:
    logger.warning('Cannot determine ro.product.first_api_level')
    return []
  return ['--property', 'ro.product.first_api_level=' + shipping_api_level]


def GetArgsForKernel(input_tmp):
  version_path = os.path.join(input_tmp, 'META/kernel_version.txt')
  config_path = os.path.join(input_tmp, 'META/kernel_configs.txt')

  if not os.path.isfile(version_path) or not os.path.isfile(config_path):
    logger.info('Skipping kernel config checks because '
                'PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS is not set')
    return []

  return ['--kernel', '{}:{}'.format(version_path, config_path)]


def CheckVintfFromExtractedTargetFiles(input_tmp, info_dict=None):
  """
  Checks VINTF metadata of an extracted target files directory.

  Args:
    inp: path to the directory that contains the extracted target files archive.
    info_dict: The build-time info dict. If None, it will be loaded from inp.

  Returns:
    True if VINTF check is skipped or compatible, False if incompatible. Raise
    a RuntimeError if any error occurs.
  """

  if info_dict is None:
    info_dict = common.LoadInfoDict(input_tmp)

  if info_dict.get('vintf_enforce') != 'true':
    logger.warning('PRODUCT_ENFORCE_VINTF_MANIFEST is not set, skipping checks')
    return True


  dirmap = GetDirmap(input_tmp)

  # Simulate apexd with target-files.
  # add a mapping('/apex' => ${input_tmp}/APEX) to dirmap
  PrepareApexDirectory(input_tmp, dirmap)

  args_for_skus = GetArgsForSkus(info_dict)
  shipping_api_level_args = GetArgsForShippingApiLevel(info_dict)
  kernel_args = GetArgsForKernel(input_tmp)

  common_command = [
      'checkvintf',
      '--check-compat',
  ]

  for device_path, real_path in sorted(dirmap.items()):
    common_command += ['--dirmap', '{}:{}'.format(device_path, real_path)]
  common_command += kernel_args
  common_command += shipping_api_level_args

  success = True
  for sku_args in args_for_skus:
    command = common_command + sku_args
    proc = common.Run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    last_out_line = out.split()[-1] if out != "" else out
    if proc.returncode == 0:
      logger.info("Command `%s` returns 'compatible'", ' '.join(command))
    elif last_out_line.strip() == "INCOMPATIBLE":
      logger.info("Command `%s` returns 'incompatible'", ' '.join(command))
      success = False
    else:
      raise common.ExternalError(
          "Failed to run command '{}' (exit code {}):\nstdout:{}\nstderr:{}"
          .format(' '.join(command), proc.returncode, out, err))
    logger.info("stdout: %s", out)
    logger.info("stderr: %s", err)

  return success


def GetVintfFileList():
  """
  Returns a list of VINTF metadata files that should be read from a target files
  package before executing checkvintf.
  """
  def PathToPatterns(path):
    if path[-1] == '/':
      path += '**'

    # Loop over all the entries in DIR_SEARCH_PATHS and find one where the key
    # is a prefix of path. In order to get find the correct prefix, sort the
    # entries by decreasing length of their keys, so that we check if longer
    # strings are prefixes before shorter strings. This is so that keys that
    # are substrings of other keys (like /system vs /system_ext) are checked
    # later, and we don't mistakenly mark a path that starts with /system_ext
    # as starting with only /system.
    for device_path, target_files_rel_paths in sorted(DIR_SEARCH_PATHS.items(), key=lambda i: len(i[0]), reverse=True):
      if path.startswith(device_path):
        suffix = path[len(device_path):]
        return [rel_path + suffix for rel_path in target_files_rel_paths]
    raise RuntimeError('Unrecognized path from checkvintf --dump-file-list: ' +
                       path)

  out = common.RunAndCheckOutput(['checkvintf', '--dump-file-list'])
  paths = out.strip().split('\n')
  paths = sum((PathToPatterns(path) for path in paths if path), [])
  return paths

def GetVintfApexUnzipPatterns():
  """ Build unzip pattern for APEXes. """
  patterns = []
  for target_files_rel_paths in DIR_SEARCH_PATHS.values():
    for target_files_rel_path in target_files_rel_paths:
      patterns.append(os.path.join(target_files_rel_path,"apex/*"))

  return patterns


def PrepareApexDirectory(inp, dirmap):
  """ Prepare /apex directory before running checkvintf

  Apex binaries do not support dirmaps, in order to use these binaries we
  need to move the APEXes from the extracted target file archives to the
  expected device locations.

  This simulates how apexd activates APEXes.
  1. create {inp}/APEX which is treated as a "/apex" on device.
  2. invoke apexd_host with APEXes.
  """

  apex_dir = common.MakeTempDir('APEX')
  # checkvintf needs /apex dirmap
  dirmap['/apex'] = apex_dir

  # Always create /apex directory for dirmap
  os.makedirs(apex_dir, exist_ok=True)

  # Invoke apexd_host to activate APEXes for checkvintf
  apex_host = os.path.join(OPTIONS.search_path, 'bin', 'apexd_host')
  cmd = [apex_host, '--tool_path', OPTIONS.search_path]
  cmd += ['--apex_path', dirmap['/apex']]
  for p in apex_utils.PARTITIONS:
    if '/' + p in dirmap:
      cmd += ['--' + p + '_path', dirmap['/' + p]]
  common.RunAndCheckOutput(cmd)


def CheckVintfFromTargetFiles(inp, info_dict=None):
  """
  Checks VINTF metadata of a target files zip.

  Args:
    inp: path to the target files archive.
    info_dict: The build-time info dict. If None, it will be loaded from inp.

  Returns:
    True if VINTF check is skipped or compatible, False if incompatible. Raise
    a RuntimeError if any error occurs.
  """
  input_tmp = common.UnzipTemp(inp, GetVintfFileList() + GetVintfApexUnzipPatterns() + UNZIP_PATTERN)
  return CheckVintfFromExtractedTargetFiles(input_tmp, info_dict)


def CheckVintf(inp, info_dict=None):
  """
  Checks VINTF metadata of a target files zip or extracted target files
  directory.

  Args:
    inp: path to the (possibly extracted) target files archive.
    info_dict: The build-time info dict. If None, it will be loaded from inp.

  Returns:
    True if VINTF check is skipped or compatible, False if incompatible. Raise
    a RuntimeError if any error occurs.
  """
  if os.path.isdir(inp):
    logger.info('Checking VINTF compatibility extracted target files...')
    return CheckVintfFromExtractedTargetFiles(inp, info_dict)

  if zipfile.is_zipfile(inp):
    logger.info('Checking VINTF compatibility target files...')
    return CheckVintfFromTargetFiles(inp, info_dict)

  raise ValueError('{} is not a valid directory or zip file'.format(inp))

def CheckVintfIfTrebleEnabled(target_files, target_info):
  """Checks compatibility info of the input target files.

  Metadata used for compatibility verification is retrieved from target_zip.

  Compatibility should only be checked for devices that have enabled
  Treble support.

  Args:
    target_files: Path to zip file containing the source files to be included
        for OTA. Can also be the path to extracted directory.
    target_info: The BuildInfo instance that holds the target build info.
  """

  # Will only proceed if the target has enabled the Treble support (as well as
  # having a /vendor partition).
  if not HasTrebleEnabled(target_files, target_info):
    return

  # Skip adding the compatibility package as a workaround for b/114240221. The
  # compatibility will always fail on devices without qualified kernels.
  if OPTIONS.skip_compatibility_check:
    return

  if not CheckVintf(target_files, target_info):
    raise RuntimeError("VINTF compatibility check failed")

def HasTrebleEnabled(target_files, target_info):
  def HasVendorPartition(target_files):
    if os.path.isdir(target_files):
      return os.path.isdir(os.path.join(target_files, "VENDOR"))
    if zipfile.is_zipfile(target_files):
      return HasPartition(zipfile.ZipFile(target_files, allowZip64=True), "vendor")
    raise ValueError("Unknown target_files argument")

  return (HasVendorPartition(target_files) and
          target_info.GetBuildProp("ro.treble.enabled") == "true")


def HasPartition(target_files_zip, partition):
  try:
    target_files_zip.getinfo(partition.upper() + "/")
    return True
  except KeyError:
    return False


def main(argv):
  args = common.ParseOptions(argv, __doc__)
  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)
  common.InitLogging()
  if not CheckVintf(args[0]):
    sys.exit(1)


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  finally:
    common.Cleanup()
