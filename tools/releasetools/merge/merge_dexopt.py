#!/usr/bin/env python
#
# Copyright (C) 2022 The Android Open Source Project
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
#
"""Generates dexopt files for vendor apps, from a merged target_files.

Expects items in OPTIONS prepared by merge_target_files.py.
"""

import glob
import json
import logging
import os
import shutil
import subprocess

import common
import merge_utils

logger = logging.getLogger(__name__)
OPTIONS = common.OPTIONS


def MergeDexopt(temp_dir, output_target_files_dir):
  """If needed, generates dexopt files for vendor apps.

  Args:
    temp_dir: Location containing an 'output' directory where target files have
      been extracted, e.g. <temp_dir>/output/SYSTEM, <temp_dir>/output/IMAGES,
      etc.
    output_target_files_dir: The name of a directory that will be used to create
      the output target files package after all the special cases are processed.
  """
  # Load vendor and framework META/misc_info.txt.
  if (OPTIONS.vendor_misc_info.get('building_with_vsdk') != 'true' or
      OPTIONS.framework_dexpreopt_tools is None or
      OPTIONS.framework_dexpreopt_config is None or
      OPTIONS.vendor_dexpreopt_config is None):
    return

  logger.info('applying dexpreopt')

  # The directory structure to apply dexpreopt is:
  #
  # <temp_dir>/
  #     framework_meta/
  #         META/
  #     vendor_meta/
  #         META/
  #     output/
  #         SYSTEM/
  #         VENDOR/
  #         IMAGES/
  #         <other items extracted from system and vendor target files>
  #     tools/
  #         <contents of dexpreopt_tools.zip>
  #     system_config/
  #         <contents of system dexpreopt_config.zip>
  #     vendor_config/
  #         <contents of vendor dexpreopt_config.zip>
  #     system -> output/SYSTEM
  #     vendor -> output/VENDOR
  #     apex/ (extracted updatable APEX)
  #         <apex 1>/
  #             ...
  #         <apex 2>/
  #             ...
  #         ...
  #     out/dex2oat_result/vendor/
  #         <app>
  #             oat/arm64/
  #                 package.vdex
  #                 package.odex
  #         <priv-app>
  #             oat/arm64/
  #                 package.vdex
  #                 package.odex
  dexpreopt_tools_files_temp_dir = os.path.join(temp_dir, 'tools')
  dexpreopt_framework_config_files_temp_dir = os.path.join(
      temp_dir, 'system_config')
  dexpreopt_vendor_config_files_temp_dir = os.path.join(temp_dir,
                                                        'vendor_config')

  merge_utils.ExtractItems(
      input_zip=OPTIONS.framework_dexpreopt_tools,
      output_dir=dexpreopt_tools_files_temp_dir,
      extract_item_list=('*',))
  merge_utils.ExtractItems(
      input_zip=OPTIONS.framework_dexpreopt_config,
      output_dir=dexpreopt_framework_config_files_temp_dir,
      extract_item_list=('*',))
  merge_utils.ExtractItems(
      input_zip=OPTIONS.vendor_dexpreopt_config,
      output_dir=dexpreopt_vendor_config_files_temp_dir,
      extract_item_list=('*',))

  os.symlink(
      os.path.join(output_target_files_dir, 'SYSTEM'),
      os.path.join(temp_dir, 'system'))
  os.symlink(
      os.path.join(output_target_files_dir, 'VENDOR'),
      os.path.join(temp_dir, 'vendor'))

  # Extract APEX.
  logging.info('extracting APEX')
  apex_extract_root_dir = os.path.join(temp_dir, 'apex')
  os.makedirs(apex_extract_root_dir)

  command = [
      'apexd_host',
      '--system_path',
      os.path.join(temp_dir, 'system'),
      '--apex_path',
      apex_extract_root_dir,
  ]
  logging.info('    running %s', command)
  subprocess.check_call(command)

  # Modify system config to point to the tools that have been extracted.
  # Absolute or .. paths are not allowed  by the dexpreopt_gen tool in
  # dexpreopt_soong.config.
  dexpreopt_framework_soon_config = os.path.join(
      dexpreopt_framework_config_files_temp_dir, 'dexpreopt_soong.config')
  with open(dexpreopt_framework_soon_config, 'w') as f:
    dexpreopt_soong_config = {
        'Profman': 'tools/profman',
        'Dex2oat': 'tools/dex2oatd',
        'Aapt': 'tools/aapt2',
        'SoongZip': 'tools/soong_zip',
        'Zip2zip': 'tools/zip2zip',
        'ManifestCheck': 'tools/manifest_check',
        'ConstructContext': 'tools/construct_context',
    }
    json.dump(dexpreopt_soong_config, f)

  # TODO(b/188179859): Make *dex location configurable to vendor or system_other.
  use_system_other_odex = False

  if use_system_other_odex:
    dex_img = 'SYSTEM_OTHER'
  else:
    dex_img = 'VENDOR'
    # Open vendor_filesystem_config to append the items generated by dexopt.
    vendor_file_system_config = open(
        os.path.join(temp_dir, 'output', 'META',
                     'vendor_filesystem_config.txt'), 'a')

  # Dexpreopt vendor apps.
  dexpreopt_config_suffix = '_dexpreopt.config'
  for config in glob.glob(
      os.path.join(dexpreopt_vendor_config_files_temp_dir,
                   '*' + dexpreopt_config_suffix)):
    app = os.path.basename(config)[:-len(dexpreopt_config_suffix)]
    logging.info('dexpreopt config: %s %s', config, app)

    apk_dir = 'app'
    apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
    if not os.path.exists(apk_path):
      apk_dir = 'priv-app'
      apk_path = os.path.join(temp_dir, 'vendor', apk_dir, app, app + '.apk')
      if not os.path.exists(apk_path):
        logging.warning(
            'skipping dexpreopt for %s, no apk found in vendor/app '
            'or vendor/priv-app', app)
        continue

    # Generate dexpreopting script. Note 'out_dir' is not the output directory
    # where the script is generated, but the OUT_DIR at build time referenced
    # in the dexpreot config files, e.g., "out/.../core-oj.jar", so the tool knows
    # how to adjust the path.
    command = [
        os.path.join(dexpreopt_tools_files_temp_dir, 'dexpreopt_gen'),
        '-global',
        os.path.join(dexpreopt_framework_config_files_temp_dir,
                     'dexpreopt.config'),
        '-global_soong',
        os.path.join(dexpreopt_framework_config_files_temp_dir,
                     'dexpreopt_soong.config'),
        '-module',
        config,
        '-dexpreopt_script',
        'dexpreopt_app.sh',
        '-out_dir',
        'out',
        '-base_path',
        '.',
        '--uses_target_files',
    ]

    # Run the command from temp_dir so all tool paths are its descendants.
    logging.info('running %s', command)
    subprocess.check_call(command, cwd=temp_dir)

    # Call the generated script.
    command = ['sh', 'dexpreopt_app.sh', apk_path]
    logging.info('running %s', command)
    subprocess.check_call(command, cwd=temp_dir)

    # Output files are in:
    #
    # <temp_dir>/out/dex2oat_result/vendor/priv-app/<app>/oat/arm64/package.vdex
    # <temp_dir>/out/dex2oat_result/vendor/priv-app/<app>/oat/arm64/package.odex
    # <temp_dir>/out/dex2oat_result/vendor/app/<app>/oat/arm64/package.vdex
    # <temp_dir>/out/dex2oat_result/vendor/app/<app>/oat/arm64/package.odex
    #
    # Copy the files to their destination. The structure of system_other is:
    #
    # system_other/
    #     system-other-odex-marker
    #     system/
    #         app/
    #             <app>/oat/arm64/
    #                 <app>.odex
    #                 <app>.vdex
    #             ...
    #         priv-app/
    #             <app>/oat/arm64/
    #                 <app>.odex
    #                 <app>.vdex
    #             ...

    # TODO(b/188179859): Support for other architectures.
    arch = 'arm64'

    dex_destination = os.path.join(temp_dir, 'output', dex_img, apk_dir, app,
                                   'oat', arch)
    os.makedirs(dex_destination)
    dex2oat_path = os.path.join(temp_dir, 'out', 'dex2oat_result', 'vendor',
                                apk_dir, app, 'oat', arch)
    shutil.copy(
        os.path.join(dex2oat_path, 'package.vdex'),
        os.path.join(dex_destination, app + '.vdex'))
    shutil.copy(
        os.path.join(dex2oat_path, 'package.odex'),
        os.path.join(dex_destination, app + '.odex'))

    # Append entries to vendor_file_system_config.txt, such as:
    #
    # vendor/app/<app>/oat 0 2000 755 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64 0 2000 755 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64/<app>.odex 0 0 644 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    # vendor/app/<app>/oat/arm64/<app>.vdex 0 0 644 selabel=u:object_r:vendor_app_file:s0 capabilities=0x0
    if not use_system_other_odex:
      vendor_app_prefix = 'vendor/' + apk_dir + '/' + app + '/oat'
      selabel = 'selabel=u:object_r:vendor_app_file:s0 capabilities=0x0'
      vendor_file_system_config.writelines([
          vendor_app_prefix + ' 0 2000 755 ' + selabel + '\n',
          vendor_app_prefix + '/' + arch + ' 0 2000 755 ' + selabel + '\n',
          vendor_app_prefix + '/' + arch + '/' + app + '.odex 0 0 644 ' +
          selabel + '\n',
          vendor_app_prefix + '/' + arch + '/' + app + '.vdex 0 0 644 ' +
          selabel + '\n',
      ])

  if not use_system_other_odex:
    vendor_file_system_config.close()
    # Delete vendor.img so that it will be regenerated.
    # TODO(b/188179859): Rebuilding a vendor image in GRF mode (e.g., T(framework)
    #                    and S(vendor) may require logic similar to that in
    #                    rebuild_image_with_sepolicy.
    vendor_img = os.path.join(output_target_files_dir, 'IMAGES', 'vendor.img')
    if os.path.exists(vendor_img):
      logging.info('Deleting %s', vendor_img)
      os.remove(vendor_img)
