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

"""
Generate the SBOM of the current target product in SPDX format.
Usage example:
  generate-sbom.py --output_file out/target/product/vsoc_x86_64/sbom.spdx \
                   --metadata out/target/product/vsoc_x86_64/sbom-metadata.csv \
                   --product_out_dir=out/target/product/vsoc_x86_64 \
                   --build_version $(cat out/target/product/vsoc_x86_64/build_fingerprint.txt) \
                   --product_mfr=Google
"""

import argparse
import csv
import datetime
import google.protobuf.text_format as text_format
import hashlib
import json
import os
import metadata_file_pb2

# Common
SPDXID = 'SPDXID'
SPDX_VERSION = 'SPDXVersion'
DATA_LICENSE = 'DataLicense'
DOCUMENT_NAME = 'DocumentName'
DOCUMENT_NAMESPACE = 'DocumentNamespace'
CREATED = 'Created'
CREATOR = 'Creator'
EXTERNAL_DOCUMENT_REF = 'ExternalDocumentRef'

# Package
PACKAGE_NAME = 'PackageName'
PACKAGE_DOWNLOAD_LOCATION = 'PackageDownloadLocation'
PACKAGE_VERSION = 'PackageVersion'
PACKAGE_SUPPLIER = 'PackageSupplier'
FILES_ANALYZED = 'FilesAnalyzed'
PACKAGE_VERIFICATION_CODE = 'PackageVerificationCode'
PACKAGE_EXTERNAL_REF = 'ExternalRef'
# Package license
PACKAGE_LICENSE_CONCLUDED = 'PackageLicenseConcluded'
PACKAGE_LICENSE_INFO_FROM_FILES = 'PackageLicenseInfoFromFiles'
PACKAGE_LICENSE_DECLARED = 'PackageLicenseDeclared'
PACKAGE_LICENSE_COMMENTS = 'PackageLicenseComments'

# File
FILE_NAME = 'FileName'
FILE_CHECKSUM = 'FileChecksum'
# File license
FILE_LICENSE_CONCLUDED = 'LicenseConcluded'
FILE_LICENSE_INFO_IN_FILE = 'LicenseInfoInFile'
FILE_LICENSE_COMMENTS = 'LicenseComments'
FILE_COPYRIGHT_TEXT = 'FileCopyrightText'
FILE_NOTICE = 'FileNotice'
FILE_ATTRIBUTION_TEXT = 'FileAttributionText'

# Relationship
RELATIONSHIP = 'Relationship'
REL_DESCRIBES = 'DESCRIBES'
REL_VARIANT_OF = 'VARIANT_OF'
REL_GENERATED_FROM = 'GENERATED_FROM'

# Package type
PKG_SOURCE = 'SOURCE'
PKG_UPSTREAM = 'UPSTREAM'
PKG_PREBUILT = 'PREBUILT'

# Security tag
NVD_CPE23 = 'NVD-CPE2.3:'

# Report
ISSUE_NO_METADATA = 'No metadata generated in Make for installed files:'
ISSUE_NO_METADATA_FILE = 'No METADATA file found for installed file:'
ISSUE_METADATA_FILE_INCOMPLETE = 'METADATA file incomplete:'
ISSUE_UNKNOWN_SECURITY_TAG_TYPE = 'Unknown security tag type:'
ISSUE_INSTALLED_FILE_NOT_EXIST = 'Non-exist installed files:'
INFO_METADATA_FOUND_FOR_PACKAGE = 'METADATA file found for packages:'


def get_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-v', '--verbose', action='store_true', default=False, help='Print more information.')
  parser.add_argument('--output_file', required=True, help='The generated SBOM file in SPDX format.')
  parser.add_argument('--metadata', required=True, help='The SBOM metadata file path.')
  parser.add_argument('--product_out_dir', required=True, help='The parent directory of all the installed files.')
  parser.add_argument('--build_version', required=True, help='The build version.')
  parser.add_argument('--product_mfr', required=True, help='The product manufacturer.')
  parser.add_argument('--json', action='store_true', default=False, help='Generated SBOM file in SPDX JSON format')
  parser.add_argument('--unbundled', action='store_true', default=False, help='Generate SBOM file for unbundled module')

  return parser.parse_args()


