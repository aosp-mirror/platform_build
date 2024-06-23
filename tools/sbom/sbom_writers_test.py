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

import io
import pathlib
import unittest
import sbom_data
import sbom_writers

BUILD_FINGER_PRINT = 'build_finger_print'
SUPPLIER_GOOGLE = 'Organization: Google'
SUPPLIER_UPSTREAM = 'Organization: upstream'

SPDXID_PREBUILT_PACKAGE1 = 'SPDXRef-PREBUILT-package1'
SPDXID_SOURCE_PACKAGE1 = 'SPDXRef-SOURCE-package1'
SPDXID_UPSTREAM_PACKAGE1 = 'SPDXRef-UPSTREAM-package1'

SPDXID_FILE1 = 'SPDXRef-file1'
SPDXID_FILE2 = 'SPDXRef-file2'
SPDXID_FILE3 = 'SPDXRef-file3'
SPDXID_FILE4 = 'SPDXRef-file4'

SPDXID_LICENSE_1 = 'LicenseRef-Android-License-1'
SPDXID_LICENSE_2 = 'LicenseRef-Android-License-2'
SPDXID_LICENSE_3 = 'LicenseRef-Android-License-3'

LICENSE_APACHE_TEXT = "LICENSE_APACHE"
LICENSE1_TEXT = 'LICENSE 1'
LICENSE2_TEXT = 'LICENSE 2'
LICENSE3_TEXT = 'LICENSE 3'

class SBOMWritersTest(unittest.TestCase):

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
                        verification_code='123456',
                        file_ids=[SPDXID_FILE1, SPDXID_FILE2, SPDXID_FILE3]))

    self.sbom_doc.add_package(
      sbom_data.Package(id=sbom_data.SPDXID_PLATFORM,
                        name=sbom_data.PACKAGE_NAME_PLATFORM,
                        download_location=sbom_data.VALUE_NONE,
                        supplier=SUPPLIER_GOOGLE,
                        version=BUILD_FINGER_PRINT,
                        declared_license_ids=[sbom_data.SPDXID_LICENSE_APACHE]
                        ))

    self.sbom_doc.add_package(
      sbom_data.Package(id=SPDXID_PREBUILT_PACKAGE1,
                        name='Prebuilt package1',
                        download_location=sbom_data.VALUE_NONE,
                        supplier=SUPPLIER_GOOGLE,
                        version=BUILD_FINGER_PRINT,
                        declared_license_ids=[SPDXID_LICENSE_1],
                        ))

    self.sbom_doc.add_package(
      sbom_data.Package(id=SPDXID_SOURCE_PACKAGE1,
                        name='Source package1',
                        download_location=sbom_data.VALUE_NONE,
                        supplier=SUPPLIER_GOOGLE,
                        version=BUILD_FINGER_PRINT,
                        declared_license_ids=[SPDXID_LICENSE_2, SPDXID_LICENSE_3],
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
                        declared_license_ids=[SPDXID_LICENSE_2, SPDXID_LICENSE_3],
                        ))

    self.sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_SOURCE_PACKAGE1,
                                                          relationship=sbom_data.RelationshipType.VARIANT_OF,
                                                          id2=SPDXID_UPSTREAM_PACKAGE1))

    self.sbom_doc.files.append(
      sbom_data.File(id=SPDXID_FILE1, name='/bin/file1', checksum='SHA1: 11111', concluded_license_ids=[sbom_data.SPDXID_LICENSE_APACHE]))
    self.sbom_doc.files.append(
      sbom_data.File(id=SPDXID_FILE2, name='/bin/file2', checksum='SHA1: 22222', concluded_license_ids=[SPDXID_LICENSE_1]))
    self.sbom_doc.files.append(
      sbom_data.File(id=SPDXID_FILE3, name='/bin/file3', checksum='SHA1: 33333', concluded_license_ids=[SPDXID_LICENSE_2, SPDXID_LICENSE_3]))
    self.sbom_doc.files.append(
      sbom_data.File(id=SPDXID_FILE4, name='file4.a', checksum='SHA1: 44444'))

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

    self.sbom_doc.add_license(sbom_data.License(sbom_data.SPDXID_LICENSE_APACHE, LICENSE_APACHE_TEXT, "License-Apache"))
    self.sbom_doc.add_license(sbom_data.License(SPDXID_LICENSE_1, LICENSE1_TEXT, "License-1"))
    self.sbom_doc.add_license(sbom_data.License(SPDXID_LICENSE_2, LICENSE2_TEXT, "License-2"))
    self.sbom_doc.add_license(sbom_data.License(SPDXID_LICENSE_3, LICENSE3_TEXT, "License-3"))

    # SBOM fragment of a APK
    self.unbundled_sbom_doc = sbom_data.Document(name='test doc',
                                                 namespace='http://www.google.com/sbom/spdx/android',
                                                 creators=[SUPPLIER_GOOGLE],
                                                 created='2023-03-31T22:17:58Z',
                                                 describes=SPDXID_FILE1)

    self.unbundled_sbom_doc.files.append(
      sbom_data.File(id=SPDXID_FILE1, name='/bin/file1.apk', checksum='SHA1: 11111'))
    self.unbundled_sbom_doc.add_package(
      sbom_data.Package(id=SPDXID_SOURCE_PACKAGE1,
                        name='Unbundled apk package',
                        download_location=sbom_data.VALUE_NONE,
                        supplier=SUPPLIER_GOOGLE,
                        version=BUILD_FINGER_PRINT))
    self.unbundled_sbom_doc.add_relationship(sbom_data.Relationship(id1=SPDXID_FILE1,
                                                                    relationship=sbom_data.RelationshipType.GENERATED_FROM,
                                                                    id2=SPDXID_SOURCE_PACKAGE1))

  def test_tagvalue_writer(self):
    with io.StringIO() as output:
      sbom_writers.TagValueWriter.write(self.sbom_doc, output)
      expected_output = pathlib.Path('testdata/expected_tagvalue_sbom.spdx').read_text()
      self.maxDiff = None
      self.assertEqual(expected_output, output.getvalue())

  def test_tagvalue_writer_doc_describes_file(self):
    with io.StringIO() as output:
      self.sbom_doc.describes = SPDXID_FILE4
      sbom_writers.TagValueWriter.write(self.sbom_doc, output)
      expected_output = pathlib.Path('testdata/expected_tagvalue_sbom_doc_describes_file.spdx').read_text()
      self.maxDiff = None
      self.assertEqual(expected_output, output.getvalue())

  def test_tagvalue_writer_unbundled(self):
    with io.StringIO() as output:
      sbom_writers.TagValueWriter.write(self.unbundled_sbom_doc, output, fragment=True)
      expected_output = pathlib.Path('testdata/expected_tagvalue_sbom_unbundled.spdx').read_text()
      self.maxDiff = None
      self.assertEqual(expected_output, output.getvalue())

  def test_json_writer(self):
    with io.StringIO() as output:
      sbom_writers.JSONWriter.write(self.sbom_doc, output)
      expected_output = pathlib.Path('testdata/expected_json_sbom.spdx.json').read_text()
      self.maxDiff = None
      self.assertEqual(expected_output, output.getvalue())


if __name__ == '__main__':
  unittest.main(verbosity=2)
