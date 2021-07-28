#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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
"""This script merges two partial target files packages.

One input package contains framework files, and the other contains vendor files.

This script produces a complete, merged target files package:
  - This package can be used to generate a flashable IMG package.
    See --output-img.
  - This package can be used to generate an OTA package. See --output-ota.
  - The merged package is checked for compatibility between the two inputs.

Usage: merge_target_files [args]

  --framework-target-files framework-target-files-zip-archive
      The input target files package containing framework bits. This is a zip
      archive.

  --framework-item-list framework-item-list-file
      The optional path to a newline-separated config file that replaces the
      contents of DEFAULT_FRAMEWORK_ITEM_LIST if provided.

  --framework-misc-info-keys framework-misc-info-keys-file
      The optional path to a newline-separated config file that replaces the
      contents of DEFAULT_FRAMEWORK_MISC_INFO_KEYS if provided.

  --vendor-target-files vendor-target-files-zip-archive
      The input target files package containing vendor bits. This is a zip
      archive.

  --vendor-item-list vendor-item-list-file
      The optional path to a newline-separated config file that replaces the
      contents of DEFAULT_VENDOR_ITEM_LIST if provided.

  --output-target-files output-target-files-package
      If provided, the output merged target files package. Also a zip archive.

  --output-dir output-directory
      If provided, the destination directory for saving merged files. Requires
      the --output-item-list flag.
      Can be provided alongside --output-target-files, or by itself.

  --output-item-list output-item-list-file.
      The optional path to a newline-separated config file that specifies the
      file patterns to copy into the --output-dir. Required if providing
      the --output-dir flag.

  --output-ota output-ota-package
      The output ota package. This is a zip archive. Use of this flag may
      require passing the --path common flag; see common.py.

  --output-img output-img-package
      The output img package, suitable for use with 'fastboot update'. Use of
      this flag may require passing the --path common flag; see common.py.

  --output-super-empty output-super-empty-image
      If provided, creates a super_empty.img file from the merged target
      files package and saves it at this path.

  --rebuild_recovery
      Deprecated; does nothing.

  --allow-duplicate-apkapex-keys
      If provided, duplicate APK/APEX keys are ignored and the value from the
      framework is used.

  --rebuild-sepolicy
      If provided, rebuilds odm.img or vendor.img to include merged sepolicy
      files. If odm is present then odm is preferred.

  --vendor-otatools otatools.zip
      If provided, use this otatools.zip when recompiling the odm or vendor
      image to include sepolicy.

  --keep-tmp
      Keep tempoary files for debugging purposes.

  The following only apply when using the VSDK to perform dexopt on vendor apps:

  --framework-dexpreopt-config
      If provided, the location of framwework's dexpreopt_config.zip.

  --framework-dexpreopt-tools
      if provided, the location of framework's dexpreopt_tools.zip.

  --vendor-dexpreopt-config
      If provided, the location of vendor's dexpreopt_config.zip.
"""

from __future__ import print_function

import fnmatch
import glob
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import zipfile
from xml.etree import ElementTree

import add_img_to_target_files
import apex_utils
import build_image
import build_super_image
import check_target_files_vintf
import common
import img_from_target_files
import find_shareduid_violation
import ota_from_target_files
import sparse_img
import verity_utils

from common import AddCareMapForAbOta, ExternalError, PARTITIONS_WITH_CARE_MAP

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
# Always turn on verbose logging.
OPTIONS.verbose = True
OPTIONS.framework_target_files = None
OPTIONS.framework_item_list = None
OPTIONS.framework_misc_info_keys = None
OPTIONS.vendor_target_files = None
OPTIONS.vendor_item_list = None
OPTIONS.output_target_files = None
OPTIONS.output_dir = None
OPTIONS.output_item_list = None
OPTIONS.output_ota = None
OPTIONS.output_img = None
OPTIONS.output_super_empty = None
# TODO(b/132730255): Remove this option.
OPTIONS.rebuild_recovery = False
# TODO(b/150582573): Remove this option.
OPTIONS.allow_duplicate_apkapex_keys = False
OPTIONS.vendor_otatools = None
OPTIONS.rebuild_sepolicy = False
OPTIONS.keep_tmp = False
OPTIONS.framework_dexpreopt_config = None
OPTIONS.framework_dexpreopt_tools = None
OPTIONS.vendor_dexpreopt_config = None

# In an item list (framework or vendor), we may see entries that select whole
# partitions. Such an entry might look like this 'SYSTEM/*' (e.g., for the
# system partition). The following regex matches this and extracts the
# partition name.

PARTITION_ITEM_PATTERN = re.compile(r'^([A-Z_]+)/\*$')

# In apexkeys.txt or apkcerts.txt, we will find partition tags on each entry in
# the file. We use these partition tags to filter the entries in those files
# from the two different target files packages to produce a merged apexkeys.txt
# or apkcerts.txt file. A partition tag (e.g., for the product partition) looks
# like this: 'partition="product"'. We use the group syntax grab the value of
# the tag. We use non-greedy matching in case there are other fields on the
# same line.

PARTITION_TAG_PATTERN = re.compile(r'partition="(.*?)"')

# The sorting algorithm for apexkeys.txt and apkcerts.txt does not include the
# ".apex" or ".apk" suffix, so we use the following pattern to extract a key.

MODULE_KEY_PATTERN = re.compile(r'name="(.+)\.(apex|apk)"')

# DEFAULT_FRAMEWORK_ITEM_LIST is a list of items to extract from the partial
# framework target files package as is, meaning these items will land in the
# output target files package exactly as they appear in the input partial
# framework target files package.

DEFAULT_FRAMEWORK_ITEM_LIST = (
    'META/apkcerts.txt',
    'META/filesystem_config.txt',
    'META/root_filesystem_config.txt',
    'META/update_engine_config.txt',
    'PRODUCT/*',
    'ROOT/*',
    'SYSTEM/*',
)

# DEFAULT_FRAMEWORK_MISC_INFO_KEYS is a list of keys to obtain from the
# framework instance of META/misc_info.txt. The remaining keys should come
# from the vendor instance.

DEFAULT_FRAMEWORK_MISC_INFO_KEYS = (
    'avb_system_hashtree_enable',
    'avb_system_add_hashtree_footer_args',
    'avb_system_key_path',
    'avb_system_algorithm',
    'avb_system_rollback_index_location',
    'avb_product_hashtree_enable',
    'avb_product_add_hashtree_footer_args',
    'avb_system_ext_hashtree_enable',
    'avb_system_ext_add_hashtree_footer_args',
    'system_root_image',
    'root_dir',
    'ab_update',
    'default_system_dev_certificate',
    'system_size',
    'building_system_image',
    'building_system_ext_image',
    'building_product_image',
)

# DEFAULT_VENDOR_ITEM_LIST is a list of items to extract from the partial
# vendor target files package as is, meaning these items will land in the output
# target files package exactly as they appear in the input partial vendor target
# files package.

DEFAULT_VENDOR_ITEM_LIST = (
    'META/boot_filesystem_config.txt',
    'META/otakeys.txt',
    'META/releasetools.py',
    'META/vendor_filesystem_config.txt',
    'BOOT/*',
    'DATA/*',
    'ODM/*',
    'OTA/android-info.txt',
    'PREBUILT_IMAGES/*',
    'RADIO/*',
    'VENDOR/*',
)

# The merge config lists should not attempt to extract items from both
# builds for any of the following partitions. The partitions in
# SINGLE_BUILD_PARTITIONS should come entirely from a single build (either
# framework or vendor, but not both).

SINGLE_BUILD_PARTITIONS = (
    'BOOT/',
    'DATA/',
    'ODM/',
    'PRODUCT/',
    'SYSTEM_EXT/',
    'RADIO/',
    'RECOVERY/',
    'ROOT/',
    'SYSTEM/',
    'SYSTEM_OTHER/',
    'VENDOR/',
    'VENDOR_DLKM/',
    'ODM_DLKM/',
)


def write_sorted_data(data, path):
  """Writes the sorted contents of either a list or dict to file.

  This function sorts the contents of the list or dict and then writes the
  resulting sorted contents to a file specified by path.

  Args:
    data: The list or dict to sort and write.
    path: Path to the file to write the sorted values to. The file at path will
      be overridden if it exists.
  """
  with open(path, 'w') as output:
    for entry in sorted(data):
      out_str = '{}={}\n'.format(entry, data[entry]) if isinstance(
          data, dict) else '{}\n'.format(entry)
      output.write(out_str)