def log(*info):
  if args.verbose:
    for i in info:
      print(i)


def new_doc_header(doc_id):
  return {
      SPDX_VERSION: 'SPDX-2.3',
      DATA_LICENSE: 'CC0-1.0',
      SPDXID: doc_id,
      DOCUMENT_NAME: args.build_version,
      DOCUMENT_NAMESPACE: f'https://www.google.com/sbom/spdx/android/{args.build_version}',
      CREATOR: 'Organization: Google, LLC',
      CREATED: '<timestamp>',
      EXTERNAL_DOCUMENT_REF: [],
  }


def new_package_record(id, name, version, supplier, download_location=None, files_analyzed='false', external_refs=[]):
  package = {
      PACKAGE_NAME: name,
      SPDXID: id,
      PACKAGE_DOWNLOAD_LOCATION: download_location if download_location else 'NONE',
      FILES_ANALYZED: files_analyzed,
  }
  if version:
    package[PACKAGE_VERSION] = version
  if supplier:
    package[PACKAGE_SUPPLIER] = f'Organization: {supplier}'
  if external_refs:
    package[PACKAGE_EXTERNAL_REF] = external_refs

  return package


def new_file_record(id, name, checksum):
  return {
      FILE_NAME: name,
      SPDXID: id,
      FILE_CHECKSUM: checksum
  }


def encode_for_spdxid(s):
  """Simple encode for string values used in SPDXID which uses the charset of A-Za-Z0-9.-"""
  result = ''
  for c in s:
    if c.isalnum() or c in '.-':
      result += c
    elif c in '_@/':
      result += '-'
    else:
      result += '0x' + c.encode('utf-8').hex()

  return result.lstrip('-')


def new_package_id(package_name, type):
  return f'SPDXRef-{type}-{encode_for_spdxid(package_name)}'


def new_external_doc_ref(package_name, sbom_url, sbom_checksum):
  doc_ref_id = f'DocumentRef-{PKG_UPSTREAM}-{encode_for_spdxid(package_name)}'
  return f'{EXTERNAL_DOCUMENT_REF}: {doc_ref_id} {sbom_url} {sbom_checksum}', doc_ref_id


def new_file_id(file_path):
  return f'SPDXRef-{encode_for_spdxid(file_path)}'


def new_relationship_record(id1, relationship, id2):
  return f'{RELATIONSHIP}: {id1} {relationship} {id2}'


def checksum(file_path):
  file_path = args.product_out_dir + '/' + file_path
  h = hashlib.sha1()
  if os.path.islink(file_path):
    h.update(os.readlink(file_path).encode('utf-8'))
  else:
    with open(file_path, 'rb') as f:
      h.update(f.read())
  return f'SHA1: {h.hexdigest()}'


