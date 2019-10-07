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
#

"""Unittests for validate_target_files.py."""

import os
import os.path
import shutil
import zipfile

import common
import test_utils
from rangelib import RangeSet
from validate_target_files import (ValidateVerifiedBootImages,
                                   ValidateFileConsistency)
from verity_utils import CreateVerityImageBuilder


class ValidateTargetFilesTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def _generate_boot_image(self, output_file):
    kernel = common.MakeTempFile(prefix='kernel-')
    with open(kernel, 'wb') as kernel_fp:
      kernel_fp.write(os.urandom(10))

    cmd = ['mkbootimg', '--kernel', kernel, '-o', output_file]
    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    self.assertEqual(
        0, proc.returncode,
        "Failed to run mkbootimg: {}".format(stdoutdata))

    cmd = ['boot_signer', '/boot', output_file,
           os.path.join(self.testdata_dir, 'testkey.pk8'),
           os.path.join(self.testdata_dir, 'testkey.x509.pem'), output_file]
    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    self.assertEqual(
        0, proc.returncode,
        "Failed to sign boot image with boot_signer: {}".format(stdoutdata))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_bootImage(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    boot_image = os.path.join(input_tmp, 'IMAGES', 'boot.img')
    self._generate_boot_image(boot_image)

    info_dict = {
        'boot_signer' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
    }
    ValidateVerifiedBootImages(input_tmp, info_dict, options)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_bootImage_wrongKey(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    boot_image = os.path.join(input_tmp, 'IMAGES', 'boot.img')
    self._generate_boot_image(boot_image)

    info_dict = {
        'boot_signer' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'verity.x509.pem'),
    }
    self.assertRaises(
        AssertionError, ValidateVerifiedBootImages, input_tmp, info_dict,
        options)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_bootImage_corrupted(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    boot_image = os.path.join(input_tmp, 'IMAGES', 'boot.img')
    self._generate_boot_image(boot_image)

    # Corrupt the late byte of the image.
    with open(boot_image, 'r+b') as boot_fp:
      boot_fp.seek(-1, os.SEEK_END)
      last_byte = boot_fp.read(1)
      last_byte = bytes([255 - ord(last_byte)])
      boot_fp.seek(-1, os.SEEK_END)
      boot_fp.write(last_byte)

    info_dict = {
        'boot_signer' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
    }
    self.assertRaises(
        AssertionError, ValidateVerifiedBootImages, input_tmp, info_dict,
        options)

  def _generate_system_image(self, output_file, system_root=None,
                             file_map=None):
    prop_dict = {
        'partition_size': str(1024 * 1024),
        'verity': 'true',
        'verity_block_device': '/dev/block/system',
        'verity_key' : os.path.join(self.testdata_dir, 'testkey'),
        'verity_fec': "true",
        'verity_signer_cmd': 'verity_signer',
    }
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    image_size = verity_image_builder.CalculateMaxImageSize()

    # Use an empty root directory.
    if not system_root:
      system_root = common.MakeTempDir()
    cmd = ['mkuserimg_mke2fs', '-s', system_root, output_file, 'ext4',
           '/system', str(image_size), '-j', '0']
    if file_map:
      cmd.extend(['-B', file_map])
    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    self.assertEqual(
        0, proc.returncode,
        "Failed to create system image with mkuserimg_mke2fs: {}".format(
            stdoutdata))

    # Append the verity metadata.
    verity_image_builder.Build(output_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_systemRootImage(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    self._generate_system_image(system_image)

    # Pack the verity key.
    verity_key_mincrypt = os.path.join(input_tmp, 'ROOT', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_mincrypt))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'testkey_mincrypt'),
        verity_key_mincrypt)

    info_dict = {
        'system_root_image' : 'true',
        'verity' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        'verity_key_mincrypt' : verity_key_mincrypt,
    }
    ValidateVerifiedBootImages(input_tmp, info_dict, options)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_nonSystemRootImage(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    self._generate_system_image(system_image)

    # Pack the verity key into the root dir in system.img.
    verity_key_mincrypt = os.path.join(input_tmp, 'ROOT', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_mincrypt))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'testkey_mincrypt'),
        verity_key_mincrypt)

    # And a copy in ramdisk.
    verity_key_ramdisk = os.path.join(
        input_tmp, 'BOOT', 'RAMDISK', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_ramdisk))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'testkey_mincrypt'),
        verity_key_ramdisk)

    info_dict = {
        'verity' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        'verity_key_mincrypt' : verity_key_mincrypt,
    }
    ValidateVerifiedBootImages(input_tmp, info_dict, options)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateVerifiedBootImages_nonSystemRootImage_mismatchingKeys(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    self._generate_system_image(system_image)

    # Pack the verity key into the root dir in system.img.
    verity_key_mincrypt = os.path.join(input_tmp, 'ROOT', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_mincrypt))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'testkey_mincrypt'),
        verity_key_mincrypt)

    # And an invalid copy in ramdisk.
    verity_key_ramdisk = os.path.join(
        input_tmp, 'BOOT', 'RAMDISK', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_ramdisk))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'verity_mincrypt'),
        verity_key_ramdisk)

    info_dict = {
        'verity' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        'verity_key_mincrypt' : verity_key_mincrypt,
    }
    self.assertRaises(
        AssertionError, ValidateVerifiedBootImages, input_tmp, info_dict,
        options)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateFileConsistency_incompleteRange(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    system_root = os.path.join(input_tmp, "SYSTEM")
    os.mkdir(system_root)

    # Write test files that contain multiple blocks of zeros, and these zero
    # blocks will be omitted by kernel. Each test file will occupy one block in
    # the final system image.
    with open(os.path.join(system_root, 'a'), 'w') as f:
      f.write('aaa')
      f.write('\0' * 4096 * 3)
    with open(os.path.join(system_root, 'b'), 'w') as f:
      f.write('bbb')
      f.write('\0' * 4096 * 3)

    raw_file_map = os.path.join(input_tmp, 'IMAGES', 'raw_system.map')
    self._generate_system_image(system_image, system_root, raw_file_map)

    # Parse the generated file map and update the block ranges for each file.
    file_map_list = {}
    image_ranges = RangeSet()
    with open(raw_file_map) as f:
      for line in f.readlines():
        info = line.split()
        self.assertEqual(2, len(info))
        image_ranges = image_ranges.union(RangeSet(info[1]))
        file_map_list[info[0]] = RangeSet(info[1])

    # Add one unoccupied block as the shared block for all test files.
    mock_shared_block = RangeSet("10-20").subtract(image_ranges).first(1)
    with open(os.path.join(input_tmp, 'IMAGES', 'system.map'), 'w') as f:
      for key in sorted(file_map_list.keys()):
        line = '{} {}\n'.format(
            key, file_map_list[key].union(mock_shared_block))
        f.write(line)

    # Prepare for the target zip file
    input_file = common.MakeTempFile()
    all_entries = ['SYSTEM/', 'SYSTEM/b', 'SYSTEM/a', 'IMAGES/',
                   'IMAGES/system.map', 'IMAGES/system.img']
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      for name in all_entries:
        input_zip.write(os.path.join(input_tmp, name), arcname=name)

    # Expect the validation to pass and both files are skipped due to
    # 'incomplete' block range.
    with zipfile.ZipFile(input_file) as input_zip:
      info_dict = {'extfs_sparse_flag': '-s'}
      ValidateFileConsistency(input_zip, input_tmp, info_dict)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ValidateFileConsistency_nonMonotonicRanges(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    system_root = os.path.join(input_tmp, "SYSTEM")
    os.mkdir(system_root)

    # Write the test file that contain three blocks of 'a', 'b', 'c'.
    with open(os.path.join(system_root, 'abc'), 'w') as f:
      f.write('a' * 4096 + 'b' * 4096 + 'c' * 4096)
    raw_file_map = os.path.join(input_tmp, 'IMAGES', 'raw_system.map')
    self._generate_system_image(system_image, system_root, raw_file_map)

    # Parse the generated file map and manipulate the block ranges of 'abc' to
    # be 'cba'.
    file_map_list = {}
    with open(raw_file_map) as f:
      for line in f.readlines():
        info = line.split()
        self.assertEqual(2, len(info))
        ranges = RangeSet(info[1])
        self.assertTrue(ranges.monotonic)
        blocks = reversed(list(ranges.next_item()))
        file_map_list[info[0]] = ' '.join([str(block) for block in blocks])

    # Update the contents of 'abc' to be 'cba'.
    with open(os.path.join(system_root, 'abc'), 'w') as f:
      f.write('c' * 4096 + 'b' * 4096 + 'a' * 4096)

    # Update the system.map.
    with open(os.path.join(input_tmp, 'IMAGES', 'system.map'), 'w') as f:
      for key in sorted(file_map_list.keys()):
        f.write('{} {}\n'.format(key, file_map_list[key]))

    # Get the target zip file.
    input_file = common.MakeTempFile()
    all_entries = ['SYSTEM/', 'SYSTEM/abc', 'IMAGES/',
                   'IMAGES/system.map', 'IMAGES/system.img']
    with zipfile.ZipFile(input_file, 'w') as input_zip:
      for name in all_entries:
        input_zip.write(os.path.join(input_tmp, name), arcname=name)

    with zipfile.ZipFile(input_file) as input_zip:
      info_dict = {'extfs_sparse_flag': '-s'}
      ValidateFileConsistency(input_zip, input_tmp, info_dict)
