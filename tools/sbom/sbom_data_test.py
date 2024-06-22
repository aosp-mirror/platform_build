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

import hashlib
import unittest
import sbom_data

BUILD_FINGER_PRINT = 'build_finger_print'
SUPPLIER_GOOGLE = 'Organization: Google'
SUPPLIER_UPSTREAM = 'Organization: upstream'

SPDXID_PREBUILT_PACKAGE1 = 'SPDXRef-PREBUILT-package1'
SPDXID_PREBUILT_PACKAGE2 = 'SPDXRef-PREBUILT-package2'
SPDXID_SOURCE_PACKAGE1 = 'SPDXRef-SOURCE-package1'
SPDXID_UPSTREAM_PACKAGE1 = 'SPDXRef-UPSTREAM-package1'

SPDXID_FILE1 = 'SPDXRef-file1'
SPDXID_FILE2 = 'SPDXRef-file2'
SPDXID_FILE3 = 'SPDXRef-file3'
SPDXID_FILE4 = 'SPDXRef-file4'

SPDXID_LICENSE1 = "SPDXRef-License-1"
SPDXID_LICENSE2 = "SPDXRef-License-2"


class SBOMDataTest(unittest.TestCase):

  def setUp(self):
    # SBOM of a product
    self.sbom_doc = sbom_data.Document(name='test doc',
                                       namespace='http://www.google.com/sbom/spdx/android',
                                       creators=[SUPPLIER_GOOGLE],
                                       created='2023-03-31T22:17:58Z',
                                       describes=sbom_data.SPDXID_PRODUCT)
    self.sbom_doc.add_external_ref(
        sbom_data.DocumentExternalReference(id='DocumentRef-external_doc_ref',
                                            uri='external_doc_uri',
                                            checksum='SHA1: 1234567890'))
    self.sbom_doc.add_package(
        sbom_data.Package(id=sbom_data.SPDXID_PRODUCT,
                          name=sbom_data.PACKAGE_NAME_PRODUCT,
                          download_location=sbom_data.VALUE_NONE,
                          supplier=SUPPLIER_GOOGLE,
                          version=BUILD_FINGER_PRINT,
                          files_analyzed=True,
                          verification_code='',
                          file_ids=[SPDXID_FILE1, SPDXID_FILE2, SPDXID_FILE3, SPDXID_FILE4]))

    self.sbom_doc.add_package(
        sbom_data.Package(id=sbom_data.SPDXID_PLATFORM,
                          name=sbom_data.PACKAGE_NAME_PLATFORM,
                          download_location=sbom_data.VALUE_NONE,
                          supplier=SUPPLIER_GOOGLE,
                          version=BUILD_FINGER_PRINT,
                          ))

    self.sbom_doc.add_package(
        sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE1,
                          name='Prebuilt package1',
                          download_location=sbom_data.VALUE_NONE,
                          supplier=SUPPLIER_GOOGLE,
                          version=BUILD_FINGER_PRINT,
                          ))

    self.sbom_doc.add_package(
        sbom_data.Package(id=SPDXID_SOURCE_PACKAGE1,
                          name='Source package1',
                          download_location=sbom_data.VALUE_NONE,
                          supplier=SUPPLIER_GOOGLE,
                          version=BUILD_FINGER_PRINT,
                          external_refs=[sbom_data.PackageExternalRef(
                              category=sbom_data.PackageExternalRefCategory.SECURITY,
                              type=sbom_data.PackageExternalRefType.cpe22Type,
                              locator='cpe:/a:jsoncpp_project:jsoncpp:1.9.4')]
                          ))

    self.sbom_doc.add_package(
        sbom_data.Package(id=SPDXID_UPSTREAM_PACKAGE1,
                          name='Upstream package1',
                          supplier=SUPPLIER_UPSTREAM,
                          version='1.1',
                          ))

    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_SOURCE_PACKAGE1,
                                                          relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                          id2=SPDXID_UPSTREAM_PACKAGE1))

    self.sbom_doc.files.append(
        sbom_data.File(id=SPDXID_FILE1, name='/bin/file1',
                       checksum='SHA1: 356a192b7913b04c54574d18c28d46e6395428ab'))  # sha1 hash of 1
    self.sbom_doc.files.append(
        sbom_data.File(id=SPDXID_FILE2, name='/bin/file2',
                       checksum='SHA1: da4b9237bacccdf19c0760cab7aec4a8359010b0'))  # sha1 hash of 2
    self.sbom_doc.files.append(
        sbom_data.File(id=SPDXID_FILE3, name='/bin/file3',
                       checksum='SHA1: 77de68daecd823babbb58edb1c8e14d7106e83bb'))  # sha1 hash of 3
    self.sbom_doc.files.append(
        sbom_data.File(id=SPDXID_FILE4, name='file4.a',
                       checksum='SHA1: 1b6453892473a467d07372d45eb05abc2031647a'))  # sha1 of 4

    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_FILE1,
                                                          relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                          id2=sbom_data.SPDXID_PLATFORM))
    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_FILE2,
                                                          relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                          id2=SPDXID_PREBUILT_PACKAGE1))
    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_FILE3,
                                                          relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                          id2=SPDXID_SOURCE_PACKAGE1
                                                          ))
    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_FILE1,
                                                          relationship=sbom_data.RelationshipType.STATIC_LINK,
                                                          id2=SPDXID_FILE4
                                                          ))

  def test_package_verification_code(self):
    checksums = []
    for file in self.sbom_doc.files:
      checksums.append(file.checksum.split(': ')[1])
      checksums.sort()
    h = hashlib.sha1()
    h.update(''.join(checksums).encode(encoding='utf-8'))
    expected_package_verification_code = h.hexdigest()

    self.sbom_doc.generate_packages_verification_code()
    self.assertEqual(expected_package_verification_code, self.sbom_doc.packages[0].verification_code)

  def test_add_package_(self):
    self.sbom_doc.add_package(sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE2,
                                                name='Prebuilt package2',
                                                download_location=sbom_data.VALUE_NONE,
                                                supplier=SUPPLIER_GOOGLE,
                                                version=BUILD_FINGER_PRINT,
                                                ))
    p = next((p for p in self.sbom_doc.packages if p.id == SPDXID_PREBUILT_PACKAGE2), None)
    self.assertNotEqual(p, None)
    self.assertEqual(p.declared_license_ids, [])

    # Add same package with license 1
    self.sbom_doc.add_package(sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE2,
                                                name='Prebuilt package2',
                                                download_location=sbom_data.VALUE_NONE,
                                                supplier=SUPPLIER_GOOGLE,
                                                version=BUILD_FINGER_PRINT,
                                                declared_license_ids=[SPDXID_LICENSE1]
                                                ))
    self.assertEqual(p.declared_license_ids, [SPDXID_LICENSE1])

    # Add same package with license 2
    self.sbom_doc.add_package(sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE2,
                                                name='Prebuilt package2',
                                                download_location=sbom_data.VALUE_NONE,
                                                supplier=SUPPLIER_GOOGLE,
                                                version=BUILD_FINGER_PRINT,
                                                declared_license_ids=[SPDXID_LICENSE2]
                                                ))
    self.assertEqual(p.declared_license_ids, [SPDXID_LICENSE1, SPDXID_LICENSE2])

    # Add same package with license 2 again
    self.sbom_doc.add_package(sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE2,
                                                name='Prebuilt package2',
                                                download_location=sbom_data.VALUE_NONE,
                                                supplier=SUPPLIER_GOOGLE,
                                                version=BUILD_FINGER_PRINT,
                                                declared_license_ids=[SPDXID_LICENSE2]
                                                ))
    self.assertEqual(p.declared_license_ids, [SPDXID_LICENSE1, SPDXID_LICENSE2])


if __name__ == '__main__':
  unittest.main(verbosity=2)