def is_soong_prebuilt_module(file_metadata):
  return file_metadata['soong_module_type'] and file_metadata['soong_module_type'] in [
      'android_app_import', 'android_library_import', 'cc_prebuilt_binary', 'cc_prebuilt_library',
      'cc_prebuilt_library_headers', 'cc_prebuilt_library_shared', 'cc_prebuilt_library_static', 'cc_prebuilt_object',
      'dex_import', 'java_import', 'java_sdk_library_import', 'java_system_modules_import',
      'libclang_rt_prebuilt_library_static', 'libclang_rt_prebuilt_library_shared', 'llvm_prebuilt_library_static',
      'ndk_prebuilt_object', 'ndk_prebuilt_shared_stl', 'nkd_prebuilt_static_stl', 'prebuilt_apex',
      'prebuilt_bootclasspath_fragment', 'prebuilt_dsp', 'prebuilt_firmware', 'prebuilt_kernel_modules',
      'prebuilt_rfsa', 'prebuilt_root', 'rust_prebuilt_dylib', 'rust_prebuilt_library', 'rust_prebuilt_rlib',
      'vndk_prebuilt_shared',

      # 'android_test_import',
      # 'cc_prebuilt_test_library_shared',
      # 'java_import_host',
      # 'java_test_import',
      # 'llvm_host_prebuilt_library_shared',
      # 'prebuilt_apis',
      # 'prebuilt_build_tool',
      # 'prebuilt_defaults',
      # 'prebuilt_etc',
      # 'prebuilt_etc_host',
      # 'prebuilt_etc_xml',
      # 'prebuilt_font',
      # 'prebuilt_hidl_interfaces',
      # 'prebuilt_platform_compat_config',
      # 'prebuilt_stubs_sources',
      # 'prebuilt_usr_share',
      # 'prebuilt_usr_share_host',
      # 'soong_config_module_type_import',
  ]


def is_source_package(file_metadata):
  module_path = file_metadata['module_path']
  return module_path.startswith('external/') and not is_prebuilt_package(file_metadata)


def is_prebuilt_package(file_metadata):
  module_path = file_metadata['module_path']
  if module_path:
    return (module_path.startswith('prebuilts/') or
            is_soong_prebuilt_module(file_metadata) or
            file_metadata['is_prebuilt_make_module'])

  kernel_module_copy_files = file_metadata['kernel_module_copy_files']
  if kernel_module_copy_files and not kernel_module_copy_files.startswith('ANDROID-GEN:'):
    return True

  return False


def get_source_package_info(file_metadata, metadata_file_path):
  if not metadata_file_path:
    return file_metadata['module_path'], []

  metadata_proto = metadata_file_protos[metadata_file_path]
  external_refs = []
  for tag in metadata_proto.third_party.security.tag:
    if tag.lower().startswith((NVD_CPE23 + 'cpe:2.3:').lower()):
      external_refs.append(f'{PACKAGE_EXTERNAL_REF}: SECURITY cpe23Type {tag.removeprefix(NVD_CPE23)}')
    elif tag.lower().startswith((NVD_CPE23 + 'cpe:/').lower()):
      external_refs.append(f'{PACKAGE_EXTERNAL_REF}: SECURITY cpe22Type {tag.removeprefix(NVD_CPE23)}')

  if metadata_proto.name:
    return metadata_proto.name, external_refs
  else:
    return os.path.basename(metadata_file_path), external_refs  # return the directory name only as package name


def get_prebuilt_package_name(file_metadata, metadata_file_path):
  name = None
  if metadata_file_path:
    metadata_proto = metadata_file_protos[metadata_file_path]
    if metadata_proto.name:
      name = metadata_proto.name
    else:
      name = metadata_file_path
  elif file_metadata['module_path']:
    name = file_metadata['module_path']
  elif file_metadata['kernel_module_copy_files']:
    src_path = file_metadata['kernel_module_copy_files'].split(':')[0]
    name = os.path.dirname(src_path)

  return name.removeprefix('prebuilts/').replace('/', '-')


def get_metadata_file_path(file_metadata):
  metadata_path = ''
  if file_metadata['module_path']:
    metadata_path = file_metadata['module_path']
  elif file_metadata['kernel_module_copy_files']:
    metadata_path = os.path.dirname(file_metadata['kernel_module_copy_files'].split(':')[0])

  while metadata_path and not os.path.exists(metadata_path + '/METADATA'):
    metadata_path = os.path.dirname(metadata_path)

  return metadata_path


def get_package_version(metadata_file_path):
  if not metadata_file_path:
    return None
  metadata_proto = metadata_file_protos[metadata_file_path]
  return metadata_proto.third_party.version


def get_package_homepage(metadata_file_path):
  if not metadata_file_path:
    return None
  metadata_proto = metadata_file_protos[metadata_file_path]
  if metadata_proto.third_party.homepage:
    return metadata_proto.third_party.homepage
  for url in metadata_proto.third_party.url:
    if url.type == metadata_file_pb2.URL.Type.HOMEPAGE:
      return url.value

  return None