def extract_items(target_files, target_files_temp_dir, extract_item_list):
  """Extracts items from target files to temporary directory.

  This function extracts from the specified target files zip archive into the
  specified temporary directory, the items specified in the extract item list.

  Args:
    target_files: The target files zip archive from which to extract items.
    target_files_temp_dir: The temporary directory where the extracted items
      will land.
    extract_item_list: A list of items to extract.
  """

  logger.info('extracting from %s', target_files)

  # Filter the extract_item_list to remove any items that do not exist in the
  # zip file. Otherwise, the extraction step will fail.

  with zipfile.ZipFile(target_files, allowZip64=True) as target_files_zipfile:
    target_files_namelist = target_files_zipfile.namelist()

  filtered_extract_item_list = []
  for pattern in extract_item_list:
    matching_namelist = fnmatch.filter(target_files_namelist, pattern)
    if not matching_namelist:
      logger.warning('no match for %s', pattern)
    else:
      filtered_extract_item_list.append(pattern)

  # Extract from target_files into target_files_temp_dir the
  # filtered_extract_item_list.

  common.UnzipToDir(target_files, target_files_temp_dir,
                    filtered_extract_item_list)


def copy_items(from_dir, to_dir, patterns):
  """Similar to extract_items() except uses an input dir instead of zip."""
  file_paths = []
  for dirpath, _, filenames in os.walk(from_dir):
    file_paths.extend(
        os.path.relpath(path=os.path.join(dirpath, filename), start=from_dir)
        for filename in filenames)

  filtered_file_paths = set()
  for pattern in patterns:
    filtered_file_paths.update(fnmatch.filter(file_paths, pattern))

  for file_path in filtered_file_paths:
    original_file_path = os.path.join(from_dir, file_path)
    copied_file_path = os.path.join(to_dir, file_path)
    copied_file_dir = os.path.dirname(copied_file_path)
    if not os.path.exists(copied_file_dir):
      os.makedirs(copied_file_dir)
    if os.path.islink(original_file_path):
      os.symlink(os.readlink(original_file_path), copied_file_path)
    else:
      shutil.copyfile(original_file_path, copied_file_path)


def validate_config_lists(framework_item_list, framework_misc_info_keys,
                          vendor_item_list):
  """Performs validations on the merge config lists.

  Args:
    framework_item_list: The list of items to extract from the partial framework
      target files package as is.
    framework_misc_info_keys: A list of keys to obtain from the framework
      instance of META/misc_info.txt. The remaining keys should come from the
      vendor instance.
    vendor_item_list: The list of items to extract from the partial vendor
      target files package as is.

  Returns:
    False if a validation fails, otherwise true.
  """
  has_error = False

  default_combined_item_set = set(DEFAULT_FRAMEWORK_ITEM_LIST)
  default_combined_item_set.update(DEFAULT_VENDOR_ITEM_LIST)

  combined_item_set = set(framework_item_list)
  combined_item_set.update(vendor_item_list)

  # Check that the merge config lists are not missing any item specified
  # by the default config lists.
  difference = default_combined_item_set.difference(combined_item_set)
  if difference:
    logger.error('Missing merge config items: %s', list(difference))
    logger.error('Please ensure missing items are in either the '
                 'framework-item-list or vendor-item-list files provided to '
                 'this script.')
    has_error = True

  # Check that partitions only come from one input.
  for partition in SINGLE_BUILD_PARTITIONS:
    image_path = 'IMAGES/{}.img'.format(partition.lower().replace('/', ''))
    in_framework = (
        any(item.startswith(partition) for item in framework_item_list) or
        image_path in framework_item_list)
    in_vendor = (
        any(item.startswith(partition) for item in vendor_item_list) or
        image_path in vendor_item_list)
    if in_framework and in_vendor:
      logger.error(
          'Cannot extract items from %s for both the framework and vendor'
          ' builds. Please ensure only one merge config item list'
          ' includes %s.', partition, partition)
      has_error = True

  if ('dynamic_partition_list'
      in framework_misc_info_keys) or ('super_partition_groups'
                                       in framework_misc_info_keys):
    logger.error('Dynamic partition misc info keys should come from '
                 'the vendor instance of META/misc_info.txt.')
    has_error = True

  return not has_error


def process_ab_partitions_txt(framework_target_files_temp_dir,
                              vendor_target_files_temp_dir,
                              output_target_files_temp_dir):
  """Performs special processing for META/ab_partitions.txt.

  This function merges the contents of the META/ab_partitions.txt files from the
  framework directory and the vendor directory, placing the merged result in the
  output directory. The precondition in that the files are already extracted.
  The post condition is that the output META/ab_partitions.txt contains the
  merged content. The format for each ab_partitions.txt is one partition name
  per line. The output file contains the union of the partition names.

  Args:
    framework_target_files_temp_dir: The name of a directory containing the
      special items extracted from the framework target files package.
    vendor_target_files_temp_dir: The name of a directory containing the special
      items extracted from the vendor target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
  """

  framework_ab_partitions_txt = os.path.join(framework_target_files_temp_dir,
                                             'META', 'ab_partitions.txt')

  vendor_ab_partitions_txt = os.path.join(vendor_target_files_temp_dir, 'META',
                                          'ab_partitions.txt')

  with open(framework_ab_partitions_txt) as f:
    framework_ab_partitions = f.read().splitlines()

  with open(vendor_ab_partitions_txt) as f:
    vendor_ab_partitions = f.read().splitlines()

  output_ab_partitions = set(framework_ab_partitions + vendor_ab_partitions)

  output_ab_partitions_txt = os.path.join(output_target_files_temp_dir, 'META',
                                          'ab_partitions.txt')

  write_sorted_data(data=output_ab_partitions, path=output_ab_partitions_txt)


def process_misc_info_txt(framework_target_files_temp_dir,
                          vendor_target_files_temp_dir,
                          output_target_files_temp_dir,
                          framework_misc_info_keys):
  """Performs special processing for META/misc_info.txt.

  This function merges the contents of the META/misc_info.txt files from the
  framework directory and the vendor directory, placing the merged result in the
  output directory. The precondition in that the files are already extracted.
  The post condition is that the output META/misc_info.txt contains the merged
  content.

  Args:
    framework_target_files_temp_dir: The name of a directory containing the
      special items extracted from the framework target files package.
    vendor_target_files_temp_dir: The name of a directory containing the special
      items extracted from the vendor target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
    framework_misc_info_keys: A list of keys to obtain from the framework
      instance of META/misc_info.txt. The remaining keys should come from the
      vendor instance.
  """

  misc_info_path = ['META', 'misc_info.txt']
  framework_dict = common.LoadDictionaryFromFile(
      os.path.join(framework_target_files_temp_dir, *misc_info_path))

  # We take most of the misc info from the vendor target files.

  merged_dict = common.LoadDictionaryFromFile(
      os.path.join(vendor_target_files_temp_dir, *misc_info_path))

  # Replace certain values in merged_dict with values from
  # framework_dict.

  for key in framework_misc_info_keys:
    merged_dict[key] = framework_dict[key]

  # Merge misc info keys used for Dynamic Partitions.
  if (merged_dict.get('use_dynamic_partitions')
      == 'true') and (framework_dict.get('use_dynamic_partitions') == 'true'):
    merged_dynamic_partitions_dict = common.MergeDynamicPartitionInfoDicts(
        framework_dict=framework_dict, vendor_dict=merged_dict)
    merged_dict.update(merged_dynamic_partitions_dict)
    # Ensure that add_img_to_target_files rebuilds super split images for
    # devices that retrofit dynamic partitions. This flag may have been set to
    # false in the partial builds to prevent duplicate building of super.img.
    merged_dict['build_super_partition'] = 'true'

  # If AVB is enabled then ensure that we build vbmeta.img.
  # Partial builds with AVB enabled may set PRODUCT_BUILD_VBMETA_IMAGE=false to
  # skip building an incomplete vbmeta.img.
  if merged_dict.get('avb_enable') == 'true':
    merged_dict['avb_building_vbmeta_image'] = 'true'

  # Replace <image>_selinux_fc values with framework or vendor file_contexts.bin
  # depending on which dictionary the key came from.
  # Only the file basename is required because all selinux_fc properties are
  # replaced with the full path to the file under META/ when misc_info.txt is
  # loaded from target files for repacking. See common.py LoadInfoDict().
  for key in merged_dict:
    if key.endswith('_selinux_fc'):
      merged_dict[key] = 'vendor_file_contexts.bin'
  for key in framework_dict:
    if key.endswith('_selinux_fc'):
      merged_dict[key] = 'framework_file_contexts.bin'

  output_misc_info_txt = os.path.join(output_target_files_temp_dir, 'META',
                                      'misc_info.txt')
  write_sorted_data(data=merged_dict, path=output_misc_info_txt)


