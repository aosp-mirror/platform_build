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
      Copy the recovery image used by non-A/B devices, used when
      regenerating vendor images with --rebuild-sepolicy.

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

from common import ExternalError

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
    'SYSTEM_DLKM/',
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


def extract_items(input_zip, output_dir, extract_item_list):
  """Extracts items in extra_item_list from a zip to a dir."""

  logger.info('extracting from %s', input_zip)

  # Filter the extract_item_list to remove any items that do not exist in the
  # zip file. Otherwise, the extraction step will fail.

  with zipfile.ZipFile(input_zip, allowZip64=True) as input_zipfile:
    input_namelist = input_zipfile.namelist()

  filtered_extract_item_list = []
  for pattern in extract_item_list:
    matching_namelist = fnmatch.filter(input_namelist, pattern)
    if not matching_namelist:
      logger.warning('no match for %s', pattern)
    else:
      filtered_extract_item_list.append(pattern)

  common.UnzipToDir(input_zip, output_dir, filtered_extract_item_list)


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


def validate_config_lists():
  """Performs validations on the merge config lists.

  Returns:
    False if a validation fails, otherwise true.
  """
  has_error = False

  default_combined_item_set = set(DEFAULT_FRAMEWORK_ITEM_LIST)
  default_combined_item_set.update(DEFAULT_VENDOR_ITEM_LIST)

  combined_item_set = set(OPTIONS.framework_item_list)
  combined_item_set.update(OPTIONS.vendor_item_list)

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

  if ('dynamic_partition_list' in OPTIONS.framework_misc_info_keys) or (
      'super_partition_groups' in OPTIONS.framework_misc_info_keys):
    logger.error('Dynamic partition misc info keys should come from '
                 'the vendor instance of META/misc_info.txt.')
    has_error = True

  return not has_error


def merge_ab_partitions_txt(framework_meta_dir, vendor_meta_dir,
                            merged_meta_dir):
  """Merges META/ab_partitions.txt.

  The output contains the union of the partition names.
  """
  with open(os.path.join(framework_meta_dir, 'ab_partitions.txt')) as f:
    framework_ab_partitions = f.read().splitlines()

  with open(os.path.join(vendor_meta_dir, 'ab_partitions.txt')) as f:
    vendor_ab_partitions = f.read().splitlines()

  write_sorted_data(
      data=set(framework_ab_partitions + vendor_ab_partitions),
      path=os.path.join(merged_meta_dir, 'ab_partitions.txt'))


def merge_misc_info_txt(framework_meta_dir, vendor_meta_dir, merged_meta_dir):
  """Merges META/misc_info.txt.

  The output contains a combination of key=value pairs from both inputs.
  Most pairs are taken from the vendor input, while some are taken from
  the framework input.
  """

  OPTIONS.framework_misc_info = common.LoadDictionaryFromFile(
      os.path.join(framework_meta_dir, 'misc_info.txt'))
  OPTIONS.vendor_misc_info = common.LoadDictionaryFromFile(
      os.path.join(vendor_meta_dir, 'misc_info.txt'))

  # Merged misc info is a combination of vendor misc info plus certain values
  # from the framework misc info.

  merged_dict = OPTIONS.vendor_misc_info
  for key in OPTIONS.framework_misc_info_keys:
    merged_dict[key] = OPTIONS.framework_misc_info[key]

  # If AVB is enabled then ensure that we build vbmeta.img.
  # Partial builds with AVB enabled may set PRODUCT_BUILD_VBMETA_IMAGE=false to
  # skip building an incomplete vbmeta.img.
  if merged_dict.get('avb_enable') == 'true':
    merged_dict['avb_building_vbmeta_image'] = 'true'

  return merged_dict


def merge_dynamic_partitions_info_txt(framework_meta_dir, vendor_meta_dir,
                                      merged_meta_dir):
  """Merge META/dynamic_partitions_info.txt."""
  framework_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(framework_meta_dir, 'dynamic_partitions_info.txt'))
  vendor_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(vendor_meta_dir, 'dynamic_partitions_info.txt'))

  merged_dynamic_partitions_dict = common.MergeDynamicPartitionInfoDicts(
      framework_dict=framework_dynamic_partitions_dict,
      vendor_dict=vendor_dynamic_partitions_dict)

  write_sorted_data(
      data=merged_dynamic_partitions_dict,
      path=os.path.join(merged_meta_dir, 'dynamic_partitions_info.txt'))

  # Merge misc info keys used for Dynamic Partitions.
  OPTIONS.merged_misc_info.update(merged_dynamic_partitions_dict)
  # Ensure that add_img_to_target_files rebuilds super split images for
  # devices that retrofit dynamic partitions. This flag may have been set to
  # false in the partial builds to prevent duplicate building of super.img.
  OPTIONS.merged_misc_info['build_super_partition'] = 'true'


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


