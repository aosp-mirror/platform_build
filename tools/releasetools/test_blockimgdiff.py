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

import os
from hashlib import sha1

import common
from blockimgdiff import BlockImageDiff, HeapItem, ImgdiffStats, Transfer
from images import DataImage, EmptyImage, FileImage
from rangelib import RangeSet
from test_utils import ReleaseToolsTestCase


class HealpItemTest(ReleaseToolsTestCase):

  class Item(object):
    def __init__(self, score):
      self.score = score

  def test_init(self):
    item1 = HeapItem(self.Item(15))
    item2 = HeapItem(self.Item(20))
    item3 = HeapItem(self.Item(15))
    self.assertTrue(item1)
    self.assertTrue(item2)
    self.assertTrue(item3)

    self.assertNotEqual(item1, item2)
    self.assertEqual(item1, item3)
    # HeapItem uses negated scores.
    self.assertGreater(item1, item2)
    self.assertLessEqual(item1, item3)
    self.assertTrue(item1 <= item3)
    self.assertFalse(item2 >= item1)

  def test_clear(self):
    item = HeapItem(self.Item(15))
    self.assertTrue(item)

    item.clear()
    self.assertFalse(item)


class BlockImageDiffTest(ReleaseToolsTestCase):

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
    t0 = Transfer("t1", "t1", RangeSet("10-15"), RangeSet("0-5"), "t1hash",
                  "t1hash", "move", transfers)
    t1 = Transfer("t2", "t2", RangeSet("20-25"), RangeSet("0-7"), "t2hash",
                  "t2hash", "move", transfers)
    t2 = Transfer("t3", "t3", RangeSet("30-35"), RangeSet("0-4"), "t3hash",
                  "t3hash", "move", transfers)
    t3 = Transfer("t4", "t4", RangeSet("0-10"), RangeSet("40-50"), "t4hash",
                  "t4hash", "move", transfers)

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
    Transfer("t1", "t1", RangeSet("11-15"), RangeSet("20-29"), "t1hash",
             "t1hash", "diff", transfers)
    Transfer("t2", "t2", RangeSet("20-29"), RangeSet("11-15"), "t2hash",
             "t2hash", "diff", transfers)

    block_image_diff.GenerateDigraph()
    block_image_diff.FindVertexSequence()
    block_image_diff.ReverseBackwardEdges()

    # Sufficient cache to stash 5 blocks (size * 0.8 >= 5).
    common.OPTIONS.cache_size = 7 * 4096
    self.assertEqual((0, 5), block_image_diff.ReviseStashSize())

    # Insufficient cache to stash 5 blocks (size * 0.8 < 5).
    common.OPTIONS.cache_size = 6 * 4096
    self.assertEqual((10, 0), block_image_diff.ReviseStashSize())

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
    t1 = Transfer("t1", "t1", RangeSet("11-15"), RangeSet("1-5"), "t1hash",
                  "t1hash", "diff", transfers)
    t2 = Transfer("t2", "t2", RangeSet("21-25"), RangeSet("11-15"), "t2hash",
                  "t2hash", "diff", transfers)
    t3 = Transfer("t3", "t3", RangeSet("1-5 30-39"), RangeSet("11-15 30-39"),
                  "t3hash", "t3hash", "diff", transfers)

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
    self.assertEqual((15, 5), block_image_diff.ReviseStashSize())

  def test_FileTypeSupportedByImgdiff(self):
    self.assertTrue(
        BlockImageDiff.FileTypeSupportedByImgdiff(
            "/system/priv-app/Settings/Settings.apk"))
    self.assertTrue(
        BlockImageDiff.FileTypeSupportedByImgdiff(
            "/system/framework/am.jar"))
    self.assertTrue(
        BlockImageDiff.FileTypeSupportedByImgdiff(
            "/system/etc/security/otacerts.zip"))

    self.assertFalse(
        BlockImageDiff.FileTypeSupportedByImgdiff(
            "/system/framework/arm/boot.oat"))
    self.assertFalse(
        BlockImageDiff.FileTypeSupportedByImgdiff(
            "/system/priv-app/notanapk"))

  def test_CanUseImgdiff(self):
    block_image_diff = BlockImageDiff(EmptyImage(), EmptyImage())
    self.assertTrue(
        block_image_diff.CanUseImgdiff(
            "/system/app/app1.apk", RangeSet("10-15"), RangeSet("0-5")))
    self.assertTrue(
        block_image_diff.CanUseImgdiff(
            "/vendor/app/app2.apk", RangeSet("20 25"), RangeSet("30-31"), True))

    self.assertDictEqual(
        {
            ImgdiffStats.USED_IMGDIFF: {"/system/app/app1.apk"},
            ImgdiffStats.USED_IMGDIFF_LARGE_APK: {"/vendor/app/app2.apk"},
        },
        block_image_diff.imgdiff_stats.stats)


  def test_CanUseImgdiff_ineligible(self):
    # Disabled by caller.
    block_image_diff = BlockImageDiff(EmptyImage(), EmptyImage(),
                                      disable_imgdiff=True)
    self.assertFalse(
        block_image_diff.CanUseImgdiff(
            "/system/app/app1.apk", RangeSet("10-15"), RangeSet("0-5")))

    # Unsupported file type.
    block_image_diff = BlockImageDiff(EmptyImage(), EmptyImage())
    self.assertFalse(
        block_image_diff.CanUseImgdiff(
            "/system/bin/gzip", RangeSet("10-15"), RangeSet("0-5")))

    # At least one of the ranges is in non-monotonic order.
    self.assertFalse(
        block_image_diff.CanUseImgdiff(
            "/system/app/app2.apk", RangeSet("10-15"),
            RangeSet("15-20 30 10-14")))

    # At least one of the ranges is incomplete.
    src_ranges = RangeSet("0-5")
    src_ranges.extra['incomplete'] = True
    self.assertFalse(
        block_image_diff.CanUseImgdiff(
            "/vendor/app/app4.apk", RangeSet("10-15"), src_ranges))

    # The stats are correctly logged.
    self.assertDictEqual(
        {
            ImgdiffStats.SKIPPED_NONMONOTONIC: {'/system/app/app2.apk'},
            ImgdiffStats.SKIPPED_INCOMPLETE: {'/vendor/app/app4.apk'},
        },
        block_image_diff.imgdiff_stats.stats)


