#
# Copyright (C) 2015 The Android Open Source Project
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
#

import unittest

from rangelib import RangeSet

class RangeSetTest(unittest.TestCase):

  def test_union(self):
    self.assertEqual(RangeSet("10-19 30-34").union(RangeSet("18-29")),
                     RangeSet("10-34"))
    self.assertEqual(RangeSet("10-19 30-34").union(RangeSet("22 32")),
                     RangeSet("10-19 22 30-34"))

  def test_intersect(self):
    self.assertEqual(RangeSet("10-19 30-34").intersect(RangeSet("18-32")),
                     RangeSet("18-19 30-32"))
    self.assertEqual(RangeSet("10-19 30-34").intersect(RangeSet("22-28")),
                     RangeSet(""))

  def test_subtract(self):
    self.assertEqual(RangeSet("10-19 30-34").subtract(RangeSet("18-32")),
                     RangeSet("10-17 33-34"))
    self.assertEqual(RangeSet("10-19 30-34").subtract(RangeSet("22-28")),
                     RangeSet("10-19 30-34"))

  def test_overlaps(self):
    self.assertTrue(RangeSet("10-19 30-34").overlaps(RangeSet("18-32")))
    self.assertFalse(RangeSet("10-19 30-34").overlaps(RangeSet("22-28")))

  def test_size(self):
    self.assertEqual(RangeSet("10-19 30-34").size(), 15)

  def test_map_within(self):
    self.assertEqual(RangeSet("0-9").map_within(RangeSet("3-4")),
                     RangeSet("3-4"))
    self.assertEqual(RangeSet("10-19").map_within(RangeSet("13-14")),
                     RangeSet("3-4"))
    self.assertEqual(
        RangeSet("10-19 30-39").map_within(RangeSet("17-19 30-32")),
        RangeSet("7-12"))
    self.assertEqual(
        RangeSet("10-19 30-39").map_within(RangeSet("12-13 17-19 30-32")),
        RangeSet("2-3 7-12"))

  def test_first(self):
    self.assertEqual(RangeSet("0-9").first(1), RangeSet("0"))
    self.assertEqual(RangeSet("10-19").first(5), RangeSet("10-14"))
    self.assertEqual(RangeSet("10-19").first(15), RangeSet("10-19"))
    self.assertEqual(RangeSet("10-19 30-39").first(3), RangeSet("10-12"))
    self.assertEqual(RangeSet("10-19 30-39").first(15),
                     RangeSet("10-19 30-34"))
    self.assertEqual(RangeSet("10-19 30-39").first(30),
                     RangeSet("10-19 30-39"))
    self.assertEqual(RangeSet("0-9").first(0), RangeSet(""))

  def test_extend(self):
    self.assertEqual(RangeSet("0-9").extend(1), RangeSet("0-10"))
    self.assertEqual(RangeSet("10-19").extend(15), RangeSet("0-34"))
    self.assertEqual(RangeSet("10-19 30-39").extend(4), RangeSet("6-23 26-43"))
    self.assertEqual(RangeSet("10-19 30-39").extend(10), RangeSet("0-49"))

