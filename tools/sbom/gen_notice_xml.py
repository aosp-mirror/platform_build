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
import compliance_metadata
import google.protobuf.text_format as text_format
import gzip
import hashlib
import metadata_file_pb2
import os
import queue
import xml.sax.saxutils


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


def new_file_name_tag(file_metadata, package_name, content_id):
  file_path = file_metadata['installed_file'].removeprefix(args.product_out)
  lib = 'Android'
  if package_name:
    lib = package_name
  return f'<file-name contentId="{content_id}" lib="{lib}">{file_path}</file-name>\n'


def new_file_content_tag(content_id, license_text):
  escaped_license_text = xml.sax.saxutils.escape(license_text, {'\t': '&#x9;', '\n': '&#xA;', '\r': '&#xD;'})
  return f'<file-content contentId="{content_id}"><![CDATA[{escaped_license_text}]]></file-content>\n\n'

def get_metadata_file_path(file_metadata):
  """Search for METADATA file of a package and return its path."""
  metadata_path = ''
  if file_metadata['module_path']:
    metadata_path = file_metadata['module_path']
  elif file_metadata['kernel_module_copy_files']:
    metadata_path = os.path.dirname(file_metadata['kernel_module_copy_files'].split(':')[0])

  while metadata_path and not os.path.exists(metadata_path + '/METADATA'):
    metadata_path = os.path.dirname(metadata_path)

  return metadata_path

def md5_file_content(filepath):
  h = hashlib.md5()
  with open(filepath, 'rb') as f:
    h.update(f.read())
  return h.hexdigest()

def get_transitive_static_dep_modules(installed_file_metadata, db):
  # Find all transitive static dep files of the installed files
  q = queue.Queue()
  if installed_file_metadata['static_dep_files']:
    for f in installed_file_metadata['static_dep_files'].split(' '):
      q.put(f)
  if installed_file_metadata['whole_static_dep_files']:
    for f in installed_file_metadata['whole_static_dep_files'].split(' '):
      q.put(f)

  static_dep_files = {}
  while not q.empty():
    dep_file = q.get()
    if dep_file in static_dep_files:
      # It has been processed
      continue

    soong_module = db.get_soong_module_of_built_file(dep_file)
    if not soong_module:
      continue

    static_dep_files[dep_file] = soong_module

    if soong_module['static_dep_files']:
      for f in soong_module['static_dep_files'].split(' '):
        if f not in static_dep_files:
          q.put(f)
    if soong_module['whole_static_dep_files']:
      for f in soong_module['whole_static_dep_files'].split(' '):
        if f not in static_dep_files:
          q.put(f)

  return static_dep_files.values()

def main():
  global args
  args = get_args()
  log('Args:', vars(args))

  global db
  db = compliance_metadata.MetadataDb(args.metadata)
  if args.debug:
    db.dump_debug_db(os.path.dirname(args.output_file) + '/compliance-metadata-debug.db')

  # NOTICE.xml
  notice_xml_file_path = os.path.dirname(args.output_file) + '/NOTICE.xml'
  with open(notice_xml_file_path, 'w', encoding="utf-8") as notice_xml_file:
    notice_xml_file.write(FILE_HEADER)

    all_license_files = {}
    for metadata in db.get_installed_file_in_dir(args.product_out + '/' + args.partition):
      soong_module = db.get_soong_module_of_installed_file(metadata['installed_file'])
      if soong_module:
        metadata.update(soong_module)
      else:
        # For make modules soong_module_type should be empty
        metadata['soong_module_type'] = ''
        metadata['static_dep_files'] = ''
        metadata['whole_static_dep_files'] = ''

      installed_file_metadata_list = [metadata]
      if args.partition in ('vendor', 'product', 'system_ext'):
        # For transitive static dependencies of an installed file, make it as if an installed file are
        # also created from static dependency modules whose licenses are also collected
        static_dep_modules = get_transitive_static_dep_modules(metadata, db)
        for dep in static_dep_modules:
          dep['installed_file'] = metadata['installed_file']
          installed_file_metadata_list.append(dep)

      for installed_file_metadata in installed_file_metadata_list:
        package_name = 'Android'
        licenses = {}
        if installed_file_metadata['module_path']:
          metadata_file_path = get_metadata_file_path(installed_file_metadata)
          if metadata_file_path:
            proto = metadata_file_pb2.Metadata()
            with open(metadata_file_path + '/METADATA', 'rt') as f:
              text_format.Parse(f.read(), proto)
            if proto.name:
              package_name = proto.name
              if proto.third_party and proto.third_party.version:
                if proto.third_party.version.startswith('v'):
                  package_name = package_name + '_' + proto.third_party.version
                else:
                  package_name = package_name + '_v_' + proto.third_party.version
            else:
              package_name = metadata_file_path
              if metadata_file_path.startswith('external/'):
                package_name = metadata_file_path.removeprefix('external/')

          # Every license file is in a <file-content> element
          licenses = db.get_module_licenses(installed_file_metadata.get('name', ''), installed_file_metadata['module_path'])

        # Installed file is from PRODUCT_COPY_FILES
        elif metadata['product_copy_files']:
          licenses['unused_name'] = metadata['license_text']

        # Installed file is generated by the platform in builds
        elif metadata['is_platform_generated']:
          licenses['unused_name'] = metadata['license_text']

        if licenses:
          # Each value is a space separated filepath list
          for license_files in licenses.values():
            if not license_files:
              continue
            for filepath in license_files.split(' '):
              if filepath not in all_license_files:
                all_license_files[filepath] = md5_file_content(filepath)
              md5 = all_license_files[filepath]
              notice_xml_file.write(new_file_name_tag(installed_file_metadata, package_name, md5))

    # Licenses
    processed_md5 = []
    for filepath, md5 in all_license_files.items():
      if md5 not in processed_md5:
        processed_md5.append(md5)
        with open(filepath, 'rt', errors='backslashreplace') as f:
          notice_xml_file.write(new_file_content_tag(md5, f.read()))

    notice_xml_file.write(FILE_FOOTER)

  # NOTICE.xml.gz
  with open(notice_xml_file_path, 'rb') as notice_xml_file, gzip.open(args.output_file, 'wb') as gz_file:
    gz_file.writelines(notice_xml_file)

if __name__ == '__main__':
  main()
