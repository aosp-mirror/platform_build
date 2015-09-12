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
Signs all the APK files in a target-files zipfile, producing a new
target-files zip.

Usage:  sign_target_files_apks [flags] input_target_files output_target_files

  -e  (--extra_apks)  <name,name,...=key>
      Add extra APK name/key pairs as though they appeared in
      apkcerts.txt (so mappings specified by -k and -d are applied).
      Keys specified in -e override any value for that app contained
      in the apkcerts.txt file.  Option may be repeated to give
      multiple extra packages.

  -k  (--key_mapping)  <src_key=dest_key>
      Add a mapping from the key name as specified in apkcerts.txt (the
      src_key) to the real key you wish to sign the package with
      (dest_key).  Option may be repeated to give multiple key
      mappings.

  -d  (--default_key_mappings)  <dir>
      Set up the following key mappings:

        $devkey/devkey    ==>  $dir/releasekey
        $devkey/testkey   ==>  $dir/releasekey
        $devkey/media     ==>  $dir/media
        $devkey/shared    ==>  $dir/shared
        $devkey/platform  ==>  $dir/platform

      where $devkey is the directory part of the value of
      default_system_dev_certificate from the input target-files's
      META/misc_info.txt.  (Defaulting to "build/target/product/security"
      if the value is not present in misc_info.

      -d and -k options are added to the set of mappings in the order
      in which they appear on the command line.

  -o  (--replace_ota_keys)
      Replace the certificate (public key) used by OTA package
      verification with the one specified in the input target_files
      zip (in the META/otakeys.txt file).  Key remapping (-k and -d)
      is performed on this key.

  -t  (--tag_changes)  <+tag>,<-tag>,...
      Comma-separated list of changes to make to the set of tags (in
      the last component of the build fingerprint).  Prefix each with
      '+' or '-' to indicate whether that tag should be added or
      removed.  Changes are processed in the order they appear.
      Default value is "-test-keys,-dev-keys,+release-keys".

"""

import sys

if sys.hexversion < 0x02070000:
  print >> sys.stderr, "Python 2.7 or newer is required."
  sys.exit(1)

import base64
import cStringIO
import copy
import errno
import os
import re
import shutil
import subprocess
import tempfile
import zipfile

import add_img_to_target_files
import common

OPTIONS = common.OPTIONS

OPTIONS.extra_apks = {}
OPTIONS.key_map = {}
OPTIONS.replace_ota_keys = False
OPTIONS.replace_verity_public_key = False
OPTIONS.replace_verity_private_key = False
OPTIONS.tag_changes = ("-test-keys", "-dev-keys", "+release-keys")

def GetApkCerts(tf_zip):
  certmap = common.ReadApkCerts(tf_zip)

  # apply the key remapping to the contents of the file
  for apk, cert in certmap.iteritems():
    certmap[apk] = OPTIONS.key_map.get(cert, cert)

  # apply all the -e options, overriding anything in the file
  for apk, cert in OPTIONS.extra_apks.iteritems():
    if not cert:
      cert = "PRESIGNED"
    certmap[apk] = OPTIONS.key_map.get(cert, cert)

  return certmap


def CheckAllApksSigned(input_tf_zip, apk_key_map):
  """Check that all the APKs we want to sign have keys specified, and
  error out if they don't."""
  unknown_apks = []
  for info in input_tf_zip.infolist():
    if info.filename.endswith(".apk"):
      name = os.path.basename(info.filename)
      if name not in apk_key_map:
        unknown_apks.append(name)
  if unknown_apks:
    print "ERROR: no key specified for:\n\n ",
    print "\n  ".join(unknown_apks)
    print "\nUse '-e <apkname>=' to specify a key (which may be an"
    print "empty string to not sign this apk)."
    sys.exit(1)


def SignApk(data, keyname, pw):
  unsigned = tempfile.NamedTemporaryFile()
  unsigned.write(data)
  unsigned.flush()

  signed = tempfile.NamedTemporaryFile()

  common.SignFile(unsigned.name, signed.name, keyname, pw, align=4)

  data = signed.read()
  unsigned.close()
  signed.close()

  return data


def ProcessTargetFiles(input_tf_zip, output_tf_zip, misc_info,
                       apk_key_map, key_passwords):

  maxsize = max([len(os.path.basename(i.filename))
                 for i in input_tf_zip.infolist()
                 if i.filename.endswith('.apk')])
  rebuild_recovery = False

  tmpdir = tempfile.mkdtemp()
  def write_to_temp(fn, attr, data):
    fn = os.path.join(tmpdir, fn)
    if fn.endswith("/"):
      fn = os.path.join(tmpdir, fn)
      os.mkdir(fn)
    else:
      d = os.path.dirname(fn)
      if d and not os.path.exists(d):
        os.makedirs(d)

      if attr >> 16 == 0xa1ff:
        os.symlink(data, fn)
      else:
        with open(fn, "wb") as f:
          f.write(data)

  for info in input_tf_zip.infolist():
    if info.filename.startswith("IMAGES/"):
      continue

    data = input_tf_zip.read(info.filename)
    out_info = copy.copy(info)

    if (info.filename == "META/misc_info.txt" and
        OPTIONS.replace_verity_private_key):
      ReplaceVerityPrivateKey(input_tf_zip, output_tf_zip, misc_info,
                              OPTIONS.replace_verity_private_key[1])
    elif (info.filename == "BOOT/RAMDISK/verity_key" and
          OPTIONS.replace_verity_public_key):
      new_data = ReplaceVerityPublicKey(output_tf_zip,
                                        OPTIONS.replace_verity_public_key[1])
      write_to_temp(info.filename, info.external_attr, new_data)
    elif (info.filename.startswith("BOOT/") or
          info.filename.startswith("RECOVERY/") or
          info.filename.startswith("META/") or
          info.filename == "SYSTEM/etc/recovery-resource.dat"):
      write_to_temp(info.filename, info.external_attr, data)

    if info.filename.endswith(".apk"):
      name = os.path.basename(info.filename)
      key = apk_key_map[name]
      if key not in common.SPECIAL_CERT_STRINGS:
        print "    signing: %-*s (%s)" % (maxsize, name, key)
        signed_data = SignApk(data, key, key_passwords[key])
        common.ZipWriteStr(output_tf_zip, out_info, signed_data)
      else:
        # an APK we're not supposed to sign.
        print "NOT signing: %s" % (name,)
        common.ZipWriteStr(output_tf_zip, out_info, data)
    elif info.filename in ("SYSTEM/build.prop",
                           "VENDOR/build.prop",
                           "BOOT/RAMDISK/default.prop",
                           "RECOVERY/RAMDISK/default.prop"):
      print "rewriting %s:" % (info.filename,)
      new_data = RewriteProps(data, misc_info)
      common.ZipWriteStr(output_tf_zip, out_info, new_data)
      if info.filename in ("BOOT/RAMDISK/default.prop",
                           "RECOVERY/RAMDISK/default.prop"):
        write_to_temp(info.filename, info.external_attr, new_data)
    elif info.filename.endswith("mac_permissions.xml"):
      print "rewriting %s with new keys." % (info.filename,)
      new_data = ReplaceCerts(data)
      common.ZipWriteStr(output_tf_zip, out_info, new_data)
    elif info.filename in ("SYSTEM/recovery-from-boot.p",
                           "SYSTEM/bin/install-recovery.sh"):
      rebuild_recovery = True
    elif (OPTIONS.replace_ota_keys and
          info.filename in ("RECOVERY/RAMDISK/res/keys",
                            "SYSTEM/etc/security/otacerts.zip")):
      # don't copy these files if we're regenerating them below
      pass
    elif (OPTIONS.replace_verity_private_key and
          info.filename == "META/misc_info.txt"):
      pass
    elif (OPTIONS.replace_verity_public_key and
          info.filename == "BOOT/RAMDISK/verity_key"):
      pass
    else:
      # a non-APK file; copy it verbatim
      common.ZipWriteStr(output_tf_zip, out_info, data)

  if OPTIONS.replace_ota_keys:
    new_recovery_keys = ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info)
    if new_recovery_keys:
      write_to_temp("RECOVERY/RAMDISK/res/keys", 0o755 << 16, new_recovery_keys)

  if rebuild_recovery:
    recovery_img = common.GetBootableImage(
        "recovery.img", "recovery.img", tmpdir, "RECOVERY", info_dict=misc_info)
    boot_img = common.GetBootableImage(
        "boot.img", "boot.img", tmpdir, "BOOT", info_dict=misc_info)

    def output_sink(fn, data):
      common.ZipWriteStr(output_tf_zip, "SYSTEM/" + fn, data)

    common.MakeRecoveryPatch(tmpdir, output_sink, recovery_img, boot_img,
                             info_dict=misc_info)

  shutil.rmtree(tmpdir)


