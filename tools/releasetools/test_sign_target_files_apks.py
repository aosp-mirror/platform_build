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

import base64
import os.path
import zipfile

import common
import test_utils
from sign_target_files_apks import (
    CheckApkAndApexKeysAvailable, EditTags, GetApkFileInfo, ReadApexKeysInfo,
    ReplaceCerts, ReplaceVerityKeyId, RewriteProps)


class SignTargetFilesApksTest(test_utils.ReleaseToolsTestCase):

  MAC_PERMISSIONS_XML = """<?xml version="1.0" encoding="iso-8859-1"?>
<policy>
  <signer signature="{}"><seinfo value="platform"/></signer>
  <signer signature="{}"><seinfo value="media"/></signer>
</policy>"""

  # pylint: disable=line-too-long
  APEX_KEYS_TXT = """name="apex.apexd_test.apex" public_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package.avbpubkey" private_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package.pem" container_certificate="build/make/target/product/security/testkey.x509.pem" container_private_key="build/make/target/product/security/testkey.pk8"
name="apex.apexd_test_different_app.apex" public_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.avbpubkey" private_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem" container_certificate="build/make/target/product/security/testkey.x509.pem" container_private_key="build/make/target/product/security/testkey.pk8"
"""

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def test_EditTags(self):
    self.assertEqual(EditTags('dev-keys'), ('release-keys'))
    self.assertEqual(EditTags('test-keys'), ('release-keys'))

    # Multiple tags.
    self.assertEqual(EditTags('abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

    # Tags are sorted.
    self.assertEqual(EditTags('xyz,abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

  def test_RewriteProps(self):
    props = (
        ('', ''),
        ('ro.build.fingerprint=foo/bar/dev-keys',
         'ro.build.fingerprint=foo/bar/release-keys'),
        ('ro.build.thumbprint=foo/bar/dev-keys',
         'ro.build.thumbprint=foo/bar/release-keys'),
        ('ro.vendor.build.fingerprint=foo/bar/dev-keys',
         'ro.vendor.build.fingerprint=foo/bar/release-keys'),
        ('ro.vendor.build.thumbprint=foo/bar/dev-keys',
         'ro.vendor.build.thumbprint=foo/bar/release-keys'),
        ('ro.odm.build.fingerprint=foo/bar/test-keys',
         'ro.odm.build.fingerprint=foo/bar/release-keys'),
        ('ro.odm.build.thumbprint=foo/bar/test-keys',
         'ro.odm.build.thumbprint=foo/bar/release-keys'),
        ('ro.product.build.fingerprint=foo/bar/dev-keys',
         'ro.product.build.fingerprint=foo/bar/release-keys'),
        ('ro.product.build.thumbprint=foo/bar/dev-keys',
         'ro.product.build.thumbprint=foo/bar/release-keys'),
        ('ro.product_services.build.fingerprint=foo/bar/test-keys',
         'ro.product_services.build.fingerprint=foo/bar/release-keys'),
        ('ro.product_services.build.thumbprint=foo/bar/test-keys',
         'ro.product_services.build.thumbprint=foo/bar/release-keys'),
        ('# comment line 1', '# comment line 1'),
        ('ro.bootimage.build.fingerprint=foo/bar/dev-keys',
         'ro.bootimage.build.fingerprint=foo/bar/release-keys'),
        ('ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 dev-keys',
         'ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 release-keys'),
        ('ro.build.tags=dev-keys', 'ro.build.tags=release-keys'),
        ('ro.build.tags=test-keys', 'ro.build.tags=release-keys'),
        ('ro.system.build.tags=dev-keys',
         'ro.system.build.tags=release-keys'),
        ('ro.vendor.build.tags=dev-keys',
         'ro.vendor.build.tags=release-keys'),
        ('ro.odm.build.tags=dev-keys',
         'ro.odm.build.tags=release-keys'),
        ('ro.product.build.tags=dev-keys',
         'ro.product.build.tags=release-keys'),
        ('ro.product_services.build.tags=dev-keys',
         'ro.product_services.build.tags=release-keys'),
        ('# comment line 2', '# comment line 2'),
        ('ro.build.display.id=OPR6.170623.012 dev-keys',
         'ro.build.display.id=OPR6.170623.012'),
        ('# comment line 3', '# comment line 3'),
    )

    # Assert the case for each individual line.
    for prop, expected in props:
      self.assertEqual(expected + '\n', RewriteProps(prop))

    # Concatenate all the input lines.
    self.assertEqual(
        '\n'.join([prop[1] for prop in props]) + '\n',
        RewriteProps('\n'.join([prop[0] for prop in props])))

  def test_ReplaceVerityKeyId(self):
    BOOT_CMDLINE1 = (
        "console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 "
        "androidboot.hardware=marlin user_debug=31 ehci-hcd.park=3 "
        "lpm_levels.sleep_disabled=1 cma=32M@0-0xffffffff loop.max_part=7 "
        "buildvariant=userdebug "
        "veritykeyid=id:7e4333f9bba00adfe0ede979e28ed1920492b40f\n")

    BOOT_CMDLINE2 = (
        "console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 "
        "androidboot.hardware=marlin user_debug=31 ehci-hcd.park=3 "
        "lpm_levels.sleep_disabled=1 cma=32M@0-0xffffffff loop.max_part=7 "
        "buildvariant=userdebug "
        "veritykeyid=id:d24f2590e9abab5cff5f59da4c4f0366e3f43e94\n")

    input_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      input_zip.writestr('BOOT/cmdline', BOOT_CMDLINE1)

    # Test with the first certificate.
    cert_file = os.path.join(self.testdata_dir, 'verity.x509.pem')

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'r') as input_zip, \
         zipfile.ZipFile(output_file, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, cert_file)

    with zipfile.ZipFile(output_file) as output_zip:
      self.assertEqual(BOOT_CMDLINE1, output_zip.read('BOOT/cmdline'))

    # Test with the second certificate.
    cert_file = os.path.join(self.testdata_dir, 'testkey.x509.pem')

    with zipfile.ZipFile(input_file, 'r') as input_zip, \
         zipfile.ZipFile(output_file, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, cert_file)

    with zipfile.ZipFile(output_file) as output_zip:
      self.assertEqual(BOOT_CMDLINE2, output_zip.read('BOOT/cmdline'))

  def test_ReplaceVerityKeyId_no_veritykeyid(self):
    BOOT_CMDLINE = (
        "console=ttyHSL0,115200,n8 androidboot.hardware=bullhead boot_cpus=0-5 "
        "lpm_levels.sleep_disabled=1 msm_poweroff.download_mode=0 "
        "loop.max_part=7\n")

    input_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      input_zip.writestr('BOOT/cmdline', BOOT_CMDLINE)

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'r') as input_zip, \
         zipfile.ZipFile(output_file, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, None)

    with zipfile.ZipFile(output_file) as output_zip:
      self.assertEqual(BOOT_CMDLINE, output_zip.read('BOOT/cmdline'))

  def test_ReplaceCerts(self):
    cert1_path = os.path.join(self.testdata_dir, 'platform.x509.pem')
    with open(cert1_path) as cert1_fp:
      cert1 = cert1_fp.read()
    cert2_path = os.path.join(self.testdata_dir, 'media.x509.pem')
    with open(cert2_path) as cert2_fp:
      cert2 = cert2_fp.read()
    cert3_path = os.path.join(self.testdata_dir, 'testkey.x509.pem')
    with open(cert3_path) as cert3_fp:
      cert3 = cert3_fp.read()

    # Replace cert1 with cert3.
    input_xml = self.MAC_PERMISSIONS_XML.format(
        base64.b16encode(common.ParseCertificate(cert1)).lower(),
        base64.b16encode(common.ParseCertificate(cert2)).lower())

    output_xml = self.MAC_PERMISSIONS_XML.format(
        base64.b16encode(common.ParseCertificate(cert3)).lower(),
        base64.b16encode(common.ParseCertificate(cert2)).lower())

    common.OPTIONS.key_map = {
        cert1_path[:-9] : cert3_path[:-9],
    }

    self.assertEqual(output_xml, ReplaceCerts(input_xml))

  def test_ReplaceCerts_duplicateEntries(self):
    cert1_path = os.path.join(self.testdata_dir, 'platform.x509.pem')
    with open(cert1_path) as cert1_fp:
      cert1 = cert1_fp.read()
    cert2_path = os.path.join(self.testdata_dir, 'media.x509.pem')
    with open(cert2_path) as cert2_fp:
      cert2 = cert2_fp.read()

    # Replace cert1 with cert2, which leads to duplicate entries.
    input_xml = self.MAC_PERMISSIONS_XML.format(
        base64.b16encode(common.ParseCertificate(cert1)).lower(),
        base64.b16encode(common.ParseCertificate(cert2)).lower())

    common.OPTIONS.key_map = {
        cert1_path[:-9] : cert2_path[:-9],
    }
    self.assertRaises(AssertionError, ReplaceCerts, input_xml)

  def test_ReplaceCerts_skipNonExistentCerts(self):
    cert1_path = os.path.join(self.testdata_dir, 'platform.x509.pem')
    with open(cert1_path) as cert1_fp:
      cert1 = cert1_fp.read()
    cert2_path = os.path.join(self.testdata_dir, 'media.x509.pem')
    with open(cert2_path) as cert2_fp:
      cert2 = cert2_fp.read()
    cert3_path = os.path.join(self.testdata_dir, 'testkey.x509.pem')
    with open(cert3_path) as cert3_fp:
      cert3 = cert3_fp.read()

    input_xml = self.MAC_PERMISSIONS_XML.format(
        base64.b16encode(common.ParseCertificate(cert1)).lower(),
        base64.b16encode(common.ParseCertificate(cert2)).lower())

    output_xml = self.MAC_PERMISSIONS_XML.format(
        base64.b16encode(common.ParseCertificate(cert3)).lower(),
        base64.b16encode(common.ParseCertificate(cert2)).lower())

    common.OPTIONS.key_map = {
        cert1_path[:-9] : cert3_path[:-9],
        'non-existent' : cert3_path[:-9],
        cert2_path[:-9] : 'non-existent',
    }
    self.assertEqual(output_xml, ReplaceCerts(input_xml))

  def test_CheckApkAndApexKeysAvailable(self):
    input_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      input_zip.writestr('SYSTEM/app/App1.apk', "App1-content")
      input_zip.writestr('SYSTEM/app/App2.apk.gz', "App2-content")

    apk_key_map = {
        'App1.apk' : 'key1',
        'App2.apk' : 'key2',
        'App3.apk' : 'key3',
    }
    with zipfile.ZipFile(input_file) as input_zip:
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, None, {})
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, '.gz', {})

      # 'App2.apk.gz' won't be considered as an APK.
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, None, {})
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, '.xz', {})

      del apk_key_map['App2.apk']
      self.assertRaises(
          AssertionError, CheckApkAndApexKeysAvailable, input_zip, apk_key_map,
          '.gz', {})

  def test_CheckApkAndApexKeysAvailable_invalidApexKeys(self):
    input_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      input_zip.writestr('SYSTEM/apex/Apex1.apex', "Apex1-content")
      input_zip.writestr('SYSTEM/apex/Apex2.apex', "Apex2-content")

    apk_key_map = {
        'Apex1.apex' : 'key1',
        'Apex2.apex' : 'key2',
        'Apex3.apex' : 'key3',
    }
    apex_keys = {
        'Apex1.apex' : ('payload-key1', 'container-key1'),
        'Apex2.apex' : ('payload-key2', 'container-key2'),
    }
    with zipfile.ZipFile(input_file) as input_zip:
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, None, apex_keys)

      # Fine to have both keys as PRESIGNED.
      apex_keys['Apex2.apex'] = ('PRESIGNED', 'PRESIGNED')
      CheckApkAndApexKeysAvailable(input_zip, apk_key_map, None, apex_keys)

      # Having only one of them as PRESIGNED is not allowed.
      apex_keys['Apex2.apex'] = ('payload-key2', 'PRESIGNED')
      self.assertRaises(
          AssertionError, CheckApkAndApexKeysAvailable, input_zip, apk_key_map,
          None, apex_keys)

      apex_keys['Apex2.apex'] = ('PRESIGNED', 'container-key1')
      self.assertRaises(
          AssertionError, CheckApkAndApexKeysAvailable, input_zip, apk_key_map,
          None, apex_keys)

  def test_GetApkFileInfo(self):
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/apps/Chats.apk", None, [])
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/apps/Chats.apk", None, [])
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/apps/Chats.dat", None, [])
    self.assertFalse(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

  def test_GetApkFileInfo_withCompressedApks(self):
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/apps/Chats.apk.gz", ".gz", [])
    self.assertTrue(is_apk)
    self.assertTrue(is_compressed)
    self.assertFalse(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/apps/Chats.apk.gz", ".xz", [])
    self.assertFalse(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

    self.assertRaises(
        AssertionError, GetApkFileInfo, "PRODUCT/apps/Chats.apk", "", [])

    self.assertRaises(
        AssertionError, GetApkFileInfo, "PRODUCT/apps/Chats.apk", "apk", [])

  def test_GetApkFileInfo_withSkippedPrefixes(self):
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/preloads/apps/Chats.apk", None, set())
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "PRODUCT/preloads/apps/Chats.apk",
        None,
        set(["PRODUCT/preloads/"]))
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertTrue(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None,
        set(["SYSTEM/preloads/", "SYSTEM_OTHER/preloads/"]))
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertTrue(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.apk.gz",
        ".gz",
        set(["PRODUCT/prebuilts/", "SYSTEM_OTHER/preloads/"]))
    self.assertTrue(is_apk)
    self.assertTrue(is_compressed)
    self.assertTrue(should_be_skipped)

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.dat",
        None,
        set(["SYSTEM_OTHER/preloads/"]))
    self.assertFalse(is_apk)
    self.assertFalse(is_compressed)
    self.assertFalse(should_be_skipped)

  def test_GetApkFileInfo_checkSkippedPrefixesInput(self):
    # set
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None,
        set(["SYSTEM_OTHER/preloads/"]))
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertTrue(should_be_skipped)

    # tuple
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None,
        ("SYSTEM_OTHER/preloads/",))
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertTrue(should_be_skipped)

    # list
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None,
        ["SYSTEM_OTHER/preloads/"])
    self.assertTrue(is_apk)
    self.assertFalse(is_compressed)
    self.assertTrue(should_be_skipped)

    # str is invalid.
    self.assertRaises(
        AssertionError, GetApkFileInfo, "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None, "SYSTEM_OTHER/preloads/")

    # None is invalid.
    self.assertRaises(
        AssertionError, GetApkFileInfo, "SYSTEM_OTHER/preloads/apps/Chats.apk",
        None, None)

  def test_ReadApexKeysInfo(self):
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apexkeys.txt', self.APEX_KEYS_TXT)

    with zipfile.ZipFile(target_files) as target_files_zip:
      keys_info = ReadApexKeysInfo(target_files_zip)

    self.assertEqual({
        'apex.apexd_test.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package.pem',
            'build/make/target/product/security/testkey'),
        'apex.apexd_test_different_app.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem',
            'build/make/target/product/security/testkey'),
        }, keys_info)

  def test_ReadApexKeysInfo_mismatchingContainerKeys(self):
    # Mismatching payload public / private keys.
    apex_keys = self.APEX_KEYS_TXT + (
        'name="apex.apexd_test_different_app2.apex" '
        'public_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.avbpubkey" '
        'private_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem" '
        'container_certificate="build/make/target/product/security/testkey.x509.pem" '
        'container_private_key="build/make/target/product/security/testkey2.pk8"')
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apexkeys.txt', apex_keys)

    with zipfile.ZipFile(target_files) as target_files_zip:
      self.assertRaises(ValueError, ReadApexKeysInfo, target_files_zip)

  def test_ReadApexKeysInfo_missingPayloadPrivateKey(self):
    # Invalid lines will be skipped.
    apex_keys = self.APEX_KEYS_TXT + (
        'name="apex.apexd_test_different_app2.apex" '
        'public_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.avbpubkey" '
        'container_certificate="build/make/target/product/security/testkey.x509.pem" '
        'container_private_key="build/make/target/product/security/testkey.pk8"')
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apexkeys.txt', apex_keys)

    with zipfile.ZipFile(target_files) as target_files_zip:
      keys_info = ReadApexKeysInfo(target_files_zip)

    self.assertEqual({
        'apex.apexd_test.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package.pem',
            'build/make/target/product/security/testkey'),
        'apex.apexd_test_different_app.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem',
            'build/make/target/product/security/testkey'),
        }, keys_info)

  def test_ReadApexKeysInfo_missingPayloadPublicKey(self):
    # Invalid lines will be skipped.
    apex_keys = self.APEX_KEYS_TXT + (
        'name="apex.apexd_test_different_app2.apex" '
        'private_key="system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem" '
        'container_certificate="build/make/target/product/security/testkey.x509.pem" '
        'container_private_key="build/make/target/product/security/testkey.pk8"')
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apexkeys.txt', apex_keys)

    with zipfile.ZipFile(target_files) as target_files_zip:
      keys_info = ReadApexKeysInfo(target_files_zip)

    self.assertEqual({
        'apex.apexd_test.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package.pem',
            'build/make/target/product/security/testkey'),
        'apex.apexd_test_different_app.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem',
            'build/make/target/product/security/testkey'),
        }, keys_info)

  def test_ReadApexKeysInfo_presignedKeys(self):
    apex_keys = self.APEX_KEYS_TXT + (
        'name="apex.apexd_test_different_app2.apex" '
        'private_key="PRESIGNED" '
        'public_key="PRESIGNED" '
        'container_certificate="PRESIGNED" '
        'container_private_key="PRESIGNED"')
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apexkeys.txt', apex_keys)

    with zipfile.ZipFile(target_files) as target_files_zip:
      keys_info = ReadApexKeysInfo(target_files_zip)

    self.assertEqual({
        'apex.apexd_test.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package.pem',
            'build/make/target/product/security/testkey'),
        'apex.apexd_test_different_app.apex': (
            'system/apex/apexd/apexd_testdata/com.android.apex.test_package_2.pem',
            'build/make/target/product/security/testkey'),
        }, keys_info)
