#!/usr/bin/env python3
#
# Copyright (C) 2023 The Android Open Source Project
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

import argparse
import hashlib
import json
import sbom_data
import sbom_writers

'''
This script generates SBOM of framework_res.jar of layoutlib shipped with Android Studio.

The generated SBOM contains some placeholders which should be substituted by release_layoutlib.sh.
The placeholders include: document name, document namespace, organization, created timestamp and 
the SHA1 checksum of framework_res.jar.
'''

def get_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-v', '--verbose', action='store_true', default=False,
                      help='Print more information.')
  parser.add_argument('--output_file', required=True,
                      help='The generated SBOM file in SPDX format.')
  parser.add_argument('--layoutlib_sbom', required=True,
                      help='The file path of the SBOM of layoutlib.')

  return parser.parse_args()


def main():
  global args
  args = get_args()

  doc = sbom_data.Document(name='<name>',
                           namespace='<namespace>',
                           creators=['Organization: <organization>'],
                           created='<created>')

  filename = 'data/framework_res.jar'
  file_id = f'SPDXRef-{sbom_data.encode_for_spdxid(filename)}'
  file = sbom_data.File(id=file_id, name=filename, checksum='SHA1: <checksum>')

  package_name = 'framework_res'
  package_id = f'SPDXRef-PREBUILT-{sbom_data.encode_for_spdxid(package_name)}'
  package = sbom_data.Package(id=package_id, name=package_name, version='<package_version>',
                    download_location=sbom_data.VALUE_NONE,
                    supplier='Organization: <organization>',
                    files_analyzed=True,
                    verification_code='<package_verification_code>')
  package.file_ids.append(file_id)

  doc.packages.append(package)
  doc.files.append(file)
  doc.describes = package_id

  with open(args.layoutlib_sbom, 'r', encoding='utf-8') as f:
    layoutlib_sbom = json.load(f)

  with open(args.layoutlib_sbom, 'rb') as f:
    sha1 = hashlib.file_digest(f, 'sha1')

  layoutlib_sbom_namespace = layoutlib_sbom[sbom_writers.PropNames.DOCUMENT_NAMESPACE]
  external_doc_ref = 'DocumentRef-layoutlib'
  doc.external_refs = [
    sbom_data.DocumentExternalReference(external_doc_ref, layoutlib_sbom_namespace,
                                        f'SHA1: {sha1.hexdigest()}')]

  resource_file_spdxids = []
  for file in layoutlib_sbom[sbom_writers.PropNames.FILES]:
    if file[sbom_writers.PropNames.FILE_NAME].startswith('data/res/'):
      resource_file_spdxids.append(file[sbom_writers.PropNames.SPDXID])

  doc.relationships = [
    sbom_data.Relationship(package_id, sbom_data.RelationshipType.CONTAINS, file_id)
  ]
  for spdxid in resource_file_spdxids:
    doc.relationships.append(
      sbom_data.Relationship(file_id, sbom_data.RelationshipType.GENERATED_FROM,
                             f'{external_doc_ref}:{spdxid}'))

  # write sbom file
  with open(args.output_file, 'w', encoding='utf-8') as f:
    sbom_writers.JSONWriter.write(doc, f)


if __name__ == '__main__':
  main()