def ReplaceCerts(data):
  """Given a string of data, replace all occurences of a set
  of X509 certs with a newer set of X509 certs and return
  the updated data string."""
  for old, new in OPTIONS.key_map.iteritems():
    try:
      if OPTIONS.verbose:
        print "    Replacing %s.x509.pem with %s.x509.pem" % (old, new)
      f = open(old + ".x509.pem")
      old_cert16 = base64.b16encode(common.ParseCertificate(f.read())).lower()
      f.close()
      f = open(new + ".x509.pem")
      new_cert16 = base64.b16encode(common.ParseCertificate(f.read())).lower()
      f.close()
      # Only match entire certs.
      pattern = "\\b"+old_cert16+"\\b"
      (data, num) = re.subn(pattern, new_cert16, data, flags=re.IGNORECASE)
      if OPTIONS.verbose:
        print "    Replaced %d occurence(s) of %s.x509.pem with " \
            "%s.x509.pem" % (num, old, new)
    except IOError as e:
      if e.errno == errno.ENOENT and not OPTIONS.verbose:
        continue

      print "    Error accessing %s. %s. Skip replacing %s.x509.pem " \
          "with %s.x509.pem." % (e.filename, e.strerror, old, new)

  return data


def EditTags(tags):
  """Given a string containing comma-separated tags, apply the edits
  specified in OPTIONS.tag_changes and return the updated string."""
  tags = set(tags.split(","))
  for ch in OPTIONS.tag_changes:
    if ch[0] == "-":
      tags.discard(ch[1:])
    elif ch[0] == "+":
      tags.add(ch[1:])
  return ",".join(sorted(tags))


