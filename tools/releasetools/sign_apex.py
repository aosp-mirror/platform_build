#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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
Signs a standalone APEX file.

Usage:  sign_apex [flags] input_apex_file output_apex_file

  --avbtool <avbtool>
      Optional flag that specifies the AVB tool to use. Defaults to `avbtool`.

  --container_key <key>
      Mandatory flag that specifies the container signing key.

  --payload_key <key>
      Mandatory flag that specifies the payload signing key.

  --payload_extra_args <args>
      Optional flag that specifies any extra args to be passed to payload signer
      (e.g. --payload_extra_args="--signing_helper_with_files /path/to/helper").

  -e  (--extra_apks)  <name,name,...=key>
      Add extra APK name/key pairs. This is useful to sign the apk files in the
      apex payload image.

  --codename_to_api_level_map Q:29,R:30,...
      A Mapping of codename to api level.  This is useful to provide sdk targeting
      information to APK Signer.

  --sign_tool <sign_tool>
      Optional flag that specifies a custom signing tool for the contents of the apex.

  --container_pw <name1=passwd,name2=passwd>
      A mapping of key_name to password
"""

import logging
import shutil
import re
import sys

import apex_utils
import common

logger = logging.getLogger(__name__)


def SignApexFile(avbtool, apex_file, payload_key, container_key, no_hashtree,
                 apk_keys=None, signing_args=None, codename_to_api_level_map=None, sign_tool=None, container_pw=None):
  """Signs the given apex file."""
  with open(apex_file, 'rb') as input_fp:
    apex_data = input_fp.read()

  return apex_utils.SignApex(
      avbtool,
      apex_data,
      payload_key=payload_key,
      container_key=container_key,
      container_pw=container_pw,
      codename_to_api_level_map=codename_to_api_level_map,
      no_hashtree=no_hashtree,
      apk_keys=apk_keys,
      signing_args=signing_args,
      sign_tool=sign_tool)


def main(argv):

  options = {}

  def option_handler(o, a):
    if o == '--avbtool':
      options['avbtool'] = a
    elif o == '--container_key':
      # Strip the suffix if any, as common.SignFile expects no suffix.
      DEFAULT_CONTAINER_KEY_SUFFIX = '.x509.pem'
      if a.endswith(DEFAULT_CONTAINER_KEY_SUFFIX):
        a = a[:-len(DEFAULT_CONTAINER_KEY_SUFFIX)]
      options['container_key'] = a
    elif o == '--payload_key':
      options['payload_key'] = a
    elif o == '--payload_extra_args':
      options['payload_extra_args'] = a
    elif o == '--codename_to_api_level_map':
      versions = a.split(",")
      for v in versions:
        key, value = v.split(":")
        if 'codename_to_api_level_map' not in options:
          options['codename_to_api_level_map'] = {}
        options['codename_to_api_level_map'].update({key: value})
    elif o in ("-e", "--extra_apks"):
      names, key = a.split("=")
      names = names.split(",")
      for n in names:
        if 'extra_apks' not in options:
          options['extra_apks'] = {}
        options['extra_apks'].update({n: key})
    elif o == '--sign_tool':
      options['sign_tool'] = a
    elif o == '--container_pw':
      passwords = {}
      pairs = a.split()
      for pair in pairs:
        if "=" not in pair:
          continue
        tokens = pair.split("=", maxsplit=1)
        passwords[tokens[0].strip()] = tokens[1].strip()
      options['container_pw'] = passwords
    else:
      return False
    return True

  args = common.ParseOptions(
      argv, __doc__,
      extra_opts='e:',
      extra_long_opts=[
          'avbtool=',
          'codename_to_api_level_map=',
          'container_key=',
          'payload_extra_args=',
          'payload_key=',
          'extra_apks=',
          'sign_tool=',
          'container_pw=',
      ],
      extra_option_handler=option_handler)

  if (len(args) != 2 or 'container_key' not in options or
      'payload_key' not in options):
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  signed_apex = SignApexFile(
      options.get('avbtool', 'avbtool'),
      args[0],
      options['payload_key'],
      options['container_key'],
      no_hashtree=False,
      apk_keys=options.get('extra_apks', {}),
      signing_args=options.get('payload_extra_args'),
      codename_to_api_level_map=options.get(
          'codename_to_api_level_map', {}),
      sign_tool=options.get('sign_tool', None),
      container_pw=options.get('container_pw'),
  )
  shutil.copyfile(signed_apex, args[1])
  logger.info("done.")


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
