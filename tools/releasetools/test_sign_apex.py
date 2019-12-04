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

import os.path

import common
import sign_apex
import test_utils


class SignApexTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    common.OPTIONS.search_path = test_utils.get_search_path()

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_SignApexFile(self):
    foo_apex = os.path.join(self.testdata_dir, 'foo.apex')
    payload_key = os.path.join(self.testdata_dir, 'testkey_RSA4096.key')
    container_key = os.path.join(self.testdata_dir, 'testkey')
    signed_foo_apex = sign_apex.SignApexFile(
        'avbtool',
        foo_apex,
        payload_key,
        container_key,
        False)
    self.assertTrue(os.path.exists(signed_foo_apex))