def RewriteProps(data, misc_info):
  output = []
  for line in data.split("\n"):
    line = line.strip()
    original_line = line
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      if (key in ("ro.build.fingerprint", "ro.vendor.build.fingerprint")
          and misc_info.get("oem_fingerprint_properties") is None):
        pieces = value.split("/")
        pieces[-1] = EditTags(pieces[-1])
        value = "/".join(pieces)
      elif (key in ("ro.build.thumbprint", "ro.vendor.build.thumbprint")
            and misc_info.get("oem_fingerprint_properties") is not None):
        pieces = value.split("/")
        pieces[-1] = EditTags(pieces[-1])
        value = "/".join(pieces)
      elif key == "ro.bootimage.build.fingerprint":
        pieces = value.split("/")
        pieces[-1] = EditTags(pieces[-1])
        value = "/".join(pieces)
      elif key == "ro.build.description":
        pieces = value.split(" ")
        assert len(pieces) == 5
        pieces[-1] = EditTags(pieces[-1])
        value = " ".join(pieces)
      elif key == "ro.build.tags":
        value = EditTags(value)
      elif key == "ro.build.display.id":
        # change, eg, "JWR66N dev-keys" to "JWR66N"
        value = value.split()
        if len(value) > 1 and value[-1].endswith("-keys"):
          value.pop()
        value = " ".join(value)
      line = key + "=" + value
    if line != original_line:
      print "  replace: ", original_line
      print "     with: ", line
    output.append(line)
  return "\n".join(output) + "\n"


def ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info):
  try:
    keylist = input_tf_zip.read("META/otakeys.txt").split()
  except KeyError:
    raise common.ExternalError("can't read META/otakeys.txt from input")

  extra_recovery_keys = misc_info.get("extra_recovery_keys", None)
  if extra_recovery_keys:
    extra_recovery_keys = [OPTIONS.key_map.get(k, k) + ".x509.pem"
                           for k in extra_recovery_keys.split()]
    if extra_recovery_keys:
      print "extra recovery-only key(s): " + ", ".join(extra_recovery_keys)
  else:
    extra_recovery_keys = []

  mapped_keys = []
  for k in keylist:
    m = re.match(r"^(.*)\.x509\.pem$", k)
    if not m:
      raise common.ExternalError(
          "can't parse \"%s\" from META/otakeys.txt" % (k,))
    k = m.group(1)
    mapped_keys.append(OPTIONS.key_map.get(k, k) + ".x509.pem")

  if mapped_keys:
    print "using:\n   ", "\n   ".join(mapped_keys)
    print "for OTA package verification"
  else:
    devkey = misc_info.get("default_system_dev_certificate",
                           "build/target/product/security/testkey")
    mapped_keys.append(
        OPTIONS.key_map.get(devkey, devkey) + ".x509.pem")
    print "META/otakeys.txt has no keys; using", mapped_keys[0]

  # recovery uses a version of the key that has been slightly
  # predigested (by DumpPublicKey.java) and put in res/keys.
  # extra_recovery_keys are used only in recovery.

  p = common.Run(["java", "-jar",
                  os.path.join(OPTIONS.search_path, "framework", "dumpkey.jar")]
                 + mapped_keys + extra_recovery_keys,
                 stdout=subprocess.PIPE)
  new_recovery_keys, _ = p.communicate()
  if p.returncode != 0:
    raise common.ExternalError("failed to run dumpkeys")
  common.ZipWriteStr(output_tf_zip, "RECOVERY/RAMDISK/res/keys",
                     new_recovery_keys)

  # SystemUpdateActivity uses the x509.pem version of the keys, but
  # put into a zipfile system/etc/security/otacerts.zip.
  # We DO NOT include the extra_recovery_keys (if any) here.

  temp_file = cStringIO.StringIO()
  certs_zip = zipfile.ZipFile(temp_file, "w")
  for k in mapped_keys:
    certs_zip.write(k)
  certs_zip.close()
  common.ZipWriteStr(output_tf_zip, "SYSTEM/etc/security/otacerts.zip",
                     temp_file.getvalue())

  return new_recovery_keys

