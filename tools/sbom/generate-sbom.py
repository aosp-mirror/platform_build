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
                   --build_version $(cat out/target/product/vsoc_x86_64/build_fingerprint.txt) \
                   --product_mfr=Google
"""

import argparse
import csv
import datetime
import google.protobuf.text_format as text_format
import hashlib
import os
import metadata_file_pb2
import sbom_data
import sbom_writers


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

SOONG_PREBUILT_MODULE_TYPES = [
  'android_app_import',
  'android_library_import',
  'cc_prebuilt_binary',
  'cc_prebuilt_library',
  'cc_prebuilt_library_headers',
  'cc_prebuilt_library_shared',
  'cc_prebuilt_library_static',
  'cc_prebuilt_object',
  'dex_import',
  'java_import',
  'java_sdk_library_import',
  'java_system_modules_import',
  'libclang_rt_prebuilt_library_static',
  'libclang_rt_prebuilt_library_shared',
  'llvm_prebuilt_library_static',
  'ndk_prebuilt_object',
  'ndk_prebuilt_shared_stl',
  'nkd_prebuilt_static_stl',
  'prebuilt_apex',
  'prebuilt_bootclasspath_fragment',
  'prebuilt_dsp',
  'prebuilt_firmware',
  'prebuilt_kernel_modules',
  'prebuilt_rfsa',
  'prebuilt_root',
  'rust_prebuilt_dylib',
  'rust_prebuilt_library',
  'rust_prebuilt_rlib',
  'vndk_prebuilt_shared',
]

THIRD_PARTY_IDENTIFIER_TYPES = [
    # Types defined in metadata_file.proto
    'Git',
    'SVN',
    'Hg',
    'Darcs',
    'VCS',
    'Archive',
    'PrebuiltByAlphabet',
    'LocalSource',
    'Other',
    # OSV ecosystems defined at https://ossf.github.io/osv-schema/#affectedpackage-field.
    'Go',
    'npm',
    'OSS-Fuzz',
    'PyPI',
    'RubyGems',
    'crates.io',
    'Hackage',
    'GHC',
    'Packagist',
    'Maven',
    'NuGet',
    'Linux',
    'Debian',
    'Alpine',
    'Hex',
    'Android',
    'GitHub Actions',
    'Pub',
    'ConanCenter',
    'Rocky Linux',
    'AlmaLinux',
    'Bitnami',
    'Photon OS',
    'CRAN',
    'Bioconductor',
    'SwiftURL'
]


def get_args():
  parser = argparse.ArgumentParser()
  parser.add_argument('-v', '--verbose', action='store_true', default=False, help='Print more information.')
  parser.add_argument('--output_file', required=True, help='The generated SBOM file in SPDX format.')
  parser.add_argument('--metadata', required=True, help='The SBOM metadata file path.')
  parser.add_argument('--build_version', required=True, help='The build version.')
  parser.add_argument('--product_mfr', required=True, help='The product manufacturer.')
  parser.add_argument('--module_name', help='The module name. If specified, the generated SBOM is for the module.')
  parser.add_argument('--json', action='store_true', default=False, help='Generated SBOM file in SPDX JSON format')
  parser.add_argument('--unbundled_apk', action='store_true', default=False, help='Generate SBOM for unbundled APKs')
  parser.add_argument('--unbundled_apex', action='store_true', default=False, help='Generate SBOM for unbundled APEXs')

  return parser.parse_args()


def log(*info):
  if args.verbose:
    for i in info:
      print(i)


def new_package_id(package_name, type):
  return f'SPDXRef-{type}-{sbom_data.encode_for_spdxid(package_name)}'


def new_file_id(file_path):
  return f'SPDXRef-{sbom_data.encode_for_spdxid(file_path)}'


def checksum(file_path):
  h = hashlib.sha1()
  if os.path.islink(file_path):
    h.update(os.readlink(file_path).encode('utf-8'))
  else:
    with open(file_path, 'rb') as f:
      h.update(f.read())
  return f'SHA1: {h.hexdigest()}'


def is_soong_prebuilt_module(file_metadata):
  return (file_metadata['soong_module_type'] and
          file_metadata['soong_module_type'] in SOONG_PREBUILT_MODULE_TYPES)


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
  """Return source package info exists in its METADATA file, currently including name, security tag
  and external SBOM reference.

  See go/android-spdx and go/android-sbom-gen for more details.
  """
  if not metadata_file_path:
    return file_metadata['module_path'], []

  metadata_proto = metadata_file_protos[metadata_file_path]
  external_refs = []
  for tag in metadata_proto.third_party.security.tag:
    if tag.lower().startswith((NVD_CPE23 + 'cpe:2.3:').lower()):
      external_refs.append(
        sbom_data.PackageExternalRef(category=sbom_data.PackageExternalRefCategory.SECURITY,
                                     type=sbom_data.PackageExternalRefType.cpe23Type,
                                     locator=tag.removeprefix(NVD_CPE23)))
    elif tag.lower().startswith((NVD_CPE23 + 'cpe:/').lower()):
      external_refs.append(
        sbom_data.PackageExternalRef(category=sbom_data.PackageExternalRefCategory.SECURITY,
                                     type=sbom_data.PackageExternalRefType.cpe22Type,
                                     locator=tag.removeprefix(NVD_CPE23)))

  if metadata_proto.name:
    return metadata_proto.name, external_refs
  else:
    return os.path.basename(metadata_file_path), external_refs  # return the directory name only as package name


def get_prebuilt_package_name(file_metadata, metadata_file_path):
  """Return name of a prebuilt package, which can be from the METADATA file, metadata file path,
  module path or kernel module's source path if the installed file is a kernel module.

  See go/android-spdx and go/android-sbom-gen for more details.
  """
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
  """Search for METADATA file of a package and return its path."""
  metadata_path = ''
  if file_metadata['module_path']:
    metadata_path = file_metadata['module_path']
  elif file_metadata['kernel_module_copy_files']:
    metadata_path = os.path.dirname(file_metadata['kernel_module_copy_files'].split(':')[0])

  while metadata_path and not os.path.exists(metadata_path + '/METADATA'):
    metadata_path = os.path.dirname(metadata_path)

  return metadata_path


def get_package_version(metadata_file_path):
  """Return a package's version in its METADATA file."""
  if not metadata_file_path:
    return None
  metadata_proto = metadata_file_protos[metadata_file_path]
  return metadata_proto.third_party.version


