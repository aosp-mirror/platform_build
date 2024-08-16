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
Define data classes that model SBOMs defined by SPDX. The data classes could be
written out to different formats (tagvalue, JSON, etc) of SPDX with corresponding
writer utilities.

Rrefer to SPDX 2.3 spec: https://spdx.github.io/spdx-spec/v2.3/ and go/android-spdx for details of
fields in each data class.
"""

from dataclasses import dataclass, field
from typing import List
import hashlib

SPDXID_DOC = 'SPDXRef-DOCUMENT'
SPDXID_PRODUCT = 'SPDXRef-PRODUCT'
SPDXID_PLATFORM = 'SPDXRef-PLATFORM'
SPDXID_LICENSE_APACHE = 'LicenseRef-Android-Apache-2.0'

PACKAGE_NAME_PRODUCT = 'PRODUCT'
PACKAGE_NAME_PLATFORM = 'PLATFORM'

VALUE_NOASSERTION = 'NOASSERTION'
VALUE_NONE = 'NONE'


class PackageExternalRefCategory:
  SECURITY = 'SECURITY'
  PACKAGE_MANAGER = 'PACKAGE-MANAGER'
  PERSISTENT_ID = 'PERSISTENT-ID'
  OTHER = 'OTHER'


class PackageExternalRefType:
  cpe22Type = 'cpe22Type'
  cpe23Type = 'cpe23Type'


@dataclass(frozen=True)
class PackageExternalRef:
  category: PackageExternalRefCategory
  type: PackageExternalRefType
  locator: str


@dataclass
class Package:
  name: str
  id: str
  version: str = None
  supplier: str = None
  download_location: str = None
  files_analyzed: bool = False
  verification_code: str = None
  file_ids: List[str] = field(default_factory=list)
  external_refs: List[PackageExternalRef] = field(default_factory=list)
  declared_license_ids: List[str] = field(default_factory=list)


@dataclass
class File:
  id: str
  name: str
  checksum: str
  concluded_license_ids: List[str] = field(default_factory=list)


class RelationshipType:
  DESCRIBES = 'DESCRIBES'
  VARIANT_OF = 'VARIANT_OF'
  GENERATED_FROM = 'GENERATED_FROM'
  CONTAINS = 'CONTAINS'
  STATIC_LINK = 'STATIC_LINK'


@dataclass(frozen=True)
class Relationship:
  id1: str
  relationship: RelationshipType
  id2: str


@dataclass(frozen=True)
class DocumentExternalReference:
  id: str
  uri: str
  checksum: str


@dataclass(frozen=True)
class License:
  id: str
  text: str
  name: str


@dataclass
class Document:
  name: str
  namespace: str
  id: str = SPDXID_DOC
  describes: str = SPDXID_PRODUCT
  creators: List[str] = field(default_factory=list)
  created: str = None
  external_refs: List[DocumentExternalReference] = field(default_factory=list)
  packages: List[Package] = field(default_factory=list)
  files: List[File] = field(default_factory=list)
  relationships: List[Relationship] = field(default_factory=list)
  licenses: List[License] = field(default_factory=list)

  def add_external_ref(self, external_ref):
    if not any(external_ref.uri == ref.uri for ref in self.external_refs):
      self.external_refs.append(external_ref)

  def add_package(self, package):
    p = next((p for p in self.packages if package.id == p.id), None)
    if not p:
      self.packages.append(package)
    else:
      for license_id in package.declared_license_ids:
        if license_id not in p.declared_license_ids:
          p.declared_license_ids.append(license_id)

  def add_relationship(self, rel):
    if not any(rel.id1 == r.id1 and rel.id2 == r.id2 and rel.relationship == r.relationship
               for r in self.relationships):
      self.relationships.append(rel)

  def add_license(self, license):
    if not any(license.id == l.id for l in self.licenses):
      self.licenses.append(license)

  def generate_packages_verification_code(self):
    for package in self.packages:
      if not package.file_ids:
        continue

      checksums = []
      for file in self.files:
        if file.id in package.file_ids:
          checksums.append(file.checksum.split(': ')[1])
      checksums.sort()
      h = hashlib.sha1()
      h.update(''.join(checksums).encode(encoding='utf-8'))
      package.verification_code = h.hexdigest()

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