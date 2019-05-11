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
"""This script merges two partial target files packages.

One package contains system files, and the other contains non-system files.
It produces a complete target files package that can be used to generate an
OTA package.

Usage: merge_target_files.py [args]

  --system-target-files system-target-files-zip-archive
      The input target files package containing system bits. This is a zip
      archive.

  --system-item-list system-item-list-file
      The optional path to a newline-separated config file that replaces the
      contents of default_system_item_list if provided.

  --system-misc-info-keys system-misc-info-keys-file
      The optional path to a newline-separated config file that replaces the
      contents of default_system_misc_info_keys if provided.

  --other-target-files other-target-files-zip-archive
      The input target files package containing other bits. This is a zip
      archive.

  --other-item-list other-item-list-file
      The optional path to a newline-separated config file that replaces the
      contents of default_other_item_list if provided.

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
      Rebuild the recovery patch used by non-A/B devices and write it to the
      system image.

  --keep-tmp
      Keep tempoary files for debugging purposes.
"""

from __future__ import print_function

import fnmatch
import logging
import os
import shutil
import subprocess
import sys
import zipfile

import add_img_to_target_files
import build_super_image
import common
import img_from_target_files
import ota_from_target_files

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS
OPTIONS.verbose = True
OPTIONS.system_target_files = None
OPTIONS.system_item_list = None
OPTIONS.system_misc_info_keys = None
OPTIONS.other_target_files = None
OPTIONS.other_item_list = None
OPTIONS.output_target_files = None
OPTIONS.output_dir = None
OPTIONS.output_item_list = None
OPTIONS.output_ota = None
OPTIONS.output_img = None
OPTIONS.output_super_empty = None
OPTIONS.rebuild_recovery = False
OPTIONS.keep_tmp = False

# default_system_item_list is a list of items to extract from the partial
# system target files package as is, meaning these items will land in the
# output target files package exactly as they appear in the input partial
# system target files package.

default_system_item_list = [
    'META/apkcerts.txt',
    'META/filesystem_config.txt',
    'META/root_filesystem_config.txt',
    'META/system_manifest.xml',
    'META/system_matrix.xml',
    'META/update_engine_config.txt',
    'PRODUCT/*',
    'ROOT/*',
    'SYSTEM/*',
]

# system_extract_special_item_list is a list of items to extract from the
# partial system target files package that need some special processing, such
# as some sort of combination with items from the partial other target files
# package.

system_extract_special_item_list = [
    'META/*',
]

# default_system_misc_info_keys is a list of keys to obtain from the system
# instance of META/misc_info.txt. The remaining keys from the other instance.

default_system_misc_info_keys = [
    'avb_system_hashtree_enable',
    'avb_system_add_hashtree_footer_args',
    'avb_system_key_path',
    'avb_system_algorithm',
    'avb_system_rollback_index_location',
    'avb_product_hashtree_enable',
    'avb_product_add_hashtree_footer_args',
    'avb_product_services_hashtree_enable',
    'avb_product_services_add_hashtree_footer_args',
    'system_root_image',
    'root_dir',
    'ab_update',
    'default_system_dev_certificate',
    'system_size',
]

# default_other_item_list is a list of items to extract from the partial
# other target files package as is, meaning these items will land in the output
# target files package exactly as they appear in the input partial other target
# files package.

default_other_item_list = [
    'META/boot_filesystem_config.txt',
    'META/file_contexts.bin',
    'META/otakeys.txt',
    'META/releasetools.py',
    'META/vendor_filesystem_config.txt',
    'META/vendor_manifest.xml',
    'META/vendor_matrix.xml',
    'BOOT/*',
    'DATA/*',
    'ODM/*',
    'OTA/android-info.txt',
    'PREBUILT_IMAGES/*',
    'RADIO/*',
    'VENDOR/*',
]

# other_extract_special_item_list is a list of items to extract from the
# partial other target files package that need some special processing, such as
# some sort of combination with items from the partial system target files
# package.

other_extract_special_item_list = [
    'META/*',
]