class ImgdiffStatsTest(ReleaseToolsTestCase):

  def test_Log(self):
    imgdiff_stats = ImgdiffStats()
    imgdiff_stats.Log("/system/app/app2.apk", ImgdiffStats.USED_IMGDIFF)
    self.assertDictEqual(
        {
            ImgdiffStats.USED_IMGDIFF: {'/system/app/app2.apk'},
        },
        imgdiff_stats.stats)

  def test_Log_invalidInputs(self):
    imgdiff_stats = ImgdiffStats()

    self.assertRaises(AssertionError, imgdiff_stats.Log, "/system/bin/gzip",
                      ImgdiffStats.USED_IMGDIFF)

    self.assertRaises(AssertionError, imgdiff_stats.Log, "/system/app/app1.apk",
                      "invalid reason")


class DataImageTest(ReleaseToolsTestCase):

  def test_read_range_set(self):
    data = "file" + ('\0' * 4092)
    image = DataImage(data)
    self.assertEqual(data, "".join(image.ReadRangeSet(image.care_map)))


class FileImageTest(ReleaseToolsTestCase):

  def setUp(self):
    self.file_path = common.MakeTempFile()
    self.data = os.urandom(4096 * 4)
    with open(self.file_path, 'wb') as f:
      f.write(self.data)
    self.file = FileImage(self.file_path)

  def test_totalsha1(self):
    self.assertEqual(sha1(self.data).hexdigest(), self.file.TotalSha1())

  def test_ranges(self):
    blocksize = self.file.blocksize
    for s in range(4):
      for e in range(s, 4):
        expected_data = self.data[s * blocksize : e * blocksize]

        rs = RangeSet([s, e])
        data = b''.join(self.file.ReadRangeSet(rs))
        self.assertEqual(expected_data, data)

        sha1sum = self.file.RangeSha1(rs)
        self.assertEqual(sha1(expected_data).hexdigest(), sha1sum)

        tmpfile = common.MakeTempFile()
        with open(tmpfile, 'wb') as f:
          self.file.WriteRangeDataToFd(rs, f)
        with open(tmpfile, 'rb') as f:
          self.assertEqual(expected_data, f.read())

  def test_read_all(self):
    data = b''.join(self.file.ReadRangeSet(self.file.care_map))
    self.assertEqual(self.data, data)
