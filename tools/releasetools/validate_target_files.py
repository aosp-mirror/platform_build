#!/usr/bin/env python

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

"""
Validate a given (signed) target_files.zip.

It performs the following checks to assert the integrity of the input zip.

 - It verifies the file consistency between the ones in IMAGES/system.img (read
   via IMAGES/system.map) and the ones under unpacked folder of SYSTEM/. The
   same check also applies to the vendor image if present.

 - It verifies the install-recovery script consistency, by comparing the
   checksums in the script against the ones of IMAGES/{boot,recovery}.img.

 - It verifies the signed Verified Boot related images, for both of Verified
   Boot 1.0 and 2.0 (aka AVB).
"""

import argparse
import filecmp
import logging
import os.path
import re
import zipfile

import common


def _ReadFile(file_name, unpacked_name, round_up=False):
  """Constructs and returns a File object. Rounds up its size if needed."""

  assert os.path.exists(unpacked_name)
  with open(unpacked_name, 'rb') as f:
    file_data = f.read()
  file_size = len(file_data)
  if round_up:
    file_size_rounded_up = common.RoundUpTo4K(file_size)
    file_data += '\0' * (file_size_rounded_up - file_size)
  return common.File(file_name, file_data)


def ValidateFileAgainstSha1(input_tmp, file_name, file_path, expected_sha1):
  """Check if the file has the expected SHA-1."""

  logging.info('Validating the SHA-1 of %s', file_name)
  unpacked_name = os.path.join(input_tmp, file_path)
  assert os.path.exists(unpacked_name)
  actual_sha1 = _ReadFile(file_name, unpacked_name, False).sha1
  assert actual_sha1 == expected_sha1, \
      'SHA-1 mismatches for {}. actual {}, expected {}'.format(
          file_name, actual_sha1, expected_sha1)


def ValidateFileConsistency(input_zip, input_tmp, info_dict):
  """Compare the files from image files and unpacked folders."""

  def CheckAllFiles(which):
    logging.info('Checking %s image.', which)
    # Allow having shared blocks when loading the sparse image, because allowing
    # that doesn't affect the checks below (we will have all the blocks on file,
    # unless it's skipped due to the holes).
    image = common.GetSparseImage(which, input_tmp, input_zip, True)
    prefix = '/' + which
    for entry in image.file_map:
      # Skip entries like '__NONZERO-0'.
      if not entry.startswith(prefix):
        continue

      # Read the blocks that the file resides. Note that it will contain the
      # bytes past the file length, which is expected to be padded with '\0's.
      ranges = image.file_map[entry]

      # Use the original RangeSet if applicable, which includes the shared
      # blocks. And this needs to happen before checking the monotonicity flag.
      if ranges.extra.get('uses_shared_blocks'):
        file_ranges = ranges.extra['uses_shared_blocks']
      else:
        file_ranges = ranges

      incomplete = file_ranges.extra.get('incomplete', False)
      if incomplete:
        logging.warning('Skipping %s that has incomplete block list', entry)
        continue

      # TODO(b/79951650): Handle files with non-monotonic ranges.
      if not file_ranges.monotonic:
        logging.warning(
            'Skipping %s that has non-monotonic ranges: %s', entry, file_ranges)
        continue

      blocks_sha1 = image.RangeSha1(file_ranges)

      # The filename under unpacked directory, such as SYSTEM/bin/sh.
      unpacked_name = os.path.join(
          input_tmp, which.upper(), entry[(len(prefix) + 1):])
      unpacked_file = _ReadFile(entry, unpacked_name, True)
      file_sha1 = unpacked_file.sha1
      assert blocks_sha1 == file_sha1, \
          'file: %s, range: %s, blocks_sha1: %s, file_sha1: %s' % (
              entry, file_ranges, blocks_sha1, file_sha1)

  logging.info('Validating file consistency.')

  # TODO(b/79617342): Validate non-sparse images.
  if info_dict.get('extfs_sparse_flag') != '-s':
    logging.warning('Skipped due to target using non-sparse images')
    return

  # Verify IMAGES/system.img.
  CheckAllFiles('system')

  # Verify IMAGES/vendor.img if applicable.
  if 'VENDOR/' in input_zip.namelist():
    CheckAllFiles('vendor')

  # Not checking IMAGES/system_other.img since it doesn't have the map file.