def merge_package_keys_txt(framework_meta_dir, vendor_meta_dir, merged_meta_dir,
                           file_name):
  """Merges APK/APEX key list files."""

  if file_name not in ('apkcerts.txt', 'apexkeys.txt'):
    raise ExternalError(
        'Unexpected file_name provided to merge_package_keys_txt: %s',
        file_name)

  def read_helper(d):
    temp = {}
    with open(os.path.join(d, file_name)) as f:
      for line in f.read().splitlines():
        line = line.strip()
        if line:
          name_search = MODULE_KEY_PATTERN.search(line.split()[0])
          temp[name_search.group(1)] = line
    return temp

  framework_dict = read_helper(framework_meta_dir)
  vendor_dict = read_helper(vendor_meta_dir)
  merged_dict = {}

  def filter_into_merged_dict(item_dict, partition_set):
    for key, value in item_dict.items():
      tag_search = PARTITION_TAG_PATTERN.search(value)

      if tag_search is None:
        raise ValueError('Entry missing partition tag: %s' % value)

      partition_tag = tag_search.group(1)

      if partition_tag in partition_set:
        if key in merged_dict:
          if OPTIONS.allow_duplicate_apkapex_keys:
            # TODO(b/150582573) Always raise on duplicates.
            logger.warning('Duplicate key %s' % key)
            continue
          else:
            raise ValueError('Duplicate key %s' % key)

        merged_dict[key] = value

  # Prioritize framework keys first.
  # Duplicate keys from vendor are an error, or ignored.
  filter_into_merged_dict(framework_dict, OPTIONS.framework_partition_set)
  filter_into_merged_dict(vendor_dict, OPTIONS.vendor_partition_set)

  # The following code is similar to write_sorted_data, but different enough
  # that we couldn't use that function. We need the output to be sorted by the
  # basename of the apex/apk (without the ".apex" or ".apk" suffix). This
  # allows the sort to be consistent with the framework/vendor input data and
  # eases comparison of input data with merged data.
  with open(os.path.join(merged_meta_dir, file_name), 'w') as output:
    for key, value in sorted(merged_dict.items()):
      output.write(value + '\n')


def create_file_contexts_copies(framework_meta_dir, vendor_meta_dir,
                                merged_meta_dir):
  """Creates named copies of each partial build's file_contexts.bin.

  Used when regenerating images from the partial build.
  """

  def copy_fc_file(source_dir, file_name):
    for name in (file_name, 'file_contexts.bin'):
      fc_path = os.path.join(source_dir, name)
      if os.path.exists(fc_path):
        shutil.copyfile(fc_path, os.path.join(merged_meta_dir, file_name))
        return
    raise ValueError('Missing file_contexts file from %s: %s', source_dir,
                     file_name)

  copy_fc_file(framework_meta_dir, 'framework_file_contexts.bin')
  copy_fc_file(vendor_meta_dir, 'vendor_file_contexts.bin')

  # Replace <image>_selinux_fc values with framework or vendor file_contexts.bin
  # depending on which dictionary the key came from.
  # Only the file basename is required because all selinux_fc properties are
  # replaced with the full path to the file under META/ when misc_info.txt is
  # loaded from target files for repacking. See common.py LoadInfoDict().
  for key in OPTIONS.vendor_misc_info:
    if key.endswith('_selinux_fc'):
      OPTIONS.merged_misc_info[key] = 'vendor_file_contexts.bin'
  for key in OPTIONS.framework_misc_info:
    if key.endswith('_selinux_fc'):
      OPTIONS.merged_misc_info[key] = 'framework_file_contexts.bin'


def compile_split_sepolicy(target_files_dir, partition_map):
  """Uses secilc to compile a split sepolicy file.

  Depends on various */etc/selinux/* and */etc/vintf/* files within partitions.

  Args:
    target_files_dir: Extracted directory of target_files, containing partition
      directories.
    partition_map: A map of partition name -> relative path within
      target_files_dir.

  Returns:
    A command list that can be executed to create the compiled sepolicy.
  """

  def get_file(partition, path):
    if partition not in partition_map:
      logger.warning('Cannot load SEPolicy files for missing partition %s',
                     partition)
      return None
    return os.path.join(target_files_dir, partition_map[partition], path)

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


