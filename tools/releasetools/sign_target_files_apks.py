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
      Replace the certificate (public key) used by OTA package verification
      with the ones specified in the input target_files zip (in the
      META/otakeys.txt file). Key remapping (-k and -d) is performed on the
      keys. For A/B devices, the payload verification key will be replaced
      as well. If there're multiple OTA keys, only the first one will be used
      for payload verification.

  -t  (--tag_changes)  <+tag>,<-tag>,...
      Comma-separated list of changes to make to the set of tags (in
      the last component of the build fingerprint).  Prefix each with
      '+' or '-' to indicate whether that tag should be added or
      removed.  Changes are processed in the order they appear.
      Default value is "-test-keys,-dev-keys,+release-keys".

  --replace_verity_private_key <key>
      Replace the private key used for verity signing. It expects a filename
      WITHOUT the extension (e.g. verity_key).

  --replace_verity_public_key <key>
      Replace the certificate (public key) used for verity verification. The
      key file replaces the one at BOOT/RAMDISK/verity_key (or ROOT/verity_key
      for devices using system_root_image). It expects the key filename WITH
      the extension (e.g. verity_key.pub).

  --replace_verity_keyid <path_to_X509_PEM_cert_file>
      Replace the veritykeyid in BOOT/cmdline of input_target_file_zip
      with keyid of the cert pointed by <path_to_X509_PEM_cert_file>.
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
OPTIONS.replace_verity_keyid = False
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


def SignApk(data, keyname, pw, platform_api_level, codename_to_api_level_map):
  unsigned = tempfile.NamedTemporaryFile()
  unsigned.write(data)
  unsigned.flush()

  signed = tempfile.NamedTemporaryFile()

  # For pre-N builds, don't upgrade to SHA-256 JAR signatures based on the APK's
  # minSdkVersion to avoid increasing incremental OTA update sizes. If an APK
  # didn't change, we don't want its signature to change due to the switch
  # from SHA-1 to SHA-256.
  # By default, APK signer chooses SHA-256 signatures if the APK's minSdkVersion
  # is 18 or higher. For pre-N builds we disable this mechanism by pretending
  # that the APK's minSdkVersion is 1.
  # For N+ builds, we let APK signer rely on the APK's minSdkVersion to
  # determine whether to use SHA-256.
  min_api_level = None
  if platform_api_level > 23:
    # Let APK signer choose whether to use SHA-1 or SHA-256, based on the APK's
    # minSdkVersion attribute
    min_api_level = None
  else:
    # Force APK signer to use SHA-1
    min_api_level = 1

  common.SignFile(unsigned.name, signed.name, keyname, pw,
      min_api_level=min_api_level,
      codename_to_api_level_map=codename_to_api_level_map)

  data = signed.read()
  unsigned.close()
  signed.close()

  return data