def get_package_download_location(metadata_file_path):
  if not metadata_file_path:
    return None
  metadata_proto = metadata_file_protos[metadata_file_path]
  if metadata_proto.third_party.url:
    urls = sorted(metadata_proto.third_party.url, key=lambda url: url.type)
    if urls[0].type != metadata_file_pb2.URL.Type.HOMEPAGE:
      return urls[0].value
    elif len(urls) > 1:
      return urls[1].value

  return None


def get_sbom_fragments(installed_file_metadata, metadata_file_path):
  external_doc_ref = None
  packages = []
  relationships = []

  # Info from METADATA file
  homepage = get_package_homepage(metadata_file_path)
  version = get_package_version(metadata_file_path)
  download_location = get_package_download_location(metadata_file_path)

  if is_source_package(installed_file_metadata):
    # Source fork packages
    name, external_refs = get_source_package_info(installed_file_metadata, metadata_file_path)
    source_package_id = new_package_id(name, PKG_SOURCE)
    source_package = new_package_record(source_package_id, name, args.build_version, args.product_mfr,
                                        external_refs=external_refs)

    upstream_package_id = new_package_id(name, PKG_UPSTREAM)
    upstream_package = new_package_record(upstream_package_id, name, version, homepage, download_location)
    packages += [source_package, upstream_package]
    relationships.append(new_relationship_record(source_package_id, REL_VARIANT_OF, upstream_package_id))
  elif is_prebuilt_package(installed_file_metadata):
    # Prebuilt fork packages
    name = get_prebuilt_package_name(installed_file_metadata, metadata_file_path)
    prebuilt_package_id = new_package_id(name, PKG_PREBUILT)
    prebuilt_package = new_package_record(prebuilt_package_id, name, args.build_version, args.product_mfr)
    packages.append(prebuilt_package)

    if metadata_file_path:
      metadata_proto = metadata_file_protos[metadata_file_path]
      if metadata_proto.third_party.WhichOneof('sbom') == 'sbom_ref':
        sbom_url = metadata_proto.third_party.sbom_ref.url
        sbom_checksum = metadata_proto.third_party.sbom_ref.checksum
        upstream_element_id = metadata_proto.third_party.sbom_ref.element_id
        if sbom_url and sbom_checksum and upstream_element_id:
          external_doc_ref, doc_ref_id = new_external_doc_ref(name, sbom_url, sbom_checksum)
          relationships.append(
              new_relationship_record(prebuilt_package_id, REL_VARIANT_OF, doc_ref_id + ':' + upstream_element_id))

  return external_doc_ref, packages, relationships


def generate_package_verification_code(files):
  checksums = [file[FILE_CHECKSUM] for file in files]
  checksums.sort()
  h = hashlib.sha1()
  h.update(''.join(checksums).encode(encoding='utf-8'))
  return h.hexdigest()


def write_record(f, record):
  if record.__class__.__name__ == 'dict':
    for k, v in record.items():
      if k == EXTERNAL_DOCUMENT_REF or k == PACKAGE_EXTERNAL_REF:
        for ref in v:
          f.write(ref + '\n')
      else:
        f.write('{}: {}\n'.format(k, v))
  elif record.__class__.__name__ == 'str':
    f.write(record + '\n')
  f.write('\n')


def write_tagvalue_sbom(all_records):
  with open(args.output_file, 'w', encoding="utf-8") as output_file:
    for rec in all_records:
      write_record(output_file, rec)