def validate_merged_apex_info(target_files_dir, partitions):
  """Validates the APEX files in the merged target files directory.

  Checks the APEX files in all possible preinstalled APEX directories.
  Depends on the <partition>/apex/* APEX files within partitions.

  Args:
    target_files_dir: Extracted directory of target_files, containing partition
      directories.
    partitions: A list of all the partitions in the output directory.

  Raises:
    RuntimeError: if apex_utils fails to parse any APEX file.
    ExternalError: if the same APEX package is provided by multiple partitions.
  """
  apex_packages = set()

  apex_partitions = ('system', 'system_ext', 'product', 'vendor', 'odm')
  for partition in filter(lambda p: p in apex_partitions, partitions):
    apex_info = apex_utils.GetApexInfoFromTargetFiles(
        target_files_dir, partition, compressed_only=False)
    partition_apex_packages = set([info.package_name for info in apex_info])
    duplicates = apex_packages.intersection(partition_apex_packages)
    if duplicates:
      raise ExternalError(
          'Duplicate APEX packages found in multiple partitions: %s' %
          ' '.join(duplicates))
    apex_packages.update(partition_apex_packages)


def generate_care_map(partitions, target_files_dir):
  """Generates a merged META/care_map.pb file in the target files dir.

  Depends on the info dict from META/misc_info.txt, as well as built images
  within IMAGES/.

  Args:
    partitions: A list of partitions to potentially include in the care map.
    target_files_dir: Extracted directory of target_files, containing partition
      directories.
  """
  OPTIONS.info_dict = common.LoadInfoDict(target_files_dir)
  partition_image_map = {}
  for partition in partitions:
    image_path = os.path.join(target_files_dir, 'IMAGES',
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


def merge_meta_files(temp_dir, merged_dir):
  """Merges various files in META/*."""

  framework_meta_dir = os.path.join(temp_dir, 'framework_meta', 'META')
  extract_items(
      input_zip=OPTIONS.framework_target_files,
      output_dir=os.path.dirname(framework_meta_dir),
      extract_item_list=('META/*',))

  vendor_meta_dir = os.path.join(temp_dir, 'vendor_meta', 'META')
  extract_items(
      input_zip=OPTIONS.vendor_target_files,
      output_dir=os.path.dirname(vendor_meta_dir),
      extract_item_list=('META/*',))

  merged_meta_dir = os.path.join(merged_dir, 'META')

  # Merge META/misc_info.txt into OPTIONS.merged_misc_info,
  # but do not write it yet. The following functions may further
  # modify this dict.
  OPTIONS.merged_misc_info = merge_misc_info_txt(
      framework_meta_dir=framework_meta_dir,
      vendor_meta_dir=vendor_meta_dir,
      merged_meta_dir=merged_meta_dir)

  create_file_contexts_copies(
      framework_meta_dir=framework_meta_dir,
      vendor_meta_dir=vendor_meta_dir,
      merged_meta_dir=merged_meta_dir)

  if OPTIONS.merged_misc_info.get('use_dynamic_partitions') == 'true':
    merge_dynamic_partitions_info_txt(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir)

  if OPTIONS.merged_misc_info.get('ab_update') == 'true':
    merge_ab_partitions_txt(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir)

  for file_name in ('apkcerts.txt', 'apexkeys.txt'):
    merge_package_keys_txt(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir,
        file_name=file_name)

  # Write the now-finalized OPTIONS.merged_misc_info.
  write_sorted_data(
      data=OPTIONS.merged_misc_info,
      path=os.path.join(merged_meta_dir, 'misc_info.txt'))


def process_dexopt(temp_dir, output_target_files_dir):
  """If needed, generates dexopt files for vendor apps.

  Args:
    temp_dir: Location containing an 'output' directory where target files have
      been extracted, e.g. <temp_dir>/output/SYSTEM, <temp_dir>/output/IMAGES,
      etc.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
  """
  # Load vendor and framework META/misc_info.txt.
  if (OPTIONS.vendor_misc_info.get('building_with_vsdk') != 'true' or
      OPTIONS.framework_dexpreopt_tools is None or
      OPTIONS.framework_dexpreopt_config is None or
      OPTIONS.vendor_dexpreopt_config is None):
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
  dexpreopt_framework_config_files_temp_dir = os.path.join(
      temp_dir, 'system_config')
  dexpreopt_vendor_config_files_temp_dir = os.path.join(temp_dir,
                                                        'vendor_config')

  extract_items(
      input_zip=OPTIONS.framework_dexpreopt_tools,
      output_dir=dexpreopt_tools_files_temp_dir,
      extract_item_list=('*',))
  extract_items(
      input_zip=OPTIONS.framework_dexpreopt_config,
      output_dir=dexpreopt_framework_config_files_temp_dir,
      extract_item_list=('*',))
  extract_items(
      input_zip=OPTIONS.vendor_dexpreopt_config,
      output_dir=dexpreopt_vendor_config_files_temp_dir,
      extract_item_list=('*',))

  os.symlink(
      os.path.join(output_target_files_dir, 'SYSTEM'),
      os.path.join(temp_dir, 'system'))
  os.symlink(
      os.path.join(output_target_files_dir, 'VENDOR'),
      os.path.join(temp_dir, 'vendor'))

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
  apex_root = os.path.join(output_target_files_dir, 'SYSTEM', 'apex')

  # Check for flattended versus updatable APEX.
  if OPTIONS.framework_misc_info.get('target_flatten_apex') == 'false':
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
        os.path.join(temp_dir, 'output', 'META',
                     'vendor_filesystem_config.txt'), 'a')

  # Dexpreopt vendor apps.
  dexpreopt_config_suffix = '_dexpreopt.config'
  for config in glob.glob(
      os.path.join(dexpreopt_vendor_config_files_temp_dir,
                   '*' + dexpreopt_config_suffix)):
    app = os.path.basename(config)[:-len(dexpreopt_config_suffix)]
    logging.info('dexpreopt config: %s %s', config, app)

    apk_dir = 'app'
    apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
    if not os.path.exists(apk_path):
      apk_dir = 'priv-app'
      apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
      if not os.path.exists(apk_path):
        logging.warning(
            'skipping dexpreopt for %s, no apk found in vendor/app '
            'or vendor/priv-app', app)
        continue

    # Generate dexpreopting script. Note 'out_dir' is not the output directory
    # where the script is generated, but the OUT_DIR at build time referenced
    # in the dexpreot config files, e.g., "out/.../core-oj.jar", so the tool knows
    # how to adjust the path.
    command = [
        os.path.join(dexpreopt_tools_files_temp_dir, 'dexpreopt_gen'),
        '-global',
        os.path.join(dexpreopt_framework_config_files_temp_dir,
                     'dexpreopt.config'),
        '-global_soong',
        os.path.join(dexpreopt_framework_config_files_temp_dir,
                     'dexpreopt_soong.config'),
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
    logging.info('running %s', command)
    subprocess.check_call(command, cwd=temp_dir)

    # Call the generated script.
    command = ['sh', 'dexpreopt_app.sh', apk_path]
    logging.info('running %s', command)
    subprocess.check_call(command, cwd=temp_dir)

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

    dex_destination = os.path.join(temp_dir, 'output', dex_img, apk_dir, app,
                                   'oat', arch)
    os.makedirs(dex_destination)
    dex2oat_path = os.path.join(temp_dir, 'out', 'dex2oat_result', 'vendor',
                                apk_dir, app, 'oat', arch)
    shutil.copy(
        os.path.join(dex2oat_path, 'package.vdex'),
        os.path.join(dex_destination, app + '.vdex'))
    shutil.copy(
        os.path.join(dex2oat_path, 'package.odex'),
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
          vendor_app_prefix + '/' + arch + '/' + app + '.odex 0 0 644 ' +
          selabel + '\n',
          vendor_app_prefix + '/' + arch + '/' + app + '.vdex 0 0 644 ' +
          selabel + '\n',
      ])

  if not use_system_other_odex:
    vendor_file_system_config.close()
    # Delete vendor.img so that it will be regenerated.
    # TODO(b/188179859): Rebuilding a vendor image in GRF mode (e.g., T(framework)
    #                    and S(vendor) may require logic similar to that in
    #                    rebuild_image_with_sepolicy.
    vendor_img = os.path.join(output_target_files_dir, 'IMAGES', 'vendor.img')
    if os.path.exists(vendor_img):
      logging.info('Deleting %s', vendor_img)
      os.remove(vendor_img)