def process_dynamic_partitions_info_txt(framework_target_files_dir,
                                        vendor_target_files_dir,
                                        output_target_files_dir):
  """Performs special processing for META/dynamic_partitions_info.txt.

  This function merges the contents of the META/dynamic_partitions_info.txt
  files from the framework directory and the vendor directory, placing the
  merged result in the output directory.

  This function does nothing if META/dynamic_partitions_info.txt from the vendor
  directory does not exist.

  Args:
    framework_target_files_dir: The name of a directory containing the special
      items extracted from the framework target files package.
    vendor_target_files_dir: The name of a directory containing the special
      items extracted from the vendor target files package.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
  """

  if not os.path.exists(
      os.path.join(vendor_target_files_dir, 'META',
                   'dynamic_partitions_info.txt')):
    return

  dynamic_partitions_info_path = ['META', 'dynamic_partitions_info.txt']

  framework_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(framework_target_files_dir, *dynamic_partitions_info_path))
  vendor_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(vendor_target_files_dir, *dynamic_partitions_info_path))

  merged_dynamic_partitions_dict = common.MergeDynamicPartitionInfoDicts(
      framework_dict=framework_dynamic_partitions_dict,
      vendor_dict=vendor_dynamic_partitions_dict)

  output_dynamic_partitions_info_txt = os.path.join(
      output_target_files_dir, 'META', 'dynamic_partitions_info.txt')
  write_sorted_data(
      data=merged_dynamic_partitions_dict,
      path=output_dynamic_partitions_info_txt)


def item_list_to_partition_set(item_list):
  """Converts a target files item list to a partition set.

  The item list contains items that might look like 'SYSTEM/*' or 'VENDOR/*' or
  'OTA/android-info.txt'. Items that end in '/*' are assumed to match entire
  directories where 'SYSTEM' or 'VENDOR' is a directory name that identifies the
  contents of a partition of the same name. Other items in the list, such as the
  'OTA' example contain metadata. This function iterates such a list, returning
  a set that contains the partition entries.

  Args:
    item_list: A list of items in a target files package.

  Returns:
    A set of partitions extracted from the list of items.
  """

  partition_set = set()

  for item in item_list:
    match = PARTITION_ITEM_PATTERN.search(item.strip())
    partition_tag = match.group(1).lower() if match else None

    if partition_tag:
      partition_set.add(partition_tag)

  return partition_set


def process_apex_keys_apk_certs_common(framework_target_files_dir,
                                       vendor_target_files_dir,
                                       output_target_files_dir,
                                       framework_partition_set,
                                       vendor_partition_set, file_name):
  """Performs special processing for META/apexkeys.txt or META/apkcerts.txt.

  This function merges the contents of the META/apexkeys.txt or
  META/apkcerts.txt files from the framework directory and the vendor directory,
  placing the merged result in the output directory. The precondition in that
  the files are already extracted. The post condition is that the output
  META/apexkeys.txt or META/apkcerts.txt contains the merged content.

  Args:
    framework_target_files_dir: The name of a directory containing the special
      items extracted from the framework target files package.
    vendor_target_files_dir: The name of a directory containing the special
      items extracted from the vendor target files package.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
    framework_partition_set: Partitions that are considered framework
      partitions. Used to filter apexkeys.txt and apkcerts.txt.
    vendor_partition_set: Partitions that are considered vendor partitions. Used
      to filter apexkeys.txt and apkcerts.txt.
    file_name: The name of the file to merge. One of apkcerts.txt or
      apexkeys.txt.
  """

  def read_helper(d):
    temp = {}
    file_path = os.path.join(d, 'META', file_name)
    with open(file_path) as f:
      for line in f:
        if line.strip():
          name = line.split()[0]
          match = MODULE_KEY_PATTERN.search(name)
          temp[match.group(1)] = line.strip()
    return temp

  framework_dict = read_helper(framework_target_files_dir)
  vendor_dict = read_helper(vendor_target_files_dir)
  merged_dict = {}

  def filter_into_merged_dict(item_dict, partition_set):
    for key, value in item_dict.items():
      match = PARTITION_TAG_PATTERN.search(value)

      if match is None:
        raise ValueError('Entry missing partition tag: %s' % value)

      partition_tag = match.group(1)

      if partition_tag in partition_set:
        if key in merged_dict:
          if OPTIONS.allow_duplicate_apkapex_keys:
            # TODO(b/150582573) Always raise on duplicates.
            logger.warning('Duplicate key %s' % key)
            continue
          else:
            raise ValueError('Duplicate key %s' % key)

        merged_dict[key] = value

  filter_into_merged_dict(framework_dict, framework_partition_set)
  filter_into_merged_dict(vendor_dict, vendor_partition_set)

  output_file = os.path.join(output_target_files_dir, 'META', file_name)

  # The following code is similar to write_sorted_data, but different enough
  # that we couldn't use that function. We need the output to be sorted by the
  # basename of the apex/apk (without the ".apex" or ".apk" suffix). This
  # allows the sort to be consistent with the framework/vendor input data and
  # eases comparison of input data with merged data.
  with open(output_file, 'w') as output:
    for key in sorted(merged_dict.keys()):
      out_str = merged_dict[key] + '\n'
      output.write(out_str)


def copy_file_contexts(framework_target_files_dir, vendor_target_files_dir,
                       output_target_files_dir):
  """Creates named copies of each build's file_contexts.bin in output META/."""
  framework_fc_path = os.path.join(framework_target_files_dir, 'META',
                                   'framework_file_contexts.bin')
  if not os.path.exists(framework_fc_path):
    framework_fc_path = os.path.join(framework_target_files_dir, 'META',
                                     'file_contexts.bin')
    if not os.path.exists(framework_fc_path):
      raise ValueError('Missing framework file_contexts.bin.')
  shutil.copyfile(
      framework_fc_path,
      os.path.join(output_target_files_dir, 'META',
                   'framework_file_contexts.bin'))

  vendor_fc_path = os.path.join(vendor_target_files_dir, 'META',
                                'vendor_file_contexts.bin')
  if not os.path.exists(vendor_fc_path):
    vendor_fc_path = os.path.join(vendor_target_files_dir, 'META',
                                  'file_contexts.bin')
    if not os.path.exists(vendor_fc_path):
      raise ValueError('Missing vendor file_contexts.bin.')
  shutil.copyfile(
      vendor_fc_path,
      os.path.join(output_target_files_dir, 'META', 'vendor_file_contexts.bin'))


def compile_split_sepolicy(product_out, partition_map):
  """Uses secilc to compile a split sepolicy file.

  Depends on various */etc/selinux/* and */etc/vintf/* files within partitions.

  Args:
    product_out: PRODUCT_OUT directory, containing partition directories.
    partition_map: A map of partition name -> relative path within product_out.

  Returns:
    A command list that can be executed to create the compiled sepolicy.
  """

  def get_file(partition, path):
    if partition not in partition_map:
      logger.warning('Cannot load SEPolicy files for missing partition %s',
                     partition)
      return None
    return os.path.join(product_out, partition_map[partition], path)

  # Load the kernel sepolicy version from the FCM. This is normally provided
  # directly to selinux.cpp as a build flag, but is also available in this file.
  fcm_file = get_file('system', 'etc/vintf/compatibility_matrix.device.xml')
  if not fcm_file or not os.path.exists(fcm_file):
    raise ExternalError('Missing required file for loading sepolicy: %s', fcm)
  kernel_sepolicy_version = ElementTree.parse(fcm_file).getroot().find(
      'sepolicy/kernel-sepolicy-version').text

  # Load the vendor's plat sepolicy version. This is the version used for
  # locating sepolicy mapping files.
  vendor_plat_version_file = get_file('vendor',
                                      'etc/selinux/plat_sepolicy_vers.txt')
  if not vendor_plat_version_file or not os.path.exists(
      vendor_plat_version_file):
    raise ExternalError('Missing required sepolicy file %s',
                        vendor_plat_version_file)
  with open(vendor_plat_version_file) as f:
    vendor_plat_version = f.read().strip()

  # Use the same flags and arguments as selinux.cpp OpenSplitPolicy().
  cmd = ['secilc', '-m', '-M', 'true', '-G', '-N']
  cmd.extend(['-c', kernel_sepolicy_version])
  cmd.extend(['-o', os.path.join(product_out, 'META/combined_sepolicy')])
  cmd.extend(['-f', '/dev/null'])

  required_policy_files = (
      ('system', 'etc/selinux/plat_sepolicy.cil'),
      ('system', 'etc/selinux/mapping/%s.cil' % vendor_plat_version),
      ('vendor', 'etc/selinux/vendor_sepolicy.cil'),
      ('vendor', 'etc/selinux/plat_pub_versioned.cil'),
  )
  for policy in (map(lambda partition_and_path: get_file(*partition_and_path),
                     required_policy_files)):
    if not policy or not os.path.exists(policy):
      raise ExternalError('Missing required sepolicy file %s', policy)
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
    if policy and os.path.exists(policy):
      cmd.append(policy)

  return cmd


