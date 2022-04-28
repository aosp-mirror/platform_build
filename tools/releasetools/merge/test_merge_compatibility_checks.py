#
# Copyright (C) 2022 The Android Open Source Project
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
import merge_compatibility_checks
import merge_target_files
import test_utils


class MergeCompatibilityChecksTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.partition_map = {
        'system': 'system',
        'system_ext': 'system_ext',
        'product': 'product',
        'vendor': 'vendor',
        'odm': 'odm',
    }
    self.OPTIONS = merge_target_files.OPTIONS
    self.OPTIONS.framework_partition_set = set(
        ['product', 'system', 'system_ext'])
    self.OPTIONS.vendor_partition_set = set(['odm', 'vendor'])

  def test_CheckCombinedSepolicy(self):
    product_out_dir = common.MakeTempDir()

    def write_temp_file(path, data=''):
      full_path = os.path.join(product_out_dir, path)
      if not os.path.exists(os.path.dirname(full_path)):
        os.makedirs(os.path.dirname(full_path))
      with open(full_path, 'w') as f:
        f.write(data)

    write_temp_file(
        'system/etc/vintf/compatibility_matrix.device.xml', """
      <compatibility-matrix>
        <sepolicy>
          <kernel-sepolicy-version>30</kernel-sepolicy-version>
        </sepolicy>
      </compatibility-matrix>""")
    write_temp_file('vendor/etc/selinux/plat_sepolicy_vers.txt', '30.0')

    write_temp_file('system/etc/selinux/plat_sepolicy.cil')
    write_temp_file('system/etc/selinux/mapping/30.0.cil')
    write_temp_file('product/etc/selinux/mapping/30.0.cil')
    write_temp_file('vendor/etc/selinux/vendor_sepolicy.cil')
    write_temp_file('vendor/etc/selinux/plat_pub_versioned.cil')

    cmd = merge_compatibility_checks.CheckCombinedSepolicy(
        product_out_dir, self.partition_map, execute=False)
    self.assertEqual(' '.join(cmd),
                     ('secilc -m -M true -G -N -c 30 '
                      '-o {OTP}/META/combined_sepolicy -f /dev/null '
                      '{OTP}/system/etc/selinux/plat_sepolicy.cil '
                      '{OTP}/system/etc/selinux/mapping/30.0.cil '
                      '{OTP}/vendor/etc/selinux/vendor_sepolicy.cil '
                      '{OTP}/vendor/etc/selinux/plat_pub_versioned.cil '
                      '{OTP}/product/etc/selinux/mapping/30.0.cil').format(
                          OTP=product_out_dir))

  def _copy_apex(self, source, output_dir, partition):
    shutil.copy(
        source,
        os.path.join(output_dir, partition, 'apex', os.path.basename(source)))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckApexDuplicatePackages(self):
    output_dir = common.MakeTempDir()
    os.makedirs(os.path.join(output_dir, 'SYSTEM/apex'))
    os.makedirs(os.path.join(output_dir, 'VENDOR/apex'))

    self._copy_apex(
        os.path.join(self.testdata_dir, 'has_apk.apex'), output_dir, 'SYSTEM')
    self._copy_apex(
        os.path.join(test_utils.get_current_dir(),
                     'com.android.apex.compressed.v1.capex'), output_dir,
        'VENDOR')
    self.assertEqual(
        len(
            merge_compatibility_checks.CheckApexDuplicatePackages(
                output_dir, self.partition_map)), 0)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_CheckApexDuplicatePackages_RaisesOnPackageInMultiplePartitions(self):
    output_dir = common.MakeTempDir()
    os.makedirs(os.path.join(output_dir, 'SYSTEM/apex'))
    os.makedirs(os.path.join(output_dir, 'VENDOR/apex'))

    same_apex_package = os.path.join(self.testdata_dir, 'has_apk.apex')
    self._copy_apex(same_apex_package, output_dir, 'SYSTEM')
    self._copy_apex(same_apex_package, output_dir, 'VENDOR')
    self.assertEqual(
        merge_compatibility_checks.CheckApexDuplicatePackages(
            output_dir, self.partition_map)[0],
        'Duplicate APEX package_names found in multiple partitions: com.android.wifi'
    )
