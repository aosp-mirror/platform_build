#
# Copyright (C) 2017 The Android Open Source Project
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
#

import os.path

import common
import merge_target_files
import merge_utils
import test_utils


class MergeUtilsTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.OPTIONS = merge_target_files.OPTIONS

  def test_CopyItems_CopiesItemsMatchingPatterns(self):

    def createEmptyFile(path):
      if not os.path.exists(os.path.dirname(path)):
        os.makedirs(os.path.dirname(path))
      open(path, 'a').close()
      return path

    def createEmptyFolder(path):
      os.makedirs(path)
      return path

    def createSymLink(source, dest):
      os.symlink(source, dest)
      return dest

    def getRelPaths(start, filepaths):
      return set(
          os.path.relpath(path=filepath, start=start)
          for filepath in filepaths)

    input_dir = common.MakeTempDir()
    output_dir = common.MakeTempDir()
    expected_copied_items = []
    actual_copied_items = []
    patterns = ['*.cpp', 'subdir/*.txt', 'subdir/empty_dir']

    # Create various files and empty directories that we expect to get copied
    # because they match one of the patterns.
    expected_copied_items.extend([
        createEmptyFile(os.path.join(input_dir, 'a.cpp')),
        createEmptyFile(os.path.join(input_dir, 'b.cpp')),
        createEmptyFile(os.path.join(input_dir, 'subdir', 'c.txt')),
        createEmptyFile(os.path.join(input_dir, 'subdir', 'd.txt')),
        createEmptyFile(
            os.path.join(input_dir, 'subdir', 'subsubdir', 'e.txt')),
        createEmptyFolder(os.path.join(input_dir, 'subdir', 'empty_dir')),
        createSymLink('a.cpp', os.path.join(input_dir, 'a_link.cpp')),
    ])
    # Create some more files that we expect to not get copied.
    createEmptyFile(os.path.join(input_dir, 'a.h'))
    createEmptyFile(os.path.join(input_dir, 'b.h'))
    createEmptyFile(os.path.join(input_dir, 'subdir', 'subsubdir', 'f.gif'))
    createSymLink('a.h', os.path.join(input_dir, 'a_link.h'))

    # Copy items.
    merge_utils.CopyItems(input_dir, output_dir, patterns)

    # Assert the actual copied items match the ones we expected.
    for root_dir, dirs, files in os.walk(output_dir):
      actual_copied_items.extend(
          os.path.join(root_dir, filename) for filename in files)
      for dirname in dirs:
        dir_path = os.path.join(root_dir, dirname)
        if not os.listdir(dir_path):
          actual_copied_items.append(dir_path)
    self.assertEqual(
        getRelPaths(output_dir, actual_copied_items),
        getRelPaths(input_dir, expected_copied_items))
    self.assertEqual(
        os.readlink(os.path.join(output_dir, 'a_link.cpp')), 'a.cpp')

  def test_ValidateConfigLists_ReturnsFalseIfSharedExtractedPartition(self):
    self.OPTIONS.system_item_list = [
        'SYSTEM/*',
    ]
    self.OPTIONS.vendor_item_list = [
        'SYSTEM/my_system_file',
        'VENDOR/*',
    ]
    self.OPTIONS.vendor_item_list.append('SYSTEM/my_system_file')
    self.assertFalse(merge_utils.ValidateConfigLists())

  def test_ValidateConfigLists_ReturnsFalseIfSharedExtractedPartitionImage(
      self):
    self.OPTIONS.system_item_list = [
        'SYSTEM/*',
    ]
    self.OPTIONS.vendor_item_list = [
        'IMAGES/system.img',
        'VENDOR/*',
    ]
    self.assertFalse(merge_utils.ValidateConfigLists())

  def test_ValidateConfigLists_ReturnsFalseIfBadSystemMiscInfoKeys(self):
    for bad_key in ['dynamic_partition_list', 'super_partition_groups']:
      self.OPTIONS.framework_misc_info_keys = [bad_key]
      self.assertFalse(merge_utils.ValidateConfigLists())

  def test_ItemListToPartitionSet(self):
    item_list = [
        'IMAGES/system_ext.img',
        'META/apexkeys.txt',
        'META/apkcerts.txt',
        'META/filesystem_config.txt',
        'PRODUCT/*',
        'SYSTEM/*',
        'SYSTEM/system_ext/*',
    ]
    partition_set = merge_utils.ItemListToPartitionSet(item_list)
    self.assertEqual(set(['product', 'system', 'system_ext']), partition_set)

  def test_InferItemList_Framework(self):
    zip_namelist = [
        'IMAGES/product.img',
        'IMAGES/product.map',
        'IMAGES/system.img',
        'IMAGES/system.map',
        'SYSTEM/my_system_file',
        'PRODUCT/my_product_file',
        # Device does not use a separate system_ext partition.
        'SYSTEM/system_ext/system_ext_file',
    ]

    item_list = merge_utils.InferItemList(zip_namelist, framework=True)

    expected_framework_item_list = [
        'IMAGES/product.img',
        'IMAGES/product.map',
        'IMAGES/system.img',
        'IMAGES/system.map',
        'META/filesystem_config.txt',
        'META/liblz4.so',
        'META/postinstall_config.txt',
        'META/product_filesystem_config.txt',
        'META/zucchini_config.txt',
        'PRODUCT/*',
        'SYSTEM/*',
    ]

    self.assertEqual(item_list, expected_framework_item_list)

  def test_InferItemList_Vendor(self):
    zip_namelist = [
        'VENDOR/my_vendor_file',
        'ODM/my_odm_file',
        'IMAGES/odm.img',
        'IMAGES/odm.map',
        'IMAGES/vendor.img',
        'IMAGES/vendor.map',
        'IMAGES/my_custom_image.img',
        'IMAGES/my_custom_file.txt',
        'IMAGES/vbmeta.img',
        'CUSTOM_PARTITION/my_custom_file',
        # Leftover framework pieces that shouldn't be grabbed.
        'IMAGES/system.img',
        'SYSTEM/system_file',
    ]

    item_list = merge_utils.InferItemList(zip_namelist, framework=False)

    expected_vendor_item_list = [
        'CUSTOM_PARTITION/*',
        'IMAGES/my_custom_file.txt',
        'IMAGES/my_custom_image.img',
        'IMAGES/odm.img',
        'IMAGES/odm.map',
        'IMAGES/vendor.img',
        'IMAGES/vendor.map',
        'META/custom_partition_filesystem_config.txt',
        'META/kernel_configs.txt',
        'META/kernel_version.txt',
        'META/odm_filesystem_config.txt',
        'META/otakeys.txt',
        'META/pack_radioimages.txt',
        'META/releasetools.py',
        'META/vendor_filesystem_config.txt',
        'ODM/*',
        'VENDOR/*',
    ]
    self.assertEqual(item_list, expected_vendor_item_list)

  def test_InferFrameworkMiscInfoKeys(self):
    zip_namelist = [
        'PRODUCT/',
        'SYSTEM/',
        'SYSTEM/system_ext/',
    ]

    keys = merge_utils.InferFrameworkMiscInfoKeys(zip_namelist)

    expected_keys = [
        'ab_update',
        'avb_product_add_hashtree_footer_args',
        'avb_product_hashtree_enable',
        'avb_system_add_hashtree_footer_args',
        'avb_system_ext_add_hashtree_footer_args',
        'avb_system_ext_hashtree_enable',
        'avb_system_hashtree_enable',
        'avb_vbmeta_system',
        'avb_vbmeta_system_algorithm',
        'avb_vbmeta_system_key_path',
        'avb_vbmeta_system_rollback_index_location',
        'building_product_image',
        'building_system_ext_image',
        'building_system_image',
        'default_system_dev_certificate',
        'fs_type',
        'product_disable_sparse',
        'product_fs_type',
        'system_disable_sparse',
        'system_ext_disable_sparse',
        'system_ext_fs_type',
    ]
    self.assertEqual(keys, expected_keys)
