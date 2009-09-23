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

import os
import re

import common

class EdifyGenerator(object):
  """Class to generate scripts in the 'edify' recovery script language
  used from donut onwards."""

  def __init__(self, version):
    self.script = []
    self.mounts = set()
    self.version = version

  def MakeTemporary(self):
    """Make a temporary script object whose commands can latter be
    appended to the parent script with AppendScript().  Used when the
    caller wants to generate script commands out-of-order."""
    x = EdifyGenerator(self.version)
    x.mounts = self.mounts
    return x

  @staticmethod
  def _WordWrap(cmd, linelen=80):
    """'cmd' should be a function call with null characters after each
    parameter (eg, "somefun(foo,\0bar,\0baz)").  This function wraps cmd
    to a given line length, replacing nulls with spaces and/or newlines
    to format it nicely."""
    indent = cmd.index("(")+1
    out = []
    first = True
    x = re.compile("^(.{,%d})\0" % (linelen-indent,))
    while True:
      if not first:
        out.append(" " * indent)
      first = False
      m = x.search(cmd)
      if not m:
        parts = cmd.split("\0", 1)
        out.append(parts[0]+"\n")
        if len(parts) == 1:
          break
        else:
          cmd = parts[1]
          continue
      out.append(m.group(1)+"\n")
      cmd = cmd[m.end():]

    return "".join(out).replace("\0", " ").rstrip("\n")

  def AppendScript(self, other):
    """Append the contents of another script (which should be created
    with temporary=True) to this one."""
    self.script.extend(other.script)

  def AssertSomeFingerprint(self, *fp):
    """Assert that the current system build fingerprint is one of *fp."""
    if not fp:
      raise ValueError("must specify some fingerprints")
    cmd = ('assert(' +
           ' ||\0'.join([('file_getprop("/system/build.prop", '
                         '"ro.build.fingerprint") == "%s"')
                        % i for i in fp]) +
           ');')
    self.script.append(self._WordWrap(cmd))

  def AssertOlderBuild(self, timestamp):
    """Assert that the build on the device is older (or the same as)
    the given timestamp."""
    self.script.append(('assert(!less_than_int(%s, '
                        'getprop("ro.build.date.utc")));') % (timestamp,))

  def AssertDevice(self, device):
    """Assert that the device identifier is the given string."""
    cmd = ('assert(getprop("ro.product.device") == "%s" ||\0'
           'getprop("ro.build.product") == "%s");' % (device, device))
    self.script.append(self._WordWrap(cmd))

  def AssertSomeBootloader(self, *bootloaders):
    """Asert that the bootloader version is one of *bootloaders."""
    cmd = ("assert(" +
           " ||\0".join(['getprop("ro.bootloader") == "%s"' % (b,)
                         for b in bootloaders]) +
           ");")
    self.script.append(self._WordWrap(cmd))

  def ShowProgress(self, frac, dur):
    """Update the progress bar, advancing it over 'frac' over the next
    'dur' seconds.  'dur' may be zero to advance it via SetProgress
    commands instead of by time."""
    self.script.append("show_progress(%f, %d);" % (frac, int(dur)))

  def SetProgress(self, frac):
    """Set the position of the progress bar within the chunk defined
    by the most recent ShowProgress call.  'frac' should be in
    [0,1]."""
    self.script.append("set_progress(%f);" % (frac,))

  def PatchCheck(self, filename, *sha1):
    """Check that the given file (or MTD reference) has one of the
    given *sha1 hashes."""
    self.script.append('assert(apply_patch_check("%s"' % (filename,) +
                       "".join([', "%s"' % (i,) for i in sha1]) +
                       '));')

  def CacheFreeSpaceCheck(self, amount):
    """Check that there's at least 'amount' space that can be made
    available on /cache."""
    self.script.append("assert(apply_patch_space(%d));" % (amount,))

  def Mount(self, kind, what, path):
    """Mount the given 'what' at the given path.  'what' should be a
    partition name if kind is "MTD", or a block device if kind is
    "vfat".  No other values of 'kind' are supported."""
    self.script.append('mount("%s", "%s", "%s");' % (kind, what, path))
    self.mounts.add(path)

  def UnpackPackageDir(self, src, dst):
    """Unpack a given directory from the OTA package into the given
    destination directory."""
    self.script.append('package_extract_dir("%s", "%s");' % (src, dst))

  def Comment(self, comment):
    """Write a comment into the update script."""
    self.script.append("")
    for i in comment.split("\n"):
      self.script.append("# " + i)
    self.script.append("")

  def Print(self, message):
    """Log a message to the screen (if the logs are visible)."""
    self.script.append('ui_print("%s");' % (message,))

  def FormatPartition(self, partition):
    """Format the given MTD partition."""
    self.script.append('format("MTD", "%s");' % (partition,))

  def DeleteFiles(self, file_list):
    """Delete all files in file_list."""
    if not file_list: return
    cmd = "delete(" + ",\0".join(['"%s"' % (i,) for i in file_list]) + ");"
    self.script.append(self._WordWrap(cmd))

  def ApplyPatch(self, srcfile, tgtfile, tgtsize, tgtsha1, *patchpairs):
    """Apply binary patches (in *patchpairs) to the given srcfile to
    produce tgtfile (which may be "-" to indicate overwriting the
    source file."""
    if len(patchpairs) % 2 != 0 or len(patchpairs) == 0:
      raise ValueError("bad patches given to ApplyPatch")
    cmd = ['apply_patch("%s",\0"%s",\0%s,\0%d'
           % (srcfile, tgtfile, tgtsha1, tgtsize)]
    for i in range(0, len(patchpairs), 2):
      cmd.append(',\0"%s:%s"' % patchpairs[i:i+2])
    cmd.append(');')
    cmd = "".join(cmd)
    self.script.append(self._WordWrap(cmd))

  def WriteFirmwareImage(self, kind, fn):
    """Arrange to update the given firmware image (kind must be
    "hboot" or "radio") when recovery finishes."""
    if self.version == 1:
      self.script.append(
          ('assert(package_extract_file("%(fn)s", "/tmp/%(kind)s.img"),\n'
           '       write_firmware_image("/tmp/%(kind)s.img", "%(kind)s"));')
          % {'kind': kind, 'fn': fn})
    else:
      self.script.append(
          'write_firmware_image("PACKAGE:%s", "%s");' % (fn, kind))

  def WriteRawImage(self, partition, fn):
    """Write the given package file into the given MTD partition."""
    self.script.append(
        ('assert(package_extract_file("%(fn)s", "/tmp/%(partition)s.img"),\n'
         '       write_raw_image("/tmp/%(partition)s.img", "%(partition)s"),\n'
         '       delete("/tmp/%(partition)s.img"));')
        % {'partition': partition, 'fn': fn})

  def SetPermissions(self, fn, uid, gid, mode):
    """Set file ownership and permissions."""
    self.script.append('set_perm(%d, %d, 0%o, "%s");' % (uid, gid, mode, fn))

  def SetPermissionsRecursive(self, fn, uid, gid, dmode, fmode):
    """Recursively set path ownership and permissions."""
    self.script.append('set_perm_recursive(%d, %d, 0%o, 0%o, "%s");'
                       % (uid, gid, dmode, fmode, fn))

  def MakeSymlinks(self, symlink_list):
    """Create symlinks, given a list of (dest, link) pairs."""
    by_dest = {}
    for d, l in symlink_list:
      by_dest.setdefault(d, []).append(l)

    for dest, links in sorted(by_dest.iteritems()):
      cmd = ('symlink("%s", ' % (dest,) +
             ",\0".join(['"' + i + '"' for i in sorted(links)]) + ");")
      self.script.append(self._WordWrap(cmd))

  def AppendExtra(self, extra):
    """Append text verbatim to the output script."""
    self.script.append(extra)

  def AddToZip(self, input_zip, output_zip, input_path=None):
    """Write the accumulated script to the output_zip file.  input_zip
    is used as the source for the 'updater' binary needed to run
    script.  If input_path is not None, it will be used as a local
    path for the binary instead of input_zip."""

    for p in sorted(self.mounts):
      self.script.append('unmount("%s");' % (p,))

    common.ZipWriteStr(output_zip, "META-INF/com/google/android/updater-script",
                       "\n".join(self.script) + "\n")

    if input_path is None:
      data = input_zip.read("OTA/bin/updater")
    else:
      data = open(os.path.join(input_path, "updater")).read()
    common.ZipWriteStr(output_zip, "META-INF/com/google/android/update-binary",
                       data, perms=0755)
