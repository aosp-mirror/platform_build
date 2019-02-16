#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

"""
This script merges two partial target files packages (one of which contains
system files, and the other contains non-system files) together, producing a
complete target files package that can be used to generate an OTA package.

Usage: merge_target_files.py [args]

  --system-target-files system-target-files-zip-archive
      The input target files package containing system bits. This is a zip
      archive.

  --other-target-files other-target-files-zip-archive
      The input target files package containing other bits. This is a zip
      archive.

  --output-target-files output-target-files-package
      The output merged target files package. Also a zip archive.
"""

from __future__ import print_function

import argparse
import fnmatch
import logging
import os
import sys
import zipfile

import common
import add_img_to_target_files

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS
OPTIONS.verbose = True

# system_extract_as_is_item_list is a list of items to extract from the partial
# system target files package as is, meaning these items will land in the
# output target files package exactly as they appear in the input partial
# system target files package.

system_extract_as_is_item_list = [
    'META/apkcerts.txt',
    'META/filesystem_config.txt',
    'META/root_filesystem_config.txt',
    'META/system_manifest.xml',
    'META/system_matrix.xml',
    'META/update_engine_config.txt',
    'PRODUCT/*',
    'ROOT/*',
    'SYSTEM/*',
]

# system_extract_special_item_list is a list of items to extract from the
# partial system target files package that need some special processing, such
# as some sort of combination with items from the partial other target files
# package.

system_extract_special_item_list = [
    'META/*',
]

# system_misc_info_keys is a list of keys to obtain from the system instance of
# META/misc_info.txt. The remaining keys from the other instance.

system_misc_info_keys = [
    'avb_system_hashtree_enable',
    'avb_system_add_hashtree_footer_args',
    'avb_system_key_path',
    'avb_system_algorithm',
    'avb_system_rollback_index_location',
    'avb_product_hashtree_enable',
    'avb_product_add_hashtree_footer_args',
    'avb_product_services_hashtree_enable',
    'avb_product_services_add_hashtree_footer_args',
    'system_root_image',
    'root_dir',
    'ab_update',
    'default_system_dev_certificate',
    'system_size',
]

# other_extract_as_is_item_list is a list of items to extract from the partial
# other target files package as is, meaning these items will land in the output
# target files package exactly as they appear in the input partial other target
# files package.

other_extract_as_is_item_list = [
    'META/boot_filesystem_config.txt',
    'META/otakeys.txt',
    'META/releasetools.py',
    'META/vendor_filesystem_config.txt',
    'META/vendor_manifest.xml',
    'META/vendor_matrix.xml',
    'BOOT/*',
    'DATA/*',
    'ODM/*',
    'OTA/android-info.txt',
    'PREBUILT_IMAGES/*',
    'RADIO/*',
    'VENDOR/*',
]

# other_extract_for_merge_item_list is a list of items to extract from the
# partial other target files package that need some special processing, such as
# some sort of combination with items from the partial system target files
# package.

other_extract_special_item_list = [
    'META/*',
]


def extract_items(target_files, target_files_temp_dir, extract_item_list):
  """Extract items from target files to temporary directory.

  This function extracts from the specified target files zip archive into the
  specified temporary directory, the items specified in the extract item list.

  Args:
    target_files: The target files zip archive from which to extract items.

    target_files_temp_dir: The temporary directory where the extracted items
    will land.

    extract_item_list: A list of items to extract.

  Returns:
    On success, 0. Otherwise, a non-zero exit code from unzip.
  """

  logger.info('extracting from %s', target_files)

  # Filter the extract_item_list to remove any items that do not exist in the
  # zip file. Otherwise, the extraction step will fail.

  with zipfile.ZipFile(
      target_files,
      'r',
      allowZip64=True) as target_files_zipfile:
    target_files_namelist = target_files_zipfile.namelist()

  filtered_extract_item_list = []
  for pattern in extract_item_list:
    matching_namelist = fnmatch.filter(target_files_namelist, pattern)
    if not matching_namelist:
      logger.warning('no match for %s', pattern)
    else:
      filtered_extract_item_list.append(pattern)

  # Extract the filtered_extract_item_list from target_files into
  # target_files_temp_dir.

  # TODO(b/124464492): Extend common.UnzipTemp() to handle this use case.
  command = [
      'unzip',
      '-n',
      '-q',
      '-d', target_files_temp_dir,
      target_files
  ] + filtered_extract_item_list

  result = common.RunAndWait(command, verbose=True)

  if result != 0:
    logger.error('extract_items command %s failed %d', str(command), result)
    return result

  return 0