def write_json_sbom(all_records, product_package_id):
  doc = {}
  product_package = None
  for r in all_records:
    if r.__class__.__name__ == 'dict':
      if DOCUMENT_NAME in r:  # Doc header
        doc['spdxVersion'] = r[SPDX_VERSION]
        doc['dataLicense'] = r[DATA_LICENSE]
        doc[SPDXID] = r[SPDXID]
        doc['name'] = r[DOCUMENT_NAME]
        doc['documentNamespace'] = r[DOCUMENT_NAMESPACE]
        doc['creationInfo'] = {
            'creators': [r[CREATOR]],
            'created': r[CREATED],
        }
        doc['externalDocumentRefs'] = []
        for ref in r[EXTERNAL_DOCUMENT_REF]:
          # ref is 'ExternalDocumentRef: <doc id> <doc url> SHA1: xxxxx'
          fields = ref.split(' ')
          doc_ref = {
              'externalDocumentId': fields[1],
              'spdxDocument': fields[2],
              'checksum': {
                  'algorithm': fields[3][:-1],
                  'checksumValue': fields[4]
              }
          }
          doc['externalDocumentRefs'].append(doc_ref)
        doc['documentDescribes'] = []
        doc['packages'] = []
        doc['files'] = []
        doc['relationships'] = []

      elif PACKAGE_NAME in r:  # packages
        package = {
            'name': r[PACKAGE_NAME],
            SPDXID: r[SPDXID],
            'downloadLocation': r[PACKAGE_DOWNLOAD_LOCATION],
            'filesAnalyzed': r[FILES_ANALYZED] == "true"
        }
        if PACKAGE_VERSION in r:
          package['versionInfo'] = r[PACKAGE_VERSION]
        if PACKAGE_SUPPLIER in r:
          package['supplier'] = r[PACKAGE_SUPPLIER]
        if PACKAGE_VERIFICATION_CODE in r:
          package['packageVerificationCode'] = {
              'packageVerificationCodeValue': r[PACKAGE_VERIFICATION_CODE]
          }
        if PACKAGE_EXTERNAL_REF in r:
          package['externalRefs'] = []
          for ref in r[PACKAGE_EXTERNAL_REF]:
            # ref is 'ExternalRef: SECURITY cpe22Type cpe:/a:jsoncpp_project:jsoncpp:1.9.4'
            fields = ref.split(' ')
            ext_ref = {
                'referenceCategory': fields[1],
                'referenceType': fields[2],
                'referenceLocator': fields[3],
            }
            package['externalRefs'].append(ext_ref)

        doc['packages'].append(package)
        if r[SPDXID] == product_package_id:
          product_package = package
          product_package['hasFiles'] = []

      elif FILE_NAME in r:  # files
        file = {
            'fileName': r[FILE_NAME],
            SPDXID: r[SPDXID]
        }
        checksum = r[FILE_CHECKSUM].split(': ')
        file['checksums'] = [{
            'algorithm': checksum[0],
            'checksumValue': checksum[1],
        }]
        doc['files'].append(file)
        product_package['hasFiles'].append(r[SPDXID])

    elif r.__class__.__name__ == 'str':
      if r.startswith(RELATIONSHIP):
        # r is 'Relationship: <spdxid> <relationship> <spdxid>'
        fields = r.split(' ')
        rel = {
            'spdxElementId': fields[1],
            'relatedSpdxElement': fields[3],
            'relationshipType': fields[2],
        }
        if fields[2] == REL_DESCRIBES:
          doc['documentDescribes'].append(fields[3])
        else:
          doc['relationships'].append(rel)

  with open(args.output_file + '.json', 'w', encoding="utf-8") as output_file:
    output_file.write(json.dumps(doc, indent=4))


def save_report(report):
  prefix, _ = os.path.splitext(args.output_file)
  with open(prefix + '-gen-report.txt', 'w', encoding='utf-8') as report_file:
    for type, issues in report.items():
      report_file.write(type + '\n')
      for issue in issues:
        report_file.write('\t' + issue + '\n')
      report_file.write('\n')


def sort_rels(rel):
  # rel = 'Relationship file_id GENERATED_FROM package_id'
  fields = rel.split(' ')
  return fields[3] + fields[1]


