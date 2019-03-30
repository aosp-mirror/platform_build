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
from merge_target_files import (
    read_config_list, validate_config_lists, default_system_item_list,
    default_other_item_list, default_system_misc_info_keys)


class MergeTargetFilesTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

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