def process_ab_partitions_txt(
    system_target_files_temp_dir,
    other_target_files_temp_dir,
    output_target_files_temp_dir):
  """Perform special processing for META/ab_partitions.txt

  This function merges the contents of the META/ab_partitions.txt files from
  the system directory and the other directory, placing the merged result in
  the output directory. The precondition in that the files are already
  extracted. The post condition is that the output META/ab_partitions.txt
  contains the merged content. The format for each ab_partitions.txt a one
  partition name per line. The output file contains the union of the parition
  names.

  Args:
    system_target_files_temp_dir: The name of a directory containing the
    special items extracted from the system target files package.

    other_target_files_temp_dir: The name of a directory containing the
    special items extracted from the other target files package.

    output_target_files_temp_dir: The name of a directory that will be used
    to create the output target files package after all the special cases
    are processed.
  """

  system_ab_partitions_txt = os.path.join(
      system_target_files_temp_dir, 'META', 'ab_partitions.txt')

  other_ab_partitions_txt = os.path.join(
      other_target_files_temp_dir, 'META', 'ab_partitions.txt')

  with open(system_ab_partitions_txt) as f:
    system_ab_partitions = f.read().splitlines()

  with open(other_ab_partitions_txt) as f:
    other_ab_partitions = f.read().splitlines()

  output_ab_partitions = set(system_ab_partitions + other_ab_partitions)

  output_ab_partitions_txt = os.path.join(
      output_target_files_temp_dir, 'META', 'ab_partitions.txt')

  with open(output_ab_partitions_txt, 'w') as output:
    for partition in sorted(output_ab_partitions):
      output.write('%s\n' % partition)


def process_misc_info_txt(
    system_target_files_temp_dir,
    other_target_files_temp_dir,
    output_target_files_temp_dir):
  """Perform special processing for META/misc_info.txt

  This function merges the contents of the META/misc_info.txt files from the
  system directory and the other directory, placing the merged result in the
  output directory. The precondition in that the files are already extracted.
  The post condition is that the output META/misc_info.txt contains the merged
  content.

  Args:
    system_target_files_temp_dir: The name of a directory containing the
    special items extracted from the system target files package.

    other_target_files_temp_dir: The name of a directory containing the
    special items extracted from the other target files package.

    output_target_files_temp_dir: The name of a directory that will be used
    to create the output target files package after all the special cases
    are processed.
  """

  def read_helper(d):
    misc_info_txt = os.path.join(d, 'META', 'misc_info.txt')
    with open(misc_info_txt) as f:
      return list(f.read().splitlines())

  system_info_dict = common.LoadDictionaryFromLines(
      read_helper(system_target_files_temp_dir))

  # We take most of the misc info from the other target files.

  merged_info_dict = common.LoadDictionaryFromLines(
      read_helper(other_target_files_temp_dir))

  # Replace certain values in merged_info_dict with values from
  # system_info_dict. TODO(b/124467065): This should be more flexible than
  # using the hard-coded system_misc_info_keys.

  for key in system_misc_info_keys:
    merged_info_dict[key] = system_info_dict[key]

  output_misc_info_txt = os.path.join(
      output_target_files_temp_dir,
      'META', 'misc_info.txt')

  sorted_keys = sorted(merged_info_dict.keys())

  with open(output_misc_info_txt, 'w') as output:
    for key in sorted_keys:
      output.write('{}={}\n'.format(key, merged_info_dict[key]))