def extract_items(target_files, target_files_temp_dir, extract_item_list):
  """Extract items from target files to temporary directory.

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

  with zipfile.ZipFile(
      target_files, 'r', allowZip64=True) as target_files_zipfile:
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


def read_config_list(config_file_path):
  """Reads a config file into a list of strings.

  Expects the file to be newline-separated.

  Args:
    config_file_path: The path to the config file to open and read.

  Returns:
    The list of strings in the config file.
  """
  with open(config_file_path) as config_file:
    return config_file.read().splitlines()


def validate_config_lists(system_item_list, system_misc_info_keys,
                          other_item_list):
  """Performs validations on the merge config lists.

  Args:
    system_item_list: The list of items to extract from the partial system
      target files package as is.
    system_misc_info_keys: A list of keys to obtain from the system instance of
      META/misc_info.txt. The remaining keys from the other instance.
    other_item_list: The list of items to extract from the partial other target
      files package as is.

  Returns:
    False if a validation fails, otherwise true.
  """
  default_combined_item_set = set(default_system_item_list)
  default_combined_item_set.update(default_other_item_list)

  combined_item_set = set(system_item_list)
  combined_item_set.update(other_item_list)

  # Check that the merge config lists are not missing any item specified
  # by the default config lists.
  difference = default_combined_item_set.difference(combined_item_set)
  if difference:
    logger.error('Missing merge config items: %s', list(difference))
    logger.error('Please ensure missing items are in either the '
                 'system-item-list or other-item-list files provided to '
                 'this script.')
    return False

  if ('dynamic_partition_list' in system_misc_info_keys) or (
      'super_partition_groups' in system_misc_info_keys):
    logger.error('Dynamic partition misc info keys should come from '
                 'the other instance of META/misc_info.txt.')
    return False

  return True


def process_ab_partitions_txt(system_target_files_temp_dir,
                              other_target_files_temp_dir,
                              output_target_files_temp_dir):
  """Perform special processing for META/ab_partitions.txt.

  This function merges the contents of the META/ab_partitions.txt files from
  the system directory and the other directory, placing the merged result in
  the output directory. The precondition in that the files are already
  extracted. The post condition is that the output META/ab_partitions.txt
  contains the merged content. The format for each ab_partitions.txt a one
  partition name per line. The output file contains the union of the parition
  names.

  Args:
    system_target_files_temp_dir: The name of a directory containing the special
      items extracted from the system target files package.
    other_target_files_temp_dir: The name of a directory containing the special
      items extracted from the other target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
  """

  system_ab_partitions_txt = os.path.join(system_target_files_temp_dir, 'META',
                                          'ab_partitions.txt')

  other_ab_partitions_txt = os.path.join(other_target_files_temp_dir, 'META',
                                         'ab_partitions.txt')

  with open(system_ab_partitions_txt) as f:
    system_ab_partitions = f.read().splitlines()

  with open(other_ab_partitions_txt) as f:
    other_ab_partitions = f.read().splitlines()

  output_ab_partitions = set(system_ab_partitions + other_ab_partitions)

  output_ab_partitions_txt = os.path.join(output_target_files_temp_dir, 'META',
                                          'ab_partitions.txt')

  with open(output_ab_partitions_txt, 'w') as output:
    for partition in sorted(output_ab_partitions):
      output.write('%s\n' % partition)


def append_recovery_to_filesystem_config(output_target_files_temp_dir):
  """Perform special processing for META/filesystem_config.txt.

  This function appends recovery information to META/filesystem_config.txt
  so that recovery patch regeneration will succeed.

  Args:
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed. We find filesystem_config.txt here.
  """

  filesystem_config_txt = os.path.join(output_target_files_temp_dir, 'META',
                                       'filesystem_config.txt')

  with open(filesystem_config_txt, 'a') as f:
    # TODO(bpeckham) this data is hard coded. It should be generated
    # programmatically.
    f.write('system/bin/install-recovery.sh 0 0 750 '
            'selabel=u:object_r:install_recovery_exec:s0 capabilities=0x0\n')
    f.write('system/recovery-from-boot.p 0 0 644 '
            'selabel=u:object_r:system_file:s0 capabilities=0x0\n')
    f.write('system/etc/recovery.img 0 0 440 '
            'selabel=u:object_r:install_recovery_exec:s0 capabilities=0x0\n')


def merge_dynamic_partition_info_dicts(system_dict,
                                       other_dict,
                                       include_dynamic_partition_list=True,
                                       size_prefix='',
                                       size_suffix='',
                                       list_prefix='',
                                       list_suffix=''):
  """Merges dynamic partition info variables.

  Args:
    system_dict: The dictionary of dynamic partition info variables from the
      partial system target files.
    other_dict: The dictionary of dynamic partition info variables from the
      partial other target files.
    include_dynamic_partition_list: If true, merges the dynamic_partition_list
      variable. Not all use cases need this variable merged.
    size_prefix: The prefix in partition group size variables that precedes the
      name of the partition group. For example, partition group 'group_a' with
      corresponding size variable 'super_group_a_group_size' would have the
      size_prefix 'super_'.
    size_suffix: Similar to size_prefix but for the variable's suffix. For
      example, 'super_group_a_group_size' would have size_suffix '_group_size'.
    list_prefix: Similar to size_prefix but for the partition group's
      partition_list variable.
    list_suffix: Similar to size_suffix but for the partition group's
      partition_list variable.

  Returns:
    The merged dynamic partition info dictionary.
  """
  merged_dict = {}
  # Partition groups and group sizes are defined by the other (non-system)
  # dict because these values may vary for each board that uses a shared system
  # image.
  merged_dict['super_partition_groups'] = other_dict['super_partition_groups']
  if include_dynamic_partition_list:
    system_dynamic_partition_list = system_dict.get('dynamic_partition_list',
                                                    '')
    other_dynamic_partition_list = other_dict.get('dynamic_partition_list', '')
    merged_dict['dynamic_partition_list'] = (
        '%s %s' %
        (system_dynamic_partition_list, other_dynamic_partition_list)).strip()
  for partition_group in merged_dict['super_partition_groups'].split(' '):
    # Set the partition group's size using the value from the other dict.
    key = '%s%s%s' % (size_prefix, partition_group, size_suffix)
    if key not in other_dict:
      raise ValueError('Other dict does not contain required key %s.' % key)
    merged_dict[key] = other_dict[key]

    # Set the partition group's partition list using a concatenation of the
    # system and other partition lists.
    key = '%s%s%s' % (list_prefix, partition_group, list_suffix)
    merged_dict[key] = (
        '%s %s' % (system_dict.get(key, ''), other_dict.get(key, ''))).strip()
  return merged_dict


def process_misc_info_txt(system_target_files_temp_dir,
                          other_target_files_temp_dir,
                          output_target_files_temp_dir, system_misc_info_keys):
  """Perform special processing for META/misc_info.txt.

  This function merges the contents of the META/misc_info.txt files from the
  system directory and the other directory, placing the merged result in the
  output directory. The precondition in that the files are already extracted.
  The post condition is that the output META/misc_info.txt contains the merged
  content.

  Args:
    system_target_files_temp_dir: The name of a directory containing the special
      items extracted from the system target files package.
    other_target_files_temp_dir: The name of a directory containing the special
      items extracted from the other target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
    system_misc_info_keys: A list of keys to obtain from the system instance of
      META/misc_info.txt. The remaining keys from the other instance.
  """

  def read_helper(d):
    misc_info_txt = os.path.join(d, 'META', 'misc_info.txt')
    with open(misc_info_txt) as f:
      return list(f.read().splitlines())

  system_info_dict = common.LoadDictionaryFromLines(
      read_helper(system_target_files_temp_dir))

  # We take most of the misc info from the other target files.

  merged_info_dict = common.LoadDictionaryFromLines(
      read_helper(other_target_files_temp_dir))

  # Replace certain values in merged_info_dict with values from
  # system_info_dict.

  for key in system_misc_info_keys:
    merged_info_dict[key] = system_info_dict[key]

  # Merge misc info keys used for Dynamic Partitions.
  if (merged_info_dict.get('use_dynamic_partitions') == 'true') and (
      system_info_dict.get('use_dynamic_partitions') == 'true'):
    merged_dynamic_partitions_dict = merge_dynamic_partition_info_dicts(
        system_dict=system_info_dict,
        other_dict=merged_info_dict,
        size_prefix='super_',
        size_suffix='_group_size',
        list_prefix='super_',
        list_suffix='_partition_list')
    merged_info_dict.update(merged_dynamic_partitions_dict)

  output_misc_info_txt = os.path.join(output_target_files_temp_dir, 'META',
                                      'misc_info.txt')
  with open(output_misc_info_txt, 'w') as output:
    sorted_keys = sorted(merged_info_dict.keys())
    for key in sorted_keys:
      output.write('{}={}\n'.format(key, merged_info_dict[key]))


def process_dynamic_partitions_info_txt(system_target_files_dir,
                                        other_target_files_dir,
                                        output_target_files_dir):
  """Perform special processing for META/dynamic_partitions_info.txt.

  This function merges the contents of the META/dynamic_partitions_info.txt
  files from the system directory and the other directory, placing the merged
  result in the output directory.

  This function does nothing if META/dynamic_partitions_info.txt from the other
  directory does not exist.

  Args:
    system_target_files_dir: The name of a directory containing the special
      items extracted from the system target files package.
    other_target_files_dir: The name of a directory containing the special items
      extracted from the other target files package.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
  """

  if not os.path.exists(
      os.path.join(other_target_files_dir, 'META',
                   'dynamic_partitions_info.txt')):
    return

  def read_helper(d):
    dynamic_partitions_info_txt = os.path.join(d, 'META',
                                               'dynamic_partitions_info.txt')
    with open(dynamic_partitions_info_txt) as f:
      return list(f.read().splitlines())

  system_dynamic_partitions_dict = common.LoadDictionaryFromLines(
      read_helper(system_target_files_dir))
  other_dynamic_partitions_dict = common.LoadDictionaryFromLines(
      read_helper(other_target_files_dir))

  merged_dynamic_partitions_dict = merge_dynamic_partition_info_dicts(
      system_dict=system_dynamic_partitions_dict,
      other_dict=other_dynamic_partitions_dict,
      # META/dynamic_partitions_info.txt does not use dynamic_partition_list.
      include_dynamic_partition_list=False,
      size_suffix='_size',
      list_suffix='_partition_list')

  output_dynamic_partitions_info_txt = os.path.join(
      output_target_files_dir, 'META', 'dynamic_partitions_info.txt')
  with open(output_dynamic_partitions_info_txt, 'w') as output:
    sorted_keys = sorted(merged_dynamic_partitions_dict.keys())
    for key in sorted_keys:
      output.write('{}={}\n'.format(key, merged_dynamic_partitions_dict[key]))


def process_special_cases(system_target_files_temp_dir,
                          other_target_files_temp_dir,
                          output_target_files_temp_dir, system_misc_info_keys,
                          rebuild_recovery):
  """Perform special-case processing for certain target files items.

  Certain files in the output target files package require special-case
  processing. This function performs all that special-case processing.

  Args:
    system_target_files_temp_dir: The name of a directory containing the special
      items extracted from the system target files package.
    other_target_files_temp_dir: The name of a directory containing the special
      items extracted from the other target files package.
    output_target_files_temp_dir: The name of a directory that will be used to
      create the output target files package after all the special cases are
      processed.
    system_misc_info_keys: A list of keys to obtain from the system instance of
      META/misc_info.txt. The remaining keys from the other instance.
    rebuild_recovery: If true, rebuild the recovery patch used by non-A/B
      devices and write it to the system image.
  """

  if 'ab_update' in system_misc_info_keys:
    process_ab_partitions_txt(
        system_target_files_temp_dir=system_target_files_temp_dir,
        other_target_files_temp_dir=other_target_files_temp_dir,
        output_target_files_temp_dir=output_target_files_temp_dir)

  if rebuild_recovery:
    append_recovery_to_filesystem_config(
        output_target_files_temp_dir=output_target_files_temp_dir)

  process_misc_info_txt(
      system_target_files_temp_dir=system_target_files_temp_dir,
      other_target_files_temp_dir=other_target_files_temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir,
      system_misc_info_keys=system_misc_info_keys)

  process_dynamic_partitions_info_txt(
      system_target_files_dir=system_target_files_temp_dir,
      other_target_files_dir=other_target_files_temp_dir,
      output_target_files_dir=output_target_files_temp_dir)


def merge_target_files(temp_dir, system_target_files, system_item_list,
                       system_misc_info_keys, other_target_files,
                       other_item_list, output_target_files, output_dir,
                       output_item_list, output_ota, output_img,
                       output_super_empty, rebuild_recovery):
  """Merge two target files packages together.

  This function takes system and other target files packages as input, performs
  various file extractions, special case processing, and finally creates a
  merged zip archive as output.

  Args:
    temp_dir: The name of a directory we use when we extract items from the
      input target files packages, and also a scratch directory that we use for
      temporary files.
    system_target_files: The name of the zip archive containing the system
      partial target files package.
    system_item_list: The list of items to extract from the partial system
      target files package as is, meaning these items will land in the output
      target files package exactly as they appear in the input partial system
      target files package.
    system_misc_info_keys: The list of keys to obtain from the system instance
      of META/misc_info.txt. The remaining keys from the other instance.
    other_target_files: The name of the zip archive containing the other partial
      target files package.
    other_item_list: The list of items to extract from the partial other target
      files package as is, meaning these items will land in the output target
      files package exactly as they appear in the input partial other target
      files package.
    output_target_files: The name of the output zip archive target files package
      created by merging system and other.
    output_dir: The destination directory for saving merged files.
    output_item_list: The list of items to copy into the output_dir.
    output_ota: The name of the output zip archive ota package.
    output_img: The name of the output zip archive img package.
    output_super_empty: If provided, creates a super_empty.img file from the
      merged target files package and saves it at this path.
    rebuild_recovery: If true, rebuild the recovery patch used by non-A/B
      devices and write it to the system image.
  """

  logger.info('starting: merge system %s and other %s into output %s',
              system_target_files, other_target_files, output_target_files)

  # Create directory names that we'll use when we extract files from system,
  # and other, and for zipping the final output.

  system_target_files_temp_dir = os.path.join(temp_dir, 'system')
  other_target_files_temp_dir = os.path.join(temp_dir, 'other')
  output_target_files_temp_dir = os.path.join(temp_dir, 'output')

  # Extract "as is" items from the input system partial target files package.
  # We extract them directly into the output temporary directory since the
  # items do not need special case processing.

  extract_items(
      target_files=system_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=system_item_list)

  # Extract "as is" items from the input other partial target files package. We
  # extract them directly into the output temporary directory since the items
  # do not need special case processing.

  extract_items(
      target_files=other_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=other_item_list)

  # Extract "special" items from the input system partial target files package.
  # We extract these items to different directory since they require special
  # processing before they will end up in the output directory.

  extract_items(
      target_files=system_target_files,
      target_files_temp_dir=system_target_files_temp_dir,
      extract_item_list=system_extract_special_item_list)

  # Extract "special" items from the input other partial target files package.
  # We extract these items to different directory since they require special
  # processing before they will end up in the output directory.

  extract_items(
      target_files=other_target_files,
      target_files_temp_dir=other_target_files_temp_dir,
      extract_item_list=other_extract_special_item_list)

  # Now that the temporary directories contain all the extracted files, perform
  # special case processing on any items that need it. After this function
  # completes successfully, all the files we need to create the output target
  # files package are in place.

  process_special_cases(
      system_target_files_temp_dir=system_target_files_temp_dir,
      other_target_files_temp_dir=other_target_files_temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir,
      system_misc_info_keys=system_misc_info_keys,
      rebuild_recovery=rebuild_recovery)

  # Regenerate IMAGES in the temporary directory.

  add_img_args = ['--verbose']
  if rebuild_recovery:
    add_img_args.append('--rebuild_recovery')
  add_img_args.append(output_target_files_temp_dir)

  add_img_to_target_files.main(add_img_args)

  # Create super_empty.img using the merged misc_info.txt.

  misc_info_txt = os.path.join(output_target_files_temp_dir, 'META',
                               'misc_info.txt')

  def read_helper():
    with open(misc_info_txt) as f:
      return list(f.read().splitlines())

  use_dynamic_partitions = common.LoadDictionaryFromLines(
      read_helper()).get('use_dynamic_partitions')

  if use_dynamic_partitions != 'true' and output_super_empty:
    raise ValueError(
        'Building super_empty.img requires use_dynamic_partitions=true.')
  elif use_dynamic_partitions == 'true':
    super_empty_img = os.path.join(output_target_files_temp_dir, 'IMAGES',
                                   'super_empty.img')
    build_super_image_args = [
        misc_info_txt,
        super_empty_img,
    ]
    build_super_image.main(build_super_image_args)

    # Copy super_empty.img to the user-provided output_super_empty location.
    if output_super_empty:
      shutil.copyfile(super_empty_img, output_super_empty)

  # Create the IMG package from the merged target files (before zipping, in
  # order to avoid an unnecessary unzip and copy).

  if output_img:
    img_from_target_files_args = [
        output_target_files_temp_dir,
        output_img,
    ]
    img_from_target_files.main(img_from_target_files_args)

  # Finally, create the output target files zip archive and/or copy the
  # output items to the output target files directory.

  if output_dir:
    copy_items(output_target_files_temp_dir, output_dir, output_item_list)

  if not output_target_files:
    return

  output_zip = os.path.abspath(output_target_files)
  output_target_files_list = os.path.join(temp_dir, 'output.list')
  output_target_files_meta_dir = os.path.join(output_target_files_temp_dir,
                                              'META')

  find_command = [
      'find',
      output_target_files_meta_dir,
  ]
  find_process = common.Run(find_command, stdout=subprocess.PIPE, verbose=False)
  meta_content = common.RunAndCheckOutput(['sort'],
                                          stdin=find_process.stdout,
                                          verbose=False)

  find_command = [
      'find', output_target_files_temp_dir, '-path',
      output_target_files_meta_dir, '-prune', '-o', '-print'
  ]
  find_process = common.Run(find_command, stdout=subprocess.PIPE, verbose=False)
  other_content = common.RunAndCheckOutput(['sort'],
                                           stdin=find_process.stdout,
                                           verbose=False)

  with open(output_target_files_list, 'wb') as f:
    f.write(meta_content)
    f.write(other_content)

  command = [
      'soong_zip',
      '-d',
      '-o',
      output_zip,
      '-C',
      output_target_files_temp_dir,
      '-l',
      output_target_files_list,
  ]
  logger.info('creating %s', output_target_files)
  common.RunAndWait(command, verbose=True)

  # Create the OTA package from the merged target files package.

  if output_ota:
    ota_from_target_files_args = [
        output_zip,
        output_ota,
    ]
    ota_from_target_files.main(ota_from_target_files_args)


def call_func_with_temp_dir(func, keep_tmp):
  """Manage the creation and cleanup of the temporary directory.

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
  except:
    raise
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
      OPTIONS.system_target_files = a
    elif o == '--system-item-list':
      OPTIONS.system_item_list = a
    elif o == '--system-misc-info-keys':
      OPTIONS.system_misc_info_keys = a
    elif o == '--other-target-files':
      OPTIONS.other_target_files = a
    elif o == '--other-item-list':
      OPTIONS.other_item_list = a
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
    elif o == '--rebuild_recovery':
      OPTIONS.rebuild_recovery = True
    elif o == '--keep-tmp':
      OPTIONS.keep_tmp = True
    else:
      return False
    return True

  args = common.ParseOptions(
      sys.argv[1:],
      __doc__,
      extra_long_opts=[
          'system-target-files=',
          'system-item-list=',
          'system-misc-info-keys=',
          'other-target-files=',
          'other-item-list=',
          'output-target-files=',
          'output-dir=',
          'output-item-list=',
          'output-ota=',
          'output-img=',
          'output-super-empty=',
          'rebuild_recovery',
          'keep-tmp',
      ],
      extra_option_handler=option_handler)

  if (args or OPTIONS.system_target_files is None or
      OPTIONS.other_target_files is None or
      (OPTIONS.output_target_files is None and OPTIONS.output_dir is None) or
      (OPTIONS.output_dir is not None and OPTIONS.output_item_list is None)):
    common.Usage(__doc__)
    sys.exit(1)

  if OPTIONS.system_item_list:
    system_item_list = read_config_list(OPTIONS.system_item_list)
  else:
    system_item_list = default_system_item_list

  if OPTIONS.system_misc_info_keys:
    system_misc_info_keys = read_config_list(OPTIONS.system_misc_info_keys)
  else:
    system_misc_info_keys = default_system_misc_info_keys

  if OPTIONS.other_item_list:
    other_item_list = read_config_list(OPTIONS.other_item_list)
  else:
    other_item_list = default_other_item_list

  if OPTIONS.output_item_list:
    output_item_list = read_config_list(OPTIONS.output_item_list)
  else:
    output_item_list = None

  if not validate_config_lists(
      system_item_list=system_item_list,
      system_misc_info_keys=system_misc_info_keys,
      other_item_list=other_item_list):
    sys.exit(1)

  call_func_with_temp_dir(
      lambda temp_dir: merge_target_files(
          temp_dir=temp_dir,
          system_target_files=OPTIONS.system_target_files,
          system_item_list=system_item_list,
          system_misc_info_keys=system_misc_info_keys,
          other_target_files=OPTIONS.other_target_files,
          other_item_list=other_item_list,
          output_target_files=OPTIONS.output_target_files,
          output_dir=OPTIONS.output_dir,
          output_item_list=output_item_list,
          output_ota=OPTIONS.output_ota,
          output_img=OPTIONS.output_img,
          output_super_empty=OPTIONS.output_super_empty,
          rebuild_recovery=OPTIONS.rebuild_recovery), OPTIONS.keep_tmp)


if __name__ == '__main__':
  main()