# Validate the metadata generated by Make for installed files and report if there is no metadata.
def installed_file_has_metadata(installed_file_metadata, report):
  installed_file = installed_file_metadata['installed_file']
  module_path = installed_file_metadata['module_path']
  product_copy_files = installed_file_metadata['product_copy_files']
  kernel_module_copy_files = installed_file_metadata['kernel_module_copy_files']
  is_platform_generated = installed_file_metadata['is_platform_generated']

  if (not module_path and
      not product_copy_files and
      not kernel_module_copy_files and
      not is_platform_generated and
      not installed_file.endswith('.fsv_meta')):
    report[ISSUE_NO_METADATA].append(installed_file)
    return False

  return True


def report_metadata_file(metadata_file_path, installed_file_metadata, report):
  if metadata_file_path:
    report[INFO_METADATA_FOUND_FOR_PACKAGE].append(
        'installed_file: {}, module_path: {}, METADATA file: {}'.format(
            installed_file_metadata['installed_file'],
            installed_file_metadata['module_path'],
            metadata_file_path + '/METADATA'))

    package_metadata = metadata_file_pb2.Metadata()
    with open(metadata_file_path + '/METADATA', 'rt') as f:
      text_format.Parse(f.read(), package_metadata)

    if not metadata_file_path in metadata_file_protos:
      metadata_file_protos[metadata_file_path] = package_metadata
      if not package_metadata.name:
        report[ISSUE_METADATA_FILE_INCOMPLETE].append(f'{metadata_file_path}/METADATA does not has "name"')

      if not package_metadata.third_party.version:
        report[ISSUE_METADATA_FILE_INCOMPLETE].append(
            f'{metadata_file_path}/METADATA does not has "third_party.version"')

      for tag in package_metadata.third_party.security.tag:
        if not tag.startswith(NVD_CPE23):
          report[ISSUE_UNKNOWN_SECURITY_TAG_TYPE].append(
              f'Unknown security tag type: {tag} in {metadata_file_path}/METADATA')
  else:
    report[ISSUE_NO_METADATA_FILE].append(
        "installed_file: {}, module_path: {}".format(
            installed_file_metadata['installed_file'], installed_file_metadata['module_path']))


def generate_fragment():
  with open(args.metadata, newline='') as sbom_metadata_file:
    reader = csv.DictReader(sbom_metadata_file)
    for installed_file_metadata in reader:
      installed_file = installed_file_metadata['installed_file']
      if args.output_file != args.product_out_dir + installed_file + ".spdx":
        continue

      module_path = installed_file_metadata['module_path']
      package_id = new_package_id(encode_for_spdxid(module_path), PKG_PREBUILT)
      package = new_package_record(package_id, module_path, args.build_version, args.product_mfr)
      file_id = new_file_id(installed_file)
      file = new_file_record(file_id, installed_file, checksum(installed_file))
      relationship = new_relationship_record(file_id, REL_GENERATED_FROM, package_id)
      records = [package, file, relationship]
      write_tagvalue_sbom(records)
      break


