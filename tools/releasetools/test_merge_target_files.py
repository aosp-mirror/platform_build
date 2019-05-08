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
import test_utils
from merge_target_files import (read_config_list, validate_config_lists,
                                default_system_item_list,
                                default_other_item_list,
                                default_system_misc_info_keys, copy_items,
                                merge_dynamic_partition_info_dicts)


class MergeTargetFilesTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def test_copy_items_CopiesItemsMatchingPatterns(self):

    def createEmptyFile(path):
      if not os.path.exists(os.path.dirname(path)):
        os.makedirs(os.path.dirname(path))
      open(path, 'a').close()
      return path

    def createSymLink(source, dest):
      os.symlink(source, dest)
      return dest

    def getRelPaths(start, filepaths):
      return set(
          os.path.relpath(path=filepath, start=start) for filepath in filepaths)

    input_dir = common.MakeTempDir()
    output_dir = common.MakeTempDir()
    expected_copied_items = []
    actual_copied_items = []
    patterns = ['*.cpp', 'subdir/*.txt']

    # Create various files that we expect to get copied because they
    # match one of the patterns.
    expected_copied_items.extend([
        createEmptyFile(os.path.join(input_dir, 'a.cpp')),
        createEmptyFile(os.path.join(input_dir, 'b.cpp')),
        createEmptyFile(os.path.join(input_dir, 'subdir', 'c.txt')),
        createEmptyFile(os.path.join(input_dir, 'subdir', 'd.txt')),
        createEmptyFile(
            os.path.join(input_dir, 'subdir', 'subsubdir', 'e.txt')),
        createSymLink('a.cpp', os.path.join(input_dir, 'a_link.cpp')),
    ])
    # Create some more files that we expect to not get copied.
    createEmptyFile(os.path.join(input_dir, 'a.h'))
    createEmptyFile(os.path.join(input_dir, 'b.h'))
    createEmptyFile(os.path.join(input_dir, 'subdir', 'subsubdir', 'f.gif'))
    createSymLink('a.h', os.path.join(input_dir, 'a_link.h'))

    # Copy items.
    copy_items(input_dir, output_dir, patterns)

    # Assert the actual copied items match the ones we expected.
    for dirpath, _, filenames in os.walk(output_dir):
      actual_copied_items.extend(
          os.path.join(dirpath, filename) for filename in filenames)
    self.assertEqual(
        getRelPaths(output_dir, actual_copied_items),
        getRelPaths(input_dir, expected_copied_items))
    self.assertEqual(
        os.readlink(os.path.join(output_dir, 'a_link.cpp')), 'a.cpp')

  def test_read_config_list(self):
    system_item_list_file = os.path.join(self.testdata_dir,
                                         'merge_config_system_item_list')
    system_item_list = read_config_list(system_item_list_file)
    expected_system_item_list = [
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
    self.assertItemsEqual(system_item_list, expected_system_item_list)

  def test_validate_config_lists_ReturnsFalseIfMissingDefaultItem(self):
    system_item_list = default_system_item_list[:]
    system_item_list.remove('SYSTEM/*')
    self.assertFalse(
        validate_config_lists(system_item_list, default_system_misc_info_keys,
                              default_other_item_list))

  def test_validate_config_lists_ReturnsTrueIfDefaultItemInDifferentList(self):
    system_item_list = default_system_item_list[:]
    system_item_list.remove('ROOT/*')
    other_item_list = default_other_item_list[:]
    other_item_list.append('ROOT/*')
    self.assertTrue(
        validate_config_lists(system_item_list, default_system_misc_info_keys,
                              other_item_list))

  def test_validate_config_lists_ReturnsTrueIfExtraItem(self):
    system_item_list = default_system_item_list[:]
    system_item_list.append('MY_NEW_PARTITION/*')
    self.assertTrue(
        validate_config_lists(system_item_list, default_system_misc_info_keys,
                              default_other_item_list))

  def test_validate_config_lists_ReturnsFalseIfBadSystemMiscInfoKeys(self):
    for bad_key in ['dynamic_partition_list', 'super_partition_groups']:
      system_misc_info_keys = default_system_misc_info_keys[:]
      system_misc_info_keys.append(bad_key)
      self.assertFalse(
          validate_config_lists(default_system_item_list, system_misc_info_keys,
                                default_other_item_list))

  def test_merge_dynamic_partition_info_dicts_ReturnsMergedDict(self):
    system_dict = {
        'super_partition_groups': 'group_a',
        'dynamic_partition_list': 'system',
        'super_group_a_list': 'system',
    }
    other_dict = {
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'vendor product',
        'super_group_a_list': 'vendor',
        'super_group_a_size': '1000',
        'super_group_b_list': 'product',
        'super_group_b_size': '2000',
    }
    merged_dict = merge_dynamic_partition_info_dicts(
        system_dict=system_dict,
        other_dict=other_dict,
        size_prefix='super_',
        size_suffix='_size',
        list_prefix='super_',
        list_suffix='_list')
    expected_merged_dict = {
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'system vendor product',
        'super_group_a_list': 'system vendor',
        'super_group_a_size': '1000',
        'super_group_b_list': 'product',
        'super_group_b_size': '2000',
    }
    self.assertEqual(merged_dict, expected_merged_dict)
