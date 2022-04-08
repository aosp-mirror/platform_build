#!/usr/bin/env python
#
# Copyright (C) 2018 The Android Open Source Project
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

import unittest
from extract_kernel import get_version, dump_version

class ExtractKernelTest(unittest.TestCase):
  def test_extract_version(self):
    self.assertEqual("4.9.100", get_version(
        b'Linux version 4.9.100-a123 (a@a) (a) a\n\x00', 0))
    self.assertEqual("4.9.123", get_version(
        b'Linux version 4.9.123 (@) () \n\x00', 0))

  def test_dump_self(self):
    self.assertEqual("4.9.1", dump_version(
        b"trash\x00Linux version 4.8.8\x00trash\x00"
        "other trash Linux version 4.9.1-g3 (2@s) (2) a\n\x00"))