def main():
  global args
  args = get_args()
  log('Args:', vars(args))

  if args.unbundled:
    generate_fragment()
    return

  global metadata_file_protos
  metadata_file_protos = {}

  doc_id = 'SPDXRef-DOCUMENT'
  doc_header = new_doc_header(doc_id)

  product_package_id = 'SPDXRef-PRODUCT'
  product_package = new_package_record(product_package_id, 'PRODUCT', args.build_version, args.product_mfr,
                                       files_analyzed='true')

  platform_package_id = 'SPDXRef-PLATFORM'
  platform_package = new_package_record(platform_package_id, 'PLATFORM', args.build_version, args.product_mfr)

  # Report on some issues and information
  report = {
    ISSUE_NO_METADATA: [],
    ISSUE_NO_METADATA_FILE: [],
    ISSUE_METADATA_FILE_INCOMPLETE: [],
    ISSUE_UNKNOWN_SECURITY_TAG_TYPE: [],
    ISSUE_INSTALLED_FILE_NOT_EXIST: [],
    INFO_METADATA_FOUND_FOR_PACKAGE: [],
  }

  # Scan the metadata in CSV file and create the corresponding package and file records in SPDX
  product_files = []
  package_ids = []
  package_records = []
  rels_file_gen_from = []
  with open(args.metadata, newline='') as sbom_metadata_file:
    reader = csv.DictReader(sbom_metadata_file)
    for installed_file_metadata in reader:
      installed_file = installed_file_metadata['installed_file']
      module_path = installed_file_metadata['module_path']
      product_copy_files = installed_file_metadata['product_copy_files']
      kernel_module_copy_files = installed_file_metadata['kernel_module_copy_files']

      if not installed_file_has_metadata(installed_file_metadata, report):
        continue
      if not os.path.isfile(installed_file):
        report[ISSUE_INSTALLED_FILE_NOT_EXIST].append(installed_file)
        continue

      file_id = new_file_id(installed_file)
      product_files.append(new_file_record(file_id, installed_file, checksum(installed_file)))

      if is_source_package(installed_file_metadata) or is_prebuilt_package(installed_file_metadata):
        metadata_file_path = get_metadata_file_path(installed_file_metadata)
        report_metadata_file(metadata_file_path, installed_file_metadata, report)

        # File from source fork packages or prebuilt fork packages
        external_doc_ref, pkgs, rels = get_sbom_fragments(installed_file_metadata, metadata_file_path)
        if len(pkgs) > 0:
          if external_doc_ref and external_doc_ref not in doc_header[EXTERNAL_DOCUMENT_REF]:
            doc_header[EXTERNAL_DOCUMENT_REF].append(external_doc_ref)
          for p in pkgs:
            if not p[SPDXID] in package_ids:
              package_ids.append(p[SPDXID])
              package_records.append(p)
          for rel in rels:
            if not rel in package_records:
              package_records.append(rel)
          fork_package_id = pkgs[0][SPDXID]  # The first package should be the source/prebuilt fork package
          rels_file_gen_from.append(new_relationship_record(file_id, REL_GENERATED_FROM, fork_package_id))
      elif module_path or installed_file_metadata['is_platform_generated']:
        # File from PLATFORM package
        rels_file_gen_from.append(new_relationship_record(file_id, REL_GENERATED_FROM, platform_package_id))
      elif product_copy_files:
        # Format of product_copy_files: <source path>:<dest path>
        src_path = product_copy_files.split(':')[0]
        # So far product_copy_files are copied from directory system, kernel, hardware, frameworks and device,
        # so process them as files from PLATFORM package
        rels_file_gen_from.append(new_relationship_record(file_id, REL_GENERATED_FROM, platform_package_id))
      elif installed_file.endswith('.fsv_meta'):
        # See build/make/core/Makefile:2988
        rels_file_gen_from.append(new_relationship_record(file_id, REL_GENERATED_FROM, platform_package_id))
      elif kernel_module_copy_files.startswith('ANDROID-GEN'):
        # For the four files generated for _dlkm, _ramdisk partitions
        # See build/make/core/Makefile:323
        rels_file_gen_from.append(new_relationship_record(file_id, REL_GENERATED_FROM, platform_package_id))

  product_package[PACKAGE_VERIFICATION_CODE] = generate_package_verification_code(product_files)

  all_records = [
      doc_header,
      product_package,
      new_relationship_record(doc_id, REL_DESCRIBES, product_package_id),
  ]
  all_records += product_files
  all_records.append(platform_package)
  all_records += package_records
  rels_file_gen_from.sort(key=sort_rels)
  all_records += rels_file_gen_from

  # Save SBOM records to output file
  doc_header[CREATED] = datetime.datetime.now(tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
  write_tagvalue_sbom(all_records)
  if args.json:
    write_json_sbom(all_records, product_package_id)

  save_report(report)


if __name__ == '__main__':
  main()