def create_merged_package(temp_dir):
  """Merges two target files packages into one target files structure.

  Returns:
    Path to merged package under temp directory.
  """
  # Extract "as is" items from the input framework and vendor partial target
  # files packages directly into the output temporary directory, since these items
  # do not need special case processing.

  output_target_files_temp_dir = os.path.join(temp_dir, 'output')
  extract_items(
      input_zip=OPTIONS.framework_target_files,
      output_dir=output_target_files_temp_dir,
      extract_item_list=OPTIONS.framework_item_list)
  extract_items(
      input_zip=OPTIONS.vendor_target_files,
      output_dir=output_target_files_temp_dir,
      extract_item_list=OPTIONS.vendor_item_list)

  # Perform special case processing on META/* items.
  # After this function completes successfully, all the files we need to create
  # the output target files package are in place.
  merge_meta_files(temp_dir=temp_dir, merged_dir=output_target_files_temp_dir)

  process_dexopt(
      temp_dir=temp_dir, output_target_files_dir=output_target_files_temp_dir)

  return output_target_files_temp_dir


def generate_missing_images(target_files_dir):
  """Generate any missing images from target files."""

  # Regenerate IMAGES in the target directory.

  add_img_args = [
      '--verbose',
      '--add_missing',
  ]
  if OPTIONS.rebuild_recovery:
    add_img_args.append('--rebuild_recovery')
  add_img_args.append(target_files_dir)

  add_img_to_target_files.main(add_img_args)