def validate_merged_apex_info(output_target_files_dir, partitions):
  """Validates the APEX files in the merged target files directory.

  Checks the APEX files in all possible preinstalled APEX directories.
  Depends on the <partition>/apex/* APEX files within partitions.

  Args:
    output_target_files_dir: Output directory containing merged partition
      directories.
    partitions: A list of all the partitions in the output directory.

  Raises:
    RuntimeError: if apex_utils fails to parse any APEX file.
    ExternalError: if the same APEX package is provided by multiple partitions.
  """
  apex_packages = set()

  apex_partitions = ('system', 'system_ext', 'product', 'vendor')
  for partition in filter(lambda p: p in apex_partitions, partitions):
    apex_info = apex_utils.GetApexInfoFromTargetFiles(
        output_target_files_dir, partition, compressed_only=False)
    partition_apex_packages = set([info.package_name for info in apex_info])
    duplicates = apex_packages.intersection(partition_apex_packages)
    if duplicates:
      raise ExternalError(
          'Duplicate APEX packages found in multiple partitions: %s' %
          ' '.join(duplicates))
    apex_packages.update(partition_apex_packages)


def generate_care_map(partitions, output_target_files_dir):
  """Generates a merged META/care_map.pb file in the output target files dir.

  Depends on the info dict from META/misc_info.txt, as well as built images
  within IMAGES/.

  Args:
    partitions: A list of partitions to potentially include in the care map.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
  """
  OPTIONS.info_dict = common.LoadInfoDict(output_target_files_dir)
  partition_image_map = {}
  for partition in partitions:
    image_path = os.path.join(output_target_files_dir, 'IMAGES',
                              '{}.img'.format(partition))
    if os.path.exists(image_path):
      partition_image_map[partition] = image_path
      # Regenerated images should have their image_size property already set.
      image_size_prop = '{}_image_size'.format(partition)
      if image_size_prop not in OPTIONS.info_dict:
        # Images copied directly from input target files packages will need
        # their image sizes calculated.
        partition_size = sparse_img.GetImagePartitionSize(image_path)
        image_props = build_image.ImagePropFromGlobalDict(
            OPTIONS.info_dict, partition)
        verity_image_builder = verity_utils.CreateVerityImageBuilder(
            image_props)
        image_size = verity_image_builder.CalculateMaxImageSize(partition_size)
        OPTIONS.info_dict[image_size_prop] = image_size

  AddCareMapForAbOta(
      os.path.join(output_target_files_dir, 'META', 'care_map.pb'),
      PARTITIONS_WITH_CARE_MAP, partition_image_map)


def process_special_cases(temp_dir, framework_meta, vendor_meta,
                          output_target_files_temp_dir,
                          framework_misc_info_keys, framework_partition_set,
                          vendor_partition_set, framework_dexpreopt_tools,
                          framework_dexpreopt_config, vendor_dexpreopt_config):
  """Performs special-case processing for certain target files items.

  Certain files in the output target files package require special-case
  processing. This function performs all that special-case processing.

  Args:
    temp_dir: Location containing an 'output' directory where target files have
      been extracted, e.g. <temp_dir>/output/SYSTEM, <temp_dir>/output/IMAGES, etc.
    framework_meta: The name of a directory containing the special items
      extracted from the framework target files package.
    vendor_meta: The name of a directory containing the special items
      extracted from the vendor target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
    framework_misc_info_keys: A list of keys to obtain from the framework
      instance of META/misc_info.txt. The remaining keys should come from the
      vendor instance.
    framework_partition_set: Partitions that are considered framework
      partitions. Used to filter apexkeys.txt and apkcerts.txt.
    vendor_partition_set: Partitions that are considered vendor partitions. Used
      to filter apexkeys.txt and apkcerts.txt.

    The following are only used if dexpreopt is applied:

    framework_dexpreopt_tools: Location of dexpreopt_tools.zip.
    framework_dexpreopt_config: Location of framework's dexpreopt_config.zip.
    vendor_dexpreopt_config: Location of vendor's dexpreopt_config.zip.
  """

  if 'ab_update' in framework_misc_info_keys:
    process_ab_partitions_txt(
        framework_target_files_temp_dir=framework_meta,
        vendor_target_files_temp_dir=vendor_meta,
        output_target_files_temp_dir=output_target_files_temp_dir)

  copy_file_contexts(
      framework_target_files_dir=framework_meta,
      vendor_target_files_dir=vendor_meta,
      output_target_files_dir=output_target_files_temp_dir)

  process_misc_info_txt(
      framework_target_files_temp_dir=framework_meta,
      vendor_target_files_temp_dir=vendor_meta,
      output_target_files_temp_dir=output_target_files_temp_dir,
      framework_misc_info_keys=framework_misc_info_keys)

  process_dynamic_partitions_info_txt(
      framework_target_files_dir=framework_meta,
      vendor_target_files_dir=vendor_meta,
      output_target_files_dir=output_target_files_temp_dir)

  process_apex_keys_apk_certs_common(
      framework_target_files_dir=framework_meta,
      vendor_target_files_dir=vendor_meta,
      output_target_files_dir=output_target_files_temp_dir,
      framework_partition_set=framework_partition_set,
      vendor_partition_set=vendor_partition_set,
      file_name='apkcerts.txt')

  process_apex_keys_apk_certs_common(
      framework_target_files_dir=framework_meta,
      vendor_target_files_dir=vendor_meta,
      output_target_files_dir=output_target_files_temp_dir,
      framework_partition_set=framework_partition_set,
      vendor_partition_set=vendor_partition_set,
      file_name='apexkeys.txt')

  process_dexopt(
      temp_dir=temp_dir,
      framework_meta=framework_meta,
      vendor_meta=vendor_meta,
      output_target_files_temp_dir=output_target_files_temp_dir,
      framework_dexpreopt_tools=framework_dexpreopt_tools,
      framework_dexpreopt_config=framework_dexpreopt_config,
      vendor_dexpreopt_config=vendor_dexpreopt_config)


