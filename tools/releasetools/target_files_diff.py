#!/usr/bin/env python
#
# Copyright (C) 2009 The Android Open Source Project
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

#
# Finds differences between two target files packages
#

from __future__ import print_function

import argparse
import contextlib
import os
import re
import subprocess
import sys
import tempfile

def ignore(name):
  """
  Files to ignore when diffing

  These are packages that we're already diffing elsewhere,
  or files that we expect to be different for every build,
  or known problems.
  """

  # We're looking at the files that make the images, so no need to search them
  if name in ['IMAGES']:
    return True
  # These are packages of the recovery partition, which we're already diffing
  if name in ['SYSTEM/etc/recovery-resource.dat',
              'SYSTEM/recovery-from-boot.p']:
    return True

  # These files are just the BUILD_NUMBER, and will always be different
  if name in ['BOOT/RAMDISK/selinux_version',
              'RECOVERY/RAMDISK/selinux_version']:
    return True

  return False


def rewrite_build_property(original, new):
  """
  Rewrite property files to remove values known to change for every build
  """

  skipped = ['ro.bootimage.build.date=',
             'ro.bootimage.build.date.utc=',
             'ro.bootimage.build.fingerprint=',
             'ro.build.id=',
             'ro.build.display.id=',
             'ro.build.version.incremental=',
             'ro.build.date=',
             'ro.build.date.utc=',
             'ro.build.host=',
             'ro.build.user=',
             'ro.build.description=',
             'ro.build.fingerprint=',
             'ro.expect.recovery_id=',
             'ro.vendor.build.date=',
             'ro.vendor.build.date.utc=',
             'ro.vendor.build.fingerprint=']

  for line in original:
    skip = False
    for s in skipped:
      if line.startswith(s):
        skip = True
        break
    if not skip:
      new.write(line)


def trim_install_recovery(original, new):
  """
  Rewrite the install-recovery script to remove the hash of the recovery
  partition.
  """
  for line in original:
    new.write(re.sub(r'[0-9a-f]{40}', '0'*40, line))

def sort_file(original, new):
  """
  Sort the file. Some OTA metadata files are not in a deterministic order
  currently.
  """
  lines = original.readlines()
  lines.sort()
  for line in lines:
    new.write(line)

# Map files to the functions that will modify them for diffing
REWRITE_RULES = {
    'BOOT/RAMDISK/default.prop': rewrite_build_property,
    'RECOVERY/RAMDISK/default.prop': rewrite_build_property,
    'SYSTEM/build.prop': rewrite_build_property,
    'VENDOR/build.prop': rewrite_build_property,

    'SYSTEM/bin/install-recovery.sh': trim_install_recovery,

    'META/boot_filesystem_config.txt': sort_file,
    'META/filesystem_config.txt': sort_file,
    'META/recovery_filesystem_config.txt': sort_file,
    'META/vendor_filesystem_config.txt': sort_file,
}

@contextlib.contextmanager
def preprocess(name, filename):
  """
  Optionally rewrite files before diffing them, to remove known-variable
  information.
  """
  if name in REWRITE_RULES:
    with tempfile.NamedTemporaryFile() as newfp:
      with open(filename, 'r') as oldfp:
        REWRITE_RULES[name](oldfp, newfp)
      newfp.flush()
      yield newfp.name
  else:
    yield filename

def diff(name, file1, file2, out_file):
  """
  Diff a file pair with diff, running preprocess() on the arguments first.
  """
  with preprocess(name, file1) as f1:
    with preprocess(name, file2) as f2:
      proc = subprocess.Popen(['diff', f1, f2], stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT)
      (stdout, _) = proc.communicate()
      if proc.returncode == 0:
        return
      stdout = stdout.strip()
      if stdout == 'Binary files %s and %s differ' % (f1, f2):
        print("%s: Binary files differ" % name, file=out_file)
      else:
        for line in stdout.strip().split('\n'):
          print("%s: %s" % (name, line), file=out_file)

def recursiveDiff(prefix, dir1, dir2, out_file):
  """
  Recursively diff two directories, checking metadata then calling diff()
  """
  list1 = sorted(os.listdir(dir1))
  list2 = sorted(os.listdir(dir2))

  for entry in list1:
    name = os.path.join(prefix, entry)
    name1 = os.path.join(dir1, entry)
    name2 = os.path.join(dir2, entry)

    if ignore(name):
      continue

    if entry in list2:
      if os.path.islink(name1) and os.path.islink(name2):
        link1 = os.readlink(name1)
        link2 = os.readlink(name2)
        if link1 != link2:
          print("%s: Symlinks differ: %s vs %s" % (name, link1, link2),
                file=out_file)
        continue
      elif os.path.islink(name1) or os.path.islink(name2):
        print("%s: File types differ, skipping compare" % name, file=out_file)
        continue

      stat1 = os.stat(name1)
      stat2 = os.stat(name2)
      type1 = stat1.st_mode & ~0o777
      type2 = stat2.st_mode & ~0o777

      if type1 != type2:
        print("%s: File types differ, skipping compare" % name, file=out_file)
        continue

      if stat1.st_mode != stat2.st_mode:
        print("%s: Modes differ: %o vs %o" %
            (name, stat1.st_mode, stat2.st_mode), file=out_file)

      if os.path.isdir(name1):
        recursiveDiff(name, name1, name2, out_file)
      elif os.path.isfile(name1):
        diff(name, name1, name2, out_file)
      else:
        print("%s: Unknown file type, skipping compare" % name, file=out_file)
    else:
      print("%s: Only in base package" % name, file=out_file)

  for entry in list2:
    name = os.path.join(prefix, entry)
    name1 = os.path.join(dir1, entry)
    name2 = os.path.join(dir2, entry)

    if ignore(name):
      continue

    if entry not in list1:
      print("%s: Only in new package" % name, file=out_file)

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('dir1', help='The base target files package (extracted)')
  parser.add_argument('dir2', help='The new target files package (extracted)')
  parser.add_argument('--output',
      help='The output file, otherwise it prints to stdout')
  args = parser.parse_args()

  if args.output:
    out_file = open(args.output, 'w')
  else:
    out_file = sys.stdout

  recursiveDiff('', args.dir1, args.dir2, out_file)

  if args.output:
    out_file.close()

if __name__ == '__main__':
  main()
