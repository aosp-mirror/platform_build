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
"""
Utility to generate the Android manifest file of runtime resource overlay
package for source module.
"""
from xml.dom.minidom import parseString
import argparse
import os
import sys

ANDROID_MANIFEST_TEMPLATE="""<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="%s.auto_generated_rro__"
    android:versionCode="1"
    android:versionName="1.0">
    <overlay android:targetPackage="%s" android:priority="0" android:isStatic="true"/>
</manifest>
"""


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-u', '--use-package-name', action='store_true',
        help='Indicate that --package-info is a package name.')
    parser.add_argument(
        '-p', '--package-info', required=True,
        help='Manifest package name or manifest file path of source module.')
    parser.add_argument(
        '-o', '--output', required=True,
        help='Output manifest file path.')
    return parser.parse_args()


def main(argv):
  args = get_args()

  package_name = args.package_info
  if not args.use_package_name:
    with open(args.package_info) as f:
      data = f.read()
      f.close()
      dom = parseString(data)
      package_name = dom.documentElement.getAttribute('package')

  with open(args.output, 'w+') as f:
    f.write(ANDROID_MANIFEST_TEMPLATE % (package_name, package_name))
    f.close()


if __name__ == "__main__":
  main(sys.argv)
