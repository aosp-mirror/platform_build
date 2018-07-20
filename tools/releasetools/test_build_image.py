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

import filecmp
import os.path
import unittest

import common
from build_image import CheckHeadroom, RunCommand, SetUpInDirAndFsConfig


class BuildImageTest(unittest.TestCase):

  # Available: 1000 blocks.
  EXT4FS_OUTPUT = (
      "Created filesystem with 2777/129024 inodes and 515099/516099 blocks")

  def tearDown(self):
    common.Cleanup()

  def test_CheckHeadroom_SizeUnderLimit(self):
    # Required headroom: 1000 blocks.
    prop_dict = {
        'fs_type' : 'ext4',
        'partition_headroom' : '4096000',
        'mount_point' : 'system',
    }
    self.assertTrue(CheckHeadroom(self.EXT4FS_OUTPUT, prop_dict))

  def test_CheckHeadroom_InsufficientHeadroom(self):
    # Required headroom: 1001 blocks.
    prop_dict = {
        'fs_type' : 'ext4',
        'partition_headroom' : '4100096',
        'mount_point' : 'system',
    }
    self.assertFalse(CheckHeadroom(self.EXT4FS_OUTPUT, prop_dict))

  def test_CheckHeadroom_WrongFsType(self):
    prop_dict = {
        'fs_type' : 'f2fs',
        'partition_headroom' : '4100096',
        'mount_point' : 'system',
    }
    self.assertRaises(
        AssertionError, CheckHeadroom, self.EXT4FS_OUTPUT, prop_dict)

  def test_CheckHeadroom_MissingProperties(self):
    prop_dict = {
        'fs_type' : 'ext4',
        'partition_headroom' : '4100096',
    }
    self.assertRaises(
        AssertionError, CheckHeadroom, self.EXT4FS_OUTPUT, prop_dict)

    prop_dict = {
        'fs_type' : 'ext4',
        'mount_point' : 'system',
    }
    self.assertRaises(
        AssertionError, CheckHeadroom, self.EXT4FS_OUTPUT, prop_dict)

  def test_CheckHeadroom_WithMke2fsOutput(self):
    """Tests the result parsing from actual call to mke2fs."""
    input_dir = common.MakeTempDir()
    output_image = common.MakeTempFile(suffix='.img')
    command = ['mkuserimg_mke2fs.sh', input_dir, output_image, 'ext4',
               '/system', '409600', '-j', '0']
    ext4fs_output, exit_code = RunCommand(command)
    self.assertEqual(0, exit_code)

    prop_dict = {
        'fs_type' : 'ext4',
        'partition_headroom' : '40960',
        'mount_point' : 'system',
    }
    self.assertTrue(CheckHeadroom(ext4fs_output, prop_dict))

    prop_dict = {
        'fs_type' : 'ext4',
        'partition_headroom' : '413696',
        'mount_point' : 'system',
    }
    self.assertFalse(CheckHeadroom(ext4fs_output, prop_dict))

  def test_SetUpInDirAndFsConfig_SystemRootImageFalse(self):
    prop_dict = {
        'fs_config': 'fs-config',
        'mount_point': 'system',
    }
    in_dir, fs_config = SetUpInDirAndFsConfig('/path/to/in_dir', prop_dict)
    self.assertEqual('/path/to/in_dir', in_dir)
    self.assertEqual('fs-config', fs_config)
    self.assertEqual('system', prop_dict['mount_point'])

  def test_SetUpInDirAndFsConfig_SystemRootImageTrue_NonSystem(self):
    prop_dict = {
        'fs_config': 'fs-config',
        'mount_point': 'vendor',
        'system_root_image': 'true',
    }
    in_dir, fs_config = SetUpInDirAndFsConfig('/path/to/in_dir', prop_dict)
    self.assertEqual('/path/to/in_dir', in_dir)
    self.assertEqual('fs-config', fs_config)
    self.assertEqual('vendor', prop_dict['mount_point'])

  @staticmethod
  def _gen_fs_config(partition):
    fs_config = common.MakeTempFile(suffix='.txt')
    with open(fs_config, 'w') as fs_config_fp:
      fs_config_fp.write('fs-config-{}\n'.format(partition))
    return fs_config

  def test_SetUpInDirAndFsConfig_SystemRootImageTrue(self):
    root_dir = common.MakeTempDir()
    with open(os.path.join(root_dir, 'init'), 'w') as init_fp:
      init_fp.write('init')

    origin_in = common.MakeTempDir()
    with open(os.path.join(origin_in, 'file'), 'w') as in_fp:
      in_fp.write('system-file')
    os.symlink('../etc', os.path.join(origin_in, 'symlink'))

    fs_config_system = self._gen_fs_config('system')

    prop_dict = {
        'fs_config': fs_config_system,
        'mount_point': 'system',
        'root_dir': root_dir,
        'system_root_image': 'true',
    }
    in_dir, fs_config = SetUpInDirAndFsConfig(origin_in, prop_dict)

    self.assertTrue(filecmp.cmp(
        os.path.join(in_dir, 'init'), os.path.join(root_dir, 'init')))
    self.assertTrue(filecmp.cmp(
        os.path.join(in_dir, 'system', 'file'),
        os.path.join(origin_in, 'file')))
    self.assertTrue(os.path.islink(os.path.join(in_dir, 'system', 'symlink')))

    self.assertTrue(filecmp.cmp(fs_config_system, fs_config))
    self.assertEqual('/', prop_dict['mount_point'])

  def test_SetUpInDirAndFsConfig_SystemRootImageTrue_WithRootFsConfig(self):
    root_dir = common.MakeTempDir()
    with open(os.path.join(root_dir, 'init'), 'w') as init_fp:
      init_fp.write('init')

    origin_in = common.MakeTempDir()
    with open(os.path.join(origin_in, 'file'), 'w') as in_fp:
      in_fp.write('system-file')
    os.symlink('../etc', os.path.join(origin_in, 'symlink'))

    fs_config_system = self._gen_fs_config('system')
    fs_config_root = self._gen_fs_config('root')

    prop_dict = {
        'fs_config': fs_config_system,
        'mount_point': 'system',
        'root_dir': root_dir,
        'root_fs_config': fs_config_root,
        'system_root_image': 'true',
    }
    in_dir, fs_config = SetUpInDirAndFsConfig(origin_in, prop_dict)

    self.assertTrue(filecmp.cmp(
        os.path.join(in_dir, 'init'), os.path.join(root_dir, 'init')))
    self.assertTrue(filecmp.cmp(
        os.path.join(in_dir, 'system', 'file'),
        os.path.join(origin_in, 'file')))
    self.assertTrue(os.path.islink(os.path.join(in_dir, 'system', 'symlink')))

    with open(fs_config) as fs_config_fp:
      fs_config_data = fs_config_fp.readlines()
    self.assertIn('fs-config-system\n', fs_config_data)
    self.assertIn('fs-config-root\n', fs_config_data)
    self.assertEqual('/', prop_dict['mount_point'])
