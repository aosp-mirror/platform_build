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
"""Functions for merging META/* files from partial builds.

Expects items in OPTIONS prepared by merge_target_files.py.
"""

import logging
import os
import re
import shutil

import build_image
import common
import merge_utils
import sparse_img
import verity_utils
from ota_utils import ParseUpdateEngineConfig

from common import ExternalError

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

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


def MergeUpdateEngineConfig(framework_meta_dir, vendor_meta_dir,
                            merged_meta_dir):
  """Merges META/update_engine_config.txt.

  The output is the configuration for maximum compatibility.
  """
  _CONFIG_NAME = 'update_engine_config.txt'
  framework_config_path = os.path.join(framework_meta_dir, _CONFIG_NAME)
  vendor_config_path = os.path.join(vendor_meta_dir, _CONFIG_NAME)
  merged_config_path = os.path.join(merged_meta_dir, _CONFIG_NAME)

  if os.path.exists(framework_config_path):
    framework_config = ParseUpdateEngineConfig(framework_config_path)
    vendor_config = ParseUpdateEngineConfig(vendor_config_path)
    # Copy older config to merged target files for maximum compatibility
    # update_engine in system partition is from system side, but
    # update_engine_sideload in recovery is from vendor side.
    if framework_config < vendor_config:
      shutil.copy(framework_config_path, merged_config_path)
    else:
      shutil.copy(vendor_config_path, merged_config_path)
  else:
    if not OPTIONS.allow_partial_ab:
      raise FileNotFoundError(framework_config_path)
    shutil.copy(vendor_config_path, merged_config_path)


def MergeMetaFiles(temp_dir, merged_dir, framework_partitions):
  """Merges various files in META/*."""

  framework_meta_dir = os.path.join(temp_dir, 'framework_meta', 'META')
  merge_utils.CollectTargetFiles(
      input_zipfile_or_dir=OPTIONS.framework_target_files,
      output_dir=os.path.dirname(framework_meta_dir),
      item_list=('META/*',))

  vendor_meta_dir = os.path.join(temp_dir, 'vendor_meta', 'META')
  merge_utils.CollectTargetFiles(
      input_zipfile_or_dir=OPTIONS.vendor_target_files,
      output_dir=os.path.dirname(vendor_meta_dir),
      item_list=('META/*',))

  merged_meta_dir = os.path.join(merged_dir, 'META')

  # Merge META/misc_info.txt into OPTIONS.merged_misc_info,
  # but do not write it yet. The following functions may further
  # modify this dict.
  OPTIONS.merged_misc_info = MergeMiscInfo(
      framework_meta_dir=framework_meta_dir,
      vendor_meta_dir=vendor_meta_dir,
      merged_meta_dir=merged_meta_dir)

  CopyNamedFileContexts(
      framework_meta_dir=framework_meta_dir,
      vendor_meta_dir=vendor_meta_dir,
      merged_meta_dir=merged_meta_dir)

  if OPTIONS.merged_misc_info.get('use_dynamic_partitions') == 'true':
    MergeDynamicPartitionsInfo(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir)

  if OPTIONS.merged_misc_info.get('ab_update') == 'true':
    MergeAbPartitions(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir,
        framework_partitions=framework_partitions)
    UpdateCareMapImageSizeProps(images_dir=os.path.join(merged_dir, 'IMAGES'))

  for file_name in ('apkcerts.txt', 'apexkeys.txt'):
    MergePackageKeys(
        framework_meta_dir=framework_meta_dir,
        vendor_meta_dir=vendor_meta_dir,
        merged_meta_dir=merged_meta_dir,
        file_name=file_name)

  if OPTIONS.merged_misc_info.get('ab_update') == 'true':
    MergeUpdateEngineConfig(
        framework_meta_dir, vendor_meta_dir, merged_meta_dir)

  # Write the now-finalized OPTIONS.merged_misc_info.
  merge_utils.WriteSortedData(
      data=OPTIONS.merged_misc_info,
      path=os.path.join(merged_meta_dir, 'misc_info.txt'))


