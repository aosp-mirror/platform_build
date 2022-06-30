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
import shutil

import common
import merge_meta
import merge_target_files
import test_utils


class MergeMetaTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.OPTIONS = merge_target_files.OPTIONS
    self.OPTIONS.framework_partition_set = set(
        ['product', 'system', 'system_ext'])
    self.OPTIONS.vendor_partition_set = set(['odm', 'vendor'])

  def test_MergePackageKeys_ReturnsTrueIfNoConflicts(self):
    output_meta_dir = common.MakeTempDir()

    framework_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework.txt'),
        os.path.join(framework_meta_dir, 'apexkeys.txt'))

    vendor_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_vendor.txt'),
        os.path.join(vendor_meta_dir, 'apexkeys.txt'))

    merge_meta.MergePackageKeys(framework_meta_dir, vendor_meta_dir,
                                output_meta_dir, 'apexkeys.txt')

    merged_entries = []
    merged_path = os.path.join(self.testdata_dir, 'apexkeys_merge.txt')

    with open(merged_path) as f:
      merged_entries = f.read().split('\n')

    output_entries = []
    output_path = os.path.join(output_meta_dir, 'apexkeys.txt')

    with open(output_path) as f:
      output_entries = f.read().split('\n')

    return self.assertEqual(merged_entries, output_entries)

  def test_MergePackageKeys_ReturnsFalseIfConflictsPresent(self):
    output_meta_dir = common.MakeTempDir()

    framework_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework.txt'),
        os.path.join(framework_meta_dir, 'apexkeys.txt'))

    conflict_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apexkeys_framework_conflict.txt'),
        os.path.join(conflict_meta_dir, 'apexkeys.txt'))

    self.assertRaises(ValueError, merge_meta.MergePackageKeys,
                      framework_meta_dir, conflict_meta_dir, output_meta_dir,
                      'apexkeys.txt')

  def test_MergePackageKeys_HandlesApkCertsSyntax(self):
    output_meta_dir = common.MakeTempDir()

    framework_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apkcerts_framework.txt'),
        os.path.join(framework_meta_dir, 'apkcerts.txt'))

    vendor_meta_dir = common.MakeTempDir()
    os.symlink(
        os.path.join(self.testdata_dir, 'apkcerts_vendor.txt'),
        os.path.join(vendor_meta_dir, 'apkcerts.txt'))

    merge_meta.MergePackageKeys(framework_meta_dir, vendor_meta_dir,
                                output_meta_dir, 'apkcerts.txt')

    merged_entries = []
    merged_path = os.path.join(self.testdata_dir, 'apkcerts_merge.txt')

    with open(merged_path) as f:
      merged_entries = f.read().split('\n')

    output_entries = []
    output_path = os.path.join(output_meta_dir, 'apkcerts.txt')

    with open(output_path) as f:
      output_entries = f.read().split('\n')

    return self.assertEqual(merged_entries, output_entries)