def process_file_contexts_bin(temp_dir, output_target_files_temp_dir):
  """Perform special processing for META/file_contexts.bin.

  This function combines plat_file_contexts and vendor_file_contexts, which are
  expected to already be extracted in temp_dir, to produce a merged
  file_contexts.bin that will land in temp_dir at META/file_contexts.bin.

  Args:
    temp_dir: The name of a scratch directory that this function can use for
    intermediate files generated during processing.

    output_target_files_temp_dir: The name of the working directory that must
    already contain plat_file_contexts and vendor_file_contexts (in the
    appropriate sub directories), and to which META/file_contexts.bin will be
    written.

  Returns:
    On success, 0. Otherwise, a non-zero exit code.
  """

  # To create a merged file_contexts.bin file, we use the system and vendor
  # file contexts files as input, the m4 tool to combine them, the sorting tool
  # to sort, and finally the sefcontext_compile tool to generate the final
  # output. We currently omit a checkfc step since the files had been checked
  # as part of the build.

  # The m4 step concatenates the two input files contexts files. Since m4
  # writes to stdout, we receive that into an array of bytes, and then write it
  # to a file.

  # Collect the file contexts that we're going to combine from SYSTEM, VENDOR,
  # PRODUCT, and ODM. We require SYSTEM and VENDOR, but others are optional.

  file_contexts_list = []

  for partition in ['SYSTEM', 'VENDOR', 'PRODUCT', 'ODM']:
    prefix = 'plat' if partition == 'SYSTEM' else partition.lower()

    file_contexts = os.path.join(
        output_target_files_temp_dir,
        partition, 'etc', 'selinux', prefix + '_file_contexts')

    mandatory = partition in ['SYSTEM', 'VENDOR']

    if mandatory or os.path.isfile(file_contexts):
      file_contexts_list.append(file_contexts)
    else:
      logger.warning('file not found: %s', file_contexts)

  command = ['m4', '--fatal-warnings', '-s'] + file_contexts_list

  merged_content = common.RunAndCheckOutput(command, verbose=False)

  merged_file_contexts_txt = os.path.join(temp_dir, 'merged_file_contexts.txt')

  with open(merged_file_contexts_txt, 'wb') as f:
    f.write(merged_content)

  # The sort step sorts the concatenated file.

  sorted_file_contexts_txt = os.path.join(temp_dir, 'sorted_file_contexts.txt')
  command = ['fc_sort', merged_file_contexts_txt, sorted_file_contexts_txt]

  # TODO(b/124521133): Refector RunAndWait to raise exception on failure.
  result = common.RunAndWait(command, verbose=True)

  if result != 0:
    return result

  # Finally, the compile step creates the final META/file_contexts.bin.

  file_contexts_bin = os.path.join(
      output_target_files_temp_dir,
      'META', 'file_contexts.bin')

  command = [
      'sefcontext_compile',
      '-o', file_contexts_bin,
      sorted_file_contexts_txt,
  ]

  result = common.RunAndWait(command, verbose=True)

  if result != 0:
    return result

  return 0


def process_special_cases(
    temp_dir,
    system_target_files_temp_dir,
    other_target_files_temp_dir,
    output_target_files_temp_dir):
  """Perform special-case processing for certain target files items.

  Certain files in the output target files package require special-case
  processing. This function performs all that special-case processing.

  Args:
    temp_dir: The name of a scratch directory that this function can use for
    intermediate files generated during processing.

    system_target_files_temp_dir: The name of a directory containing the
    special items extracted from the system target files package.

    other_target_files_temp_dir: The name of a directory containing the
    special items extracted from the other target files package.

    output_target_files_temp_dir: The name of a directory that will be used
    to create the output target files package after all the special cases
    are processed.

  Returns:
    On success, 0. Otherwise, a non-zero exit code.
  """

  process_ab_partitions_txt(
      system_target_files_temp_dir=system_target_files_temp_dir,
      other_target_files_temp_dir=other_target_files_temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir)

  process_misc_info_txt(
      system_target_files_temp_dir=system_target_files_temp_dir,
      other_target_files_temp_dir=other_target_files_temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir)

  result = process_file_contexts_bin(
      temp_dir=temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir)

  if result != 0:
    return result

  return 0


