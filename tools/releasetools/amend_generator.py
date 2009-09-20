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

import common

class AmendGenerator(object):
  """Class to generate scripts in the 'amend' recovery script language
  used up through cupcake."""

  def __init__(self):
    self.script = ['assert compatible_with("0.2") == "true"']
    self.included_files = set()

  def MakeTemporary(self):
    """Make a temporary script object whose commands can latter be
    appended to the parent script with AppendScript().  Used when the
    caller wants to generate script commands out-of-order."""
    x = AmendGenerator()
    x.script = []
    x.included_files = self.included_files
    return x

  @staticmethod
  def _FileRoot(fn):
    """Convert a file path to the 'root' notation used by amend."""
    if fn.startswith("/system/"):
      return "SYSTEM:" + fn[8:]
    elif fn == "/system":
      return "SYSTEM:"
    elif fn.startswith("/tmp/"):
      return "CACHE:.." + fn
    else:
      raise ValueError("don't know root for \"%s\"" % (fn,))

  @staticmethod
  def _PartitionRoot(partition):
    """Convert a partition name to the 'root' notation used by amend."""
    if partition == "userdata":
      return "DATA:"
    else:
      return partition.upper() + ":"

  def AppendScript(self, other):
    """Append the contents of another script (which should be created
    with temporary=True) to this one."""
    self.script.extend(other.script)
    self.included_files.update(other.included_files)

  def AssertSomeFingerprint(self, *fp):
    """Assert that the current fingerprint is one of *fp."""
    x = [('file_contains("SYSTEM:build.prop", '
          '"ro.build.fingerprint=%s") == "true"') % i for i in fp]
    self.script.append("assert %s" % (" || ".join(x),))

  def AssertOlderBuild(self, timestamp):
    """Assert that the build on the device is older (or the same as)
    the given timestamp."""
    self.script.append("run_program PACKAGE:check_prereq %s" % (timestamp,))
    self.included_files.add("check_prereq")

  def AssertDevice(self, device):
    """Assert that the device identifier is the given string."""
    self.script.append('assert getprop("ro.product.device") == "%s" || '
                       'getprop("ro.build.product") == "%s"' % (device, device))

  def AssertSomeBootloader(self, *bootloaders):
    """Asert that the bootloader version is one of *bootloaders."""
    self.script.append("assert " +
                  " || ".join(['getprop("ro.bootloader") == "%s"' % (b,)
                               for b in bootloaders]))

  def ShowProgress(self, frac, dur):
    """Update the progress bar, advancing it over 'frac' over the next
    'dur' seconds."""
    self.script.append("show_progress %f %d" % (frac, int(dur)))

  def SetProgress(self, frac):
    """Not implemented in amend."""
    pass

  def PatchCheck(self, filename, *sha1):
    """Check that the given file (or MTD reference) has one of the
    given *sha1 hashes."""
    out = ["run_program PACKAGE:applypatch -c %s" % (filename,)]
    for i in sha1:
      out.append(" " + i)
    self.script.append("".join(out))
    self.included_files.add(("applypatch_static", "applypatch"))

  def CacheFreeSpaceCheck(self, amount):
    """Check that there's at least 'amount' space that can be made
    available on /cache."""
    self.script.append("run_program PACKAGE:applypatch -s %d" % (amount,))
    self.included_files.add(("applypatch_static", "applypatch"))

  def Mount(self, kind, what, path):
    # no-op; amend uses it's 'roots' system to automatically mount
    # things when they're referred to
    pass

  def UnpackPackageDir(self, src, dst):
    """Unpack a given directory from the OTA package into the given
    destination directory."""
    dst = self._FileRoot(dst)
    self.script.append("copy_dir PACKAGE:%s %s" % (src, dst))

  def Comment(self, comment):
    """Write a comment into the update script."""
    self.script.append("")
    for i in comment.split("\n"):
      self.script.append("# " + i)
    self.script.append("")

  def Print(self, message):
    """Log a message to the screen (if the logs are visible)."""
    # no way to do this from amend; substitute a script comment instead
    self.Comment(message)

  def FormatPartition(self, partition):
    """Format the given MTD partition."""
    self.script.append("format %s" % (self._PartitionRoot(partition),))

  def DeleteFiles(self, file_list):
    """Delete all files in file_list."""
    line = []
    t = 0
    for i in file_list:
      i = self._FileRoot(i)
      line.append(i)
      t += len(i) + 1
      if t > 80:
        self.script.append("delete " + " ".join(line))
        line = []
        t = 0
    if line:
      self.script.append("delete " + " ".join(line))

  def ApplyPatch(self, srcfile, tgtfile, tgtsize, tgtsha1, *patchpairs):
    """Apply binary patches (in *patchpairs) to the given srcfile to
    produce tgtfile (which may be "-" to indicate overwriting the
    source file."""
    if len(patchpairs) % 2 != 0:
      raise ValueError("bad patches given to ApplyPatch")
    self.script.append(
        ("run_program PACKAGE:applypatch %s %s %s %d " %
         (srcfile, tgtfile, tgtsha1, tgtsize)) +
        " ".join(["%s:%s" % patchpairs[i:i+2]
                  for i in range(0, len(patchpairs), 2)]))
    self.included_files.add(("applypatch_static", "applypatch"))

  def WriteFirmwareImage(self, kind, fn):
    """Arrange to update the given firmware image (kind must be
    "hboot" or "radio") when recovery finishes."""
    self.script.append("write_%s_image PACKAGE:%s" % (kind, fn))

  def WriteRawImage(self, partition, fn):
    """Write the given file into the given MTD partition."""
    self.script.append("write_raw_image PACKAGE:%s %s" %
                       (fn, self._PartitionRoot(partition)))

  def SetPermissions(self, fn, uid, gid, mode):
    """Set file ownership and permissions."""
    fn = self._FileRoot(fn)
    self.script.append("set_perm %d %d 0%o %s" % (uid, gid, mode, fn))

  def SetPermissionsRecursive(self, fn, uid, gid, dmode, fmode):
    """Recursively set path ownership and permissions."""
    fn = self._FileRoot(fn)
    self.script.append("set_perm_recursive %d %d 0%o 0%o %s" %
                       (uid, gid, dmode, fmode, fn))

  def MakeSymlinks(self, symlink_list):
    """Create symlinks, given a list of (dest, link) pairs."""
    self.DeleteFiles([i[1] for i in symlink_list])
    self.script.extend(["symlink %s %s" % (i[0], self._FileRoot(i[1]))
                        for i in sorted(symlink_list)])

  def AppendExtra(self, extra):
    """Append text verbatim to the output script."""
    self.script.append(extra)

  def AddToZip(self, input_zip, output_zip, input_path=None):
    """Write the accumulated script to the output_zip file.  input_zip
    is used as the source for any ancillary binaries needed by the
    script.  If input_path is not None, it will be used as a local
    path for binaries instead of input_zip."""
    common.ZipWriteStr(output_zip, "META-INF/com/google/android/update-script",
                       "\n".join(self.script) + "\n")
    for i in self.included_files:
      if isinstance(i, tuple):
        sourcefn, targetfn = i
      else:
        sourcefn = i
        targetfn = i
      try:
        if input_path is None:
          data = input_zip.read(os.path.join("OTA/bin", sourcefn))
        else:
          data = open(os.path.join(input_path, sourcefn)).read()
        common.ZipWriteStr(output_zip, targetfn, data, perms=0755)
      except (IOError, KeyError), e:
        raise ExternalError("unable to include binary %s: %s" % (i, e))
