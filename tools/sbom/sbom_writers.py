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
Serialize objects defined in package sbom_data to SPDX format: tagvalue, JSON.
"""

import json
import sbom_data

SPDX_VER = 'SPDX-2.3'
DATA_LIC = 'CC0-1.0'


class Tags:
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

  # License
  LICENSE_ID = 'LicenseID'
  LICENSE_NAME = 'LicenseName'
  LICENSE_EXTRACTED_TEXT = 'ExtractedText'


class TagValueWriter:
  @staticmethod
  def marshal_doc_headers(sbom_doc):
    headers = [
      f'{Tags.SPDX_VERSION}: {SPDX_VER}',
      f'{Tags.DATA_LICENSE}: {DATA_LIC}',
      f'{Tags.SPDXID}: {sbom_doc.id}',
      f'{Tags.DOCUMENT_NAME}: {sbom_doc.name}',
      f'{Tags.DOCUMENT_NAMESPACE}: {sbom_doc.namespace}',
    ]
    for creator in sbom_doc.creators:
      headers.append(f'{Tags.CREATOR}: {creator}')
    headers.append(f'{Tags.CREATED}: {sbom_doc.created}')
    for doc_ref in sbom_doc.external_refs:
      headers.append(
        f'{Tags.EXTERNAL_DOCUMENT_REF}: {doc_ref.id} {doc_ref.uri} {doc_ref.checksum}')
    headers.append('')
    return headers

  @staticmethod
  def marshal_package(sbom_doc, package, fragment):
    download_location = sbom_data.VALUE_NOASSERTION
    if package.download_location:
      download_location = package.download_location
    tagvalues = [
      f'{Tags.PACKAGE_NAME}: {package.name}',
      f'{Tags.SPDXID}: {package.id}',
      f'{Tags.PACKAGE_DOWNLOAD_LOCATION}: {download_location}',
      f'{Tags.FILES_ANALYZED}: {str(package.files_analyzed).lower()}',
    ]
    if package.version:
      tagvalues.append(f'{Tags.PACKAGE_VERSION}: {package.version}')
    if package.supplier:
      tagvalues.append(f'{Tags.PACKAGE_SUPPLIER}: {package.supplier}')

    license = sbom_data.VALUE_NOASSERTION
    if package.declared_license_ids:
      license = ' OR '.join(package.declared_license_ids)
    tagvalues.append(f'{Tags.PACKAGE_LICENSE_DECLARED}: {license}')

    if package.verification_code:
      tagvalues.append(f'{Tags.PACKAGE_VERIFICATION_CODE}: {package.verification_code}')
    if package.external_refs:
      for external_ref in package.external_refs:
        tagvalues.append(
          f'{Tags.PACKAGE_EXTERNAL_REF}: {external_ref.category} {external_ref.type} {external_ref.locator}')

    tagvalues.append('')

    if package.id == sbom_doc.describes and not fragment:
      tagvalues.append(
          f'{Tags.RELATIONSHIP}: {sbom_doc.id} {sbom_data.RelationshipType.DESCRIBES} {sbom_doc.describes}')
      tagvalues.append('')

    for file in sbom_doc.files:
      if file.id in package.file_ids:
        tagvalues += TagValueWriter.marshal_file(file)

    return tagvalues

  @staticmethod
  def marshal_packages(sbom_doc, fragment):
    tagvalues = []
    marshaled_relationships = []
    i = 0
    packages = sbom_doc.packages
    while i < len(packages):
      if (i + 1 < len(packages)
          and packages[i].id.startswith('SPDXRef-SOURCE-')
          and packages[i + 1].id.startswith('SPDXRef-UPSTREAM-')):
        # Output SOURCE, UPSTREAM packages and their VARIANT_OF relationship together, so they are close to each other
        # in SBOMs in tagvalue format.
        tagvalues += TagValueWriter.marshal_package(sbom_doc, packages[i], fragment)
        tagvalues += TagValueWriter.marshal_package(sbom_doc, packages[i + 1], fragment)
        rel = next((r for r in sbom_doc.relationships if
                    r.id1 == packages[i].id and
                    r.id2 == packages[i + 1].id and
                    r.relationship == sbom_data.RelationshipType.VARIANT_OF), None)
        if rel:
          marshaled_relationships.append(rel)
          tagvalues.append(TagValueWriter.marshal_relationship(rel))
          tagvalues.append('')

        i += 2
      else:
        tagvalues += TagValueWriter.marshal_package(sbom_doc, packages[i], fragment)
        i += 1

    return tagvalues, marshaled_relationships

  @staticmethod
  def marshal_file(file):
    tagvalues = [
      f'{Tags.FILE_NAME}: {file.name}',
      f'{Tags.SPDXID}: {file.id}',
      f'{Tags.FILE_CHECKSUM}: {file.checksum}',
    ]
    license = sbom_data.VALUE_NOASSERTION
    if file.concluded_license_ids:
      license = ' OR '.join(file.concluded_license_ids)
    tagvalues.append(f'{Tags.FILE_LICENSE_CONCLUDED}: {license}')
    tagvalues.append('')

    return tagvalues

  @staticmethod
  def marshal_files(sbom_doc, fragment):
    tagvalues = []
    files_in_packages = []
    for package in sbom_doc.packages:
      files_in_packages += package.file_ids
    for file in sbom_doc.files:
      if file.id in files_in_packages:
        continue
      tagvalues += TagValueWriter.marshal_file(file)
      if file.id == sbom_doc.describes and not fragment:
        # Fragment is not a full SBOM document so the relationship DESCRIBES is not applicable.
        tagvalues.append(
            f'{Tags.RELATIONSHIP}: {sbom_doc.id} {sbom_data.RelationshipType.DESCRIBES} {sbom_doc.describes}')
        tagvalues.append('')
    return tagvalues

  @staticmethod
  def marshal_relationship(rel):
    return f'{Tags.RELATIONSHIP}: {rel.id1} {rel.relationship} {rel.id2}'

  @staticmethod
  def marshal_relationships(sbom_doc, marshaled_rels):
    tagvalues = []
    sorted_rels = sorted(sbom_doc.relationships, key=lambda r: r.id2 + r.id1)
    for rel in sorted_rels:
      if any(r.id1 == rel.id1 and r.id2 == rel.id2 and r.relationship == rel.relationship
             for r in marshaled_rels):
        continue
      tagvalues.append(TagValueWriter.marshal_relationship(rel))
    tagvalues.append('')
    return tagvalues

  @staticmethod
  def marshal_license(license):
    tagvalues = []
    tagvalues.append(f'{Tags.LICENSE_ID}: {license.id}')
    tagvalues.append(f'{Tags.LICENSE_NAME}: {license.name}')
    tagvalues.append(f'{Tags.LICENSE_EXTRACTED_TEXT}: <text>{license.text}</text>')
    return tagvalues

  @staticmethod
  def marshal_licenses(sbom_doc):
    tagvalues = []
    for license in sbom_doc.licenses:
      tagvalues += TagValueWriter.marshal_license(license)
      tagvalues.append('')
    return tagvalues

  @staticmethod
  def write(sbom_doc, file, fragment=False):
    content = []
    if not fragment:
      content += TagValueWriter.marshal_doc_headers(sbom_doc)
    content += TagValueWriter.marshal_files(sbom_doc, fragment)
    tagvalues, marshaled_relationships = TagValueWriter.marshal_packages(sbom_doc, fragment)
    content += tagvalues
    content += TagValueWriter.marshal_relationships(sbom_doc, marshaled_relationships)
    content += TagValueWriter.marshal_licenses(sbom_doc)
    file.write('\n'.join(content))


class PropNames:
  # Common
  SPDXID = 'SPDXID'
  SPDX_VERSION = 'spdxVersion'
  DATA_LICENSE = 'dataLicense'
  NAME = 'name'
  DOCUMENT_NAMESPACE = 'documentNamespace'
  CREATION_INFO = 'creationInfo'
  CREATORS = 'creators'
  CREATED = 'created'
  EXTERNAL_DOCUMENT_REF = 'externalDocumentRefs'
  DOCUMENT_DESCRIBES = 'documentDescribes'
  EXTERNAL_DOCUMENT_ID = 'externalDocumentId'
  EXTERNAL_DOCUMENT_URI = 'spdxDocument'
  EXTERNAL_DOCUMENT_CHECKSUM = 'checksum'
  ALGORITHM = 'algorithm'
  CHECKSUM_VALUE = 'checksumValue'

  # Package
  PACKAGES = 'packages'
  PACKAGE_DOWNLOAD_LOCATION = 'downloadLocation'
  PACKAGE_VERSION = 'versionInfo'
  PACKAGE_SUPPLIER = 'supplier'
  FILES_ANALYZED = 'filesAnalyzed'
  PACKAGE_VERIFICATION_CODE = 'packageVerificationCode'
  PACKAGE_VERIFICATION_CODE_VALUE = 'packageVerificationCodeValue'
  PACKAGE_EXTERNAL_REFS = 'externalRefs'
  PACKAGE_EXTERNAL_REF_CATEGORY = 'referenceCategory'
  PACKAGE_EXTERNAL_REF_TYPE = 'referenceType'
  PACKAGE_EXTERNAL_REF_LOCATOR = 'referenceLocator'
  PACKAGE_HAS_FILES = 'hasFiles'
  PACKAGE_LICENSE_DECLARED = 'licenseDeclared'

  # File
  FILES = 'files'
  FILE_NAME = 'fileName'
  FILE_CHECKSUMS = 'checksums'
  FILE_LICENSE_CONCLUDED = 'licenseConcluded'

  # Relationship
  RELATIONSHIPS = 'relationships'
  REL_ELEMENT_ID = 'spdxElementId'
  REL_RELATED_ELEMENT_ID = 'relatedSpdxElement'
  REL_TYPE = 'relationshipType'

  # License
  LICENSES = 'hasExtractedLicensingInfos'
  LICENSE_ID = 'licenseId'
  LICENSE_NAME = 'name'
  LICENSE_EXTRACTED_TEXT = 'extractedText'


class JSONWriter:
  @staticmethod
  def marshal_doc_headers(sbom_doc):
    headers = {
      PropNames.SPDX_VERSION: SPDX_VER,
      PropNames.DATA_LICENSE: DATA_LIC,
      PropNames.SPDXID: sbom_doc.id,
      PropNames.NAME: sbom_doc.name,
      PropNames.DOCUMENT_NAMESPACE: sbom_doc.namespace,
      PropNames.CREATION_INFO: {}
    }
    creators = [creator for creator in sbom_doc.creators]
    headers[PropNames.CREATION_INFO][PropNames.CREATORS] = creators
    headers[PropNames.CREATION_INFO][PropNames.CREATED] = sbom_doc.created
    external_refs = []
    for doc_ref in sbom_doc.external_refs:
      checksum = doc_ref.checksum.split(': ')
      external_refs.append({
        PropNames.EXTERNAL_DOCUMENT_ID: f'{doc_ref.id}',
        PropNames.EXTERNAL_DOCUMENT_URI: doc_ref.uri,
        PropNames.EXTERNAL_DOCUMENT_CHECKSUM: {
          PropNames.ALGORITHM: checksum[0],
          PropNames.CHECKSUM_VALUE: checksum[1]
        }
      })
    if external_refs:
      headers[PropNames.EXTERNAL_DOCUMENT_REF] = external_refs
    headers[PropNames.DOCUMENT_DESCRIBES] = [sbom_doc.describes]

    return headers

  @staticmethod
  def marshal_packages(sbom_doc):
    packages = []
    for p in sbom_doc.packages:
      package = {
        PropNames.NAME: p.name,
        PropNames.SPDXID: p.id,
        PropNames.PACKAGE_DOWNLOAD_LOCATION: p.download_location if p.download_location else sbom_data.VALUE_NOASSERTION,
        PropNames.FILES_ANALYZED: p.files_analyzed
      }
      if p.version:
        package[PropNames.PACKAGE_VERSION] = p.version
      if p.supplier:
        package[PropNames.PACKAGE_SUPPLIER] = p.supplier
      package[PropNames.PACKAGE_LICENSE_DECLARED] = sbom_data.VALUE_NOASSERTION
      if p.declared_license_ids:
        package[PropNames.PACKAGE_LICENSE_DECLARED] = ' OR '.join(p.declared_license_ids)
      if p.verification_code:
        package[PropNames.PACKAGE_VERIFICATION_CODE] = {
          PropNames.PACKAGE_VERIFICATION_CODE_VALUE: p.verification_code
        }
      if p.external_refs:
        package[PropNames.PACKAGE_EXTERNAL_REFS] = []
        for ref in p.external_refs:
          ext_ref = {
            PropNames.PACKAGE_EXTERNAL_REF_CATEGORY: ref.category,
            PropNames.PACKAGE_EXTERNAL_REF_TYPE: ref.type,
            PropNames.PACKAGE_EXTERNAL_REF_LOCATOR: ref.locator,
          }
          package[PropNames.PACKAGE_EXTERNAL_REFS].append(ext_ref)
      if p.file_ids:
        package[PropNames.PACKAGE_HAS_FILES] = []
        for file_id in p.file_ids:
          package[PropNames.PACKAGE_HAS_FILES].append(file_id)

      packages.append(package)

    return {PropNames.PACKAGES: packages}

  @staticmethod
  def marshal_files(sbom_doc):
    files = []
    for f in sbom_doc.files:
      file = {
        PropNames.FILE_NAME: f.name,
        PropNames.SPDXID: f.id
      }
      checksum = f.checksum.split(': ')
      file[PropNames.FILE_CHECKSUMS] = [{
        PropNames.ALGORITHM: checksum[0],
        PropNames.CHECKSUM_VALUE: checksum[1],
      }]
      file[PropNames.FILE_LICENSE_CONCLUDED] = sbom_data.VALUE_NOASSERTION
      if f.concluded_license_ids:
        file[PropNames.FILE_LICENSE_CONCLUDED] = ' OR '.join(f.concluded_license_ids)
      files.append(file)
    return {PropNames.FILES: files}

  @staticmethod
  def marshal_relationships(sbom_doc):
    relationships = []
    sorted_rels = sorted(sbom_doc.relationships, key=lambda r: r.relationship + r.id2 + r.id1)
    for r in sorted_rels:
      rel = {
        PropNames.REL_ELEMENT_ID: r.id1,
        PropNames.REL_RELATED_ELEMENT_ID: r.id2,
        PropNames.REL_TYPE: r.relationship,
      }
      relationships.append(rel)

    return {PropNames.RELATIONSHIPS: relationships}

  @staticmethod
  def marshal_licenses(sbom_doc):
    licenses = []
    for l in sbom_doc.licenses:
      licenses.append({
          PropNames.LICENSE_ID: l.id,
          PropNames.LICENSE_NAME: l.name,
          PropNames.LICENSE_EXTRACTED_TEXT: f'<text>{l.text}</text>'
      })
    return {PropNames.LICENSES: licenses}

  @staticmethod
  def write(sbom_doc, file):
    doc = {}
    doc.update(JSONWriter.marshal_doc_headers(sbom_doc))
    doc.update(JSONWriter.marshal_packages(sbom_doc))
    doc.update(JSONWriter.marshal_files(sbom_doc))
    doc.update(JSONWriter.marshal_relationships(sbom_doc))
    doc.update(JSONWriter.marshal_licenses(sbom_doc))
    file.write(json.dumps(doc, indent=4))