def MergeAbPartitions(framework_meta_dir, vendor_meta_dir, merged_meta_dir,
                      framework_partitions):
  """Merges META/ab_partitions.txt.

  The output contains the union of the partition names.
  """
  framework_ab_partitions = []
  framework_ab_config = os.path.join(framework_meta_dir, 'ab_partitions.txt')
  if os.path.exists(framework_ab_config):
    with open(framework_ab_config) as f:
      # Filter out some partitions here to support the case that the
      # ab_partitions.txt of framework-target-files has non-framework
      # partitions. This case happens when we use a complete merged target
      # files package as the framework-target-files.
      framework_ab_partitions.extend([
          partition
          for partition in f.read().splitlines()
          if partition in framework_partitions
      ])
  else:
    if not OPTIONS.allow_partial_ab:
      raise FileNotFoundError(framework_ab_config)
    logger.info('Use partial AB because framework ab_partitions.txt does not '
                'exist.')

  with open(os.path.join(vendor_meta_dir, 'ab_partitions.txt')) as f:
    vendor_ab_partitions = f.read().splitlines()

  merge_utils.WriteSortedData(
      data=set(framework_ab_partitions + vendor_ab_partitions),
      path=os.path.join(merged_meta_dir, 'ab_partitions.txt'))


def MergeMiscInfo(framework_meta_dir, vendor_meta_dir, merged_meta_dir):
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
    if key in OPTIONS.framework_misc_info:
      merged_dict[key] = OPTIONS.framework_misc_info[key]

  # If AVB is enabled then ensure that we build vbmeta.img.
  # Partial builds with AVB enabled may set PRODUCT_BUILD_VBMETA_IMAGE=false to
  # skip building an incomplete vbmeta.img.
  if merged_dict.get('avb_enable') == 'true':
    merged_dict['avb_building_vbmeta_image'] = 'true'

  return merged_dict


def MergeDynamicPartitionsInfo(framework_meta_dir, vendor_meta_dir,
                               merged_meta_dir):
  """Merge META/dynamic_partitions_info.txt."""
  framework_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(framework_meta_dir, 'dynamic_partitions_info.txt'))
  vendor_dynamic_partitions_dict = common.LoadDictionaryFromFile(
      os.path.join(vendor_meta_dir, 'dynamic_partitions_info.txt'))

  merged_dynamic_partitions_dict = common.MergeDynamicPartitionInfoDicts(
      framework_dict=framework_dynamic_partitions_dict,
      vendor_dict=vendor_dynamic_partitions_dict)

  merge_utils.WriteSortedData(
      data=merged_dynamic_partitions_dict,
      path=os.path.join(merged_meta_dir, 'dynamic_partitions_info.txt'))

  # Merge misc info keys used for Dynamic Partitions.
  OPTIONS.merged_misc_info.update(merged_dynamic_partitions_dict)
  # Ensure that add_img_to_target_files rebuilds super split images for
  # devices that retrofit dynamic partitions. This flag may have been set to
  # false in the partial builds to prevent duplicate building of super.img.
  OPTIONS.merged_misc_info['build_super_partition'] = 'true'


def MergePackageKeys(framework_meta_dir, vendor_meta_dir, merged_meta_dir,
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

  # The following code is similar to WriteSortedData, but different enough
  # that we couldn't use that function. We need the output to be sorted by the
  # basename of the apex/apk (without the ".apex" or ".apk" suffix). This
  # allows the sort to be consistent with the framework/vendor input data and
  # eases comparison of input data with merged data.
  with open(os.path.join(merged_meta_dir, file_name), 'w') as output:
    for key, value in sorted(merged_dict.items()):
      output.write(value + '\n')


def CopyNamedFileContexts(framework_meta_dir, vendor_meta_dir, merged_meta_dir):
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


def UpdateCareMapImageSizeProps(images_dir):
  """Sets <partition>_image_size props in misc_info.

  add_images_to_target_files uses these props to generate META/care_map.pb.
  Regenerated images will have this property set during regeneration.

  However, images copied directly from input partial target files packages
  need this value calculated here.
  """
  for partition in common.PARTITIONS_WITH_CARE_MAP:
    image_path = os.path.join(images_dir, '{}.img'.format(partition))
    if os.path.exists(image_path):
      partition_size = sparse_img.GetImagePartitionSize(image_path)
      image_props = build_image.ImagePropFromGlobalDict(
          OPTIONS.merged_misc_info, partition)
      verity_image_builder = verity_utils.CreateVerityImageBuilder(image_props)
      image_size = verity_image_builder.CalculateMaxImageSize(partition_size)
      OPTIONS.merged_misc_info['{}_image_size'.format(partition)] = image_size
