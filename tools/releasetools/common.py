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

import getopt
import getpass
import os
import re
import shutil
import subprocess
import sys
import tempfile

# missing in Python 2.4 and before
if not hasattr(os, "SEEK_SET"):
  os.SEEK_SET = 0

class Options(object): pass
OPTIONS = Options()
OPTIONS.signapk_jar = "out/host/linux-x86/framework/signapk.jar"
OPTIONS.max_image_size = {}
OPTIONS.verbose = False
OPTIONS.tempfiles = []


class ExternalError(RuntimeError): pass


def Run(args, **kwargs):
  """Create and return a subprocess.Popen object, printing the command
  line on the terminal if -v was specified."""
  if OPTIONS.verbose:
    print "  running: ", " ".join(args)
  return subprocess.Popen(args, **kwargs)


def LoadBoardConfig(fn):
  """Parse a board_config.mk file looking for lines that specify the
  maximum size of various images, and parse them into the
  OPTIONS.max_image_size dict."""
  OPTIONS.max_image_size = {}
  for line in open(fn):
    line = line.strip()
    m = re.match(r"BOARD_(BOOT|RECOVERY|SYSTEM|USERDATA)IMAGE_MAX_SIZE"
                 r"\s*:=\s*(\d+)", line)
    if not m: continue

    OPTIONS.max_image_size[m.group(1).lower() + ".img"] = int(m.group(2))


def BuildAndAddBootableImage(sourcedir, targetname, output_zip):
  """Take a kernel, cmdline, and ramdisk directory from the input (in
  'sourcedir'), and turn them into a boot image.  Put the boot image
  into the output zip file under the name 'targetname'."""

  print "creating %s..." % (targetname,)

  img = BuildBootableImage(sourcedir)

  CheckSize(img, targetname)
  output_zip.writestr(targetname, img)

def BuildBootableImage(sourcedir):
  """Take a kernel, cmdline, and ramdisk directory from the input (in
  'sourcedir'), and turn them into a boot image.  Return the image data."""

  ramdisk_img = tempfile.NamedTemporaryFile()
  img = tempfile.NamedTemporaryFile()

  p1 = Run(["mkbootfs", os.path.join(sourcedir, "RAMDISK")],
           stdout=subprocess.PIPE)
  p2 = Run(["gzip", "-n"], stdin=p1.stdout, stdout=ramdisk_img.file.fileno())

  p2.wait()
  p1.wait()
  assert p1.returncode == 0, "mkbootfs of %s ramdisk failed" % (targetname,)
  assert p2.returncode == 0, "gzip of %s ramdisk failed" % (targetname,)

  cmdline = open(os.path.join(sourcedir, "cmdline")).read().rstrip("\n")
  p = Run(["mkbootimg",
           "--kernel", os.path.join(sourcedir, "kernel"),
           "--cmdline", cmdline,
           "--ramdisk", ramdisk_img.name,
           "--output", img.name],
          stdout=subprocess.PIPE)
  p.communicate()
  assert p.returncode == 0, "mkbootimg of %s image failed" % (targetname,)

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
  p = Run(["unzip", "-q", filename, "-d", tmp], stdout=subprocess.PIPE)
  p.communicate()
  if p.returncode != 0:
    raise ExternalError("failed to unzip input target-files \"%s\"" %
                        (filename,))
  return tmp


def GetKeyPasswords(keylist):
  """Given a list of keys, prompt the user to enter passwords for
  those which require them.  Return a {key: password} dict.  password
  will be None if the key has no password."""

  key_passwords = {}
  devnull = open("/dev/null", "w+b")
  for k in sorted(keylist):
    p = subprocess.Popen(["openssl", "pkcs8", "-in", k+".pk8",
                          "-inform", "DER", "-nocrypt"],
                         stdin=devnull.fileno(),
                         stdout=devnull.fileno(),
                         stderr=subprocess.STDOUT)
    p.communicate()
    if p.returncode == 0:
      print "%s.pk8 does not require a password" % (k,)
      key_passwords[k] = None
    else:
      key_passwords[k] = getpass.getpass("Enter password for %s.pk8> " % (k,))
  devnull.close()
  print
  return key_passwords


def SignFile(input_name, output_name, key, password, align=None):
  """Sign the input_name zip/jar/apk, producing output_name.  Use the
  given key and password (the latter may be None if the key does not
  have a password.

  If align is an integer > 1, zipalign is run to align stored files in
  the output zip on 'align'-byte boundaries.
  """
  if align == 0 or align == 1:
    align = None

  if align:
    temp = tempfile.NamedTemporaryFile()
    sign_name = temp.name
  else:
    sign_name = output_name

  p = subprocess.Popen(["java", "-jar", OPTIONS.signapk_jar,
                        key + ".x509.pem",
                        key + ".pk8",
                        input_name, sign_name],
                       stdin=subprocess.PIPE,
                       stdout=subprocess.PIPE)
  if password is not None:
    password += "\n"
  p.communicate(password)
  if p.returncode != 0:
    raise ExternalError("signapk.jar failed: return code %s" % (p.returncode,))

  if align:
    p = subprocess.Popen(["zipalign", "-f", str(align), sign_name, output_name])
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
      Prepend <dir> to the list of places to search for binaries run
      by this script.

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
        argv, "hvp:" + extra_opts,
        ["help", "verbose", "path="] + list(extra_long_opts))
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
      os.environ["PATH"] = a + os.pathsep + os.environ["PATH"]
      path_specified = True
    else:
      if extra_option_handler is None or not extra_option_handler(o, a):
        assert False, "unknown option \"%s\"" % (o,)

  if not path_specified:
    os.environ["PATH"] = ("out/host/linux-x86/bin" + os.pathsep +
                          os.environ["PATH"])

  return args


def Cleanup():
  for i in OPTIONS.tempfiles:
    if os.path.isdir(i):
      shutil.rmtree(i)
    else:
      os.remove(i)
