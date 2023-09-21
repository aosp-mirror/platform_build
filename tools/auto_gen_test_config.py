#!/usr/bin/env python3
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

import argparse
import re
import os
import shutil
import sys
from xml.dom.minidom import parse

ATTRIBUTE_LABEL = 'android:label'
ATTRIBUTE_RUNNER = 'android:name'
ATTRIBUTE_PACKAGE = 'package'

PLACEHOLDER_LABEL = '{LABEL}'
PLACEHOLDER_EXTRA_CONFIGS = '{EXTRA_CONFIGS}'
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

  parser = argparse.ArgumentParser()
  parser.add_argument(
      "target_config",
      help="Path to the generated output config.")
  parser.add_argument(
      "android_manifest",
      help="Path to AndroidManifest.xml or output of 'aapt2 dump xmltree' with .xmltree extension.")
  parser.add_argument(
      "empty_config",
      help="Path to the empty config template.")
  parser.add_argument(
      "instrumentation_test_config_template",
      help="Path to the instrumentation test config template.")
  parser.add_argument("--extra-configs", default="")
  args = parser.parse_args(argv)

  target_config = args.target_config
  android_manifest = args.android_manifest
  empty_config = args.empty_config
  instrumentation_test_config_template = args.instrumentation_test_config_template
  extra_configs = '\n'.join(args.extra_configs.split('\\n'))

  module = os.path.splitext(os.path.basename(target_config))[0]

  # If the AndroidManifest.xml is not available, but the APK is, this tool also
  # accepts the output of `aapt2 dump xmltree <apk> AndroidManifest.xml` written
  # into a file. This is a custom structured aapt2 output - not raw XML!
  if android_manifest.endswith(".xmltree"):
    label = module
    with open(android_manifest, encoding="utf-8") as manifest:
      # e.g. A: package="android.test.example.helloworld" (Raw: "android.test.example.helloworld")
      #                                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      pattern = re.compile(r"\(Raw:\s\"(.*)\"\)$")
      curr_element = None
      for line in manifest:
        curr_line = line.strip()
        if curr_line.startswith("E:"):
          # e.g. "E: instrumentation (line=9)"
          #          ^^^^^^^^^^^^^^^
          curr_element = curr_line.split(" ")[1]
        if curr_element == "instrumentation":
          if ATTRIBUTE_RUNNER in curr_line:
            runner =  re.findall(pattern, curr_line)[0]
          if ATTRIBUTE_LABEL in curr_line:
            label = re.findall(pattern, curr_line)[0]
        if curr_element == "manifest":
          if ATTRIBUTE_PACKAGE in curr_line:
            package = re.findall(pattern, curr_line)[0]

    if not (runner and label and package):
      # Failed to locate instrumentation or manifest element in AndroidManifest.
      # file. Empty test config file will be created.
      shutil.copyfile(empty_config, target_config)
      return 0

  else:
    # If the AndroidManifest.xml file is directly available, read it as an XML file.
    manifest = parse(android_manifest)
    instrumentation_elements = manifest.getElementsByTagName('instrumentation')
    manifest_elements = manifest.getElementsByTagName('manifest')
    if len(instrumentation_elements) != 1 or len(manifest_elements) != 1:
      # Failed to locate instrumentation or manifest element in AndroidManifest.
      # file. Empty test config file will be created.
      shutil.copyfile(empty_config, target_config)
      return 0

    instrumentation = instrumentation_elements[0]
    manifest = manifest_elements[0]
    if ATTRIBUTE_LABEL in instrumentation.attributes:
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
    config = config.replace(PLACEHOLDER_EXTRA_CONFIGS, extra_configs)
    config = config.replace(PLACEHOLDER_RUNNER, runner)
    with open(target_config, 'w') as config_file:
      config_file.write(config)
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
