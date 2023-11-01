#
# Copyright (C) 2020 The Android Open Source Project
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

import copy
import os
import zipfile

import common
import test_utils
import validate_target_files

from images import EmptyImage, DataImage
from non_ab_ota import NonAbOtaPropertyFiles, WriteFingerprintAssertion, BlockDifference, DynamicPartitionsDifference, MakeRecoveryPatch
from test_utils import PropertyFilesTestCase


class NonAbOtaPropertyFilesTest(PropertyFilesTestCase):
  """Additional validity checks specialized for NonAbOtaPropertyFiles."""

  def setUp(self):
    common.OPTIONS.no_signing = False

  def test_init(self):
    property_files = NonAbOtaPropertyFiles()
    self.assertEqual('ota-property-files', property_files.name)
    self.assertEqual((), property_files.required)
    self.assertEqual((), property_files.optional)

  def test_Compute(self):
    entries = ()
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(2, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Finalize(self):
    entries = [
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      property_files_string = property_files.Finalize(
          zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(property_files_string)

    self.assertEqual(2, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata'.
    entries[0] = 'metadata'
    entries[1] = 'metadata.pb'
    self._verify_entries(zip_file, tokens, entries)

  def test_Verify(self):
    entries = (
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      property_files.Verify(zip_fp, raw_metadata)


class NonAbOTATest(test_utils.ReleaseToolsTestCase):
  TEST_TARGET_INFO_DICT = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.device': 'product-device',
              'ro.build.fingerprint': 'build-fingerprint-target',
              'ro.build.version.incremental': 'build-version-incremental-target',
              'ro.build.version.sdk': '27',
              'ro.build.version.security_patch': '2017-12-01',
              'ro.build.date.utc': '1500000000'}
      )
  }
  TEST_INFO_DICT_USES_OEM_PROPS = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.name': 'product-name',
              'ro.build.thumbprint': 'build-thumbprint',
              'ro.build.bar': 'build-bar'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.vendor.build.fingerprint': 'vendor-build-fingerprint'}
      ),
      'property1': 'value1',
      'property2': 4096,
      'oem_fingerprint_properties': 'ro.product.device ro.product.brand',
  }
  TEST_OEM_DICTS = [
      {
          'ro.product.brand': 'brand1',
          'ro.product.device': 'device1',
      },
      {
          'ro.product.brand': 'brand2',
          'ro.product.device': 'device2',
      },
      {
          'ro.product.brand': 'brand3',
          'ro.product.device': 'device3',
      },
  ]

  def test_WriteFingerprintAssertion_without_oem_props(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict['build.prop'].build_props['ro.build.fingerprint'] = (
        'source-build-fingerprint')
    source_info = common.BuildInfo(source_info_dict, None)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeFingerprint', 'source-build-fingerprint',
          'build-fingerprint-target')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_source_oem_props(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint-target',
          'build-thumbprint')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_target_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    source_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint-target',
          'build-thumbprint')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_both_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    source_info_dict = copy.deepcopy(self.TEST_INFO_DICT_USES_OEM_PROPS)
    source_info_dict['build.prop'].build_props['ro.build.thumbprint'] = (
        'source-build-thumbprint')
    source_info = common.BuildInfo(source_info_dict, self.TEST_OEM_DICTS)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeThumbprint', 'build-thumbprint',
          'source-build-thumbprint')],
        script_writer.lines)


KiB = 1024
MiB = 1024 * KiB
GiB = 1024 * MiB


class MockBlockDifference(object):

  def __init__(self, partition, tgt, src=None):
    self.partition = partition
    self.tgt = tgt
    self.src = src

  def WriteScript(self, script, _, progress=None,
                  write_verify_script=False):
    if progress:
      script.AppendExtra("progress({})".format(progress))
    script.AppendExtra("patch({});".format(self.partition))
    if write_verify_script:
      self.WritePostInstallVerifyScript(script)

  def WritePostInstallVerifyScript(self, script):
    script.AppendExtra("verify({});".format(self.partition))


class FakeSparseImage(object):

  def __init__(self, size):
    self.blocksize = 4096
    self.total_blocks = size // 4096
    assert size % 4096 == 0, "{} is not a multiple of 4096".format(size)


class DynamicPartitionsDifferenceTest(test_utils.ReleaseToolsTestCase):

  @staticmethod
  def get_op_list(output_path):
    with zipfile.ZipFile(output_path, allowZip64=True) as output_zip:
      with output_zip.open('dynamic_partitions_op_list') as op_list:
        return [line.decode().strip() for line in op_list.readlines()
                if not line.startswith(b'#')]

  def setUp(self):
    self.script = test_utils.MockScriptWriter()
    self.output_path = common.MakeTempFile(suffix='.zip')

  def test_full(self):
    target_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor
super_partition_groups=group_foo
super_group_foo_group_size={group_size}
super_group_foo_partition_list=system vendor
""".format(group_size=4 * GiB).split("\n"))
    block_diffs = [MockBlockDifference("system", FakeSparseImage(3 * GiB)),
                   MockBlockDifference("vendor", FakeSparseImage(1 * GiB))]

    dp_diff = DynamicPartitionsDifference(target_info, block_diffs)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    self.assertEqual(str(self.script).strip(), """
assert(update_dynamic_partitions(package_extract_file("dynamic_partitions_op_list")));
patch(system);
verify(system);
unmap_partition("system");
patch(vendor);
verify(vendor);
unmap_partition("vendor");
""".strip())

    lines = self.get_op_list(self.output_path)

    remove_all_groups = lines.index("remove_all_groups")
    add_group = lines.index("add_group group_foo 4294967296")
    add_vendor = lines.index("add vendor group_foo")
    add_system = lines.index("add system group_foo")
    resize_vendor = lines.index("resize vendor 1073741824")
    resize_system = lines.index("resize system 3221225472")

    self.assertLess(remove_all_groups, add_group,
                    "Should add groups after removing all groups")
    self.assertLess(add_group, min(add_vendor, add_system),
                    "Should add partitions after adding group")
    self.assertLess(add_system, resize_system,
                    "Should resize system after adding it")
    self.assertLess(add_vendor, resize_vendor,
                    "Should resize vendor after adding it")

  def test_inc_groups(self):
    source_info = common.LoadDictionaryFromLines("""
