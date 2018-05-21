#!/usr/bin/env python
#
# Copyright 2017, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Unittests for auto_gen_test_config."""

import os
import shutil
import tempfile
import unittest

import auto_gen_test_config

TEST_MODULE = 'TestModule'

MANIFEST_INVALID = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
</manifest>
"""

MANIFEST_JUNIT_TEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.android.my.tests.x">
    <instrumentation
        android:name="android.support.test.runner.AndroidJUnitRunner"
        android:targetPackage="com.android.my.tests" />
</manifest>
"""

MANIFEST_INSTRUMENTATION_TEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.android.my.tests.x">
    <instrumentation
        android:name="android.test.InstrumentationTestRunner"
        android:targetPackage="com.android.my.tests"
        android:label="My Tests" />
</manifest>
"""

EXPECTED_JUNIT_TEST_CONFIG = """<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2017 The Android Open Source Project

     Licensed under the Apache License, Version 2.0 (the "License");
     you may not use this file except in compliance with the License.
     You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

     Unless required by applicable law or agreed to in writing, software
     distributed under the License is distributed on an "AS IS" BASIS,
     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     See the License for the specific language governing permissions and
     limitations under the License.
-->
<!-- This test config file is auto-generated. -->
<configuration description="Runs TestModule.">
    <target_preparer class="com.android.tradefed.targetprep.suite.SuiteApkInstaller">
        <option name="test-file-name" value="TestModule.apk" />
    </target_preparer>

    <test class="com.android.tradefed.testtype.AndroidJUnitTest" >
        <option name="package" value="com.android.my.tests.x" />
        <option name="runner" value="android.support.test.runner.AndroidJUnitRunner" />
    </test>
</configuration>
"""

EXPECTED_INSTRUMENTATION_TEST_CONFIG = """<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2017 The Android Open Source Project

     Licensed under the Apache License, Version 2.0 (the "License");
     you may not use this file except in compliance with the License.
     You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

     Unless required by applicable law or agreed to in writing, software
     distributed under the License is distributed on an "AS IS" BASIS,
     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     See the License for the specific language governing permissions and
     limitations under the License.
-->
<!-- This test config file is auto-generated. -->
<configuration description="Runs My Tests.">
    <target_preparer class="com.android.tradefed.targetprep.suite.SuiteApkInstaller">
        <option name="test-file-name" value="TestModule.apk" />
    </target_preparer>

    <test class="com.android.tradefed.testtype.InstrumentationTest" >
        <option name="package" value="com.android.my.tests.x" />
        <option name="runner" value="android.test.InstrumentationTestRunner" />
    </test>
</configuration>
"""

TOOLS_DIR = os.path.dirname(os.path.dirname(__file__))
EMPTY_TEST_CONFIG = os.path.join(
    TOOLS_DIR, '..', 'core', 'empty_test_config.xml')
INSTRUMENTATION_TEST_CONFIG_TEMPLATE = os.path.join(
    TOOLS_DIR, '..', 'core', 'instrumentation_test_config_template.xml')


class AutoGenTestConfigUnittests(unittest.TestCase):
  """Unittests for auto_gen_test_config."""

  def setUp(self):
    """Setup directory for test."""
    self.test_dir = tempfile.mkdtemp()
    self.config_file = os.path.join(self.test_dir, TEST_MODULE + '.config')
    self.manifest_file = os.path.join(self.test_dir, 'AndroidManifest.xml')

  def tearDown(self):
    """Cleanup the test directory."""
    shutil.rmtree(self.test_dir, ignore_errors=True)

  def testInvalidManifest(self):
    """An empty test config should be generated if AndroidManifest is invalid.
    """
    with open(self.manifest_file, 'w') as f:
      f.write(MANIFEST_INVALID)

    argv = [self.config_file,
            self.manifest_file,
            EMPTY_TEST_CONFIG,
            INSTRUMENTATION_TEST_CONFIG_TEMPLATE]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      with open(EMPTY_TEST_CONFIG) as empty_config:
        self.assertEqual(config_file.read(), empty_config.read())

  def testCreateJUnitTestConfig(self):
    """Test creating test config for AndroidJUnitTest.
    """
    with open(self.manifest_file, 'w') as f:
      f.write(MANIFEST_JUNIT_TEST)

    argv = [self.config_file,
            self.manifest_file,
            EMPTY_TEST_CONFIG,
            INSTRUMENTATION_TEST_CONFIG_TEMPLATE]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      self.assertEqual(config_file.read(), EXPECTED_JUNIT_TEST_CONFIG)

  def testCreateInstrumentationTestConfig(self):
    """Test creating test config for InstrumentationTest.
    """
    with open(self.manifest_file, 'w') as f:
      f.write(MANIFEST_INSTRUMENTATION_TEST)

    argv = [self.config_file,
            self.manifest_file,
            EMPTY_TEST_CONFIG,
            INSTRUMENTATION_TEST_CONFIG_TEMPLATE]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      self.assertEqual(
          config_file.read(), EXPECTED_INSTRUMENTATION_TEST_CONFIG)

if __name__ == '__main__':
  unittest.main()