def process_dexopt(temp_dir, framework_meta, vendor_meta,
                   output_target_files_temp_dir,
                   framework_dexpreopt_tools, framework_dexpreopt_config,
                   vendor_dexpreopt_config):
  """If needed, generates dexopt files for vendor apps.

  Args:
    temp_dir: Location containing an 'output' directory where target files have
      been extracted, e.g. <temp_dir>/output/SYSTEM, <temp_dir>/output/IMAGES, etc.
    framework_meta: The name of a directory containing the special items
      extracted from the framework target files package.
    vendor_meta: The name of a directory containing the special items extracted
      from the vendor target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
    framework_dexpreopt_tools: Location of dexpreopt_tools.zip.
    framework_dexpreopt_config: Location of framework's dexpreopt_config.zip.
    vendor_dexpreopt_config: Location of vendor's dexpreopt_config.zip.
  """
  # Load vendor and framework META/misc_info.txt.
  misc_info_path = ['META', 'misc_info.txt']
  vendor_misc_info_dict = common.LoadDictionaryFromFile(
      os.path.join(vendor_meta, *misc_info_path))

  if (vendor_misc_info_dict.get('building_with_vsdk') != 'true' or
      framework_dexpreopt_tools is None or
      framework_dexpreopt_config is None or
      vendor_dexpreopt_config is None):
    return

  logger.info('applying dexpreopt')

  # The directory structure to apply dexpreopt is:
  #
  # <temp_dir>/
  #     framework_meta/
  #         META/
  #     vendor_meta/
  #         META/
  #     output/
  #         SYSTEM/
  #         VENDOR/
  #         IMAGES/
  #         <other items extracted from system and vendor target files>
  #     tools/
  #         <contents of dexpreopt_tools.zip>
  #     system_config/
  #         <contents of system dexpreopt_config.zip>
  #     vendor_config/
  #         <contents of vendor dexpreopt_config.zip>
  #     system -> output/SYSTEM
  #     vendor -> output/VENDOR
  #     apex -> output/SYSTEM/apex (only for flattened APEX builds)
  #     apex/ (extracted updatable APEX)
  #         <apex 1>/
  #             ...
  #         <apex 2>/
  #             ...
  #         ...
  #     out/dex2oat_result/vendor/
  #         <app>
  #             oat/arm64/
  #                 package.vdex
  #                 package.odex
  #         <priv-app>
  #             oat/arm64/
  #                 package.vdex
  #                 package.odex
  dexpreopt_tools_files_temp_dir = os.path.join(temp_dir, 'tools')
  dexpreopt_framework_config_files_temp_dir = os.path.join(temp_dir, 'system_config')
  dexpreopt_vendor_config_files_temp_dir = os.path.join(temp_dir, 'vendor_config')

  extract_items(
      target_files=OPTIONS.framework_dexpreopt_tools,
      target_files_temp_dir=dexpreopt_tools_files_temp_dir,
      extract_item_list=('*',))
  extract_items(
      target_files=OPTIONS.framework_dexpreopt_config,
      target_files_temp_dir=dexpreopt_framework_config_files_temp_dir,
      extract_item_list=('*',))
  extract_items(
      target_files=OPTIONS.vendor_dexpreopt_config,
      target_files_temp_dir=dexpreopt_vendor_config_files_temp_dir,
      extract_item_list=('*',))

  os.symlink(os.path.join(output_target_files_temp_dir, "SYSTEM"),
             os.path.join(temp_dir, "system"))
  os.symlink(os.path.join(output_target_files_temp_dir, "VENDOR"),
             os.path.join(temp_dir, "vendor"))

  # The directory structure for flatteded APEXes is:
  #
  # SYSTEM
  #     apex
  #         <APEX name, e.g., com.android.wifi>
  #             apex_manifest.pb
  #             apex_pubkey
  #             etc/
  #             javalib/
  #             lib/
  #             lib64/
  #             priv-app/
  #
  # The directory structure for updatable APEXes is:
  #
  # SYSTEM
  #     apex
  #         com.android.adbd.apex
  #         com.android.appsearch.apex
  #         com.android.art.apex
  #         ...
  apex_root = os.path.join(output_target_files_temp_dir, "SYSTEM", "apex")
  framework_misc_info_dict = common.LoadDictionaryFromFile(
      os.path.join(framework_meta, *misc_info_path))

  # Check for flattended versus updatable APEX.
  if framework_misc_info_dict.get('target_flatten_apex') == 'false':
    # Extract APEX.
    logging.info('extracting APEX')

    apex_extract_root_dir = os.path.join(temp_dir, 'apex')
    os.makedirs(apex_extract_root_dir)

    for apex in (glob.glob(os.path.join(apex_root, '*.apex')) +
                 glob.glob(os.path.join(apex_root, '*.capex'))):
      logging.info('  apex: %s', apex)
      # deapexer is in the same directory as the merge_target_files binary extracted
      # from otatools.zip.
      apex_json_info = subprocess.check_output(['deapexer', 'info', apex])
      logging.info('    info: %s', apex_json_info)
      apex_info = json.loads(apex_json_info)
      apex_name = apex_info['name']
      logging.info('    name: %s', apex_name)

      apex_extract_dir = os.path.join(apex_extract_root_dir, apex_name)
      os.makedirs(apex_extract_dir)

      # deapexer uses debugfs_static, which is part of otatools.zip.
      command = [
          'deapexer',
          '--debugfs_path',
          'debugfs_static',
          'extract',
          apex,
          apex_extract_dir,
      ]
      logging.info('    running %s', command)
      subprocess.check_call(command)
  else:
    # Flattened APEXes don't need to be extracted since they have the necessary
    # directory structure.
    os.symlink(os.path.join(apex_root), os.path.join(temp_dir, 'apex'))

  # Modify system config to point to the tools that have been extracted.
  # Absolute or .. paths are not allowed  by the dexpreopt_gen tool in
  # dexpreopt_soong.config.
  dexpreopt_framework_soon_config = os.path.join(
      dexpreopt_framework_config_files_temp_dir, 'dexpreopt_soong.config')
  with open(dexpreopt_framework_soon_config, 'w') as f:
    dexpreopt_soong_config = {
        'Profman': 'tools/profman',
        'Dex2oat': 'tools/dex2oatd',
        'Aapt': 'tools/aapt2',
        'SoongZip': 'tools/soong_zip',
        'Zip2zip': 'tools/zip2zip',
        'ManifestCheck': 'tools/manifest_check',
        'ConstructContext': 'tools/construct_context',
    }
    json.dump(dexpreopt_soong_config, f)

  # TODO(b/188179859): Make *dex location configurable to vendor or system_other.
  use_system_other_odex = False

  if use_system_other_odex:
    dex_img = 'SYSTEM_OTHER'
  else:
    dex_img = 'VENDOR'
    # Open vendor_filesystem_config to append the items generated by dexopt.
    vendor_file_system_config = open(
        os.path.join(temp_dir, 'output', 'META', 'vendor_filesystem_config.txt'),
        'a')

  # Dexpreopt vendor apps.
  dexpreopt_config_suffix = '_dexpreopt.config'
  for config in glob.glob(os.path.join(
      dexpreopt_vendor_config_files_temp_dir, '*' + dexpreopt_config_suffix)):
    app = os.path.basename(config)[:-len(dexpreopt_config_suffix)]
    logging.info('dexpreopt config: %s %s', config, app)

    apk_dir = 'app'
    apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
    if not os.path.exists(apk_path):
      apk_dir = 'priv-app'
      apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
      if not os.path.exists(apk_path):
        logging.warning('skipping dexpreopt for %s, no apk found in vendor/app '
                        'or vendor/priv-app', app)
        continue

    # Generate dexpreopting script. Note 'out_dir' is not the output directory
    # where the script is generated, but the OUT_DIR at build time referenced
    # in the dexpreot config files, e.g., "out/.../core-oj.jar", so the tool knows
    # how to adjust the path.
    command = [
        os.path.join(dexpreopt_tools_files_temp_dir, 'dexpreopt_gen'),
        '-global',
        os.path.join(dexpreopt_framework_config_files_temp_dir, 'dexpreopt.config'),
        '-global_soong',
        os.path.join(
            dexpreopt_framework_config_files_temp_dir, 'dexpreopt_soong.config'),
        '-module',
        config,
        '-dexpreopt_script',
        'dexpreopt_app.sh',
        '-out_dir',
        'out',
        '-base_path',
        '.',
        '--uses_target_files',
    ]

    # Run the command from temp_dir so all tool paths are its descendants.
    logging.info("running %s", command)
    subprocess.check_call(command, cwd = temp_dir)

    # Call the generated script.
    command = ['sh', 'dexpreopt_app.sh', apk_path]
    logging.info("running %s", command)
    subprocess.check_call(command, cwd = temp_dir)

    # Output files are in:
    #
    # <temp_dir>/out/dex2oat_result/vendor/priv-app/<app>/oat/arm64/package.vdex
    # <temp_dir>/out/dex2oat_result/vendor/priv-app/<app>/oat/arm64/package.odex
    # <temp_dir>/out/dex2oat_result/vendor/app/<app>/oat/arm64/package.vdex
    # <temp_dir>/out/dex2oat_result/vendor/app/<app>/oat/arm64/package.odex
    #
    # Copy the files to their destination. The structure of system_other is:
    #
    # system_other/
    #     system-other-odex-marker
    #     system/
    #         app/
    #             <app>/oat/arm64/
    #                 <app>.odex
    #                 <app>.vdex
    #             ...
    #         priv-app/
    #             <app>/oat/arm64/
    #                 <app>.odex
    #                 <app>.vdex
    #             ...

    # TODO(b/188179859): Support for other architectures.
    arch = 'arm64'

    dex_destination = os.path.join(temp_dir, 'output', dex_img, apk_dir, app, 'oat', arch)
    os.makedirs(dex_destination)
    dex2oat_path = os.path.join(
        temp_dir, 'out', 'dex2oat_result', 'vendor', apk_dir, app, 'oat', arch)
    shutil.copy(os.path.join(dex2oat_path, 'package.vdex'),
                os.path.join(dex_destination, app + '.vdex'))
    shutil.copy(os.path.join(dex2oat_path, 'package.odex'),
                os.path.join(dex_destination, app + '.odex'))

    # Append entries to vendor_file_system_config.txt, such as:
    #
    # vendor/app/<app>/oat 0 2000 755 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64 0 2000 755 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64/<app>.odex 0 0 644 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64/<app>.vdex 0 0 644 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    if not use_system_other_odex:
      vendor_app_prefix = 'vendor/' + apk_dir + '/' + app + '/oat'
      selabel = 'selabel=u:object_r:vendor_app_file:s0 capabilities=0x0'
      vendor_file_system_config.writelines([
          vendor_app_prefix + ' 0 2000 755 ' + selabel + '\n',
          vendor_app_prefix + '/' + arch + ' 0 2000 755 ' + selabel + '\n',
          vendor_app_prefix + '/' + arch + '/' + app + '.odex 0 0 644 ' + selabel + '\n',
          vendor_app_prefix + '/' + arch + '/' + app + '.vdex 0 0 644 ' + selabel + '\n',
      ])

  if not use_system_other_odex:
    vendor_file_system_config.close()
    # Delete vendor.img so that it will be regenerated.
    # TODO(b/188179859): Rebuilding a vendor image in GRF mode (e.g., T(framework)
    #                    and S(vendor) may require logic similar to that in
    #                    rebuild_image_with_sepolicy.
    vendor_img = os.path.join(output_target_files_temp_dir, 'IMAGES', 'vendor.img')
    if os.path.exists(vendor_img):
      logging.info('Deleting %s', vendor_img)
      os.remove(vendor_img)


