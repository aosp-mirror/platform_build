#!/usr/bin/env python
#
# Copyright (C) 2008 The Android Open Source Project
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
Given an input target-files, produces an image zipfile suitable for use with
'fastboot update'.

Usage:  img_from_target_files [flags] input_target_files output_image_zip

input_target_files: Path to the input target_files zip.

Flags:
  -z  (--bootable_zip)
      Include only the bootable images (eg 'boot' and 'recovery') in
      the output.

  --additional <filespec>
      Include an additional entry into the generated zip file. The filespec is
      in a format that's accepted by zip2zip (e.g.
      'OTA/android-info.txt:android-info.txt', to copy `OTA/android-info.txt`
      from input_file into output_file as `android-info.txt`. Refer to the
      `filespec` arg in zip2zip's help message). The option can be repeated to
      include multiple entries.

  --exclude <filespec>
      Don't include these files. If the file is in --additional and --exclude,
      the file will not be included.

"""

from __future__ import print_function

import logging
import os
import sys
import zipfile

import common
from build_super_image import BuildSuperImage

if sys.hexversion < 0x02070000:
  print('Python 2.7 or newer is required.', file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

OPTIONS.additional_entries = []
OPTIONS.excluded_entries = []
OPTIONS.bootable_only = False
OPTIONS.put_super = None
OPTIONS.put_bootloader = None
OPTIONS.dynamic_partition_list = None
OPTIONS.super_device_list = None
OPTIONS.retrofit_dap = None
OPTIONS.build_super = None
OPTIONS.sparse_userimages = None
OPTIONS.use_fastboot_info = True
OPTIONS.build_super_image = None


def LoadOptions(input_file):
  """Loads information from input_file to OPTIONS.

  Args:
    input_file: Path to the input target_files zip file.
  """
  with zipfile.ZipFile(input_file) as input_zip:
    info = OPTIONS.info_dict = common.LoadInfoDict(input_zip)

  OPTIONS.put_super = info.get('super_image_in_update_package') == 'true'
  OPTIONS.put_bootloader = info.get('bootloader_in_update_package') == 'true'
  OPTIONS.dynamic_partition_list = info.get('dynamic_partition_list',
                                            '').strip().split()
  OPTIONS.super_device_list = info.get('super_block_devices',
                                       '').strip().split()
  OPTIONS.retrofit_dap = info.get('dynamic_partition_retrofit') == 'true'
  OPTIONS.build_super = info.get('build_super_partition') == 'true'
  OPTIONS.sparse_userimages = bool(info.get('extfs_sparse_flag'))


def CopyZipEntries(input_file, output_file, entries):
  """Copies ZIP entries between input and output files.

  Args:
    input_file: Path to the input target_files zip.
    output_file: Output filename.
    entries: A list of entries to copy, in a format that's accepted by zip2zip
        (e.g. 'OTA/android-info.txt:android-info.txt', which copies
        `OTA/android-info.txt` from input_file into output_file as
        `android-info.txt`. Refer to the `filespec` arg in zip2zip's help
        message).
  """
  logger.info('Writing %d entries to archive...', len(entries))
  cmd = ['zip2zip', '-i', input_file, '-o', output_file]
  cmd.extend(entries)
  common.RunAndCheckOutput(cmd)


def LocatePartitionEntry(partition_name, namelist):
  for subdir in ["IMAGES", "PREBUILT_IMAGES", "RADIO"]:
    entry_name = os.path.join(subdir, partition_name + ".img")
    if entry_name in namelist:
      return entry_name


def EntriesForUserImages(input_file):
  """Returns the user images entries to be copied.

  Args:
    input_file: Path to the input target_files zip file.
  """
  dynamic_images = [p + '.img' for p in OPTIONS.dynamic_partition_list]

  # Filter out system_other for launch DAP devices because it is in super image.
  if not OPTIONS.retrofit_dap and 'system' in OPTIONS.dynamic_partition_list:
    dynamic_images.append('system_other.img')

  entries = [
      'OTA/android-info.txt:android-info.txt',
  ]
  if OPTIONS.use_fastboot_info:
    entries.append('META/fastboot-info.txt:fastboot-info.txt')
  ab_partitions = []
  with zipfile.ZipFile(input_file) as input_zip:
    namelist = input_zip.namelist()
    if "META/ab_partitions.txt" in namelist:
      ab_partitions = input_zip.read(
          "META/ab_partitions.txt").decode().strip().split()
  if 'PREBUILT_IMAGES/kernel_16k' in namelist:
    entries.append('PREBUILT_IMAGES/kernel_16k:kernel_16k')
  if 'PREBUILT_IMAGES/ramdisk_16k.img' in namelist:
    entries.append('PREBUILT_IMAGES/ramdisk_16k.img:ramdisk_16k.img')

  visited_partitions = set(OPTIONS.dynamic_partition_list)
  for image_path in [name for name in namelist if name.startswith('IMAGES/')]:
    image = os.path.basename(image_path)
    if OPTIONS.bootable_only and image not in ('boot.img', 'recovery.img', 'bootloader', 'init_boot.img'):
      continue
    if not image.endswith('.img') and image != 'bootloader':
      continue
    if image == 'bootloader' and not OPTIONS.put_bootloader:
      continue
    # Filter out super_empty and the images that are already in super partition.
    if OPTIONS.put_super:
      if image == 'super_empty.img':
        continue
      if image in dynamic_images:
        continue
    partition_name = image.rstrip(".img")
    visited_partitions.add(partition_name)
    entries.append('{}:{}'.format(image_path, image))
  for part in [part for part in ab_partitions if part not in visited_partitions]:
    entry = LocatePartitionEntry(part, namelist)
    image = os.path.basename(entry)
    if entry is not None:
      entries.append('{}:{}'.format(entry, image))
  return entries


def EntriesForSplitSuperImages(input_file):
  """Returns the entries for split super images.

  This is only done for retrofit dynamic partition devices.

  Args:
    input_file: Path to the input target_files zip file.
  """
  with zipfile.ZipFile(input_file) as input_zip:
    namelist = input_zip.namelist()
  entries = []
  for device in OPTIONS.super_device_list:
    image = 'OTA/super_{}.img'.format(device)
    assert image in namelist, 'Failed to find {}'.format(image)
    entries.append('{}:{}'.format(image, os.path.basename(image)))
  return entries


def RebuildAndWriteSuperImages(input_file, output_file):
  """Builds and writes super images to the output file."""
  logger.info('Building super image...')

  # We need files under IMAGES/, OTA/, META/ for img_from_target_files.py.
  # However, common.LoadInfoDict() may read additional files under BOOT/,
  # RECOVERY/ and ROOT/. So unzip everything from the target_files.zip.
  input_tmp = common.UnzipTemp(input_file)

  super_file = common.MakeTempFile('super_', '.img')

  # Allow overriding the BUILD_SUPER_IMAGE binary
  if OPTIONS.build_super_image:
    command = [OPTIONS.build_super_image, input_tmp, super_file]
    common.RunAndCheckOutput(command)
  else:
    BuildSuperImage(input_tmp, super_file)

  logger.info('Writing super.img to archive...')
  with zipfile.ZipFile(
          output_file, 'a', compression=zipfile.ZIP_DEFLATED,
          allowZip64=True) as output_zip:
    common.ZipWrite(output_zip, super_file, 'super.img')


def ImgFromTargetFiles(input_file, output_file):
  """Creates an image archive from the input target_files zip.

  Args:
    input_file: Path to the input target_files zip.
    output_file: Output filename.

  Raises:
    ValueError: On invalid input.
  """
  if not os.path.exists(input_file):
    raise ValueError('%s is not exist' % input_file)

  if not zipfile.is_zipfile(input_file):
    raise ValueError('%s is not a valid zipfile' % input_file)

  logger.info('Building image zip from target files zip.')

  LoadOptions(input_file)

  # Entries to be copied into the output file.
  entries = EntriesForUserImages(input_file)

  # Only for devices that retrofit dynamic partitions there're split super
  # images available in the target_files.zip.
  rebuild_super = False
  if OPTIONS.build_super and OPTIONS.put_super:
    if OPTIONS.retrofit_dap:
      entries += EntriesForSplitSuperImages(input_file)
    else:
      rebuild_super = True

  # Any additional entries provided by caller.
  entries += OPTIONS.additional_entries

  # Remove any excluded entries
  entries = [e for e in entries if e not in OPTIONS.excluded_entries]

  CopyZipEntries(input_file, output_file, entries)

  if rebuild_super:
    RebuildAndWriteSuperImages(input_file, output_file)


def main(argv):

  def option_handler(o, a):
    if o in ('-z', '--bootable_zip'):
      OPTIONS.bootable_only = True
    elif o == '--additional':
      OPTIONS.additional_entries.append(a)
    elif o == '--exclude':
      OPTIONS.excluded_entries.append(a)
    elif o == '--build_super_image':
      OPTIONS.build_super_image = a
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts='z',
                             extra_long_opts=[
                                 'additional=',
                                 'exclude=',
                                 'bootable_zip',
                                 'build_super_image=',
                             ],
                             extra_option_handler=option_handler)
  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  ImgFromTargetFiles(args[0], args[1])

  logger.info('done.')


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  finally:
    common.Cleanup()
