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

import tempfile
import unittest
import zipfile

import common
from sign_target_files_apks import EditTags, ReplaceVerityKeyId, RewriteProps


class SignTargetFilesApksTest(unittest.TestCase):

  def setUp(self):
    self.tempdir = common.MakeTempDir()

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
        "veritykeyid=id:485900563d272c46ae118605a47419ac09ca8c11\n")

    # From build/target/product/security/verity.x509.pem.
    VERITY_CERTIFICATE1 = """-----BEGIN CERTIFICATE-----
MIID/TCCAuWgAwIBAgIJAJcPmDkJqolJMA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD
VQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNTW91bnRhaW4g
VmlldzEQMA4GA1UECgwHQW5kcm9pZDEQMA4GA1UECwwHQW5kcm9pZDEQMA4GA1UE
AwwHQW5kcm9pZDEiMCAGCSqGSIb3DQEJARYTYW5kcm9pZEBhbmRyb2lkLmNvbTAe
Fw0xNDExMDYxOTA3NDBaFw00MjAzMjQxOTA3NDBaMIGUMQswCQYDVQQGEwJVUzET
MBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNTW91bnRhaW4gVmlldzEQMA4G
A1UECgwHQW5kcm9pZDEQMA4GA1UECwwHQW5kcm9pZDEQMA4GA1UEAwwHQW5kcm9p
ZDEiMCAGCSqGSIb3DQEJARYTYW5kcm9pZEBhbmRyb2lkLmNvbTCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAOjreE0vTVSRenuzO9vnaWfk0eQzYab0gqpi
6xAzi6dmD+ugoEKJmbPiuE5Dwf21isZ9uhUUu0dQM46dK4ocKxMRrcnmGxydFn6o
fs3ODJMXOkv2gKXL/FdbEPdDbxzdu8z3yk+W67udM/fW7WbaQ3DO0knu+izKak/3
T41c5uoXmQ81UNtAzRGzGchNVXMmWuTGOkg6U+0I2Td7K8yvUMWhAWPPpKLtVH9r
AL5TzjYNR92izdKcz3AjRsI3CTjtpiVABGeX0TcjRSuZB7K9EK56HV+OFNS6I1NP
jdD7FIShyGlqqZdUOkAUZYanbpgeT5N7QL6uuqcGpoTOkalu6kkCAwEAAaNQME4w
HQYDVR0OBBYEFH5DM/m7oArf4O3peeKO0ZIEkrQPMB8GA1UdIwQYMBaAFH5DM/m7
oArf4O3peeKO0ZIEkrQPMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEB
AHO3NSvDE5jFvMehGGtS8BnFYdFKRIglDMc4niWSzhzOVYRH4WajxdtBWc5fx0ix
NF/+hVKVhP6AIOQa+++sk+HIi7RvioPPbhjcsVlZe7cUEGrLSSveGouQyc+j0+m6
JF84kszIl5GGNMTnx0XRPO+g8t6h5LWfnVydgZfpGRRg+WHewk1U2HlvTjIceb0N
dcoJ8WKJAFWdcuE7VIm4w+vF/DYX/A2Oyzr2+QRhmYSv1cusgAeC1tvH4ap+J1Lg
UnOu5Kh/FqPLLSwNVQp4Bu7b9QFfqK8Moj84bj88NqRGZgDyqzuTrFxn6FW7dmyA
yttuAJAEAymk1mipd9+zp38=
-----END CERTIFICATE-----
"""

    # From build/target/product/security/testkey.x509.pem.
    VERITY_CERTIFICATE2 = """-----BEGIN CERTIFICATE-----
MIIEqDCCA5CgAwIBAgIJAJNurL4H8gHfMA0GCSqGSIb3DQEBBQUAMIGUMQswCQYD
VQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNTW91bnRhaW4g
VmlldzEQMA4GA1UEChMHQW5kcm9pZDEQMA4GA1UECxMHQW5kcm9pZDEQMA4GA1UE
AxMHQW5kcm9pZDEiMCAGCSqGSIb3DQEJARYTYW5kcm9pZEBhbmRyb2lkLmNvbTAe
Fw0wODAyMjkwMTMzNDZaFw0zNTA3MTcwMTMzNDZaMIGUMQswCQYDVQQGEwJVUzET
MBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEQMA4G
A1UEChMHQW5kcm9pZDEQMA4GA1UECxMHQW5kcm9pZDEQMA4GA1UEAxMHQW5kcm9p
ZDEiMCAGCSqGSIb3DQEJARYTYW5kcm9pZEBhbmRyb2lkLmNvbTCCASAwDQYJKoZI
hvcNAQEBBQADggENADCCAQgCggEBANaTGQTexgskse3HYuDZ2CU+Ps1s6x3i/waM
qOi8qM1r03hupwqnbOYOuw+ZNVn/2T53qUPn6D1LZLjk/qLT5lbx4meoG7+yMLV4
wgRDvkxyGLhG9SEVhvA4oU6Jwr44f46+z4/Kw9oe4zDJ6pPQp8PcSvNQIg1QCAcy
4ICXF+5qBTNZ5qaU7Cyz8oSgpGbIepTYOzEJOmc3Li9kEsBubULxWBjf/gOBzAzU
RNps3cO4JFgZSAGzJWQTT7/emMkod0jb9WdqVA2BVMi7yge54kdVMxHEa5r3b97s
zI5p58ii0I54JiCUP5lyfTwE/nKZHZnfm644oLIXf6MdW2r+6R8CAQOjgfwwgfkw
HQYDVR0OBBYEFEhZAFY9JyxGrhGGBaR0GawJyowRMIHJBgNVHSMEgcEwgb6AFEhZ
AFY9JyxGrhGGBaR0GawJyowRoYGapIGXMIGUMQswCQYDVQQGEwJVUzETMBEGA1UE
CBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEQMA4GA1UEChMH
QW5kcm9pZDEQMA4GA1UECxMHQW5kcm9pZDEQMA4GA1UEAxMHQW5kcm9pZDEiMCAG
CSqGSIb3DQEJARYTYW5kcm9pZEBhbmRyb2lkLmNvbYIJAJNurL4H8gHfMAwGA1Ud
EwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBAHqvlozrUMRBBVEY0NqrrwFbinZa
J6cVosK0TyIUFf/azgMJWr+kLfcHCHJsIGnlw27drgQAvilFLAhLwn62oX6snb4Y
LCBOsVMR9FXYJLZW2+TcIkCRLXWG/oiVHQGo/rWuWkJgU134NDEFJCJGjDbiLCpe
+ZTWHdcwauTJ9pUbo8EvHRkU3cYfGmLaLfgn9gP+pWA7LFQNvXwBnDa6sppCccEX
31I828XzgXpJ4O+mDL1/dBd+ek8ZPUP0IgdyZm5MTYPhvVqGCHzzTy3sIeJFymwr
sBbmg2OAUNLEMO6nwmocSdN2ClirfxqCzJOLSDE4QyS9BAH6EhY6UFcOaE0=
-----END CERTIFICATE-----
"""

    input_file = tempfile.NamedTemporaryFile(
        delete=False, suffix='.zip', dir=self.tempdir)
    with zipfile.ZipFile(input_file.name, 'w') as input_zip:
      input_zip.writestr('BOOT/cmdline', BOOT_CMDLINE1)

    # Test with the first certificate.
    cert_file = tempfile.NamedTemporaryFile(
        delete=False, suffix='.x509.pem', dir=self.tempdir)
    cert_file.write(VERITY_CERTIFICATE1)
    cert_file.close()

    output_file = tempfile.NamedTemporaryFile(
        delete=False, suffix='.zip', dir=self.tempdir)
    with zipfile.ZipFile(input_file.name, 'r') as input_zip, \
         zipfile.ZipFile(output_file.name, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, cert_file.name)

    with zipfile.ZipFile(output_file.name) as output_zip:
      self.assertEqual(BOOT_CMDLINE1, output_zip.read('BOOT/cmdline'))

    # Test with the second certificate.
    with open(cert_file.name, 'w') as cert_file_fp:
      cert_file_fp.write(VERITY_CERTIFICATE2)

    with zipfile.ZipFile(input_file.name, 'r') as input_zip, \
         zipfile.ZipFile(output_file.name, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, cert_file.name)

    with zipfile.ZipFile(output_file.name) as output_zip:
      self.assertEqual(BOOT_CMDLINE2, output_zip.read('BOOT/cmdline'))

  def test_ReplaceVerityKeyId_no_veritykeyid(self):
    BOOT_CMDLINE = (
        "console=ttyHSL0,115200,n8 androidboot.hardware=bullhead boot_cpus=0-5 "
        "lpm_levels.sleep_disabled=1 msm_poweroff.download_mode=0 "
        "loop.max_part=7\n")

    input_file = tempfile.NamedTemporaryFile(
        delete=False, suffix='.zip', dir=self.tempdir)
    with zipfile.ZipFile(input_file.name, 'w') as input_zip:
      input_zip.writestr('BOOT/cmdline', BOOT_CMDLINE)

    output_file = tempfile.NamedTemporaryFile(
        delete=False, suffix='.zip', dir=self.tempdir)
    with zipfile.ZipFile(input_file.name, 'r') as input_zip, \
         zipfile.ZipFile(output_file.name, 'w') as output_zip:
      ReplaceVerityKeyId(input_zip, output_zip, None)

    with zipfile.ZipFile(output_file.name) as output_zip:
      self.assertEqual(BOOT_CMDLINE, output_zip.read('BOOT/cmdline'))
