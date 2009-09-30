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

import errno
import getopt
import getpass
import imp
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# missing in Python 2.4 and before
if not hasattr(os, "SEEK_SET"):
  os.SEEK_SET = 0

class Options(object): pass
OPTIONS = Options()
OPTIONS.search_path = "out/host/linux-x86"
OPTIONS.max_image_size = {}
OPTIONS.verbose = False
OPTIONS.tempfiles = []
OPTIONS.device_specific = None

class ExternalError(RuntimeError): pass


def Run(args, **kwargs):
  """Create and return a subprocess.Popen object, printing the command
  line on the terminal if -v was specified."""
  if OPTIONS.verbose:
    print "  running: ", " ".join(args)
  return subprocess.Popen(args, **kwargs)


def LoadMaxSizes():
  """Load the maximum allowable images sizes from the input
  target_files size."""
  OPTIONS.max_image_size = {}
  try:
    for line in open(os.path.join(OPTIONS.input_tmp, "META", "imagesizes.txt")):
      pieces = line.split()
      if len(pieces) != 2: continue
      image = pieces[0]
      size = int(pieces[1])
      OPTIONS.max_image_size[image + ".img"] = size
  except IOError, e:
    if e.errno == errno.ENOENT:
      pass


def BuildAndAddBootableImage(sourcedir, targetname, output_zip):
  """Take a kernel, cmdline, and ramdisk directory from the input (in
  'sourcedir'), and turn them into a boot image.  Put the boot image
  into the output zip file under the name 'targetname'.  Returns
  targetname on success or None on failure (if sourcedir does not
  appear to contain files for the requested image)."""

  print "creating %s..." % (targetname,)

  img = BuildBootableImage(sourcedir)
  if img is None:
    return None

  CheckSize(img, targetname)
  ZipWriteStr(output_zip, targetname, img)
  return targetname

def BuildBootableImage(sourcedir):
  """Take a kernel, cmdline, and ramdisk directory from the input (in
  'sourcedir'), and turn them into a boot image.  Return the image
  data, or None if sourcedir does not appear to contains files for
  building the requested image."""

  if (not os.access(os.path.join(sourcedir, "RAMDISK"), os.F_OK) or
      not os.access(os.path.join(sourcedir, "kernel"), os.F_OK)):
    return None

  ramdisk_img = tempfile.NamedTemporaryFile()
  img = tempfile.NamedTemporaryFile()

  p1 = Run(["mkbootfs", os.path.join(sourcedir, "RAMDISK")],
           stdout=subprocess.PIPE)
  p2 = Run(["minigzip"],
           stdin=p1.stdout, stdout=ramdisk_img.file.fileno())

  p2.wait()
  p1.wait()
  assert p1.returncode == 0, "mkbootfs of %s ramdisk failed" % (targetname,)
  assert p2.returncode == 0, "minigzip of %s ramdisk failed" % (targetname,)

  cmd = ["mkbootimg", "--kernel", os.path.join(sourcedir, "kernel")]

  fn = os.path.join(sourcedir, "cmdline")
  if os.access(fn, os.F_OK):
    cmd.append("--cmdline")
    cmd.append(open(fn).read().rstrip("\n"))

  fn = os.path.join(sourcedir, "base")
  if os.access(fn, os.F_OK):
    cmd.append("--base")
    cmd.append(open(fn).read().rstrip("\n"))

  cmd.extend(["--ramdisk", ramdisk_img.name,
              "--output", img.name])

  p = Run(cmd, stdout=subprocess.PIPE)
  p.communicate()
  assert p.returncode == 0, "mkbootimg of %s image failed" % (
      os.path.basename(sourcedir),)

  img.seek(os.SEEK_SET, 0)
  data = img.read()

  ramdisk_img.close()
  img.close()

  return data


def AddRecovery(output_zip):
  BuildAndAddBootableImage(os.path.join(OPTIONS.input_tmp, "RECOVERY"),
                           "recovery.img", output_zip)

def AddBoot(output_zip):
  BuildAndAddBootableImage(os.path.join(OPTIONS.input_tmp, "BOOT"),
                           "boot.img", output_zip)

def UnzipTemp(filename):
  """Unzip the given archive into a temporary directory and return the name."""

  tmp = tempfile.mkdtemp(prefix="targetfiles-")
  OPTIONS.tempfiles.append(tmp)
  p = Run(["unzip", "-o", "-q", filename, "-d", tmp], stdout=subprocess.PIPE)
  p.communicate()
  if p.returncode != 0:
    raise ExternalError("failed to unzip input target-files \"%s\"" %
                        (filename,))
  return tmp