def get_package_homepage(metadata_file_path):
  """Return a package's homepage URL in its METADATA file."""
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
  """Return a package's code repository URL in its METADATA file."""
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
  """Return SPDX fragment of source/prebuilt packages, which usually contains a SOURCE/PREBUILT
  package, a UPSTREAM package and an external SBOM document reference if sbom_ref defined in its
  METADATA file.

  See go/android-spdx and go/android-sbom-gen for more details.
  """
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
    source_package = sbom_data.Package(id=source_package_id, name=name, version=args.build_version,
                                       download_location=sbom_data.VALUE_NONE,
                                       supplier='Organization: ' + args.product_mfr,
                                       external_refs=external_refs)

    upstream_package_id = new_package_id(name, PKG_UPSTREAM)
    upstream_package = sbom_data.Package(id=upstream_package_id, name=name, version=version,
                                         supplier=('Organization: ' + homepage) if homepage else sbom_data.VALUE_NOASSERTION,
                                         download_location=download_location)
    packages += [source_package, upstream_package]
    relationships.append(sbom_data.Relationship(id1=source_package_id,
                                                relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                id2=upstream_package_id))
  elif is_prebuilt_package(installed_file_metadata):
    # Prebuilt fork packages
    name = get_prebuilt_package_name(installed_file_metadata, metadata_file_path)
    prebuilt_package_id = new_package_id(name, PKG_PREBUILT)
    prebuilt_package = sbom_data.Package(id=prebuilt_package_id,
                                         name=name,
                                         download_location=sbom_data.VALUE_NONE,
                                         version=version if version else args.build_version,
                                         supplier='Organization: ' + args.product_mfr)

    upstream_package_id = new_package_id(name, PKG_UPSTREAM)
    upstream_package = sbom_data.Package(id=upstream_package_id, name=name, version = version,
                                         supplier=('Organization: ' + homepage) if homepage else sbom_data.VALUE_NOASSERTION,
                                         download_location=download_location)
    packages += [prebuilt_package, upstream_package]
    relationships.append(sbom_data.Relationship(id1=prebuilt_package_id,
                                                relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                id2=upstream_package_id))

  if metadata_file_path:
    metadata_proto = metadata_file_protos[metadata_file_path]
    if metadata_proto.third_party.WhichOneof('sbom') == 'sbom_ref':
      sbom_url = metadata_proto.third_party.sbom_ref.url
      sbom_checksum = metadata_proto.third_party.sbom_ref.checksum
      upstream_element_id = metadata_proto.third_party.sbom_ref.element_id
      if sbom_url and sbom_checksum and upstream_element_id:
        doc_ref_id = f'DocumentRef-{PKG_UPSTREAM}-{sbom_data.encode_for_spdxid(name)}'
        external_doc_ref = sbom_data.DocumentExternalReference(id=doc_ref_id,
                                                               uri=sbom_url,
                                                               checksum=sbom_checksum)
        relationships.append(
          sbom_data.Relationship(id1=upstream_package_id,
                                 relationship=sbom_data.RelationshipType.VARIANT_OF,
                                 id2=doc_ref_id + ':' + upstream_element_id))

  return external_doc_ref, packages, relationships


