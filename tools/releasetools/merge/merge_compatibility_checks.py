#!/usr/bin/env python
#
# Copyright (C) 2022 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
"""Compatibility checks that should be performed on merged target_files."""

import json
import logging
import os
from xml.etree import ElementTree

import apex_utils
import check_target_files_vintf
import common
import find_shareduid_violation

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS


def CheckCompatibility(target_files_dir, partition_map):
  """Runs various compatibility checks.

  Returns a possibly-empty list of error messages.
  """
  errors = []

  errors.extend(CheckVintf(target_files_dir))
  errors.extend(CheckShareduidViolation(target_files_dir, partition_map))
  errors.extend(CheckApexDuplicatePackages(target_files_dir, partition_map))

  # The remaining checks only use the following partitions:
  partition_map = {
      partition: path
      for partition, path in partition_map.items()
      if partition in ('system', 'system_ext', 'product', 'vendor', 'odm')
  }

  errors.extend(CheckInitRcFiles(target_files_dir, partition_map))
  errors.extend(CheckCombinedSepolicy(target_files_dir, partition_map))

  return errors


def CheckVintf(target_files_dir):
  """Check for any VINTF issues using check_vintf."""
  errors = []
  try:
    if not check_target_files_vintf.CheckVintf(target_files_dir):
      errors.append('Incompatible VINTF.')
  except RuntimeError as err:
    errors.append(str(err))
  return errors


def CheckShareduidViolation(target_files_dir, partition_map):
  """Check for any APK sharedUserId violations across partition sets.

  Writes results to META/shareduid_violation_modules.json to help
  with followup debugging.
  """
  errors = []
  violation = find_shareduid_violation.FindShareduidViolation(
      target_files_dir, partition_map)
  shareduid_violation_modules = os.path.join(
      target_files_dir, 'META', 'shareduid_violation_modules.json')
  with open(shareduid_violation_modules, 'w') as f:
    # Write the output to a file to enable debugging.
    f.write(violation)

    # Check for violations across the partition sets.
    shareduid_errors = common.SharedUidPartitionViolations(
        json.loads(violation),
        [OPTIONS.framework_partition_set, OPTIONS.vendor_partition_set])
    if shareduid_errors:
      for error in shareduid_errors:
        errors.append('APK sharedUserId error: %s' % error)
      errors.append('See APK sharedUserId violations file: %s' %
                    shareduid_violation_modules)
  return errors


def CheckInitRcFiles(target_files_dir, partition_map):
  """Check for any init.rc issues using host_init_verifier."""
  try:
    common.RunHostInitVerifier(
        product_out=target_files_dir, partition_map=partition_map)
  except RuntimeError as err:
    return [str(err)]
  return []


def CheckCombinedSepolicy(target_files_dir, partition_map, execute=True):
  """Uses secilc to compile a split sepolicy file.

  Depends on various */etc/selinux/* and */etc/vintf/* files within partitions.
  """
  errors = []

  def get_file(partition, path):
    if partition not in partition_map:
      logger.warning('Cannot load SEPolicy files for missing partition %s',
                     partition)
      return None
    file_path = os.path.join(target_files_dir, partition_map[partition], path)
    if os.path.exists(file_path):
      return file_path
    return None

  # Load the kernel sepolicy version from the FCM. This is normally provided
  # directly to selinux.cpp as a build flag, but is also available in this file.
  fcm_file = get_file('system', 'etc/vintf/compatibility_matrix.device.xml')
  if not fcm_file:
    errors.append('Missing required file for loading sepolicy: '
                  '/system/etc/vintf/compatibility_matrix.device.xml')
    return errors
  kernel_sepolicy_version = ElementTree.parse(fcm_file).getroot().find(
      'sepolicy/kernel-sepolicy-version').text

  # Load the vendor's plat sepolicy version. This is the version used for
  # locating sepolicy mapping files.
  vendor_plat_version_file = get_file('vendor',
                                      'etc/selinux/plat_sepolicy_vers.txt')
  if not vendor_plat_version_file:
    errors.append('Missing required sepolicy file %s' %
                  vendor_plat_version_file)
    return errors
  with open(vendor_plat_version_file) as f:
    vendor_plat_version = f.read().strip()

  # Use the same flags and arguments as selinux.cpp OpenSplitPolicy().
  cmd = ['secilc', '-m', '-M', 'true', '-G', '-N']
  cmd.extend(['-c', kernel_sepolicy_version])
  cmd.extend(['-o', os.path.join(target_files_dir, 'META/combined_sepolicy')])
  cmd.extend(['-f', '/dev/null'])

  required_policy_files = (
      ('system', 'etc/selinux/plat_sepolicy.cil'),
      ('system', 'etc/selinux/mapping/%s.cil' % vendor_plat_version),
      ('vendor', 'etc/selinux/vendor_sepolicy.cil'),
      ('vendor', 'etc/selinux/plat_pub_versioned.cil'),
  )
  for policy in (map(lambda partition_and_path: get_file(*partition_and_path),
                     required_policy_files)):
    if not policy:
      errors.append('Missing required sepolicy file %s' % policy)
      return errors
    cmd.append(policy)

  optional_policy_files = (
      ('system', 'etc/selinux/mapping/%s.compat.cil' % vendor_plat_version),
      ('system_ext', 'etc/selinux/system_ext_sepolicy.cil'),
      ('system_ext', 'etc/selinux/mapping/%s.cil' % vendor_plat_version),
      ('product', 'etc/selinux/product_sepolicy.cil'),
      ('product', 'etc/selinux/mapping/%s.cil' % vendor_plat_version),
      ('odm', 'etc/selinux/odm_sepolicy.cil'),
  )
  for policy in (map(lambda partition_and_path: get_file(*partition_and_path),
                     optional_policy_files)):
    if policy:
      cmd.append(policy)

  try:
    if execute:
      common.RunAndCheckOutput(cmd)
    else:
      return cmd
  except RuntimeError as err:
    errors.append(str(err))

  return errors


def CheckApexDuplicatePackages(target_files_dir, partition_map):
  """Checks if the same APEX package name is provided by multiple partitions."""
  errors = []

  apex_packages = set()
  for partition in partition_map.keys():
    try:
      apex_info = apex_utils.GetApexInfoForPartition(
          target_files_dir, partition)
    except RuntimeError as err:
      errors.append(str(err))
      apex_info = []
    partition_apex_packages = set([info.package_name for info in apex_info])
    duplicates = apex_packages.intersection(partition_apex_packages)
    if duplicates:
      errors.append(
          'Duplicate APEX package_names found in multiple partitions: %s' %
          ' '.join(duplicates))
    apex_packages.update(partition_apex_packages)

  return errors
