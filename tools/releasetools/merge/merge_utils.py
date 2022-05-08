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
  framework_partitions = ItemListToPartitionSet(OPTIONS.framework_item_list)
  vendor_partitions = ItemListToPartitionSet(OPTIONS.vendor_item_list)
  from_both = framework_partitions.intersection(vendor_partitions)
  if from_both:
    logger.error(
        'Cannot extract items from the same partition in both the '
        'framework and vendor builds. Please ensure only one merge config '
        'item list (or inferred list) includes each partition: %s' %
        ','.join(from_both))
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

_PARTITION_ITEM_PATTERN = re.compile(r'^([A-Z_]+)/.*$')
_IMAGE_PARTITION_PATTERN = re.compile(r'^IMAGES/(.*)\.img$')


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
    for pattern in (_PARTITION_ITEM_PATTERN, _IMAGE_PARTITION_PATTERN):
      partition_match = pattern.search(item.strip())
      if partition_match:
        partition = partition_match.group(1).lower()
        # These directories in target-files are not actual partitions.
        if partition not in ('meta', 'images'):
          partition_set.add(partition)

  return partition_set


# Partitions that are grabbed from the framework partial build by default.
_FRAMEWORK_PARTITIONS = {
    'system', 'product', 'system_ext', 'system_other', 'root', 'system_dlkm',
    'vbmeta_system'
}


def InferItemList(input_namelist, framework):
  item_set = set()

  # Some META items are always grabbed from partial builds directly.
  # Others are combined in merge_meta.py.
  if framework:
    item_set.update([
        'META/liblz4.so',
        'META/postinstall_config.txt',
        'META/update_engine_config.txt',
        'META/zucchini_config.txt',
    ])
  else:  # vendor
    item_set.update([
        'META/kernel_configs.txt',
        'META/kernel_version.txt',
        'META/otakeys.txt',
        'META/pack_radioimages.txt',
        'META/releasetools.py',
    ])

  # Grab a set of items for the expected partitions in the partial build.
  seen_partitions = []
  for namelist in input_namelist:
    if namelist.endswith('/'):
      continue

    partition = namelist.split('/')[0].lower()

    # META items are grabbed above, or merged later.
    if partition == 'meta':
      continue

    if partition == 'images':
      image_partition, extension = os.path.splitext(os.path.basename(namelist))
      if image_partition == 'vbmeta':
        # Always regenerate vbmeta.img since it depends on hash information
        # from both builds.
        continue
      if extension in ('.img', '.map'):
        # Include image files in IMAGES/* if the partition comes from
        # the expected set.
        if (framework and image_partition in _FRAMEWORK_PARTITIONS) or (
            not framework and image_partition not in _FRAMEWORK_PARTITIONS):
          item_set.add(namelist)
      elif not framework:
        # Include all miscellaneous non-image files in IMAGES/* from
        # the vendor build.
        item_set.add(namelist)
      continue

    # Skip already-visited partitions.
    if partition in seen_partitions:
      continue
    seen_partitions.append(partition)

    if (framework and partition in _FRAMEWORK_PARTITIONS) or (
        not framework and partition not in _FRAMEWORK_PARTITIONS):
      fs_config_prefix = '' if partition == 'system' else '%s_' % partition
      item_set.update([
          '%s/*' % partition.upper(),
          'META/%sfilesystem_config.txt' % fs_config_prefix,
      ])

  return sorted(item_set)


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
    for partition_dir in ('%s/' % partition.upper(), 'SYSTEM/%s/' % partition):
      if partition_dir in input_namelist:
        fs_type_prefix = '' if partition == 'system' else '%s_' % partition
        keys.extend([
            'avb_%s_hashtree_enable' % partition,
            'avb_%s_add_hashtree_footer_args' % partition,
            '%s_disable_sparse' % partition,
            'building_%s_image' % partition,
            '%sfs_type' % fs_type_prefix,
        ])

  return sorted(keys)
