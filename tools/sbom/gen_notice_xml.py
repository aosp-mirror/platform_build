# !/usr/bin/env python3
#
# Copyright (C) 2024 The Android Open Source Project
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
Generate NOTICE.xml.gz of a partition.
Usage example:
  gen_notice_xml.py --output_file out/soong/.intermediate/.../NOTICE.xml.gz \
              --metadata out/soong/compliance-metadata/aosp_cf_x86_64_phone/compliance-metadata.db \
              --partition system \
              --product_out out/target/vsoc_x86_64 \
              --soong_out out/soong
"""

import argparse


FILE_HEADER = '''\
<?xml version="1.0" encoding="utf-8"?>
<licenses>
'''
FILE_FOOTER = '''\
</licenses>
'''


def get_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-v', '--verbose', action='store_true', default=False, help='Print more information.')
  parser.add_argument('-d', '--debug', action='store_true', default=True, help='Debug mode')
  parser.add_argument('--output_file', required=True, help='The path of the generated NOTICE.xml.gz file.')
  parser.add_argument('--partition', required=True, help='The name of partition for which the NOTICE.xml.gz is generated.')
  parser.add_argument('--metadata', required=True, help='The path of compliance metadata DB file.')
  parser.add_argument('--product_out', required=True, help='The path of PRODUCT_OUT, e.g. out/target/product/vsoc_x86_64.')
  parser.add_argument('--soong_out', required=True, help='The path of Soong output directory, e.g. out/soong')

  return parser.parse_args()


def log(*info):
  if args.verbose:
    for i in info:
      print(i)


def new_file_name_tag(file_metadata, package_name):
  file_path = file_metadata['installed_file'].removeprefix(args.product_out)
  lib = 'Android'
  if package_name:
    lib = package_name
  return f'<file-name contentId="" lib="{lib}">{file_path}</file-name>\n'


def new_file_content_tag():
  pass


def main():
  global args
  args = get_args()
  log('Args:', vars(args))

  with open(args.output_file, 'w', encoding="utf-8") as notice_xml_file:
    notice_xml_file.write(FILE_HEADER)
    notice_xml_file.write(FILE_FOOTER)


if __name__ == '__main__':
  main()
