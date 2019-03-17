#
# Copyright (C) 2019 The Android Open Source Project
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

import os
import os.path

import apex_utils
import common
import test_utils


class ApexUtilsTest(test_utils.ReleaseToolsTestCase):

  # echo "foo" | sha256sum
  SALT = 'b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c'

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    # The default payload signing key.
    self.payload_key = os.path.join(self.testdata_dir, 'testkey.key')

  @staticmethod
  def _GetTestPayload():
    payload_file = common.MakeTempFile(prefix='apex-', suffix='.img')
    with open(payload_file, 'wb') as payload_fp:
      payload_fp.write(os.urandom(8192))
    return payload_file

  def test_ParseApexPayloadInfo(self):
    payload_file = self._GetTestPayload()
    apex_utils.SignApexPayload(
        payload_file, self.payload_key, 'testkey', 'SHA256_RSA2048', self.SALT)
    payload_info = apex_utils.ParseApexPayloadInfo(payload_file)
    self.assertEqual('SHA256_RSA2048', payload_info['Algorithm'])
    self.assertEqual(self.SALT, payload_info['Salt'])
    self.assertEqual('testkey', payload_info['apex.key'])

  def test_SignApexPayload(self):
    payload_file = self._GetTestPayload()
    apex_utils.SignApexPayload(
        payload_file, self.payload_key, 'testkey', 'SHA256_RSA2048', self.SALT)
    apex_utils.VerifyApexPayload(payload_file, self.payload_key)

  def test_SignApexPayload_withSignerHelper(self):
    payload_file = self._GetTestPayload()
    payload_signer_args = '--signing_helper_with_files {}'.format(
        os.path.join(self.testdata_dir, 'signing_helper.sh'))
    apex_utils.SignApexPayload(
        payload_file,
        self.payload_key,
        'testkey', 'SHA256_RSA2048', self.SALT,
        payload_signer_args)
    apex_utils.VerifyApexPayload(payload_file, self.payload_key)

  def test_SignApexPayload_invalidKey(self):
    self.assertRaises(
        apex_utils.ApexSigningError,
        apex_utils.SignApexPayload,
        self._GetTestPayload(),
        os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        'testkey',
        'SHA256_RSA2048',
        self.SALT)

  def test_VerifyApexPayload_wrongKey(self):
    payload_file = self._GetTestPayload()
    apex_utils.SignApexPayload(
        payload_file, self.payload_key, 'testkey', 'SHA256_RSA2048', self.SALT)
    apex_utils.VerifyApexPayload(payload_file, self.payload_key)
    self.assertRaises(
        apex_utils.ApexSigningError,
        apex_utils.VerifyApexPayload,
        payload_file,
        os.path.join(self.testdata_dir, 'testkey_with_passwd.key'))
