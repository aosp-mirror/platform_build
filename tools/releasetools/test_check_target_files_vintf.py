#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os.path

import common
import test_utils
from check_target_files_vintf import CheckVintf

# A skeleton target files directory structure. This is VINTF compatible.
SKELETON_TARGET_FILE_STRUCTURE = {
    # Empty files
    'PRODUCT/build.prop': '',
    'PRODUCT/etc/build.prop': '',
    'VENDOR/etc/build.prop': '',
    'ODM/build.prop': '',
    'ODM/etc/build.prop': '',
    'RECOVERY/RAMDISK/etc/recovery.fstab': '',
    'SYSTEM/build.prop': '',
    'SYSTEM/etc/build.prop': '',
    'SYSTEM_EXT/build.prop': '',
    'SYSTEM_EXT/etc/build.prop': '',

    # Non-empty files
    'SYSTEM/compatibility_matrix.xml':"""
        <compatibility-matrix version="1.0" type="framework">
            <sepolicy>
                <sepolicy-version>0.0</sepolicy-version>
                <kernel-sepolicy-version>0</kernel-sepolicy-version>
            </sepolicy>
        </compatibility-matrix>""",
    'SYSTEM/manifest.xml':
        '<manifest version="1.0" type="framework" />',
    'VENDOR/build.prop': 'ro.product.first_api_level=29\n',
    'VENDOR/compatibility_matrix.xml':
        '<compatibility-matrix version="1.0" type="device" />',
    'VENDOR/manifest.xml':
        '<manifest version="1.0" type="device"/>',
    'META/misc_info.txt':
        'recovery_api_version=3\nfstab_version=2\nvintf_enforce=true\n',
}


def write_string_to_file(content, path, mode='w'):
  if not os.path.isdir(os.path.dirname(path)):
    os.makedirs(os.path.dirname(path))
  with open(path, mode=mode) as f:
    f.write(content)


class CheckTargetFilesVintfTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def prepare_test_dir(self, test_delta_rel_path):
    test_delta_dir = os.path.join(self.testdata_dir, test_delta_rel_path)
    test_dir = common.MakeTempDir(prefix='check_target_files_vintf')

    # Create a skeleton directory structure of target files
    for rel_path, content in SKELETON_TARGET_FILE_STRUCTURE.items():
      write_string_to_file(content, os.path.join(test_dir, rel_path))

    # Overwrite with files from test_delta_rel_path
    for root, _, files in os.walk(test_delta_dir):
      rel_root = os.path.relpath(root, test_delta_dir)
      for f in files:
        if not f.endswith('.xml'):
          continue
        output_file = os.path.join(test_dir, rel_root, f)
        with open(os.path.join(root, f)) as inp:
          write_string_to_file(inp.read(), output_file)

    return test_dir

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_sanity(self):
    msg = 'Sanity check with skeleton target files failed.'
    test_dir = self.prepare_test_dir('does-not-exist')
    self.assertTrue(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_matrix_incompat(self):
    msg = 'vintf/matrix_incompat should be incompatible because sepolicy ' \
          'version fails to match'
    test_dir = self.prepare_test_dir('vintf/matrix_incompat')
    self.assertFalse(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_kernel_compat(self):
    msg = 'vintf/kernel with 4.14.1 kernel version should be compatible'
    test_dir = self.prepare_test_dir('vintf/kernel')
    write_string_to_file('', os.path.join(test_dir, 'META/kernel_configs.txt'))
    write_string_to_file('4.14.1',
                         os.path.join(test_dir, 'META/kernel_version.txt'))
    self.assertTrue(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_kernel_incompat(self):
    msg = 'vintf/kernel with 4.14.0 kernel version should be incompatible ' \
          'because 4.14.1 kernel version is required'
    test_dir = self.prepare_test_dir('vintf/kernel')
    write_string_to_file('', os.path.join(test_dir, 'META/kernel_configs.txt'))
    write_string_to_file('4.14.0',
                         os.path.join(test_dir, 'META/kernel_version.txt'))
    self.assertFalse(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_sku_compat(self):
    msg = 'vintf/sku_compat should be compatible because ' \
          'ODM/etc/vintf/manifest_sku.xml has the required HALs'
    test_dir = self.prepare_test_dir('vintf/sku_compat')
    write_string_to_file('vintf_odm_manifest_skus=sku',
                         os.path.join(test_dir, 'META/misc_info.txt'), mode='a')
    self.assertTrue(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_sku_incompat(self):
    msg = 'vintf/sku_compat should be compatible because ' \
          'ODM/etc/vintf/manifest_sku.xml does not have the required HALs'
    test_dir = self.prepare_test_dir('vintf/sku_incompat')
    write_string_to_file('vintf_odm_manifest_skus=sku',
                         os.path.join(test_dir, 'META/misc_info.txt'), mode='a')
    self.assertFalse(CheckVintf(test_dir), msg=msg)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckVintf_bad_xml(self):
    test_dir = self.prepare_test_dir('does-not-exist')
    write_string_to_file('not an XML',
                         os.path.join(test_dir, 'VENDOR/manifest.xml'))
    # Should raise an error because a file has invalid format.
    self.assertRaises(common.ExternalError, CheckVintf, test_dir)