def rebuild_image_with_sepolicy(target_files_dir):
  """Rebuilds odm.img or vendor.img to include merged sepolicy files.

  If odm is present then odm is preferred -- otherwise vendor is used.
  """
  partition = 'vendor'
  if os.path.exists(os.path.join(target_files_dir, 'ODM')) or os.path.exists(
      os.path.join(target_files_dir, 'IMAGES/odm.img')):
    partition = 'odm'
  partition_img = '{}.img'.format(partition)
  partition_map = '{}.map'.format(partition)

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

  if not OPTIONS.vendor_otatools:
    # Remove the partition from the merged target-files archive. It will be
    # rebuilt later automatically by generate_missing_images().
    os.remove(os.path.join(target_files_dir, 'IMAGES', partition_img))
    return

  # TODO(b/192253131): Remove the need for vendor_otatools by fixing
  # backwards-compatibility issues when compiling images across releases.
  if not OPTIONS.vendor_target_files:
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
  common.UnzipToDir(OPTIONS.vendor_otatools, vendor_otatools_dir)
  common.UnzipToDir(OPTIONS.vendor_target_files, vendor_target_files_dir)

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
  ]
  if OPTIONS.rebuild_recovery:
    rebuild_partition_command.append('--rebuild_recovery')
  rebuild_partition_command.append(vendor_target_files_dir)
  logger.info('Recompiling %s: %s', partition_img,
              ' '.join(rebuild_partition_command))
  common.RunAndCheckOutput(rebuild_partition_command, verbose=True)

  # Move the newly-created image to the merged target files dir.
  if not os.path.exists(os.path.join(target_files_dir, 'IMAGES')):
    os.makedirs(os.path.join(target_files_dir, 'IMAGES'))
  shutil.move(
      os.path.join(vendor_target_files_dir, 'IMAGES', partition_img),
      os.path.join(target_files_dir, 'IMAGES', partition_img))
  shutil.move(
      os.path.join(vendor_target_files_dir, 'IMAGES', partition_map),
      os.path.join(target_files_dir, 'IMAGES', partition_map))

  def copy_recovery_file(filename):
    for subdir in ('VENDOR', 'SYSTEM/vendor'):
      source = os.path.join(vendor_target_files_dir, subdir, filename)
      if os.path.exists(source):
        dest = os.path.join(target_files_dir, subdir, filename)
        shutil.copy(source, dest)
        return
    logger.info('Skipping copy_recovery_file for %s, file not found', filename)

  if OPTIONS.rebuild_recovery:
    copy_recovery_file('etc/recovery.img')
    copy_recovery_file('bin/install-recovery.sh')
    copy_recovery_file('recovery-from-boot.p')


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


def create_target_files_archive(output_zip, source_dir, temp_dir):
  """Creates a target_files zip archive from the input source dir.

  Args:
    output_zip: The name of the zip archive target files package.
    source_dir: The target directory contains package to be archived.
    temp_dir: Path to temporary directory for any intermediate files.
  """
  output_target_files_list = os.path.join(temp_dir, 'output.list')
  output_target_files_meta_dir = os.path.join(source_dir, 'META')

  def files_from_path(target_path, extra_args=None):
    """Gets files under the given path and return a sorted list."""
    find_command = ['find', target_path] + (extra_args or [])
    find_process = common.Run(
        find_command, stdout=subprocess.PIPE, verbose=False)
    return common.RunAndCheckOutput(['sort'],
                                    stdin=find_process.stdout,
                                    verbose=False)

  # META content appears first in the zip. This is done by the
  # standard build system for optimized extraction of those files,
  # so we do the same step for merged target_files.zips here too.
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
      os.path.abspath(output_zip),
      '-C',
      source_dir,
      '-r',
      output_target_files_list,
  ]

  logger.info('creating %s', output_zip)
  common.RunAndCheckOutput(command, verbose=True)
  logger.info('finished creating %s', output_zip)


