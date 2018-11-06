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

import common
import test_utils
import verity_utils
from validate_target_files import ValidateVerifiedBootImages
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

  def test_ValidateVerifiedBootImages_bootImage_corrupted(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    boot_image = os.path.join(input_tmp, 'IMAGES', 'boot.img')
    self._generate_boot_image(boot_image)

    # Corrupt the late byte of the image.
    with open(boot_image, 'r+b') as boot_fp:
      boot_fp.seek(-1, os.SEEK_END)
      last_byte = boot_fp.read(1)
      last_byte = chr(255 - ord(last_byte))
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

  def _generate_system_image(self, output_file):
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
    system_root = common.MakeTempDir()
    cmd = ['mkuserimg_mke2fs', '-s', system_root, output_file, 'ext4',
           '/system', str(image_size), '-j', '0']
    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    self.assertEqual(
        0, proc.returncode,
        "Failed to create system image with mkuserimg_mke2fs: {}".format(
            stdoutdata))

    # Append the verity metadata.
    verity_image_builder.Build(output_file)

  def test_ValidateVerifiedBootImages_systemImage(self):
    input_tmp = common.MakeTempDir()
    os.mkdir(os.path.join(input_tmp, 'IMAGES'))
    system_image = os.path.join(input_tmp, 'IMAGES', 'system.img')
    self._generate_system_image(system_image)

    # Pack the verity key.
    verity_key_mincrypt = os.path.join(
        input_tmp, 'BOOT', 'RAMDISK', 'verity_key')
    os.makedirs(os.path.dirname(verity_key_mincrypt))
    shutil.copyfile(
        os.path.join(self.testdata_dir, 'testkey_mincrypt'),
        verity_key_mincrypt)

    info_dict = {
        'verity' : 'true',
    }
    options = {
        'verity_key' : os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        'verity_key_mincrypt' : verity_key_mincrypt,
    }
    ValidateVerifiedBootImages(input_tmp, info_dict, options)