def ProcessTargetFiles(input_tf_zip, output_tf_zip, misc_info,
                       apk_key_map, key_passwords, platform_api_level,
                       codename_to_api_level_map):

  maxsize = max([len(os.path.basename(i.filename))
                 for i in input_tf_zip.infolist()
                 if i.filename.endswith('.apk')])
  rebuild_recovery = False
  system_root_image = misc_info.get("system_root_image") == "true"

  # tmpdir will only be used to regenerate the recovery-from-boot patch.
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

    # Sign APKs.
    if info.filename.endswith(".apk"):
      name = os.path.basename(info.filename)
      key = apk_key_map[name]
      if key not in common.SPECIAL_CERT_STRINGS:
        print "    signing: %-*s (%s)" % (maxsize, name, key)
        signed_data = SignApk(data, key, key_passwords[key], platform_api_level,
            codename_to_api_level_map)
        common.ZipWriteStr(output_tf_zip, out_info, signed_data)
      else:
        # an APK we're not supposed to sign.
        print "NOT signing: %s" % (name,)
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # System properties.
    elif info.filename in ("SYSTEM/build.prop",
                           "VENDOR/build.prop",
                           "BOOT/RAMDISK/default.prop",
                           "ROOT/default.prop",
                           "RECOVERY/RAMDISK/default.prop"):
      print "rewriting %s:" % (info.filename,)
      new_data = RewriteProps(data, misc_info)
      common.ZipWriteStr(output_tf_zip, out_info, new_data)
      if info.filename in ("BOOT/RAMDISK/default.prop",
                           "ROOT/default.prop",
                           "RECOVERY/RAMDISK/default.prop"):
        write_to_temp(info.filename, info.external_attr, new_data)

    elif info.filename.endswith("mac_permissions.xml"):
      print "rewriting %s with new keys." % (info.filename,)
      new_data = ReplaceCerts(data)
      common.ZipWriteStr(output_tf_zip, out_info, new_data)

    # Trigger a rebuild of the recovery patch if needed.
    elif info.filename in ("SYSTEM/recovery-from-boot.p",
                           "SYSTEM/etc/recovery.img",
                           "SYSTEM/bin/install-recovery.sh"):
      rebuild_recovery = True

    # Don't copy OTA keys if we're replacing them.
    elif (OPTIONS.replace_ota_keys and
          info.filename in (
              "BOOT/RAMDISK/res/keys",
              "BOOT/RAMDISK/etc/update_engine/update-payload-key.pub.pem",
              "RECOVERY/RAMDISK/res/keys",
              "SYSTEM/etc/security/otacerts.zip",
              "SYSTEM/etc/update_engine/update-payload-key.pub.pem")):
      pass

    # Skip META/misc_info.txt if we will replace the verity private key later.
    elif (OPTIONS.replace_verity_private_key and
          info.filename == "META/misc_info.txt"):
      pass

    # Skip verity public key if we will replace it.
    elif (OPTIONS.replace_verity_public_key and
          info.filename in ("BOOT/RAMDISK/verity_key",
                            "ROOT/verity_key")):
      pass

    # Skip verity keyid (for system_root_image use) if we will replace it.
    elif (OPTIONS.replace_verity_keyid and
          info.filename == "BOOT/cmdline"):
      pass

    # Skip the care_map as we will regenerate the system/vendor images.
    elif (info.filename == "META/care_map.txt"):
      pass

    # Copy BOOT/, RECOVERY/, META/, ROOT/ to rebuild recovery patch. This case
    # must come AFTER other matching rules.
    elif (info.filename.startswith("BOOT/") or
          info.filename.startswith("RECOVERY/") or
          info.filename.startswith("META/") or
          info.filename.startswith("ROOT/") or
          info.filename == "SYSTEM/etc/recovery-resource.dat"):
      write_to_temp(info.filename, info.external_attr, data)
      common.ZipWriteStr(output_tf_zip, out_info, data)

    # A non-APK file; copy it verbatim.
    else:
      common.ZipWriteStr(output_tf_zip, out_info, data)

  if OPTIONS.replace_ota_keys:
    new_recovery_keys = ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info)
    if new_recovery_keys:
      if system_root_image:
        recovery_keys_location = "BOOT/RAMDISK/res/keys"
      else:
        recovery_keys_location = "RECOVERY/RAMDISK/res/keys"
      # The "new_recovery_keys" has been already written into the output_tf_zip
      # while calling ReplaceOtaKeys(). We're just putting the same copy to
      # tmpdir in case we need to regenerate the recovery-from-boot patch.
      write_to_temp(recovery_keys_location, 0o755 << 16, new_recovery_keys)

  # Replace the keyid string in META/misc_info.txt.
  if OPTIONS.replace_verity_private_key:
    ReplaceVerityPrivateKey(input_tf_zip, output_tf_zip, misc_info,
                            OPTIONS.replace_verity_private_key[1])

  if OPTIONS.replace_verity_public_key:
    if system_root_image:
      dest = "ROOT/verity_key"
    else:
      dest = "BOOT/RAMDISK/verity_key"
    # We are replacing the one in boot image only, since the one under
    # recovery won't ever be needed.
    new_data = ReplaceVerityPublicKey(
        output_tf_zip, dest, OPTIONS.replace_verity_public_key[1])
    write_to_temp(dest, 0o755 << 16, new_data)

  # Replace the keyid string in BOOT/cmdline.
  if OPTIONS.replace_verity_keyid:
    new_cmdline = ReplaceVerityKeyId(input_tf_zip, output_tf_zip,
      OPTIONS.replace_verity_keyid[1])
    # Writing the new cmdline to tmpdir is redundant as the bootimage
    # gets build in the add_image_to_target_files and rebuild_recovery
    # is not exercised while building the boot image for the A/B
    # path
    write_to_temp("BOOT/cmdline", 0o755 << 16, new_cmdline)

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
    print("META/otakeys.txt has no keys; using %s for OTA package"
          " verification." % (mapped_keys[0],))

  # recovery uses a version of the key that has been slightly
  # predigested (by DumpPublicKey.java) and put in res/keys.
  # extra_recovery_keys are used only in recovery.
  cmd = ([OPTIONS.java_path] + OPTIONS.java_args +
         ["-jar",
          os.path.join(OPTIONS.search_path, "framework", "dumpkey.jar")] +
         mapped_keys + extra_recovery_keys)
  p = common.Run(cmd, stdout=subprocess.PIPE)
  new_recovery_keys, _ = p.communicate()
  if p.returncode != 0:
    raise common.ExternalError("failed to run dumpkeys")

  # system_root_image puts the recovery keys at BOOT/RAMDISK.
  if misc_info.get("system_root_image") == "true":
    recovery_keys_location = "BOOT/RAMDISK/res/keys"
  else:
    recovery_keys_location = "RECOVERY/RAMDISK/res/keys"
  common.ZipWriteStr(output_tf_zip, recovery_keys_location, new_recovery_keys)

  # SystemUpdateActivity uses the x509.pem version of the keys, but
  # put into a zipfile system/etc/security/otacerts.zip.
  # We DO NOT include the extra_recovery_keys (if any) here.

  temp_file = cStringIO.StringIO()
  certs_zip = zipfile.ZipFile(temp_file, "w")
  for k in mapped_keys:
    common.ZipWrite(certs_zip, k)
  common.ZipClose(certs_zip)
  common.ZipWriteStr(output_tf_zip, "SYSTEM/etc/security/otacerts.zip",
                     temp_file.getvalue())

  # For A/B devices, update the payload verification key.
  if misc_info.get("ab_update") == "true":
    # Unlike otacerts.zip that may contain multiple keys, we can only specify
    # ONE payload verification key.
    if len(mapped_keys) > 1:
      print("\n  WARNING: Found more than one OTA keys; Using the first one"
            " as payload verification key.\n\n")

    print "Using %s for payload verification." % (mapped_keys[0],)
    cmd = common.Run(
        ["openssl", "x509", "-pubkey", "-noout", "-in", mapped_keys[0]],
        stdout=subprocess.PIPE)
    pubkey, _ = cmd.communicate()
    common.ZipWriteStr(
        output_tf_zip,
        "SYSTEM/etc/update_engine/update-payload-key.pub.pem",
        pubkey)
    common.ZipWriteStr(
        output_tf_zip,
        "BOOT/RAMDISK/etc/update_engine/update-payload-key.pub.pem",
        pubkey)

  return new_recovery_keys