def create_merged_package(temp_dir, framework_target_files, framework_item_list,
                          vendor_target_files, vendor_item_list,
                          framework_misc_info_keys, rebuild_recovery,
                          framework_dexpreopt_tools, framework_dexpreopt_config,
                          vendor_dexpreopt_config):
  """Merges two target files packages into one target files structure.

  Args:
    temp_dir: The name of a directory we use when we extract items from the
      input target files packages, and also a scratch directory that we use for
      temporary files.
    framework_target_files: The name of the zip archive containing the framework
      partial target files package.
    framework_item_list: The list of items to extract from the partial framework
      target files package as is, meaning these items will land in the output
      target files package exactly as they appear in the input partial framework
      target files package.
    vendor_target_files: The name of the zip archive containing the vendor
      partial target files package.
    vendor_item_list: The list of items to extract from the partial vendor
      target files package as is, meaning these items will land in the output
      target files package exactly as they appear in the input partial vendor
      target files package.
    framework_misc_info_keys: A list of keys to obtain from the framework
      instance of META/misc_info.txt. The remaining keys should come from the
      vendor instance.
    rebuild_recovery: If true, rebuild the recovery patch used by non-A/B
      devices and write it to the system image.

    The following are only used if dexpreopt is applied:

    framework_dexpreopt_tools: Location of dexpreopt_tools.zip.
    framework_dexpreopt_config: Location of framework's dexpreopt_config.zip.
    vendor_dexpreopt_config: Location of vendor's dexpreopt_config.zip.

  Returns:
    Path to merged package under temp directory.
  """
  # Extract "as is" items from the input framework and vendor partial target
  # files packages directly into the output temporary directory, since these items
  # do not need special case processing.

  output_target_files_temp_dir = os.path.join(temp_dir, 'output')
  extract_items(
      target_files=framework_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=framework_item_list)
  extract_items(
      target_files=vendor_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=vendor_item_list)

  # Perform special case processing on META/* items.
  # After this function completes successfully, all the files we need to create
  # the output target files package are in place.
  framework_meta = os.path.join(temp_dir, 'framework_meta')
  vendor_meta = os.path.join(temp_dir, 'vendor_meta')
  extract_items(
      target_files=framework_target_files,
      target_files_temp_dir=framework_meta,
      extract_item_list=('META/*',))
  extract_items(
      target_files=vendor_target_files,
      target_files_temp_dir=vendor_meta,
      extract_item_list=('META/*',))
  process_special_cases(
      temp_dir=temp_dir,
      framework_meta=framework_meta,
      vendor_meta=vendor_meta,
      output_target_files_temp_dir=output_target_files_temp_dir,
      framework_misc_info_keys=framework_misc_info_keys,
      framework_partition_set=item_list_to_partition_set(framework_item_list),
      vendor_partition_set=item_list_to_partition_set(vendor_item_list),
      framework_dexpreopt_tools=framework_dexpreopt_tools,
      framework_dexpreopt_config=framework_dexpreopt_config,
      vendor_dexpreopt_config=vendor_dexpreopt_config)

  return output_target_files_temp_dir


def generate_images(target_files_dir, rebuild_recovery):
  """Generate images from target files.

  This function takes merged output temporary directory and create images
  from it.

  Args:
    target_files_dir: Path to merged temp directory.
    rebuild_recovery: If true, rebuild the recovery patch used by non-A/B
      devices and write it to the system image.
  """

  # Regenerate IMAGES in the target directory.

  add_img_args = [
      '--verbose',
      '--add_missing',
  ]
  # TODO(b/132730255): Remove this if statement.
  if rebuild_recovery:
    add_img_args.append('--rebuild_recovery')
  add_img_args.append(target_files_dir)

  add_img_to_target_files.main(add_img_args)


def rebuild_image_with_sepolicy(target_files_dir,
                                vendor_otatools=None,
                                vendor_target_files=None):
  """Rebuilds odm.img or vendor.img to include merged sepolicy files.

  If odm is present then odm is preferred -- otherwise vendor is used.

  Args:
    target_files_dir: Path to the extracted merged target-files package.
    vendor_otatools: If not None, path to an otatools.zip from the vendor build
      that is used when recompiling the image.
    vendor_target_files: Expected if vendor_otatools is not None. Path to the
      vendor target-files zip.
  """
  partition = 'vendor'
  if os.path.exists(os.path.join(target_files_dir, 'ODM')) or os.path.exists(
      os.path.join(target_files_dir, 'IMAGES/odm.img')):
    partition = 'odm'
  partition_img = '{}.img'.format(partition)

  logger.info('Recompiling %s using the merged sepolicy files.', partition_img)

  # Copy the combined SEPolicy file and framework hashes to the image that is
  # being rebuilt.
  def copy_selinux_file(input_path, output_filename):
    input_filename = os.path.join(target_files_dir, input_path)
    if not os.path.exists(input_filename):
      input_filename = input_filename.replace('SYSTEM_EXT/', 'SYSTEM/system_ext/') \
          .replace('PRODUCT/', 'SYSTEM/product/')
      if not os.path.exists(input_filename):
        logger.info('Skipping copy_selinux_file for %s', input_filename)
        return
    shutil.copy(
        input_filename,
        os.path.join(target_files_dir, partition.upper(), 'etc/selinux',
                     output_filename))

  copy_selinux_file('META/combined_sepolicy', 'precompiled_sepolicy')
  copy_selinux_file('SYSTEM/etc/selinux/plat_sepolicy_and_mapping.sha256',
                    'precompiled_sepolicy.plat_sepolicy_and_mapping.sha256')
  copy_selinux_file(
      'SYSTEM_EXT/etc/selinux/system_ext_sepolicy_and_mapping.sha256',
      'precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256')
  copy_selinux_file('PRODUCT/etc/selinux/product_sepolicy_and_mapping.sha256',
                    'precompiled_sepolicy.product_sepolicy_and_mapping.sha256')

  if not vendor_otatools:
    # Remove the partition from the merged target-files archive. It will be
    # rebuilt later automatically by generate_images().
    os.remove(os.path.join(target_files_dir, 'IMAGES', partition_img))
  else:
    # TODO(b/192253131): Remove the need for vendor_otatools by fixing
    # backwards-compatibility issues when compiling images on R from S+.
    if not vendor_target_files:
      raise ValueError(
          'Expected vendor_target_files if vendor_otatools is not None.')
    logger.info(
        '%s recompilation will be performed using the vendor otatools.zip',
        partition_img)

    # Unzip the vendor build's otatools.zip and target-files archive.
    vendor_otatools_dir = common.MakeTempDir(
        prefix='merge_target_files_vendor_otatools_')
    vendor_target_files_dir = common.MakeTempDir(
        prefix='merge_target_files_vendor_target_files_')
    common.UnzipToDir(vendor_otatools, vendor_otatools_dir)
    common.UnzipToDir(vendor_target_files, vendor_target_files_dir)

    # Copy the partition contents from the merged target-files archive to the
    # vendor target-files archive.
    shutil.rmtree(os.path.join(vendor_target_files_dir, partition.upper()))
    shutil.copytree(
        os.path.join(target_files_dir, partition.upper()),
        os.path.join(vendor_target_files_dir, partition.upper()),
        symlinks=True)

    # Delete then rebuild the partition.
    os.remove(os.path.join(vendor_target_files_dir, 'IMAGES', partition_img))
    rebuild_partition_command = [
        os.path.join(vendor_otatools_dir, 'bin', 'add_img_to_target_files'),
        '--verbose',
        '--add_missing',
        vendor_target_files_dir,
    ]
    logger.info('Recompiling %s: %s', partition_img,
                ' '.join(rebuild_partition_command))
    common.RunAndCheckOutput(rebuild_partition_command, verbose=True)

    # Move the newly-created image to the merged target files dir.
    if not os.path.exists(os.path.join(target_files_dir, 'IMAGES')):
      os.makedirs(os.path.join(target_files_dir, 'IMAGES'))
    shutil.move(
        os.path.join(vendor_target_files_dir, 'IMAGES', partition_img),
        os.path.join(target_files_dir, 'IMAGES', partition_img))


