#
# Copyright (C) 2017 The Android Open Source Project
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

import shutil
import tempfile
import unittest

from build_image import CheckHeadroom, RunCommand


class BuildImageTest(unittest.TestCase):

  def test_CheckHeadroom_SizeUnderLimit(self):
    ext4fs_output = ("Created filesystem with 2777/129024 inodes and "
                     "508140/516099 blocks")
    prop_dict = {
        'partition_headroom' : '4194304',
        'mount_point' : 'system',
    }
    self.assertTrue(CheckHeadroom(ext4fs_output, prop_dict))

  def test_CheckHeadroom_InsufficientHeadroom(self):
    ext4fs_output = ("Created filesystem with 2777/129024 inodes and "
                     "515099/516099 blocks")
    prop_dict = {
        'partition_headroom' : '4100096',
        'mount_point' : 'system',
    }
    self.assertFalse(CheckHeadroom(ext4fs_output, prop_dict))

  def test_CheckHeadroom_WithMke2fsOutput(self):
    """Tests the result parsing from actual call to mke2fs."""
    input_dir = tempfile.mkdtemp()
    output_image = tempfile.NamedTemporaryFile(suffix='.img')
    command = ['mkuserimg_mke2fs.sh', input_dir, output_image.name, 'ext4',
               '/system', '409600', '-j', '0']
    ext4fs_output, exit_code = RunCommand(command)
    self.assertEqual(0, exit_code)

    prop_dict = {
        'partition_headroom' : '40960',
        'mount_point' : 'system',
    }
    self.assertTrue(CheckHeadroom(ext4fs_output, prop_dict))

    prop_dict = {
        'partition_headroom' : '413696',
        'mount_point' : 'system',
    }
    self.assertFalse(CheckHeadroom(ext4fs_output, prop_dict))

    shutil.rmtree(input_dir)