def merge_target_files(
    temp_dir,
    system_target_files,
    other_target_files,
    output_target_files):
  """Merge two target files packages together.

  This function takes system and other target files packages as input, performs
  various file extractions, special case processing, and finally creates a
  merged zip archive as output.

  Args:
    temp_dir: The name of a directory we use when we extract items from the
    input target files packages, and also a scratch directory that we use for
    temporary files.

    system_target_files: The name of the zip archive containing the system
    partial target files package.

    other_target_files: The name of the zip archive containing the other
    partial target files package.

    output_target_files: The name of the output zip archive target files
    package created by merging system and other.

  Returns:
    On success, 0. Otherwise, a non-zero exit code.
  """

  # Create directory names that we'll use when we extract files from system,
  # and other, and for zipping the final output.

  system_target_files_temp_dir = os.path.join(temp_dir, 'system')
  other_target_files_temp_dir = os.path.join(temp_dir, 'other')
  output_target_files_temp_dir = os.path.join(temp_dir, 'output')

  # Extract "as is" items from the input system partial target files package.
  # We extract them directly into the output temporary directory since the
  # items do not need special case processing.

  result = extract_items(
      target_files=system_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=system_extract_as_is_item_list)

  if result != 0:
    return result

  # Extract "as is" items from the input other partial target files package. We
  # extract them directly into the output temporary directory since the items
  # do not need special case processing.

  result = extract_items(
      target_files=other_target_files,
      target_files_temp_dir=output_target_files_temp_dir,
      extract_item_list=other_extract_as_is_item_list)

  if result != 0:
    return result

  # Extract "special" items from the input system partial target files package.
  # We extract these items to different directory since they require special
  # processing before they will end up in the output directory.

  result = extract_items(
      target_files=system_target_files,
      target_files_temp_dir=system_target_files_temp_dir,
      extract_item_list=system_extract_special_item_list)

  if result != 0:
    return result

  # Extract "special" items from the input other partial target files package.
  # We extract these items to different directory since they require special
  # processing before they will end up in the output directory.

  result = extract_items(
      target_files=other_target_files,
      target_files_temp_dir=other_target_files_temp_dir,
      extract_item_list=other_extract_special_item_list)

  if result != 0:
    return result

  # Now that the temporary directories contain all the extracted files, perform
  # special case processing on any items that need it. After this function
  # completes successfully, all the files we need to create the output target
  # files package are in place.

  result = process_special_cases(
      temp_dir=temp_dir,
      system_target_files_temp_dir=system_target_files_temp_dir,
      other_target_files_temp_dir=other_target_files_temp_dir,
      output_target_files_temp_dir=output_target_files_temp_dir)

  if result != 0:
    return result

  # Regenerate IMAGES in the temporary directory.

  add_img_args = [
      '--verbose',
      output_target_files_temp_dir,
  ]

  add_img_to_target_files.main(add_img_args)

  # Finally, create the output target files zip archive.

  output_zip = os.path.abspath(output_target_files)
  output_target_files_list = os.path.join(temp_dir, 'output.list')
  output_target_files_meta_dir = os.path.join(
      output_target_files_temp_dir, 'META')

  command = [
      'find',
      output_target_files_meta_dir,
  ]
  # TODO(bpeckham): sort this to be more like build.
  meta_content = common.RunAndCheckOutput(command, verbose=False)
  command = [
      'find',
      output_target_files_temp_dir,
      '-path',
      output_target_files_meta_dir,
      '-prune',
      '-o',
      '-print'
  ]
  # TODO(bpeckham): sort this to be more like build.
  other_content = common.RunAndCheckOutput(command, verbose=False)

  with open(output_target_files_list, 'wb') as f:
    f.write(meta_content)
    f.write(other_content)

  command = [
      # TODO(124468071): Use soong_zip from otatools.zip
      'prebuilts/build-tools/linux-x86/bin/soong_zip',
      '-d',
      '-o', output_zip,
      '-C', output_target_files_temp_dir,
      '-l', output_target_files_list,
  ]
  logger.info('creating %s', output_target_files)
  result = common.RunAndWait(command, verbose=True)

  if result != 0:
    logger.error('zip command %s failed %d', str(command), result)
    return result

  return 0


def merge_target_files_with_temp_dir(
    system_target_files,
    other_target_files,
    output_target_files,
    keep_tmp):
  """Manage the creation and cleanup of the temporary directory.

  This function wraps merge_target_files after first creating a temporary
  directory. It also cleans up the temporary directory.

  Args:
    system_target_files: The name of the zip archive containing the system
    partial target files package.

    other_target_files: The name of the zip archive containing the other
    partial target files package.

    output_target_files: The name of the output zip archive target files
    package created by merging system and other.

    keep_tmp: Keep the temporary directory after processing is complete.

  Returns:
    On success, 0. Otherwise, a non-zero exit code.
  """

  # Create a temporary directory. This will serve as the parent of directories
  # we use when we extract items from the input target files packages, and also
  # a scratch directory that we use for temporary files.

  logger.info(
      'starting: merge system %s and other %s into output %s',
      system_target_files,
      other_target_files,
      output_target_files)

  temp_dir = common.MakeTempDir(prefix='merge_target_files_')

  try:
    return merge_target_files(
        temp_dir=temp_dir,
        system_target_files=system_target_files,
        other_target_files=other_target_files,
        output_target_files=output_target_files)
  except:
    raise
  finally:
    if keep_tmp:
      logger.info('keeping %s', temp_dir)
    else:
      common.Cleanup()


def main():
  """The main function.

  Process command line arguments, then call merge_target_files_with_temp_dir to
  perform the heavy lifting.

  Returns:
    On success, 0. Otherwise, a non-zero exit code.
  """

  common.InitLogging()

  parser = argparse.ArgumentParser()

  parser.add_argument(
      '--system-target-files',
      required=True,
      help='The input target files package containing system bits.')

  parser.add_argument(
      '--other-target-files',
      required=True,
      help='The input target files package containing other bits.')

  parser.add_argument(
      '--output-target-files',
      required=True,
      help='The output merged target files package.')

  parser.add_argument(
      '--keep-tmp',
      required=False,
      action='store_true',
      help='Keep the temporary directories after execution.')

  args = parser.parse_args()

  return merge_target_files_with_temp_dir(
      system_target_files=args.system_target_files,
      other_target_files=args.other_target_files,
      output_target_files=args.output_target_files,
      keep_tmp=args.keep_tmp)


if __name__ == '__main__':
  sys.exit(main())
