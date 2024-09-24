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
Generate the SBOM of the current target product in SPDX format.
Usage example:
  gen_sbom.py --output_file out/soong/sbom/aosp_cf_x86_64_phone/sbom.spdx \
              --metadata out/soong/metadata/aosp_cf_x86_64_phone/metadata.db \
              --product_out out/target/vsoc_x86_64
              --soong_out out/soong
              --build_version $(cat out/target/product/vsoc_x86_64/build_fingerprint.txt) \
              --product_mfr=Google
"""

import argparse
import compliance_metadata
import datetime
import google.protobuf.text_format as text_format
import hashlib
import os
import pathlib
import queue
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
ISSUE_INSTALLED_FILE_NOT_EXIST = 'Non-existent installed files:'
ISSUE_NO_MODULE_FOUND_FOR_STATIC_DEP = 'No module found for static dependency files:'
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
  parser.add_argument('-d', '--debug', action='store_true', default=False, help='Debug mode')
  parser.add_argument('--output_file', required=True, help='The generated SBOM file in SPDX format.')
  parser.add_argument('--metadata', required=True, help='The metadata DB file path.')
  parser.add_argument('--product_out', required=True, help='The path of PRODUCT_OUT, e.g. out/target/product/vsoc_x86_64.')
  parser.add_argument('--soong_out', required=True, help='The path of Soong output directory, e.g. out/soong')
  parser.add_argument('--build_version', required=True, help='The build version.')
  parser.add_argument('--product_mfr', required=True, help='The product manufacturer.')
  parser.add_argument('--json', action='store_true', default=False, help='Generated SBOM file in SPDX JSON format')

  return parser.parse_args()


def log(*info):
  if args.verbose:
    for i in info:
      print(i)


def new_package_id(package_name, type):
  return f'SPDXRef-{type}-{sbom_data.encode_for_spdxid(package_name)}'


def new_file_id(file_path):
  return f'SPDXRef-{sbom_data.encode_for_spdxid(file_path)}'


def new_license_id(license_name):
  return f'LicenseRef-{sbom_data.encode_for_spdxid(license_name)}'


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


def get_license_text(license_files):
  license_text = ''
  for license_file in license_files:
    if args.debug:
      license_text += '#### Content from ' + license_file + '\n'
    else:
      license_text += pathlib.Path(license_file).read_text(errors='replace') + '\n\n'
  return license_text


def get_sbom_fragments(installed_file_metadata, metadata_file_path):
  """Return SPDX fragment of source/prebuilt packages, which usually contains a SOURCE/PREBUILT
  package, a UPSTREAM package and an external SBOM document reference if sbom_ref defined in its
  METADATA file.

  See go/android-spdx and go/android-sbom-gen for more details.
  """
  external_doc_ref = None
  packages = []
  relationships = []
  licenses = []

  # Info from METADATA file
  homepage = get_package_homepage(metadata_file_path)
  version = get_package_version(metadata_file_path)
  download_location = get_package_download_location(metadata_file_path)

  lics = db.get_package_licenses(installed_file_metadata['module_path'])
  if not lics:
    lics = db.get_package_licenses(metadata_file_path)

  if lics:
    for license_name, license_files in lics.items():
      if not license_files:
        continue
      license_id = new_license_id(license_name)
      if license_name not in licenses_text:
        licenses_text[license_name] = get_license_text(license_files.split(' '))
      licenses.append(sbom_data.License(id=license_id, name=license_name, text=licenses_text[license_name]))

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
                                         supplier=(
                                               'Organization: ' + homepage) if homepage else sbom_data.VALUE_NOASSERTION,
                                         download_location=download_location)
    packages += [source_package, upstream_package]
    relationships.append(sbom_data.Relationship(id1=source_package_id,
                                                relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                id2=upstream_package_id))

    for license in licenses:
      source_package.declared_license_ids.append(license.id)
      upstream_package.declared_license_ids.append(license.id)

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
    upstream_package = sbom_data.Package(id=upstream_package_id, name=name, version=version,
                                         supplier=(
                                               'Organization: ' + homepage) if homepage else sbom_data.VALUE_NOASSERTION,
                                         download_location=download_location)
    packages += [prebuilt_package, upstream_package]
    relationships.append(sbom_data.Relationship(id1=prebuilt_package_id,
                                                relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                id2=upstream_package_id))
    for license in licenses:
      prebuilt_package.declared_license_ids.append(license.id)
      upstream_package.declared_license_ids.append(license.id)

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

  return external_doc_ref, packages, relationships, licenses


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


# If a file is from a source fork or prebuilt fork package, add its package information to SBOM
def add_package_of_file(file_id, file_metadata, doc, report):
  metadata_file_path = get_metadata_file_path(file_metadata)
  report_metadata_file(metadata_file_path, file_metadata, report)

  external_doc_ref, pkgs, rels, licenses = get_sbom_fragments(file_metadata, metadata_file_path)
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
    for license in licenses:
      doc.add_license(license)


# Add STATIC_LINK relationship for static dependencies of a file
def add_static_deps_of_file(file_id, file_metadata, doc):
  if not file_metadata['static_dep_files'] and not file_metadata['whole_static_dep_files']:
    return
  static_dep_files = []
  if file_metadata['static_dep_files']:
    static_dep_files += file_metadata['static_dep_files'].split(' ')
  if file_metadata['whole_static_dep_files']:
    static_dep_files += file_metadata['whole_static_dep_files'].split(' ')

  for dep_file in static_dep_files:
    # Static libs are not shipped on devices, so names are derived from .intermediates paths.
    doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                relationship=sbom_data.RelationshipType.STATIC_LINK,
                                                id2=new_file_id(
                                                  dep_file.removeprefix(args.soong_out + '/.intermediates/'))))


def add_licenses_of_file(file_id, file_metadata, doc):
  lics = db.get_module_licenses(file_metadata.get('name', ''), file_metadata['module_path'])
  if lics:
    file = next(f for f in doc.files if file_id == f.id)
    for license_name, license_files in lics.items():
      if not license_files:
        continue
      license_id = new_license_id(license_name)
      file.concluded_license_ids.append(license_id)
      if license_name not in licenses_text:
        license_text = get_license_text(license_files.split(' '))
        licenses_text[license_name] = license_text

      doc.add_license(sbom_data.License(id=license_id, name=license_name, text=licenses_text[license_name]))


def get_all_transitive_static_dep_files_of_installed_files(installed_files_metadata, db, report):
  # Find all transitive static dep files of all installed files
  q = queue.Queue()
  for installed_file_metadata in installed_files_metadata:
    if installed_file_metadata['static_dep_files']:
      for f in installed_file_metadata['static_dep_files'].split(' '):
        q.put(f)
    if installed_file_metadata['whole_static_dep_files']:
      for f in installed_file_metadata['whole_static_dep_files'].split(' '):
        q.put(f)

  all_static_dep_files = {}
  while not q.empty():
    dep_file = q.get()
    if dep_file in all_static_dep_files:
      # It has been processed
      continue

    all_static_dep_files[dep_file] = True
    soong_module = db.get_soong_module_of_built_file(dep_file)
    if not soong_module:
      # This should not happen, add to report[ISSUE_NO_MODULE_FOUND_FOR_STATIC_DEP]
      report[ISSUE_NO_MODULE_FOUND_FOR_STATIC_DEP].append(f)
      continue

    if soong_module['static_dep_files']:
      for f in soong_module['static_dep_files'].split(' '):
        if f not in all_static_dep_files:
          q.put(f)
    if soong_module['whole_static_dep_files']:
      for f in soong_module['whole_static_dep_files'].split(' '):
        if f not in all_static_dep_files:
          q.put(f)

  return sorted(all_static_dep_files.keys())


def main():
  global args
  args = get_args()
  log('Args:', vars(args))

  global db
  db = compliance_metadata.MetadataDb(args.metadata)
  if args.debug:
    db.dump_debug_db(os.path.dirname(args.output_file) + '/compliance-metadata-debug.db')

  global metadata_file_protos
  metadata_file_protos = {}
  global licenses_text
  licenses_text = {}

  product_package_id = sbom_data.SPDXID_PRODUCT
  product_package_name = sbom_data.PACKAGE_NAME_PRODUCT
  product_package = sbom_data.Package(id=product_package_id,
                                      name=product_package_name,
                                      download_location=sbom_data.VALUE_NONE,
                                      version=args.build_version,
                                      supplier='Organization: ' + args.product_mfr,
                                      files_analyzed=True)
  doc_name = args.build_version
  doc = sbom_data.Document(name=doc_name,
                           namespace=f'https://www.google.com/sbom/spdx/android/{doc_name}',
                           creators=['Organization: ' + args.product_mfr],
                           describes=product_package_id)

  doc.packages.append(product_package)
  doc.packages.append(sbom_data.Package(id=sbom_data.SPDXID_PLATFORM,
                                        name=sbom_data.PACKAGE_NAME_PLATFORM,
                                        download_location=sbom_data.VALUE_NONE,
                                        version=args.build_version,
                                        supplier='Organization: ' + args.product_mfr,
                                        declared_license_ids=[sbom_data.SPDXID_LICENSE_APACHE]))

  # Report on some issues and information
  report = {
      ISSUE_NO_METADATA: [],
      ISSUE_NO_METADATA_FILE: [],
      ISSUE_METADATA_FILE_INCOMPLETE: [],
      ISSUE_UNKNOWN_SECURITY_TAG_TYPE: [],
      ISSUE_INSTALLED_FILE_NOT_EXIST: [],
      ISSUE_NO_MODULE_FOUND_FOR_STATIC_DEP: [],
      INFO_METADATA_FOUND_FOR_PACKAGE: [],
  }

  # Get installed files and corresponding make modules' metadata if an installed file is from a make module.
  installed_files_metadata = db.get_installed_files()

  # Find which Soong module an installed file is from and merge metadata from Make and Soong
  for installed_file_metadata in installed_files_metadata:
    soong_module = db.get_soong_module_of_installed_file(installed_file_metadata['installed_file'])
    if soong_module:
      # Merge soong metadata to make metadata
      installed_file_metadata.update(soong_module)
    else:
      # For make modules soong_module_type should be empty
      installed_file_metadata['soong_module_type'] = ''
      installed_file_metadata['static_dep_files'] = ''
      installed_file_metadata['whole_static_dep_files'] = ''

  # Scan the metadata and create the corresponding package and file records in SPDX
  for installed_file_metadata in installed_files_metadata:
    installed_file = installed_file_metadata['installed_file']
    module_path = installed_file_metadata['module_path']
    product_copy_files = installed_file_metadata['product_copy_files']
    kernel_module_copy_files = installed_file_metadata['kernel_module_copy_files']
    build_output_path = installed_file
    installed_file = installed_file.removeprefix(args.product_out)

    if not installed_file_has_metadata(installed_file_metadata, report):
      continue
    if not (os.path.islink(build_output_path) or os.path.isfile(build_output_path)):
      report[ISSUE_INSTALLED_FILE_NOT_EXIST].append(installed_file)
      continue

    file_id = new_file_id(installed_file)
    sha1 = checksum(build_output_path)
    f = sbom_data.File(id=file_id, name=installed_file, checksum=sha1)
    doc.files.append(f)
    product_package.file_ids.append(file_id)

    if is_source_package(installed_file_metadata) or is_prebuilt_package(installed_file_metadata):
      add_package_of_file(file_id, installed_file_metadata, doc, report)

    elif module_path or installed_file_metadata['is_platform_generated']:
      # File from PLATFORM package
      doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                  relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                  id2=sbom_data.SPDXID_PLATFORM))
      if installed_file_metadata['is_platform_generated']:
        f.concluded_license_ids = [sbom_data.SPDXID_LICENSE_APACHE]

    elif product_copy_files:
      # Format of product_copy_files: <source path>:<dest path>
      src_path = product_copy_files.split(':')[0]
      # So far product_copy_files are copied from directory system, kernel, hardware, frameworks and device,
      # so process them as files from PLATFORM package
      doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                  relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                  id2=sbom_data.SPDXID_PLATFORM))
      if installed_file_metadata['license_text']:
        if installed_file_metadata['license_text'] == 'build/soong/licenses/LICENSE':
          f.concluded_license_ids = [sbom_data.SPDXID_LICENSE_APACHE]

    elif installed_file.endswith('.fsv_meta'):
      doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                  relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                  id2=sbom_data.SPDXID_PLATFORM))
      f.concluded_license_ids = [sbom_data.SPDXID_LICENSE_APACHE]

    elif kernel_module_copy_files.startswith('ANDROID-GEN'):
      # For the four files generated for _dlkm, _ramdisk partitions
      doc.add_relationship(sbom_data.Relationship(id1=file_id,
                                                  relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                  id2=sbom_data.SPDXID_PLATFORM))

    # Process static dependencies of the installed file
    add_static_deps_of_file(file_id, installed_file_metadata, doc)

    # Add licenses of the installed file
    add_licenses_of_file(file_id, installed_file_metadata, doc)

  # Add all static library files to SBOM
  for dep_file in get_all_transitive_static_dep_files_of_installed_files(installed_files_metadata, db, report):
    filepath = dep_file.removeprefix(args.soong_out + '/.intermediates/')
    file_id = new_file_id(filepath)
    # SHA1 of empty string. Sometimes .a files might not be built.
    sha1 = 'SHA1: da39a3ee5e6b4b0d3255bfef95601890afd80709'
    if os.path.islink(dep_file) or os.path.isfile(dep_file):
      sha1 = checksum(dep_file)
    doc.files.append(sbom_data.File(id=file_id,
                                    name=filepath,
                                    checksum=sha1))
    file_metadata = {
        'installed_file': dep_file,
        'is_prebuilt_make_module': False
    }
    file_metadata.update(db.get_soong_module_of_built_file(dep_file))
    add_package_of_file(file_id, file_metadata, doc, report)

    # Add relationships for static deps of static libraries
    add_static_deps_of_file(file_id, file_metadata, doc)

    # Add licenses of the static lib
    add_licenses_of_file(file_id, file_metadata, doc)

  # Save SBOM records to output file
  doc.generate_packages_verification_code()
  doc.created = datetime.datetime.now(tz=datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
  prefix = args.output_file
  if prefix.endswith('.spdx'):
    prefix = prefix.removesuffix('.spdx')
  elif prefix.endswith('.spdx.json'):
    prefix = prefix.removesuffix('.spdx.json')

  output_file = prefix + '.spdx'
  with open(output_file, 'w', encoding="utf-8") as file:
    sbom_writers.TagValueWriter.write(doc, file)
  if args.json:
    with open(prefix + '.spdx.json', 'w', encoding="utf-8") as file:
      sbom_writers.JSONWriter.write(doc, file)

  save_report(prefix + '-gen-report.txt', report)


if __name__ == '__main__':
  main()
