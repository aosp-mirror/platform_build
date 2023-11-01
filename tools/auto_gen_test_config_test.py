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

XMLTREE_JUNIT_TEST = """N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    A: package="com.android.my.tests.x" (Raw: "com.android.my.tests.x")
      E: instrumentation (line=9)
        A: http://schemas.android.com/apk/res/android:label(0x01010001)="TestModule" (Raw: "TestModule")
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="androidx.test.runner.AndroidJUnitRunner" (Raw: "androidx.test.runner.AndroidJUnitRunner")
        A: http://schemas.android.com/apk/res/android:targetPackage(0x01010021)="com.android.my.tests" (Raw: "com.android.my.tests")
"""

XMLTREE_INSTRUMENTATION_TEST = """N: android=http://schemas.android.com/apk/res/android (line=2)
  E: manifest (line=2)
    A: package="com.android.my.tests.x" (Raw: "com.android.my.tests.x")
      E: instrumentation (line=9)
        A: http://schemas.android.com/apk/res/android:label(0x01010001)="TestModule" (Raw: "TestModule")
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="android.test.InstrumentationTestRunner" (Raw: "android.test.InstrumentationTestRunner")
        A: http://schemas.android.com/apk/res/android:targetPackage(0x01010021)="com.android.my.tests" (Raw: "com.android.my.tests")
"""

MANIFEST_JUNIT_TEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.android.my.tests.x">
    <instrumentation
        android:name="androidx.test.runner.AndroidJUnitRunner"
        android:targetPackage="com.android.my.tests" />
</manifest>
"""

MANIFEST_INSTRUMENTATION_TEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.android.my.tests.x">
    <instrumentation
        android:name="android.test.InstrumentationTestRunner"
        android:targetPackage="com.android.my.tests"
        android:label="TestModule" />
</manifest>
"""

EXPECTED_JUNIT_TEST_CONFIG = """<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2023 The Android Open Source Project

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
    <option name="test-suite-tag" value="apct" />
    <option name="test-suite-tag" value="apct-instrumentation" />

    <target_preparer class="com.android.tradefed.targetprep.suite.SuiteApkInstaller">
        <option name="cleanup-apks" value="true" />
        <option name="test-file-name" value="TestModule.apk" />
    </target_preparer>

    <test class="com.android.tradefed.testtype.AndroidJUnitTest" >
        <option name="package" value="com.android.my.tests.x" />
        <option name="runner" value="androidx.test.runner.AndroidJUnitRunner" />
    </test>
</configuration>
"""

EXPECTED_INSTRUMENTATION_TEST_CONFIG = """<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2023 The Android Open Source Project

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
    <option name="test-suite-tag" value="apct" />
    <option name="test-suite-tag" value="apct-instrumentation" />

    <target_preparer class="com.android.tradefed.targetprep.suite.SuiteApkInstaller">
        <option name="cleanup-apks" value="true" />
        <option name="test-file-name" value="TestModule.apk" />
    </target_preparer>

    <test class="com.android.tradefed.testtype.InstrumentationTest" >
        <option name="package" value="com.android.my.tests.x" />
        <option name="runner" value="android.test.InstrumentationTestRunner" />
    </test>
</configuration>
"""

EMPTY_TEST_CONFIG_CONTENT = """<?xml version="1.0" encoding="utf-8"?>
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
<!-- No AndroidTest.xml was provided and the manifest does not include
     instrumentation, hence this apk is not instrumentable.
-->
<configuration description="Empty Configuration" />
"""

INSTRUMENTATION_TEST_CONFIG_TEMPLATE_CONTENT = """<?xml version="1.0" encoding="utf-8"?>
<!-- Copyright (C) 2023 The Android Open Source Project

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
<configuration description="Runs {LABEL}.">
    <option name="test-suite-tag" value="apct" />
    <option name="test-suite-tag" value="apct-instrumentation" />
{EXTRA_CONFIGS}
    <target_preparer class="com.android.tradefed.targetprep.suite.SuiteApkInstaller">
        <option name="cleanup-apks" value="true" />
        <option name="test-file-name" value="{MODULE}.apk" />
    </target_preparer>

    <test class="com.android.tradefed.testtype.{TEST_TYPE}" >
        <option name="package" value="{PACKAGE}" />
        <option name="runner" value="{RUNNER}" />
    </test>
</configuration>
"""


class AutoGenTestConfigUnittests(unittest.TestCase):
  """Unittests for auto_gen_test_config."""

  def setUp(self):
    """Setup directory for test."""
    self.test_dir = tempfile.mkdtemp()
    self.config_file = os.path.join(self.test_dir, TEST_MODULE + '.config')
    self.manifest_file = os.path.join(self.test_dir, 'AndroidManifest.xml')
    self.xmltree_file = os.path.join(self.test_dir, TEST_MODULE + '.xmltree')
    self.empty_test_config_file = os.path.join(self.test_dir, 'empty.config')
    self.instrumentation_test_config_template_file = os.path.join(
        self.test_dir, 'instrumentation.config')

    with open(self.empty_test_config_file, 'w') as f:
      f.write(EMPTY_TEST_CONFIG_CONTENT)

    with open(self.instrumentation_test_config_template_file, 'w') as f:
      f.write(INSTRUMENTATION_TEST_CONFIG_TEMPLATE_CONTENT)

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
            self.empty_test_config_file,
            self.instrumentation_test_config_template_file]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      with open(self.empty_test_config_file) as empty_config:
        self.assertEqual(config_file.read(), empty_config.read())

  def testCreateJUnitTestConfig(self):
    """Test creating test config for AndroidJUnitTest.
    """
    with open(self.manifest_file, 'w') as f:
      f.write(MANIFEST_JUNIT_TEST)

    argv = [self.config_file,
            self.manifest_file,
            self.empty_test_config_file,
            self.instrumentation_test_config_template_file]
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
            self.empty_test_config_file,
            self.instrumentation_test_config_template_file]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      self.assertEqual(
          config_file.read(), EXPECTED_INSTRUMENTATION_TEST_CONFIG)

  def testCreateJUnitTestConfigWithXMLTree(self):
    """Test creating test config for AndroidJUnitTest.
    """
    with open(self.xmltree_file, 'w') as f:
      f.write(XMLTREE_JUNIT_TEST)

    argv = [self.config_file,
            self.xmltree_file,
            self.empty_test_config_file,
            self.instrumentation_test_config_template_file]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      self.assertEqual(config_file.read(), EXPECTED_JUNIT_TEST_CONFIG)

  def testCreateInstrumentationTestConfigWithXMLTree(self):
    """Test creating test config for InstrumentationTest.
    """
    with open(self.xmltree_file, 'w') as f:
      f.write(XMLTREE_INSTRUMENTATION_TEST)

    argv = [self.config_file,
            self.xmltree_file,
            self.empty_test_config_file,
            self.instrumentation_test_config_template_file]
    auto_gen_test_config.main(argv)
    with open(self.config_file) as config_file:
      self.assertEqual(
          config_file.read(), EXPECTED_INSTRUMENTATION_TEST_CONFIG)

if __name__ == '__main__':
  unittest.main()