def ReplaceVerityPublicKey(targetfile_zip, filename, key_path):
  print "Replacing verity public key with %s" % key_path
  with open(key_path) as f:
    data = f.read()
  common.ZipWriteStr(targetfile_zip, filename, data)
  return data


def ReplaceVerityPrivateKey(targetfile_input_zip, targetfile_output_zip,
                            misc_info, key_path):
  print "Replacing verity private key with %s" % key_path
  current_key = misc_info["verity_key"]
  original_misc_info = targetfile_input_zip.read("META/misc_info.txt")
  new_misc_info = original_misc_info.replace(current_key, key_path)
  common.ZipWriteStr(targetfile_output_zip, "META/misc_info.txt", new_misc_info)
  misc_info["verity_key"] = key_path


def ReplaceVerityKeyId(targetfile_input_zip, targetfile_output_zip, keypath):
  in_cmdline = targetfile_input_zip.read("BOOT/cmdline")
  # copy in_cmdline to output_zip if veritykeyid is not present in in_cmdline
  if "veritykeyid" not in in_cmdline:
    common.ZipWriteStr(targetfile_output_zip, "BOOT/cmdline", in_cmdline)
    return in_cmdline
  out_cmdline = []
  for param in in_cmdline.split():
    if "veritykeyid" in param:
      # extract keyid using openssl command
      p = common.Run(["openssl", "x509", "-in", keypath, "-text"], stdout=subprocess.PIPE)
      keyid, stderr = p.communicate()
      keyid = re.search(r'keyid:([0-9a-fA-F:]*)', keyid).group(1).replace(':', '').lower()
      print "Replacing verity keyid with %s error=%s" % (keyid, stderr)
      out_cmdline.append("veritykeyid=id:%s" % (keyid,))
    else:
      out_cmdline.append(param)

  out_cmdline = ' '.join(out_cmdline)
  out_cmdline = out_cmdline.strip()
  print "out_cmdline %s" % (out_cmdline)
  common.ZipWriteStr(targetfile_output_zip, "BOOT/cmdline", out_cmdline)
  return out_cmdline


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


