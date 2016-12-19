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

from blockimgdiff import BlockImageDiff, EmptyImage, Transfer
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

  def test_ReviseStashSize(self):
    """ReviseStashSize should convert transfers to 'new' commands as needed.

    t1: diff <20-29> => <11-15>
    t2: diff <11-15> => <20-29>
    """

    src = EmptyImage()
    tgt = EmptyImage()
    block_image_diff = BlockImageDiff(tgt, src, version=3)

    transfers = block_image_diff.transfers
    Transfer("t1", "t1", RangeSet("11-15"), RangeSet("20-29"), "diff",
             transfers)
    Transfer("t2", "t2", RangeSet("20-29"), RangeSet("11-15"), "diff",
             transfers)

    block_image_diff.GenerateDigraph()
    block_image_diff.FindVertexSequence()
    block_image_diff.ReverseBackwardEdges()

    # Sufficient cache to stash 5 blocks (size * 0.8 >= 5).
    common.OPTIONS.cache_size = 7 * 4096
    self.assertEqual(0, block_image_diff.ReviseStashSize())

    # Insufficient cache to stash 5 blocks (size * 0.8 < 5).
    common.OPTIONS.cache_size = 6 * 4096
    self.assertEqual(10, block_image_diff.ReviseStashSize())

  def test_ReviseStashSize_bug_33687949(self):
    """ReviseStashSize() should "free" the used stash _after_ the command.

    t1: diff <1-5> => <11-15>
    t2: diff <11-15> => <21-25>
    t3: diff <11-15 30-39> => <1-5 30-39>

    For transfer t3, the used stash "11-15" should not be freed until the
    command finishes. Assume the allowed cache size is 12-block, it should
    convert the command to 'new' due to insufficient cache (12 < 5 + 10).
    """

    src = EmptyImage()
    tgt = EmptyImage()
    block_image_diff = BlockImageDiff(tgt, src, version=3)

    transfers = block_image_diff.transfers
    t1 = Transfer("t1", "t1", RangeSet("11-15"), RangeSet("1-5"), "diff",
                  transfers)
    t2 = Transfer("t2", "t2", RangeSet("21-25"), RangeSet("11-15"), "diff",
                  transfers)
    t3 = Transfer("t3", "t3", RangeSet("1-5 30-39"), RangeSet("11-15 30-39"),
                  "diff", transfers)

    block_image_diff.GenerateDigraph()

    # Instead of calling FindVertexSequence() and ReverseBackwardEdges(), we
    # just set up the stash_before and use_stash manually. Otherwise it will
    # reorder the transfer, which makes testing ReviseStashSize() harder.
    t1.stash_before.append((0, RangeSet("11-15")))
    t2.use_stash.append((0, RangeSet("11-15")))
    t1.stash_before.append((1, RangeSet("11-15")))
    t3.use_stash.append((1, RangeSet("11-15")))

    # Insufficient cache to stash 15 blocks (size * 0.8 < 15).
    common.OPTIONS.cache_size = 15 * 4096
    self.assertEqual(15, block_image_diff.ReviseStashSize())