def GetKeyPasswords(keylist):
  """Given a list of keys, prompt the user to enter passwords for
  those which require them.  Return a {key: password} dict.  password
  will be None if the key has no password."""

  no_passwords = []
  need_passwords = []
  devnull = open("/dev/null", "w+b")
  for k in sorted(keylist):
    # An empty-string key is used to mean don't re-sign this package.
    # Obviously we don't need a password for this non-key.
    if not k:
      no_passwords.append(k)
      continue

    p = Run(["openssl", "pkcs8", "-in", k+".pk8",
             "-inform", "DER", "-nocrypt"],
            stdin=devnull.fileno(),
            stdout=devnull.fileno(),
            stderr=subprocess.STDOUT)
    p.communicate()
    if p.returncode == 0:
      no_passwords.append(k)
    else:
      need_passwords.append(k)
  devnull.close()

  key_passwords = PasswordManager().GetPasswords(need_passwords)
  key_passwords.update(dict.fromkeys(no_passwords, None))
  return key_passwords


def SignFile(input_name, output_name, key, password, align=None,
             whole_file=False):
  """Sign the input_name zip/jar/apk, producing output_name.  Use the
  given key and password (the latter may be None if the key does not
  have a password.

  If align is an integer > 1, zipalign is run to align stored files in
  the output zip on 'align'-byte boundaries.

  If whole_file is true, use the "-w" option to SignApk to embed a
  signature that covers the whole file in the archive comment of the
  zip file.
  """

  if align == 0 or align == 1:
    align = None

  if align:
    temp = tempfile.NamedTemporaryFile()
    sign_name = temp.name
  else:
    sign_name = output_name

  cmd = ["java", "-Xmx512m", "-jar",
           os.path.join(OPTIONS.search_path, "framework", "signapk.jar")]
  if whole_file:
    cmd.append("-w")
  cmd.extend([key + ".x509.pem", key + ".pk8",
              input_name, sign_name])

  p = Run(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
  if password is not None:
    password += "\n"
  p.communicate(password)
  if p.returncode != 0:
    raise ExternalError("signapk.jar failed: return code %s" % (p.returncode,))

  if align:
    p = Run(["zipalign", "-f", str(align), sign_name, output_name])
    p.communicate()
    if p.returncode != 0:
      raise ExternalError("zipalign failed: return code %s" % (p.returncode,))
    temp.close()


def CheckSize(data, target):
  """Check the data string passed against the max size limit, if
  any, for the given target.  Raise exception if the data is too big.
  Print a warning if the data is nearing the maximum size."""
  limit = OPTIONS.max_image_size.get(target, None)
  if limit is None: return

  size = len(data)
  pct = float(size) * 100.0 / limit
  msg = "%s size (%d) is %.2f%% of limit (%d)" % (target, size, pct, limit)
  if pct >= 99.0:
    raise ExternalError(msg)
  elif pct >= 95.0:
    print
    print "  WARNING: ", msg
    print
  elif OPTIONS.verbose:
    print "  ", msg


COMMON_DOCSTRING = """
  -p  (--path)  <dir>
      Prepend <dir>/bin to the list of places to search for binaries
      run by this script, and expect to find jars in <dir>/framework.

  -s  (--device_specific) <file>
      Path to the python module containing device-specific
      releasetools code.

  -v  (--verbose)
      Show command lines being executed.

  -h  (--help)
      Display this usage message and exit.
"""

def Usage(docstring):
  print docstring.rstrip("\n")
  print COMMON_DOCSTRING


def ParseOptions(argv,
                 docstring,
                 extra_opts="", extra_long_opts=(),
                 extra_option_handler=None):
  """Parse the options in argv and return any arguments that aren't
  flags.  docstring is the calling module's docstring, to be displayed
  for errors and -h.  extra_opts and extra_long_opts are for flags
  defined by the caller, which are processed by passing them to
  extra_option_handler."""

  try:
    opts, args = getopt.getopt(
        argv, "hvp:s:" + extra_opts,
        ["help", "verbose", "path=", "device_specific="] +
          list(extra_long_opts))
  except getopt.GetoptError, err:
    Usage(docstring)
    print "**", str(err), "**"
    sys.exit(2)

  path_specified = False

  for o, a in opts:
    if o in ("-h", "--help"):
      Usage(docstring)
      sys.exit()
    elif o in ("-v", "--verbose"):
      OPTIONS.verbose = True
    elif o in ("-p", "--path"):
      OPTIONS.search_path = a
    elif o in ("-s", "--device_specific"):
      OPTIONS.device_specific = a
    else:
      if extra_option_handler is None or not extra_option_handler(o, a):
        assert False, "unknown option \"%s\"" % (o,)

  os.environ["PATH"] = (os.path.join(OPTIONS.search_path, "bin") +
                        os.pathsep + os.environ["PATH"])

  return args


def Cleanup():
  for i in OPTIONS.tempfiles:
    if os.path.isdir(i):
      shutil.rmtree(i)
    else:
      os.remove(i)


class PasswordManager(object):
  def __init__(self):
    self.editor = os.getenv("EDITOR", None)
    self.pwfile = os.getenv("ANDROID_PW_FILE", None)

  def GetPasswords(self, items):
    """Get passwords corresponding to each string in 'items',
    returning a dict.  (The dict may have keys in addition to the
    values in 'items'.)

    Uses the passwords in $ANDROID_PW_FILE if available, letting the
    user edit that file to add more needed passwords.  If no editor is
    available, or $ANDROID_PW_FILE isn't define, prompts the user
    interactively in the ordinary way.
    """

    current = self.ReadFile()

    first = True
    while True:
      missing = []
      for i in items:
        if i not in current or not current[i]:
          missing.append(i)
      # Are all the passwords already in the file?
      if not missing: return current

      for i in missing:
        current[i] = ""

      if not first:
        print "key file %s still missing some passwords." % (self.pwfile,)
        answer = raw_input("try to edit again? [y]> ").strip()
        if answer and answer[0] not in 'yY':
          raise RuntimeError("key passwords unavailable")
      first = False

      current = self.UpdateAndReadFile(current)

  def PromptResult(self, current):
    """Prompt the user to enter a value (password) for each key in
    'current' whose value is fales.  Returns a new dict with all the
    values.
    """
    result = {}
    for k, v in sorted(current.iteritems()):
      if v:
        result[k] = v
      else:
        while True:
          result[k] = getpass.getpass("Enter password for %s key> "
                                      % (k,)).strip()
          if result[k]: break
    return result

  def UpdateAndReadFile(self, current):
    if not self.editor or not self.pwfile:
      return self.PromptResult(current)

    f = open(self.pwfile, "w")
    os.chmod(self.pwfile, 0600)
    f.write("# Enter key passwords between the [[[ ]]] brackets.\n")
    f.write("# (Additional spaces are harmless.)\n\n")

    first_line = None
    sorted = [(not v, k, v) for (k, v) in current.iteritems()]
    sorted.sort()
    for i, (_, k, v) in enumerate(sorted):
      f.write("[[[  %s  ]]] %s\n" % (v, k))
      if not v and first_line is None:
        # position cursor on first line with no password.
        first_line = i + 4
    f.close()

    p = Run([self.editor, "+%d" % (first_line,), self.pwfile])
    _, _ = p.communicate()

    return self.ReadFile()

  def ReadFile(self):
    result = {}
    if self.pwfile is None: return result
    try:
      f = open(self.pwfile, "r")
      for line in f:
        line = line.strip()
        if not line or line[0] == '#': continue
        m = re.match(r"^\[\[\[\s*(.*?)\s*\]\]\]\s*(\S+)$", line)
        if not m:
          print "failed to parse password file: ", line
        else:
          result[m.group(2)] = m.group(1)
      f.close()
    except IOError, e:
      if e.errno != errno.ENOENT:
        print "error reading password file: ", str(e)
    return result


def ZipWriteStr(zip, filename, data, perms=0644):
  # use a fixed timestamp so the output is repeatable.
  zinfo = zipfile.ZipInfo(filename=filename,
                          date_time=(2009, 1, 1, 0, 0, 0))
  zinfo.compress_type = zip.compression
  zinfo.external_attr = perms << 16
  zip.writestr(zinfo, data)


class DeviceSpecificParams(object):
  module = None
  def __init__(self, **kwargs):
    """Keyword arguments to the constructor become attributes of this
    object, which is passed to all functions in the device-specific
    module."""
    for k, v in kwargs.iteritems():
      setattr(self, k, v)

    if self.module is None:
      path = OPTIONS.device_specific
      if not path: return
      try:
        if os.path.isdir(path):
          info = imp.find_module("releasetools", [path])
        else:
          d, f = os.path.split(path)
          b, x = os.path.splitext(f)
          if x == ".py":
            f = b
          info = imp.find_module(f, [d])
        self.module = imp.load_module("device_specific", *info)
      except ImportError:
        print "unable to load device-specific module; assuming none"

  def _DoCall(self, function_name, *args, **kwargs):
    """Call the named function in the device-specific module, passing
    the given args and kwargs.  The first argument to the call will be
    the DeviceSpecific object itself.  If there is no module, or the
    module does not define the function, return the value of the
    'default' kwarg (which itself defaults to None)."""
    if self.module is None or not hasattr(self.module, function_name):
      return kwargs.get("default", None)
    return getattr(self.module, function_name)(*((self,) + args), **kwargs)

  def FullOTA_Assertions(self):
    """Called after emitting the block of assertions at the top of a
    full OTA package.  Implementations can add whatever additional
    assertions they like."""
    return self._DoCall("FullOTA_Assertions")

  def FullOTA_InstallEnd(self):
    """Called at the end of full OTA installation; typically this is
    used to install the image for the device's baseband processor."""
    return self._DoCall("FullOTA_InstallEnd")

  def IncrementalOTA_Assertions(self):
    """Called after emitting the block of assertions at the top of an
    incremental OTA package.  Implementations can add whatever
    additional assertions they like."""
    return self._DoCall("IncrementalOTA_Assertions")

  def IncrementalOTA_VerifyEnd(self):
    """Called at the end of the verification phase of incremental OTA
    installation; additional checks can be placed here to abort the
    script before any changes are made."""
    return self._DoCall("IncrementalOTA_VerifyEnd")

  def IncrementalOTA_InstallEnd(self):
    """Called at the end of incremental OTA installation; typically
    this is used to install the image for the device's baseband
    processor."""
    return self._DoCall("IncrementalOTA_InstallEnd")
