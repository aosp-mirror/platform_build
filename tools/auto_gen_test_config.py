#!/usr/bin/env python
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

"""A tool to generate TradeFed test config file.
"""

import os
import shutil
import sys
from xml.dom.minidom import parse

ATTRIBUTE_LABEL = 'android:label'
ATTRIBUTE_RUNNER = 'android:name'
ATTRIBUTE_PACKAGE = 'package'

PLACEHOLDER_LABEL = '{LABEL}'
PLACEHOLDER_MODULE = '{MODULE}'
PLACEHOLDER_PACKAGE = '{PACKAGE}'
PLACEHOLDER_RUNNER = '{RUNNER}'
PLACEHOLDER_TEST_TYPE = '{TEST_TYPE}'


def main(argv):
  """Entry point of auto_gen_test_config.

  Args:
    argv: A list of arguments.
  Returns:
    0 if no error, otherwise 1.
  """
  if len(argv) != 4:
    sys.stderr.write(
        'Invalid arguements. The script requires 4 arguments for file paths: '
        'target_config android_manifest empty_config '
        'instrumentation_test_config_template.\n')
    return 1
  target_config = argv[0]
  android_manifest = argv[1]
  empty_config = argv[2]
  instrumentation_test_config_template = argv[3]

  manifest = parse(android_manifest)
  instrumentation_elements = manifest.getElementsByTagName('instrumentation')
  manifest_elements = manifest.getElementsByTagName('manifest')
  if len(instrumentation_elements) != 1 or len(manifest_elements) != 1:
    # Failed to locate instrumentation or manifest element in AndroidManifest.
    # file. Empty test config file will be created.
    shutil.copyfile(empty_config, target_config)
    return 0

  module = os.path.splitext(os.path.basename(target_config))[0]
  instrumentation = instrumentation_elements[0]
  manifest = manifest_elements[0]
  if instrumentation.attributes.has_key(ATTRIBUTE_LABEL):
    label = instrumentation.attributes[ATTRIBUTE_LABEL].value
  else:
    label = module
  runner = instrumentation.attributes[ATTRIBUTE_RUNNER].value
  package = manifest.attributes[ATTRIBUTE_PACKAGE].value
  test_type = ('InstrumentationTest'
               if runner.endswith('.InstrumentationTestRunner')
               else 'AndroidJUnitTest')

  with open(instrumentation_test_config_template) as template:
    config = template.read()
    config = config.replace(PLACEHOLDER_LABEL, label)
    config = config.replace(PLACEHOLDER_MODULE, module)
    config = config.replace(PLACEHOLDER_PACKAGE, package)
    config = config.replace(PLACEHOLDER_TEST_TYPE, test_type)
    config = config.replace(PLACEHOLDER_RUNNER, runner)
    with open(target_config, 'w') as config_file:
      config_file.write(config)
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