def ReplaceVerityPublicKey(targetfile_zip, key_path):
  print "Replacing verity public key with %s" % key_path
  with open(key_path) as f:
    data = f.read()
  common.ZipWriteStr(targetfile_zip, "BOOT/RAMDISK/verity_key", data)
  return data

def ReplaceVerityPrivateKey(targetfile_input_zip, targetfile_output_zip,
                            misc_info, key_path):
  print "Replacing verity private key with %s" % key_path
  current_key = misc_info["verity_key"]
  original_misc_info = targetfile_input_zip.read("META/misc_info.txt")
  new_misc_info = original_misc_info.replace(current_key, key_path)
  common.ZipWriteStr(targetfile_output_zip, "META/misc_info.txt", new_misc_info)
  misc_info["verity_key"] = key_path

def BuildKeyMap(misc_info, key_mapping_options):
  for s, d in key_mapping_options:
    if s is None:   # -d option
      devkey = misc_info.get("default_system_dev_certificate",
                             "build/target/product/security/testkey")
      devkeydir = os.path.dirname(devkey)

      OPTIONS.key_map.update({
          devkeydir + "/testkey":  d + "/releasekey",
          devkeydir + "/devkey":   d + "/releasekey",
          devkeydir + "/media":    d + "/media",
          devkeydir + "/shared":   d + "/shared",
          devkeydir + "/platform": d + "/platform",
          })
    else:
      OPTIONS.key_map[s] = d


def main(argv):

  key_mapping_options = []

  def option_handler(o, a):
    if o in ("-e", "--extra_apks"):
      names, key = a.split("=")
      names = names.split(",")
      for n in names:
        OPTIONS.extra_apks[n] = key
    elif o in ("-d", "--default_key_mappings"):
      key_mapping_options.append((None, a))
    elif o in ("-k", "--key_mapping"):
      key_mapping_options.append(a.split("=", 1))
    elif o in ("-o", "--replace_ota_keys"):
      OPTIONS.replace_ota_keys = True
    elif o in ("-t", "--tag_changes"):
      new = []
      for i in a.split(","):
        i = i.strip()
        if not i or i[0] not in "-+":
          raise ValueError("Bad tag change '%s'" % (i,))
        new.append(i[0] + i[1:].strip())
      OPTIONS.tag_changes = tuple(new)
    elif o == "--replace_verity_public_key":
      OPTIONS.replace_verity_public_key = (True, a)
    elif o == "--replace_verity_private_key":
      OPTIONS.replace_verity_private_key = (True, a)
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="e:d:k:ot:",
                             extra_long_opts=["extra_apks=",
                                              "default_key_mappings=",
                                              "key_mapping=",
                                              "replace_ota_keys",
                                              "tag_changes=",
                                              "replace_verity_public_key=",
                                              "replace_verity_private_key="],
                             extra_option_handler=option_handler)

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  input_zip = zipfile.ZipFile(args[0], "r")
  output_zip = zipfile.ZipFile(args[1], "w")

  misc_info = common.LoadInfoDict(input_zip)

  BuildKeyMap(misc_info, key_mapping_options)

  apk_key_map = GetApkCerts(input_zip)
  CheckAllApksSigned(input_zip, apk_key_map)

  key_passwords = common.GetKeyPasswords(set(apk_key_map.values()))
  ProcessTargetFiles(input_zip, output_zip, misc_info,
                     apk_key_map, key_passwords)

  common.ZipClose(input_zip)
  common.ZipClose(output_zip)

  add_img_to_target_files.AddImagesToTargetFiles(args[1])

  print "done."


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  except common.ExternalError, e:
    print
    print "   ERROR: %s" % (e,)
    print
    sys.exit(1)
