#
# Copyright (C) 2016 The Android Open Source Project
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

from __future__ import print_function

import common
import unittest

from collections import OrderedDict
from blockimgdiff import BlockImageDiff, EmptyImage, DataImage, Transfer
from rangelib import RangeSet

class BlockImageDiffTest(unittest.TestCase):

  def test_GenerateDigraphOrder(self):
    """Make sure GenerateDigraph preserves the order.

    t0: <0-5> => <...>
    t1: <0-7> => <...>
    t2: <0-4> => <...>
    t3: <...> => <0-10>

    t0, t1 and t2 must go before t3, i.e. t3.goes_after =
    { t0:..., t1:..., t2:... }. But the order of t0-t2 must be preserved.
    """

    src = EmptyImage()
    tgt = EmptyImage()
    block_image_diff = BlockImageDiff(tgt, src)

    transfers = block_image_diff.transfers
    t0 = Transfer(
        "t1", "t1", RangeSet("10-15"), RangeSet("0-5"), "move", transfers)
    t1 = Transfer(
        "t2", "t2", RangeSet("20-25"), RangeSet("0-7"), "move", transfers)
    t2 = Transfer(
        "t3", "t3", RangeSet("30-35"), RangeSet("0-4"), "move", transfers)
    t3 = Transfer(
        "t4", "t4", RangeSet("0-10"), RangeSet("40-50"), "move", transfers)

    block_image_diff.GenerateDigraph()
    t3_goes_after_copy = t3.goes_after.copy()

    # Elements in the set must be in the transfer evaluation order.
    elements = list(t3_goes_after_copy)
    self.assertEqual(t0, elements[0])
    self.assertEqual(t1, elements[1])
    self.assertEqual(t2, elements[2])

    # Now switch the order of t0, t1 and t2.
    transfers[0], transfers[1], transfers[2] = (
        transfers[2], transfers[0], transfers[1])
    t3.goes_after.clear()
    t3.goes_before.clear()
    block_image_diff.GenerateDigraph()

    # The goes_after must be different from last run.
    self.assertNotEqual(t3_goes_after_copy, t3.goes_after)

    # Assert that each element must agree with the transfer order.
    elements = list(t3.goes_after)
    self.assertEqual(t2, elements[0])
    self.assertEqual(t0, elements[1])
    self.assertEqual(t1, elements[2])
