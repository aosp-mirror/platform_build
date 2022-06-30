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
"""Common utility functions shared by merge_* scripts.

Expects items in OPTIONS prepared by merge_target_files.py.
"""

import fnmatch
import logging
import os
import re
import shutil
import zipfile

import common

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS


def ExtractItems(input_zip, output_dir, extract_item_list):
  """Extracts items in extract_item_list from a zip to a dir."""

  # Filter the extract_item_list to remove any items that do not exist in the
  # zip file. Otherwise, the extraction step will fail.

  with zipfile.ZipFile(input_zip, allowZip64=True) as input_zipfile:
    input_namelist = input_zipfile.namelist()

  filtered_extract_item_list = []
  for pattern in extract_item_list:
    if fnmatch.filter(input_namelist, pattern):
      filtered_extract_item_list.append(pattern)

  common.UnzipToDir(input_zip, output_dir, filtered_extract_item_list)


def CopyItems(from_dir, to_dir, patterns):
  """Similar to ExtractItems() except uses an input dir instead of zip."""
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


def WriteSortedData(data, path):
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


def ValidateConfigLists():
  """Performs validations on the merge config lists.

  Returns:
    False if a validation fails, otherwise true.
  """
  has_error = False

  # Check that partitions only come from one input.
  for partition in _FRAMEWORK_PARTITIONS.union(_VENDOR_PARTITIONS):
    image_path = 'IMAGES/{}.img'.format(partition.lower().replace('/', ''))
    in_framework = (
        any(item.startswith(partition) for item in OPTIONS.framework_item_list)
        or image_path in OPTIONS.framework_item_list)
    in_vendor = (
        any(item.startswith(partition) for item in OPTIONS.vendor_item_list) or
        image_path in OPTIONS.vendor_item_list)
    if in_framework and in_vendor:
      logger.error(
          'Cannot extract items from %s for both the framework and vendor'
          ' builds. Please ensure only one merge config item list'
          ' includes %s.', partition, partition)
      has_error = True

  if any([
      key in OPTIONS.framework_misc_info_keys
      for key in ('dynamic_partition_list', 'super_partition_groups')
  ]):
    logger.error('Dynamic partition misc info keys should come from '
                 'the vendor instance of META/misc_info.txt.')
    has_error = True

  return not has_error


# In an item list (framework or vendor), we may see entries that select whole
# partitions. Such an entry might look like this 'SYSTEM/*' (e.g., for the
# system partition). The following regex matches this and extracts the
# partition name.

_PARTITION_ITEM_PATTERN = re.compile(r'^([A-Z_]+)/\*$')


def ItemListToPartitionSet(item_list):
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
    partition_match = _PARTITION_ITEM_PATTERN.search(item.strip())
    partition_tag = partition_match.group(
        1).lower() if partition_match else None

    if partition_tag:
      partition_set.add(partition_tag)

  return partition_set


# Partitions that are grabbed from the framework partial build by default.
_FRAMEWORK_PARTITIONS = {
    'system', 'product', 'system_ext', 'system_other', 'root', 'system_dlkm'
}
# Partitions that are grabbed from the vendor partial build by default.
_VENDOR_PARTITIONS = {
    'vendor', 'odm', 'oem', 'boot', 'vendor_boot', 'recovery',
    'prebuilt_images', 'radio', 'data', 'vendor_dlkm', 'odm_dlkm'
}


def InferItemList(input_namelist, framework):
  item_list = []

  # Some META items are grabbed from partial builds directly.
  # Others are combined in merge_meta.py.
  if framework:
    item_list.extend([
        'META/liblz4.so',
        'META/postinstall_config.txt',
        'META/update_engine_config.txt',
        'META/zucchini_config.txt',
    ])
  else:  # vendor
    item_list.extend([
        'META/kernel_configs.txt',
        'META/kernel_version.txt',
        'META/otakeys.txt',
        'META/releasetools.py',
        'OTA/android-info.txt',
    ])

  # Grab a set of items for the expected partitions in the partial build.
  for partition in (_FRAMEWORK_PARTITIONS if framework else _VENDOR_PARTITIONS):
    for namelist in input_namelist:
      if namelist.startswith('%s/' % partition.upper()):
        fs_config_prefix = '' if partition == 'system' else '%s_' % partition
        item_list.extend([
            '%s/*' % partition.upper(),
            'IMAGES/%s.img' % partition,
            'IMAGES/%s.map' % partition,
            'META/%sfilesystem_config.txt' % fs_config_prefix,
        ])
        break

  return sorted(item_list)


def InferFrameworkMiscInfoKeys(input_namelist):
  keys = [
      'ab_update',
      'avb_vbmeta_system',
      'avb_vbmeta_system_algorithm',
      'avb_vbmeta_system_key_path',
      'avb_vbmeta_system_rollback_index_location',
      'default_system_dev_certificate',
  ]

  for partition in _FRAMEWORK_PARTITIONS:
    for namelist in input_namelist:
      if namelist.startswith('%s/' % partition.upper()):
        fs_type_prefix = '' if partition == 'system' else '%s_' % partition
        keys.extend([
            'avb_%s_hashtree_enable' % partition,
            'avb_%s_add_hashtree_footer_args' % partition,
            '%s_disable_sparse' % partition,
            'building_%s_image' % partition,
            '%sfs_type' % fs_type_prefix,
        ])

  return sorted(keys)