def ValidateInstallRecoveryScript(input_tmp, info_dict):
  """Validate the SHA-1 embedded in install-recovery.sh.

  install-recovery.sh is written in common.py and has the following format:

  1. full recovery:
  ...
  if ! applypatch --check type:device:size:sha1; then
    applypatch --flash /system/etc/recovery.img \\
        type:device:size:sha1 && \\
  ...

  2. recovery from boot:
  ...
  if ! applypatch --check type:recovery_device:recovery_size:recovery_sha1; then
    applypatch [--bonus bonus_args] \\
        --patch /system/recovery-from-boot.p \\
        --source type:boot_device:boot_size:boot_sha1 \\
        --target type:recovery_device:recovery_size:recovery_sha1 && \\
  ...

  For full recovery, we want to calculate the SHA-1 of /system/etc/recovery.img
  and compare it against the one embedded in the script. While for recovery
  from boot, we want to check the SHA-1 for both recovery.img and boot.img
  under IMAGES/.
  """

  script_path = 'SYSTEM/bin/install-recovery.sh'
  if not os.path.exists(os.path.join(input_tmp, script_path)):
    logging.info('%s does not exist in input_tmp', script_path)
    return

  logging.info('Checking %s', script_path)
  with open(os.path.join(input_tmp, script_path), 'r') as script:
    lines = script.read().strip().split('\n')
  assert len(lines) >= 10
  check_cmd = re.search(r'if ! applypatch --check (\w+:.+:\w+:\w+);',
                        lines[1].strip())
  check_partition = check_cmd.group(1)
  assert len(check_partition.split(':')) == 4

  full_recovery_image = info_dict.get("full_recovery_image") == "true"
  if full_recovery_image:
    assert len(lines) == 10, "Invalid line count: {}".format(lines)

    # Expect something like "EMMC:/dev/block/recovery:28:5f9c..62e3".
    target = re.search(r'--target (.+) &&', lines[4].strip())
    assert target is not None, \
        "Failed to parse target line \"{}\"".format(lines[4])
    flash_partition = target.group(1)

    # Check we have the same recovery target in the check and flash commands.
    assert check_partition == flash_partition, \
        "Mismatching targets: {} vs {}".format(check_partition, flash_partition)

    # Validate the SHA-1 of the recovery image.
    recovery_sha1 = flash_partition.split(':')[3]
    ValidateFileAgainstSha1(
        input_tmp, 'recovery.img', 'SYSTEM/etc/recovery.img', recovery_sha1)
  else:
    assert len(lines) == 11, "Invalid line count: {}".format(lines)

    # --source boot_type:boot_device:boot_size:boot_sha1
    source = re.search(r'--source (\w+:.+:\w+:\w+) \\', lines[4].strip())
    assert source is not None, \
        "Failed to parse source line \"{}\"".format(lines[4])

    source_partition = source.group(1)
    source_info = source_partition.split(':')
    assert len(source_info) == 4, \
        "Invalid source partition: {}".format(source_partition)
    ValidateFileAgainstSha1(input_tmp, file_name='boot.img',
                            file_path='IMAGES/boot.img',
                            expected_sha1=source_info[3])

    # --target recovery_type:recovery_device:recovery_size:recovery_sha1
    target = re.search(r'--target (\w+:.+:\w+:\w+) && \\', lines[5].strip())
    assert target is not None, \
        "Failed to parse target line \"{}\"".format(lines[5])
    target_partition = target.group(1)

    # Check we have the same recovery target in the check and patch commands.
    assert check_partition == target_partition, \
        "Mismatching targets: {} vs {}".format(
            check_partition, target_partition)

    recovery_info = target_partition.split(':')
    assert len(recovery_info) == 4, \
        "Invalid target partition: {}".format(target_partition)
    ValidateFileAgainstSha1(input_tmp, file_name='recovery.img',
                            file_path='IMAGES/recovery.img',
                            expected_sha1=recovery_info[3])

  logging.info('Done checking %s', script_path)