def generate_super_empty_image(target_dir, output_super_empty):
  """Generates super_empty image from target package.

  Args:
    target_dir: Path to the target file package which contains misc_info.txt for
      detailed information for super image.
    output_super_empty: If provided, copies a super_empty.img file from the
      target files package to this path.
  """
  # Create super_empty.img using the merged misc_info.txt.

  misc_info_txt = os.path.join(target_dir, 'META', 'misc_info.txt')

  use_dynamic_partitions = common.LoadDictionaryFromFile(misc_info_txt).get(
      'use_dynamic_partitions')

  if use_dynamic_partitions != 'true' and output_super_empty:
    raise ValueError(
        'Building super_empty.img requires use_dynamic_partitions=true.')
  elif use_dynamic_partitions == 'true':
    super_empty_img = os.path.join(target_dir, 'IMAGES', 'super_empty.img')
    build_super_image_args = [
        misc_info_txt,
        super_empty_img,
    ]
    build_super_image.main(build_super_image_args)

    # Copy super_empty.img to the user-provided output_super_empty location.
    if output_super_empty:
      shutil.copyfile(super_empty_img, output_super_empty)


def create_target_files_archive(output_file, source_dir, temp_dir):
  """Creates archive from target package.

  Args:
    output_file: The name of the zip archive target files package.
    source_dir: The target directory contains package to be archived.
    temp_dir: Path to temporary directory for any intermediate files.
  """
  output_target_files_list = os.path.join(temp_dir, 'output.list')
  output_zip = os.path.abspath(output_file)
  output_target_files_meta_dir = os.path.join(source_dir, 'META')

  def files_from_path(target_path, extra_args=None):
    """Gets files under the given path and return a sorted list."""
    find_command = ['find', target_path] + (extra_args or [])
    find_process = common.Run(
        find_command, stdout=subprocess.PIPE, verbose=False)
    return common.RunAndCheckOutput(['sort'],
                                    stdin=find_process.stdout,
                                    verbose=False)

  meta_content = files_from_path(output_target_files_meta_dir)
  other_content = files_from_path(
      source_dir,
      ['-path', output_target_files_meta_dir, '-prune', '-o', '-print'])

  with open(output_target_files_list, 'w') as f:
    f.write(meta_content)
    f.write(other_content)

  command = [
      'soong_zip',
      '-d',
      '-o',
      output_zip,
      '-C',
      source_dir,
      '-r',
      output_target_files_list,
  ]

  logger.info('creating %s', output_file)
  common.RunAndCheckOutput(command, verbose=True)
  logger.info('finished creating %s', output_file)

  return output_zip


def merge_target_files(temp_dir, framework_target_files, framework_item_list,
                       framework_misc_info_keys, vendor_target_files,
                       vendor_item_list, output_target_files, output_dir,
                       output_item_list, output_ota, output_img,
                       output_super_empty, rebuild_recovery, vendor_otatools,
                       rebuild_sepolicy, framework_dexpreopt_tools,
                       framework_dexpreopt_config, vendor_dexpreopt_config):
  """Merges two target files packages together.

  This function takes framework and vendor target files packages as input,
  performs various file extractions, special case processing, and finally
  creates a merged zip archive as output.

  Args:
    temp_dir: The name of a directory we use when we extract items from the
      input target files packages, and also a scratch directory that we use for
      temporary files.
    framework_target_files: The name of the zip archive containing the framework
      partial target files package.
    framework_item_list: The list of items to extract from the partial framework
      target files package as is, meaning these items will land in the output
      target files package exactly as they appear in the input partial framework
      target files package.
    framework_misc_info_keys: A list of keys to obtain from the framework
      instance of META/misc_info.txt. The remaining keys should come from the
      vendor instance.
    vendor_target_files: The name of the zip archive containing the vendor
      partial target files package.
    vendor_item_list: The list of items to extract from the partial vendor
      target files package as is, meaning these items will land in the output
      target files package exactly as they appear in the input partial vendor
      target files package.
    output_target_files: The name of the output zip archive target files package
      created by merging framework and vendor.
    output_dir: The destination directory for saving merged files.
    output_item_list: The list of items to copy into the output_dir.
    output_ota: The name of the output zip archive ota package.
    output_img: The name of the output zip archive img package.
    output_super_empty: If provided, creates a super_empty.img file from the
      merged target files package and saves it at this path.
    rebuild_recovery: If true, rebuild the recovery patch used by non-A/B
      devices and write it to the system image.
    vendor_otatools: Path to an otatools zip used for recompiling vendor images.
    rebuild_sepolicy: If true, rebuild odm.img (if target uses ODM) or
      vendor.img using a merged precompiled_sepolicy file.

    The following are only used if dexpreopt is applied:

    framework_dexpreopt_tools: Location of dexpreopt_tools.zip.
    framework_dexpreopt_config: Location of framework's dexpreopt_config.zip.
    vendor_dexpreopt_config: Location of vendor's dexpreopt_config.zip.
  """

  logger.info('starting: merge framework %s and vendor %s into output %s',
              framework_target_files, vendor_target_files, output_target_files)

  output_target_files_temp_dir = create_merged_package(
      temp_dir, framework_target_files, framework_item_list,
      vendor_target_files, vendor_item_list, framework_misc_info_keys,
      rebuild_recovery, framework_dexpreopt_tools, framework_dexpreopt_config,
      vendor_dexpreopt_config)

  if not check_target_files_vintf.CheckVintf(output_target_files_temp_dir):
    raise RuntimeError('Incompatible VINTF metadata')

  partition_map = common.PartitionMapFromTargetFiles(
      output_target_files_temp_dir)

  # Generate and check for cross-partition violations of sharedUserId
  # values in APKs. This requires the input target-files packages to contain
  # *.apk files.
  shareduid_violation_modules = os.path.join(
      output_target_files_temp_dir, 'META', 'shareduid_violation_modules.json')
  with open(shareduid_violation_modules, 'w') as f:
    violation = find_shareduid_violation.FindShareduidViolation(
        output_target_files_temp_dir, partition_map)

    # Write the output to a file to enable debugging.
    f.write(violation)

    # Check for violations across the input builds' partition groups.
    framework_partitions = item_list_to_partition_set(framework_item_list)
    vendor_partitions = item_list_to_partition_set(vendor_item_list)
    shareduid_errors = common.SharedUidPartitionViolations(
        json.loads(violation), [framework_partitions, vendor_partitions])
    if shareduid_errors:
      for error in shareduid_errors:
        logger.error(error)
      raise ValueError('sharedUserId APK error. See %s' %
                       shareduid_violation_modules)

  # host_init_verifier and secilc check only the following partitions:
  filtered_partitions = {
      partition: path
      for partition, path in partition_map.items()
      if partition in ['system', 'system_ext', 'product', 'vendor', 'odm']
  }

  # Run host_init_verifier on the combined init rc files.
  common.RunHostInitVerifier(
      product_out=output_target_files_temp_dir,
      partition_map=filtered_partitions)

  # Check that the split sepolicy from the multiple builds can compile.
  split_sepolicy_cmd = compile_split_sepolicy(output_target_files_temp_dir,
                                              filtered_partitions)
  logger.info('Compiling split sepolicy: %s', ' '.join(split_sepolicy_cmd))
  common.RunAndCheckOutput(split_sepolicy_cmd)
  # Include the compiled policy in an image if requested.
  if rebuild_sepolicy:
    rebuild_image_with_sepolicy(output_target_files_temp_dir, vendor_otatools,
                                vendor_target_files)

  # Run validation checks on the pre-installed APEX files.
  validate_merged_apex_info(output_target_files_temp_dir, partition_map.keys())

  generate_images(output_target_files_temp_dir, rebuild_recovery)

  generate_super_empty_image(output_target_files_temp_dir, output_super_empty)

  # Finally, create the output target files zip archive and/or copy the
  # output items to the output target files directory.

  if output_dir:
    copy_items(output_target_files_temp_dir, output_dir, output_item_list)

  if not output_target_files:
    return

  # Create the merged META/care_map.bp
  generate_care_map(partition_map.keys(), output_target_files_temp_dir)

  output_zip = create_target_files_archive(output_target_files,
                                           output_target_files_temp_dir,
                                           temp_dir)

  # Create the IMG package from the merged target files package.
  if output_img:
    img_from_target_files.main([output_zip, output_img])

  # Create the OTA package from the merged target files package.

  if output_ota:
    ota_from_target_files.main([output_zip, output_ota])


