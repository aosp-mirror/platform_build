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
    self.assertEqual(RangeSet("").size(), 0)

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

  def test_equality(self):
    self.assertTrue(RangeSet("") == RangeSet(""))
    self.assertTrue(RangeSet("3") == RangeSet("3"))
    self.assertTrue(RangeSet("3 5") == RangeSet("5 3"))
    self.assertTrue(
        RangeSet("10-19 30-39") == RangeSet("30-32 10-14 33-39 15-19"))
    self.assertTrue(RangeSet("") != RangeSet("3"))
    self.assertTrue(RangeSet("10-19") != RangeSet("10-19 20"))

    self.assertFalse(RangeSet(""))
    self.assertTrue(RangeSet("3"))

  def test_init(self):
    self.assertIsNotNone(RangeSet(""))
    self.assertIsNotNone(RangeSet("3"))
    self.assertIsNotNone(RangeSet("3 5"))
    self.assertIsNotNone(RangeSet("10 19 30-39"))

    with self.assertRaises(AssertionError):
      RangeSet(data=[0])

  def test_str(self):
    self.assertEqual(str(RangeSet("0-9")), "0-9")
    self.assertEqual(str(RangeSet("2-10 12")), "2-10 12")
    self.assertEqual(str(RangeSet("11 2-10 12 1 0")), "0-12")
    self.assertEqual(str(RangeSet("")), "empty")

  def test_to_string_raw(self):
    self.assertEqual(RangeSet("0-9").to_string_raw(), "2,0,10")
    self.assertEqual(RangeSet("2-10 12").to_string_raw(), "4,2,11,12,13")
    self.assertEqual(RangeSet("11 2-10 12 1 0").to_string_raw(), "2,0,13")

    with self.assertRaises(AssertionError):
      RangeSet("").to_string_raw()

  def test_monotonic(self):
    self.assertTrue(RangeSet("0-9").monotonic)
    self.assertTrue(RangeSet("2-9").monotonic)
    self.assertTrue(RangeSet("2-9 30 31 35").monotonic)
    self.assertTrue(RangeSet("").monotonic)
    self.assertTrue(RangeSet("0-4 5-9").monotonic)
    self.assertFalse(RangeSet("5-9 0-4").monotonic)
    self.assertFalse(RangeSet("258768-259211 196604").monotonic)

    self.assertTrue(RangeSet(data=[0, 10]).monotonic)
    self.assertTrue(RangeSet(data=[0, 10, 15, 20]).monotonic)
    self.assertTrue(RangeSet(data=[2, 9, 30, 31, 31, 32, 35, 36]).monotonic)
    self.assertTrue(RangeSet(data=[0, 5, 5, 10]).monotonic)
    self.assertFalse(RangeSet(data=[5, 10, 0, 5]).monotonic)