def merge_target_files(temp_dir):
  """Merges two target files packages together.

  This function uses framework and vendor target files packages as input,
  performs various file extractions, special case processing, and finally
  creates a merged zip archive as output.

  Args:
    temp_dir: The name of a directory we use when we extract items from the
      input target files packages, and also a scratch directory that we use for
      temporary files.
  """

  logger.info('starting: merge framework %s and vendor %s into output %s',
              OPTIONS.framework_target_files, OPTIONS.vendor_target_files,
              OPTIONS.output_target_files)

  output_target_files_temp_dir = create_merged_package(temp_dir)

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
    shareduid_errors = common.SharedUidPartitionViolations(
        json.loads(violation),
        [OPTIONS.framework_partition_set, OPTIONS.vendor_partition_set])
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
  if OPTIONS.rebuild_sepolicy:
    rebuild_image_with_sepolicy(output_target_files_temp_dir)

  # Run validation checks on the pre-installed APEX files.
  validate_merged_apex_info(output_target_files_temp_dir, partition_map.keys())

  generate_missing_images(output_target_files_temp_dir)

  generate_super_empty_image(output_target_files_temp_dir,
                             OPTIONS.output_super_empty)

  # Finally, create the output target files zip archive and/or copy the
  # output items to the output target files directory.

  if OPTIONS.output_dir:
    copy_items(output_target_files_temp_dir, OPTIONS.output_dir,
               OPTIONS.output_item_list)

  if not OPTIONS.output_target_files:
    return

  # Create the merged META/care_map.pb if the device uses A/B updates.
  if OPTIONS.merged_misc_info.get('ab_update') == 'true':
    generate_care_map(partition_map.keys(), output_target_files_temp_dir)

  create_target_files_archive(OPTIONS.output_target_files,
                              output_target_files_temp_dir, temp_dir)

  # Create the IMG package from the merged target files package.
  if OPTIONS.output_img:
    img_from_target_files.main(
        [OPTIONS.output_target_files, OPTIONS.output_img])

  # Create the OTA package from the merged target files package.

  if OPTIONS.output_ota:
    ota_from_target_files.main(
        [OPTIONS.output_target_files, OPTIONS.output_ota])


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
    elif o == '--rebuild_recovery':
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
      (OPTIONS.output_dir is not None and OPTIONS.output_item_list is None) or
      (OPTIONS.rebuild_recovery and not OPTIONS.rebuild_sepolicy)):
    common.Usage(__doc__)
    sys.exit(1)

  if OPTIONS.framework_item_list:
    OPTIONS.framework_item_list = common.LoadListFromFile(
        OPTIONS.framework_item_list)
  else:
    OPTIONS.framework_item_list = DEFAULT_FRAMEWORK_ITEM_LIST
  OPTIONS.framework_partition_set = item_list_to_partition_set(
      OPTIONS.framework_item_list)

  if OPTIONS.framework_misc_info_keys:
    OPTIONS.framework_misc_info_keys = common.LoadListFromFile(
        OPTIONS.framework_misc_info_keys)
  else:
    OPTIONS.framework_misc_info_keys = DEFAULT_FRAMEWORK_MISC_INFO_KEYS

  if OPTIONS.vendor_item_list:
    OPTIONS.vendor_item_list = common.LoadListFromFile(OPTIONS.vendor_item_list)
  else:
    OPTIONS.vendor_item_list = DEFAULT_VENDOR_ITEM_LIST
  OPTIONS.vendor_partition_set = item_list_to_partition_set(
      OPTIONS.vendor_item_list)

  if OPTIONS.output_item_list:
    OPTIONS.output_item_list = common.LoadListFromFile(OPTIONS.output_item_list)
  else:
    OPTIONS.output_item_list = None

  if not validate_config_lists():
    sys.exit(1)

  call_func_with_temp_dir(lambda temp_dir: merge_target_files(temp_dir),
                          OPTIONS.keep_tmp)


if __name__ == '__main__':
  main()
