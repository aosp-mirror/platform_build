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

import logging
import subprocess
import sys
import os
import zipfile

import common

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
  skus = info_dict.get('vintf_odm_manifest_skus', '').strip().split()
  if not skus:
    logger.info("ODM_MANIFEST_SKUS is not defined. Check once without SKUs.")
    skus = ['']
  return [['--property', 'ro.boot.product.hardware.sku=' + sku]
          for sku in skus]


def GetArgsForShippingApiLevel(info_dict):
  shipping_api_level = info_dict['vendor.build.prop'].get(
      'ro.product.first_api_level')
  if not shipping_api_level:
    logger.warning('Cannot determine ro.product.first_api_level')
    return []
  return ['--property', 'ro.product.first_api_level=' + shipping_api_level]


def GetArgsForKernel(input_tmp):
  version_path = os.path.join(input_tmp, 'META/kernel_version.txt')
  config_path = os.path.join(input_tmp, 'META/kernel_configs.txt')

  if not os.path.isfile(version_path) or not os.path.isfile(config_path):
    logger.info('Skipping kernel config checks because ' +
                'PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS is not set')
    return []

  with open(version_path) as f:
    version = f.read().strip()

  return ['--kernel', '{}:{}'.format(version, config_path)]


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
  args_for_skus = GetArgsForSkus(info_dict)
  shipping_api_level_args = GetArgsForShippingApiLevel(info_dict)
  kernel_args = GetArgsForKernel(input_tmp)

  common_command = [
      'checkvintf',
      '--check-compat',
  ]
  for device_path, real_path in dirmap.items():
    common_command += ['--dirmap', '{}:{}'.format(device_path, real_path)]
  common_command += kernel_args
  common_command += shipping_api_level_args

  success = True
  for sku_args in args_for_skus:
    command = common_command + sku_args
    proc = common.Run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode == 0:
      logger.info("Command `%s` returns 'compatible'", ' '.join(command))
    elif out.strip() == "INCOMPATIBLE":
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
      path += '*'
    for device_path, target_files_rel_paths in DIR_SEARCH_PATHS.items():
      if path.startswith(device_path):
        suffix = path[len(device_path):]
        return [rel_path + suffix for rel_path in target_files_rel_paths]
    raise RuntimeError('Unrecognized path from checkvintf --dump-file-list: ' +
                       path)

  out = common.RunAndCheckOutput(['checkvintf', '--dump-file-list'])
  paths = out.strip().split('\n')
  paths = sum((PathToPatterns(path) for path in paths if path), [])
  return paths


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
  input_tmp = common.UnzipTemp(inp, GetVintfFileList() + UNZIP_PATTERN)
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
  except common.ExternalError:
    logger.exception('\n   ERROR:\n')
    sys.exit(1)
  finally:
    common.Cleanup()