def ValidateVerifiedBootImages(input_tmp, info_dict, options):
  """Validates the Verified Boot related images.

  For Verified Boot 1.0, it verifies the signatures of the bootable images
  (boot/recovery etc), as well as the dm-verity metadata in system images
  (system/vendor/product). For Verified Boot 2.0, it calls avbtool to verify
  vbmeta.img, which in turn verifies all the descriptors listed in vbmeta.

  Args:
    input_tmp: The top-level directory of unpacked target-files.zip.
    info_dict: The loaded info dict.
    options: A dict that contains the user-supplied public keys to be used for
        image verification. In particular, 'verity_key' is used to verify the
        bootable images in VB 1.0, and the vbmeta image in VB 2.0, where
        applicable. 'verity_key_mincrypt' will be used to verify the system
        images in VB 1.0.

  Raises:
    AssertionError: On any verification failure.
  """
  # Verified boot 1.0 (images signed with boot_signer and verity_signer).
  if info_dict.get('boot_signer') == 'true':
    logging.info('Verifying Verified Boot images...')

    # Verify the boot/recovery images (signed with boot_signer), against the
    # given X.509 encoded pubkey (or falling back to the one in the info_dict if
    # none given).
    verity_key = options['verity_key']
    if verity_key is None:
      verity_key = info_dict['verity_key'] + '.x509.pem'
    for image in ('boot.img', 'recovery.img', 'recovery-two-step.img'):
      image_path = os.path.join(input_tmp, 'IMAGES', image)
      if not os.path.exists(image_path):
        continue

      cmd = ['boot_signer', '-verify', image_path, '-certificate', verity_key]
      proc = common.Run(cmd)
      stdoutdata, _ = proc.communicate()
      assert proc.returncode == 0, \
          'Failed to verify {} with boot_signer:\n{}'.format(image, stdoutdata)
      logging.info(
          'Verified %s with boot_signer (key: %s):\n%s', image, verity_key,
          stdoutdata.rstrip())

  # Verify verity signed system images in Verified Boot 1.0. Note that not using
  # 'elif' here, since 'boot_signer' and 'verity' are not bundled in VB 1.0.
  if info_dict.get('verity') == 'true':
    # First verify that the verity key that's built into the root image (as
    # /verity_key) matches the one given via command line, if any.
    if info_dict.get("system_root_image") == "true":
      verity_key_mincrypt = os.path.join(input_tmp, 'ROOT', 'verity_key')
    else:
      verity_key_mincrypt = os.path.join(
          input_tmp, 'BOOT', 'RAMDISK', 'verity_key')
    assert os.path.exists(verity_key_mincrypt), 'Missing verity_key'

    if options['verity_key_mincrypt'] is None:
      logging.warn(
          'Skipped checking the content of /verity_key, as the key file not '
          'provided. Use --verity_key_mincrypt to specify.')
    else:
      expected_key = options['verity_key_mincrypt']
      assert filecmp.cmp(expected_key, verity_key_mincrypt, shallow=False), \
          "Mismatching mincrypt verity key files"
      logging.info('Verified the content of /verity_key')

    # Then verify the verity signed system/vendor/product images, against the
    # verity pubkey in mincrypt format.
    for image in ('system.img', 'vendor.img', 'product.img'):
      image_path = os.path.join(input_tmp, 'IMAGES', image)

      # We are not checking if the image is actually enabled via info_dict (e.g.
      # 'system_verity_block_device=...'). Because it's most likely a bug that
      # skips signing some of the images in signed target-files.zip, while
      # having the top-level verity flag enabled.
      if not os.path.exists(image_path):
        continue

      cmd = ['verity_verifier', image_path, '-mincrypt', verity_key_mincrypt]
      proc = common.Run(cmd)
      stdoutdata, _ = proc.communicate()
      assert proc.returncode == 0, \
          'Failed to verify {} with verity_verifier (key: {}):\n{}'.format(
              image, verity_key_mincrypt, stdoutdata)
      logging.info(
          'Verified %s with verity_verifier (key: %s):\n%s', image,
          verity_key_mincrypt, stdoutdata.rstrip())

  # Handle the case of Verified Boot 2.0 (AVB).
  if info_dict.get("avb_enable") == "true":
    logging.info('Verifying Verified Boot 2.0 (AVB) images...')

    key = options['verity_key']
    if key is None:
      key = info_dict['avb_vbmeta_key_path']

    # avbtool verifies all the images that have descriptors listed in vbmeta.
    image = os.path.join(input_tmp, 'IMAGES', 'vbmeta.img')
    cmd = ['avbtool', 'verify_image', '--image', image, '--key', key]

    # Append the args for chained partitions if any.
    for partition in common.AVB_PARTITIONS + common.AVB_VBMETA_PARTITIONS:
      key_name = 'avb_' + partition + '_key_path'
      if info_dict.get(key_name) is not None:
        # Use the key file from command line if specified; otherwise fall back
        # to the one in info dict.
        key_file = options.get(key_name, info_dict[key_name])
        chained_partition_arg = common.GetAvbChainedPartitionArg(
            partition, info_dict, key_file)
        cmd.extend(["--expected_chain_partition", chained_partition_arg])

    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    assert proc.returncode == 0, \
        'Failed to verify {} with avbtool (key: {}):\n{}'.format(
            image, key, stdoutdata)

    logging.info(
        'Verified %s with avbtool (key: %s):\n%s', image, key,
        stdoutdata.rstrip())