def save_report(report_file_path, report):
  with open(report_file_path, 'w', encoding='utf-8') as report_file:
    for type, issues in report.items():
      report_file.write(type + '\n')
      for issue in issues:
        report_file.write('\t' + issue + '\n')
      report_file.write('\n')


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


# Validate identifiers in a package's METADATA.
# 1) Only known identifier type is allowed
# 2) Only one identifier's primary_source can be true
def validate_package_metadata(metadata_file_path, package_metadata):
  primary_source_found = False
  for identifier in package_metadata.third_party.identifier:
    if identifier.type not in THIRD_PARTY_IDENTIFIER_TYPES:
      sys.exit(f'Unknown value of third_party.identifier.type in {metadata_file_path}/METADATA: {identifier.type}.')
    if primary_source_found and identifier.primary_source:
      sys.exit(
        f'Field "primary_source" is set to true in multiple third_party.identifier in {metadata_file_path}/METADATA.')
    primary_source_found = identifier.primary_source


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

    validate_package_metadata(metadata_file_path, package_metadata)

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


def generate_sbom_for_unbundled_apk():
  with open(args.metadata, newline='') as sbom_metadata_file:
    reader = csv.DictReader(sbom_metadata_file)
    doc = sbom_data.Document(name=args.build_version,
                             namespace=f'https://www.google.com/sbom/spdx/android/{args.build_version}',
                             creators=['Organization: ' + args.product_mfr])
    for installed_file_metadata in reader:
      installed_file = installed_file_metadata['installed_file']
      if args.output_file != installed_file_metadata['build_output_path'] + '.spdx.json':
        continue

      module_path = installed_file_metadata['module_path']
      package_id = new_package_id(module_path, PKG_PREBUILT)
      package = sbom_data.Package(id=package_id,
                                  name=module_path,
                                  version=args.build_version,
                                  supplier='Organization: ' + args.product_mfr)
      file_id = new_file_id(installed_file)
      file = sbom_data.File(id=file_id,
                            name=installed_file,
                            checksum=checksum(installed_file_metadata['build_output_path']))
      relationship = sbom_data.Relationship(id1=file_id,
                                            relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                            id2=package_id)
      doc.add_package(package)
      doc.files.append(file)
      doc.describes = file_id
      doc.add_relationship(relationship)
      doc.created = datetime.datetime.now(tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
      break

  with open(args.output_file, 'w', encoding='utf-8') as file:
    sbom_writers.JSONWriter.write(doc, file)
  fragment_file = args.output_file.removesuffix('.spdx.json') + '-fragment.spdx'
  with open(fragment_file, 'w', encoding='utf-8') as file:
    sbom_writers.TagValueWriter.write(doc, file, fragment=True)


def main():
  global args
  args = get_args()
  log('Args:', vars(args))

  if args.unbundled_apk:
    generate_sbom_for_unbundled_apk()
    return

  global metadata_file_protos
  metadata_file_protos = {}

  product_package_id = sbom_data.SPDXID_PRODUCT
  product_package_name = sbom_data.PACKAGE_NAME_PRODUCT
  if args.module_name:
    # Build SBOM of a module so use the module name instead.
    product_package_id = f'SPDXRef-{sbom_data.encode_for_spdxid(args.module_name)}'
    product_package_name = args.module_name
  product_package = sbom_data.Package(id=product_package_id,
                                      name=product_package_name,
                                      download_location=sbom_data.VALUE_NONE,
                                      version=args.build_version,
                                      supplier='Organization: ' + args.product_mfr,
                                      files_analyzed=True)
  doc_name = args.build_version
  if args.module_name:
    doc_name = f'{args.build_version}/{args.module_name}'
  doc = sbom_data.Document(name=doc_name,
                           namespace=f'https://www.google.com/sbom/spdx/android/{doc_name}',
                           creators=['Organization: ' + args.product_mfr],
                           describes=product_package_id)
  if not args.unbundled_apex:
    doc.packages.append(product_package)

  doc.packages.append(sbom_data.Package(id=sbom_data.SPDXID_PLATFORM,
                                        name=sbom_data.PACKAGE_NAME_PLATFORM,
                                        download_location=sbom_data.VALUE_NONE,
                                        version=args.build_version,
                                        supplier='Organization: ' + args.product_mfr))

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
  with open(args.metadata, newline='') as sbom_metadata_file:
    reader = csv.DictReader(sbom_metadata_file)
    for installed_file_metadata in reader:
      installed_file = installed_file_metadata['installed_file']
      module_path = installed_file_metadata['module_path']
      product_copy_files = installed_file_metadata['product_copy_files']
      kernel_module_copy_files = installed_file_metadata['kernel_module_copy_files']
      build_output_path = installed_file_metadata['build_output_path']
      is_static_lib = installed_file_metadata['is_static_lib']

      if not installed_file_has_metadata(installed_file_metadata, report):
        continue
      if not is_static_lib and not (os.path.islink(build_output_path) or os.path.isfile(build_output_path)):
        # Ignore non-existing static library files for now since they are not shipped on devices.
        report[ISSUE_INSTALLED_FILE_NOT_EXIST].append(installed_file)
        continue

      file_id = new_file_id(installed_file)
      # TODO(b/285453664): Soong should report the information of statically linked libraries to Make.
      # This happens when a different sanitized version of static libraries is used in linking.
      # As a workaround, use the following SHA1 checksum for static libraries created by Soong, if .a files could not be
      # located correctly because Soong doesn't report the information to Make.
      sha1 = 'SHA1: da39a3ee5e6b4b0d3255bfef95601890afd80709'  # SHA1 of empty string
      if os.path.islink(build_output_path) or os.path.isfile(build_output_path):
        sha1 = checksum(build_output_path)
      doc.files.append(sbom_data.File(id=file_id,
                                      name=installed_file,
                                      checksum=sha1))

      if not is_static_lib:
        if not args.unbundled_apex:
          product_package.file_ids.append(file_id)
        elif len(doc.files) > 1:
            doc.add_relationship(sbom_data.Relationship(doc.files[0].id, sbom_data.RelationshipType.CONTAINS, file_id))

      if is_source_package(installed_file_metadata) or is_prebuilt_package(installed_file_metadata):
        metadata_file_path = get_metadata_file_path(installed_file_metadata)
        report_metadata_file(metadata_file_path, installed_file_metadata, report)

        # File from source fork packages or prebuilt fork packages
        external_doc_ref, pkgs, rels = get_sbom_fragments(installed_file_metadata, metadata_file_path)
        if len(pkgs) > 0:
          if external_doc_ref:
            doc.add_external_ref(external_doc_ref)
          for p in pkgs:
            doc.add_package(p)
          for rel in rels:
            doc.add_relationship(rel)
          fork_package_id = pkgs[0].id  # The first package should be the source/prebuilt fork package
          doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                      relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                      id2=fork_package_id))
      elif module_path or installed_file_metadata['is_platform_generated']:
        # File from PLATFORM package
        doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                    relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                    id2=sbom_data.SPDXID_PLATFORM))
      elif product_copy_files:
        # Format of product_copy_files: <source path>:<dest path>
        src_path = product_copy_files.split(':')[0]
        # So far product_copy_files are copied from directory system, kernel, hardware, frameworks and device,
        # so process them as files from PLATFORM package
        doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                    relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                    id2=sbom_data.SPDXID_PLATFORM))
      elif installed_file.endswith('.fsv_meta'):
        # See build/make/core/Makefile:2988
        doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                    relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                    id2=sbom_data.SPDXID_PLATFORM))
      elif kernel_module_copy_files.startswith('ANDROID-GEN'):
        # For the four files generated for _dlkm, _ramdisk partitions
        # See build/make/core/Makefile:323
        doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                    relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                    id2=sbom_data.SPDXID_PLATFORM))

      # Process static libraries and whole static libraries the installed file links to
      static_libs = installed_file_metadata['static_libraries']
      whole_static_libs = installed_file_metadata['whole_static_libraries']
      all_static_libs = (static_libs + ' ' + whole_static_libs).strip()
      if all_static_libs:
        for lib in all_static_libs.split(' '):
          doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                      relationship=sbom_data.RelationshipType.STATIC_LINK,
                                                      id2=new_file_id(lib + '.a')))

  if args.unbundled_apex:
    doc.describes = doc.files[0].id

  # Save SBOM records to output file
  doc.generate_packages_verification_code()
  doc.created = datetime.datetime.now(tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
  prefix = args.output_file
  if prefix.endswith('.spdx'):
    prefix = prefix.removesuffix('.spdx')
  elif prefix.endswith('.spdx.json'):
    prefix = prefix.removesuffix('.spdx.json')

  output_file = prefix + '.spdx'
  if args.unbundled_apex:
    output_file = prefix + '-fragment.spdx'
  with open(output_file, 'w', encoding="utf-8") as file:
    sbom_writers.TagValueWriter.write(doc, file, fragment=args.unbundled_apex)
  if args.json:
    with open(prefix + '.spdx.json', 'w', encoding="utf-8") as file:
      sbom_writers.JSONWriter.write(doc, file)

  save_report(prefix + '-gen-report.txt', report)


if __name__ == '__main__':
  main()
