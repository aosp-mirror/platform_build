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

from __future__ import print_function

import base64
import os.path
import unittest
import zipfile

import common
import test_utils
from sign_target_files_apks import (
    EditTags, ReplaceCerts, ReplaceVerityKeyId, RewriteProps)


class SignTargetFilesApksTest(unittest.TestCase):

  MAC_PERMISSIONS_XML = """<?xml version="1.0" encoding="iso-8859-1"?>
<policy>
  <signer signature="{}"><seinfo value="platform"/></signer>
  <signer signature="{}"><seinfo value="media"/></signer>
</policy>"""

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def tearDown(self):
    common.Cleanup()

  def test_EditTags(self):
    self.assertEqual(EditTags('dev-keys'), ('release-keys'))
    self.assertEqual(EditTags('test-keys'), ('release-keys'))

    # Multiple tags.
    self.assertEqual(EditTags('abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

    # Tags are sorted.
    self.assertEqual(EditTags('xyz,abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

  def test_RewriteProps(self):
    props = (
        ('', '\n'),
        ('ro.build.fingerprint=foo/bar/dev-keys',
         'ro.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.build.thumbprint=foo/bar/dev-keys',
         'ro.build.thumbprint=foo/bar/release-keys\n'),
        ('ro.vendor.build.fingerprint=foo/bar/dev-keys',
         'ro.vendor.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.vendor.build.thumbprint=foo/bar/dev-keys',
         'ro.vendor.build.thumbprint=foo/bar/release-keys\n'),
        ('# comment line 1', '# comment line 1\n'),
        ('ro.bootimage.build.fingerprint=foo/bar/dev-keys',
         'ro.bootimage.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 dev-keys',
         'ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 release-keys\n'),
        ('ro.build.tags=dev-keys', 'ro.build.tags=release-keys\n'),
        ('# comment line 2', '# comment line 2\n'),
        ('ro.build.display.id=OPR6.170623.012 dev-keys',
         'ro.build.display.id=OPR6.170623.012\n'),
        ('# comment line 3', '# comment line 3\n'),
    )

    # Assert the case for each individual line.
    for prop, output in props:
      self.assertEqual(RewriteProps(prop), output)

    # Concatenate all the input lines.
    self.assertEqual(RewriteProps('\n'.join([prop[0] for prop in props])),
                     ''.join([prop[1] for prop in props]))

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