super_partition_groups=group_foo group_bar group_baz
super_group_foo_group_size={group_foo_size}
super_group_bar_group_size={group_bar_size}
""".format(group_foo_size=4 * GiB, group_bar_size=3 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
super_partition_groups=group_foo group_baz group_qux
super_group_foo_group_size={group_foo_size}
super_group_baz_group_size={group_baz_size}
super_group_qux_group_size={group_qux_size}
""".format(group_foo_size=3 * GiB, group_baz_size=4 * GiB,
           group_qux_size=1 * GiB).split("\n"))

    dp_diff = DynamicPartitionsDifference(target_info,
                                                 block_diffs=[],
                                                 source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    lines = self.get_op_list(self.output_path)

    removed = lines.index("remove_group group_bar")
    shrunk = lines.index("resize_group group_foo 3221225472")
    grown = lines.index("resize_group group_baz 4294967296")
    added = lines.index("add_group group_qux 1073741824")

    self.assertLess(max(removed, shrunk),
                    min(grown, added),
                    "ops that remove / shrink partitions must precede ops that "
                    "grow / add partitions")

  def test_incremental(self):
    source_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor product system_ext
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=system vendor product system_ext
""".format(group_foo_size=4 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor product odm
super_partition_groups=group_foo group_bar
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=system vendor odm
super_group_bar_group_size={group_bar_size}
super_group_bar_partition_list=product
""".format(group_foo_size=3 * GiB, group_bar_size=1 * GiB).split("\n"))

    block_diffs = [MockBlockDifference("system", FakeSparseImage(1536 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("vendor", FakeSparseImage(512 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("product", FakeSparseImage(1024 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("system_ext", None,
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("odm", FakeSparseImage(1024 * MiB),
                                       src=None)]

    dp_diff = DynamicPartitionsDifference(target_info, block_diffs,
                                                 source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    metadata_idx = self.script.lines.index(
        'assert(update_dynamic_partitions(package_extract_file('
        '"dynamic_partitions_op_list")));')
    self.assertLess(self.script.lines.index('patch(vendor);'), metadata_idx)
    self.assertLess(metadata_idx, self.script.lines.index('verify(vendor);'))
    for p in ("product", "system", "odm"):
      patch_idx = self.script.lines.index("patch({});".format(p))
      verify_idx = self.script.lines.index("verify({});".format(p))
      self.assertLess(metadata_idx, patch_idx,
                      "Should patch {} after updating metadata".format(p))
      self.assertLess(patch_idx, verify_idx,
                      "Should verify {} after patching".format(p))

    self.assertNotIn("patch(system_ext);", self.script.lines)

    lines = self.get_op_list(self.output_path)

    remove = lines.index("remove system_ext")
    move_product_out = lines.index("move product default")
    shrink = lines.index("resize vendor 536870912")
    shrink_group = lines.index("resize_group group_foo 3221225472")
    add_group_bar = lines.index("add_group group_bar 1073741824")
    add_odm = lines.index("add odm group_foo")
    grow_existing = lines.index("resize system 1610612736")
    grow_added = lines.index("resize odm 1073741824")
    move_product_in = lines.index("move product group_bar")

    max_idx_move_partition_out_foo = max(remove, move_product_out, shrink)
    min_idx_move_partition_in_foo = min(add_odm, grow_existing, grow_added)

    self.assertLess(max_idx_move_partition_out_foo, shrink_group,
                    "Must shrink group after partitions inside group are shrunk"
                    " / removed")

    self.assertLess(add_group_bar, move_product_in,
                    "Must add partitions to group after group is added")

    self.assertLess(max_idx_move_partition_out_foo,
                    min_idx_move_partition_in_foo,
                    "Must shrink partitions / remove partitions from group"
                    "before adding / moving partitions into group")

  def test_remove_partition(self):
    source_info = common.LoadDictionaryFromLines("""
blockimgdiff_versions=3,4
use_dynamic_partitions=true
dynamic_partition_list=foo
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=foo
""".format(group_foo_size=4 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
blockimgdiff_versions=3,4
use_dynamic_partitions=true
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
""".format(group_foo_size=4 * GiB).split("\n"))

    common.OPTIONS.info_dict = target_info
    common.OPTIONS.target_info_dict = target_info
    common.OPTIONS.source_info_dict = source_info
    common.OPTIONS.cache_size = 4 * 4096

    block_diffs = [BlockDifference("foo", EmptyImage(),
                                   src=DataImage("source", pad=True))]

    dp_diff = DynamicPartitionsDifference(target_info, block_diffs,
                                          source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    self.assertNotIn("block_image_update", str(self.script),
                     "Removed partition should not be patched.")

    lines = self.get_op_list(self.output_path)
    self.assertEqual(lines, ["remove foo"])



class InstallRecoveryScriptFormatTest(test_utils.ReleaseToolsTestCase):
  """Checks the format of install-recovery.sh.

  Its format should match between common.py and validate_target_files.py.
  """

  def setUp(self):
    self._tempdir = common.MakeTempDir()
    # Create a fake dict that contains the fstab info for boot&recovery.
    self._info = {"fstab": {}}
    fake_fstab = [
        "/dev/soc.0/by-name/boot /boot emmc defaults defaults",
        "/dev/soc.0/by-name/recovery /recovery emmc defaults defaults"]
    self._info["fstab"] = common.LoadRecoveryFSTab("\n".join, 2, fake_fstab)
    # Construct the gzipped recovery.img and boot.img
    self.recovery_data = bytearray([
        0x1f, 0x8b, 0x08, 0x00, 0x81, 0x11, 0x02, 0x5a, 0x00, 0x03, 0x2b, 0x4a,
        0x4d, 0xce, 0x2f, 0x4b, 0x2d, 0xaa, 0x04, 0x00, 0xc9, 0x93, 0x43, 0xf3,
        0x08, 0x00, 0x00, 0x00
    ])
    # echo -n "boot" | gzip -f | hd
    self.boot_data = bytearray([
        0x1f, 0x8b, 0x08, 0x00, 0x8c, 0x12, 0x02, 0x5a, 0x00, 0x03, 0x4b, 0xca,
        0xcf, 0x2f, 0x01, 0x00, 0xc4, 0xae, 0xed, 0x46, 0x04, 0x00, 0x00, 0x00
    ])

  def _out_tmp_sink(self, name, data, prefix="SYSTEM"):
    loc = os.path.join(self._tempdir, prefix, name)
    if not os.path.exists(os.path.dirname(loc)):
      os.makedirs(os.path.dirname(loc))
    with open(loc, "wb") as f:
      f.write(data)

  def test_full_recovery(self):
    recovery_image = common.File("recovery.img", self.recovery_data)
    boot_image = common.File("boot.img", self.boot_data)
    self._info["full_recovery_image"] = "true"

    MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_recovery_from_boot(self):
    recovery_image = common.File("recovery.img", self.recovery_data)
    self._out_tmp_sink("recovery.img", recovery_image.data, "IMAGES")
    boot_image = common.File("boot.img", self.boot_data)
    self._out_tmp_sink("boot.img", boot_image.data, "IMAGES")

    MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)
    # Validate 'recovery-from-boot' with bonus argument.
    self._out_tmp_sink("etc/recovery-resource.dat", b"bonus", "SYSTEM")
    MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