def call_func_with_temp_dir(func, keep_tmp):
  """Manages the creation and cleanup of the temporary directory.

  This function calls the given function after first creating a temporary
  directory. It also cleans up the temporary directory.

  Args:
    func: The function to call. Should accept one parameter, the path to the
      temporary directory.
    keep_tmp: Keep the temporary directory after processing is complete.
  """

  # Create a temporary directory. This will serve as the parent of directories
  # we use when we extract items from the input target files packages, and also
  # a scratch directory that we use for temporary files.

  temp_dir = common.MakeTempDir(prefix='merge_target_files_')

  try:
    func(temp_dir)
  finally:
    if keep_tmp:
      logger.info('keeping %s', temp_dir)
    else:
      common.Cleanup()


def main():
  """The main function.

  Process command line arguments, then call merge_target_files to
  perform the heavy lifting.
  """

  common.InitLogging()

  def option_handler(o, a):
    if o == '--system-target-files':
      logger.warning(
          '--system-target-files has been renamed to --framework-target-files')
      OPTIONS.framework_target_files = a
    elif o == '--framework-target-files':
      OPTIONS.framework_target_files = a
    elif o == '--system-item-list':
      logger.warning(
          '--system-item-list has been renamed to --framework-item-list')
      OPTIONS.framework_item_list = a
    elif o == '--framework-item-list':
      OPTIONS.framework_item_list = a
    elif o == '--system-misc-info-keys':
      logger.warning('--system-misc-info-keys has been renamed to '
                     '--framework-misc-info-keys')
      OPTIONS.framework_misc_info_keys = a
    elif o == '--framework-misc-info-keys':
      OPTIONS.framework_misc_info_keys = a
    elif o == '--other-target-files':
      logger.warning(
          '--other-target-files has been renamed to --vendor-target-files')
      OPTIONS.vendor_target_files = a
    elif o == '--vendor-target-files':
      OPTIONS.vendor_target_files = a
    elif o == '--other-item-list':
      logger.warning('--other-item-list has been renamed to --vendor-item-list')
      OPTIONS.vendor_item_list = a
    elif o == '--vendor-item-list':
      OPTIONS.vendor_item_list = a
    elif o == '--output-target-files':
      OPTIONS.output_target_files = a
    elif o == '--output-dir':
      OPTIONS.output_dir = a
    elif o == '--output-item-list':
      OPTIONS.output_item_list = a
    elif o == '--output-ota':
      OPTIONS.output_ota = a
    elif o == '--output-img':
      OPTIONS.output_img = a
    elif o == '--output-super-empty':
      OPTIONS.output_super_empty = a
    elif o == '--rebuild_recovery':  # TODO(b/132730255): Warn
      OPTIONS.rebuild_recovery = True
    elif o == '--allow-duplicate-apkapex-keys':
      OPTIONS.allow_duplicate_apkapex_keys = True
    elif o == '--vendor-otatools':
      OPTIONS.vendor_otatools = a
    elif o == '--rebuild-sepolicy':
      OPTIONS.rebuild_sepolicy = True
    elif o == '--keep-tmp':
      OPTIONS.keep_tmp = True
    elif o == '--framework-dexpreopt-config':
      OPTIONS.framework_dexpreopt_config = a
    elif o == '--framework-dexpreopt-tools':
      OPTIONS.framework_dexpreopt_tools = a
    elif o == '--vendor-dexpreopt-config':
      OPTIONS.vendor_dexpreopt_config = a
    else:
      return False
    return True

  args = common.ParseOptions(
      sys.argv[1:],
      __doc__,
      extra_long_opts=[
          'system-target-files=',
          'framework-target-files=',
          'system-item-list=',
          'framework-item-list=',
          'system-misc-info-keys=',
          'framework-misc-info-keys=',
          'other-target-files=',
          'vendor-target-files=',
          'other-item-list=',
          'vendor-item-list=',
          'output-target-files=',
          'output-dir=',
          'output-item-list=',
          'output-ota=',
          'output-img=',
          'output-super-empty=',
          'framework-dexpreopt-config=',
          'framework-dexpreopt-tools=',
          'vendor-dexpreopt-config=',
          'rebuild_recovery',
          'allow-duplicate-apkapex-keys',
          'vendor-otatools=',
          'rebuild-sepolicy',
          'keep-tmp',
      ],
      extra_option_handler=option_handler)

  # pylint: disable=too-many-boolean-expressions
  if (args or OPTIONS.framework_target_files is None or
      OPTIONS.vendor_target_files is None or
      (OPTIONS.output_target_files is None and OPTIONS.output_dir is None) or
      (OPTIONS.output_dir is not None and OPTIONS.output_item_list is None)):
    common.Usage(__doc__)
    sys.exit(1)

  if OPTIONS.framework_item_list:
    framework_item_list = common.LoadListFromFile(OPTIONS.framework_item_list)
  else:
    framework_item_list = DEFAULT_FRAMEWORK_ITEM_LIST

  if OPTIONS.framework_misc_info_keys:
    framework_misc_info_keys = common.LoadListFromFile(
        OPTIONS.framework_misc_info_keys)
  else:
    framework_misc_info_keys = DEFAULT_FRAMEWORK_MISC_INFO_KEYS

  if OPTIONS.vendor_item_list:
    vendor_item_list = common.LoadListFromFile(OPTIONS.vendor_item_list)
  else:
    vendor_item_list = DEFAULT_VENDOR_ITEM_LIST

  if OPTIONS.output_item_list:
    output_item_list = common.LoadListFromFile(OPTIONS.output_item_list)
  else:
    output_item_list = None

  if not validate_config_lists(
      framework_item_list=framework_item_list,
      framework_misc_info_keys=framework_misc_info_keys,
      vendor_item_list=vendor_item_list):
    sys.exit(1)

  call_func_with_temp_dir(
      lambda temp_dir: merge_target_files(
          temp_dir=temp_dir,
          framework_target_files=OPTIONS.framework_target_files,
          framework_item_list=framework_item_list,
          framework_misc_info_keys=framework_misc_info_keys,
          vendor_target_files=OPTIONS.vendor_target_files,
          vendor_item_list=vendor_item_list,
          output_target_files=OPTIONS.output_target_files,
          output_dir=OPTIONS.output_dir,
          output_item_list=output_item_list,
          output_ota=OPTIONS.output_ota,
          output_img=OPTIONS.output_img,
          output_super_empty=OPTIONS.output_super_empty,
          rebuild_recovery=OPTIONS.rebuild_recovery,
          vendor_otatools=OPTIONS.vendor_otatools,
          rebuild_sepolicy=OPTIONS.rebuild_sepolicy,
          framework_dexpreopt_tools=OPTIONS.framework_dexpreopt_tools,
          framework_dexpreopt_config=OPTIONS.framework_dexpreopt_config,
          vendor_dexpreopt_config=OPTIONS.vendor_dexpreopt_config), OPTIONS.keep_tmp)


if __name__ == '__main__':
  main()