def main():
  parser = argparse.ArgumentParser(
      description=__doc__,
      formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument(
      'target_files',
      help='the input target_files.zip to be validated')
  parser.add_argument(
      '--verity_key',
      help='the verity public key to verify the bootable images (Verified '
           'Boot 1.0), or the vbmeta image (Verified Boot 2.0, aka AVB), where '
           'applicable')
  for partition in common.AVB_PARTITIONS + common.AVB_VBMETA_PARTITIONS:
    parser.add_argument(
        '--avb_' + partition + '_key_path',
        help='the public or private key in PEM format to verify AVB chained '
             'partition of {}'.format(partition))
  parser.add_argument(
      '--verity_key_mincrypt',
      help='the verity public key in mincrypt format to verify the system '
           'images, if target using Verified Boot 1.0')
  args = parser.parse_args()

  # Unprovided args will have 'None' as the value.
  options = vars(args)

  logging_format = '%(asctime)s - %(filename)s - %(levelname)-8s: %(message)s'
  date_format = '%Y/%m/%d %H:%M:%S'
  logging.basicConfig(level=logging.INFO, format=logging_format,
                      datefmt=date_format)

  logging.info("Unzipping the input target_files.zip: %s", args.target_files)
  input_tmp = common.UnzipTemp(args.target_files)

  info_dict = common.LoadInfoDict(input_tmp)
  with zipfile.ZipFile(args.target_files, 'r') as input_zip:
    ValidateFileConsistency(input_zip, input_tmp, info_dict)

  ValidateInstallRecoveryScript(input_tmp, info_dict)

  ValidateVerifiedBootImages(input_tmp, info_dict, options)

  # TODO: Check if the OTA keys have been properly updated (the ones on /system,
  # in recovery image).

  logging.info("Done.")


if __name__ == '__main__':
  try:
    main()
  finally:
    common.Cleanup()