def GetApiLevelAndCodename(input_tf_zip):
  data = input_tf_zip.read("SYSTEM/build.prop")
  api_level = None
  codename = None
  for line in data.split("\n"):
    line = line.strip()
    original_line = line
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      key = key.strip()
      if key == "ro.build.version.sdk":
        api_level = int(value.strip())
      elif key == "ro.build.version.codename":
        codename = value.strip()

  if api_level is None:
    raise ValueError("No ro.build.version.sdk in SYSTEM/build.prop")
  if codename is None:
    raise ValueError("No ro.build.version.codename in SYSTEM/build.prop")

  return (api_level, codename)


def GetCodenameToApiLevelMap(input_tf_zip):
  data = input_tf_zip.read("SYSTEM/build.prop")
  api_level = None
  codenames = None
  for line in data.split("\n"):
    line = line.strip()
    original_line = line
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      key = key.strip()
      if key == "ro.build.version.sdk":
        api_level = int(value.strip())
      elif key == "ro.build.version.all_codenames":
        codenames = value.strip().split(",")

  if api_level is None:
    raise ValueError("No ro.build.version.sdk in SYSTEM/build.prop")
  if codenames is None:
    raise ValueError("No ro.build.version.all_codenames in SYSTEM/build.prop")

  result = dict()
  for codename in codenames:
    codename = codename.strip()
    if len(codename) > 0:
      result[codename] = api_level
  return result


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
    elif o == "--replace_verity_keyid":
      OPTIONS.replace_verity_keyid = (True, a)
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
                                              "replace_verity_private_key=",
                                              "replace_verity_keyid="],
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
  platform_api_level, platform_codename = GetApiLevelAndCodename(input_zip)
  codename_to_api_level_map = GetCodenameToApiLevelMap(input_zip)
  # Android N will be API Level 24, but isn't yet.
  # TODO: Remove this workaround once Android N is officially API Level 24.
  if platform_api_level == 23 and platform_codename == "N":
    platform_api_level = 24

  ProcessTargetFiles(input_zip, output_zip, misc_info,
                     apk_key_map, key_passwords,
                     platform_api_level,
                     codename_to_api_level_map)

  common.ZipClose(input_zip)
  common.ZipClose(output_zip)

  # Skip building userdata.img and cache.img when signing the target files.
  new_args = ["--is_signing", args[1]]
  add_img_to_target_files.main(new_args)

  print "done."


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  except common.ExternalError, e:
    print
    print "   ERROR: %s" % (e,)
    print
    sys.exit(1)
