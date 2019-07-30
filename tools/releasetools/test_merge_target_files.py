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
from merge_target_files import (validate_config_lists,
                                DEFAULT_FRAMEWORK_ITEM_LIST,
                                DEFAULT_VENDOR_ITEM_LIST,
                                DEFAULT_FRAMEWORK_MISC_INFO_KEYS, copy_items,
                                process_apex_keys_apk_certs_common)


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

  def test_validate_config_lists_ReturnsFalseIfMissingDefaultItem(self):
    framework_item_list = list(DEFAULT_FRAMEWORK_ITEM_LIST)
    framework_item_list.remove('SYSTEM/*')
    self.assertFalse(
        validate_config_lists(framework_item_list,
                              DEFAULT_FRAMEWORK_MISC_INFO_KEYS,
                              DEFAULT_VENDOR_ITEM_LIST))

  def test_validate_config_lists_ReturnsTrueIfDefaultItemInDifferentList(self):
    framework_item_list = list(DEFAULT_FRAMEWORK_ITEM_LIST)
    framework_item_list.remove('ROOT/*')
    vendor_item_list = list(DEFAULT_VENDOR_ITEM_LIST)
    vendor_item_list.append('ROOT/*')
    self.assertTrue(
        validate_config_lists(framework_item_list,
                              DEFAULT_FRAMEWORK_MISC_INFO_KEYS,
                              vendor_item_list))

  def test_validate_config_lists_ReturnsTrueIfExtraItem(self):
    framework_item_list = list(DEFAULT_FRAMEWORK_ITEM_LIST)
    framework_item_list.append('MY_NEW_PARTITION/*')
    self.assertTrue(
        validate_config_lists(framework_item_list,
                              DEFAULT_FRAMEWORK_MISC_INFO_KEYS,
                              DEFAULT_VENDOR_ITEM_LIST))

  def test_validate_config_lists_ReturnsFalseIfSharedExtractedPartition(self):
    vendor_item_list = list(DEFAULT_VENDOR_ITEM_LIST)
    vendor_item_list.append('SYSTEM/my_system_file')
    self.assertFalse(
        validate_config_lists(DEFAULT_FRAMEWORK_ITEM_LIST,
                              DEFAULT_FRAMEWORK_MISC_INFO_KEYS,
                              vendor_item_list))

  def test_validate_config_lists_ReturnsFalseIfBadSystemMiscInfoKeys(self):
    for bad_key in ['dynamic_partition_list', 'super_partition_groups']:
      framework_misc_info_keys = list(DEFAULT_FRAMEWORK_MISC_INFO_KEYS)
      framework_misc_info_keys.append(bad_key)
      self.assertFalse(
          validate_config_lists(DEFAULT_FRAMEWORK_ITEM_LIST,
                                framework_misc_info_keys,
                                DEFAULT_VENDOR_ITEM_LIST))

  def test_process_apex_keys_apk_certs_ReturnsTrueIfNoConflicts(self):
    output_dir = common.MakeTempDir()
    os.makedirs(os.path.join(output_dir, 'META'))

    framework_dir = common.MakeTempDir()
    os.makedirs(os.path.join(framework_dir, 'META'))
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework.txt'),
        os.path.join(framework_dir, 'META', 'apexkeys.txt'))

    vendor_dir = common.MakeTempDir()
    os.makedirs(os.path.join(vendor_dir, 'META'))
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_vendor.txt'),
        os.path.join(vendor_dir, 'META', 'apexkeys.txt'))

    process_apex_keys_apk_certs_common(framework_dir, vendor_dir, output_dir,
                                       'apexkeys.txt')

    merged_entries = []
    merged_path = os.path.join(self.testdata_dir, 'apexkeys_merge.txt')

    with open(merged_path) as f:
      merged_entries = f.read().split('\n')

    output_entries = []
    output_path = os.path.join(output_dir, 'META', 'apexkeys.txt')

    with open(output_path) as f:
      output_entries = f.read().split('\n')

    return self.assertEqual(merged_entries, output_entries)

  def test_process_apex_keys_apk_certs_ReturnsFalseIfConflictsPresent(self):
    output_dir = common.MakeTempDir()
    os.makedirs(os.path.join(output_dir, 'META'))

    framework_dir = common.MakeTempDir()
    os.makedirs(os.path.join(framework_dir, 'META'))
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework.txt'),
        os.path.join(framework_dir, 'META', 'apexkeys.txt'))

    conflict_dir = common.MakeTempDir()
    os.makedirs(os.path.join(conflict_dir, 'META'))
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework_conflict.txt'),
        os.path.join(conflict_dir, 'META', 'apexkeys.txt'))

    self.assertRaises(ValueError, process_apex_keys_apk_certs_common,
                      framework_dir, conflict_dir, output_dir, 'apexkeys.txt')
