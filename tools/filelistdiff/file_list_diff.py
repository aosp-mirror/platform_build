# Copyright (C) 2024 The Android Open Source Project
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

import argparse
import sys

COLOR_WARNING = '\033[93m'
COLOR_ERROR = '\033[91m'
COLOR_NORMAL = '\033[0m'

def find_unique_items(kati_installed_files, soong_installed_files, system_module_name, allowlists):
    with open(kati_installed_files, 'r') as kati_list_file, \
            open(soong_installed_files, 'r') as soong_list_file:
        kati_files = set(kati_list_file.read().split())
        soong_files = set(soong_list_file.read().split())

    allowed_files = set()
    for allowlist in allowlists:
        with open(allowlist, 'r') as allowlist_file:
            allowed_files.update(set(filter(lambda x: len(x), map(lambda x: x.lstrip().split('#',1)[0].rstrip() , allowlist_file.read().split('\n')))))

    def is_unknown_diff(filepath):
        return not filepath in allowed_files

    unique_in_kati = set(filter(is_unknown_diff, kati_files - soong_files))
    unique_in_soong = set(filter(is_unknown_diff, soong_files - kati_files))

    if unique_in_kati:
        print('')
        print(f'{COLOR_ERROR}Missing required modules in {system_module_name} module.{COLOR_NORMAL}')
        print(f'To resolve this issue, please add the modules to the Android.bp file for the {system_module_name} to install the following KATI only installed files.')
        print(f'You can find the correct Android.bp file using the command "gomod {system_module_name}".')
        print(f'{COLOR_WARNING}KATI only installed file(s):{COLOR_NORMAL}')
        for item in sorted(unique_in_kati):
            print('  '+item)

    if unique_in_soong:
        print('')
        print(f'{COLOR_ERROR}Missing packages in base_system.mk.{COLOR_NORMAL}')
        print('Please add packages into build/make/target/product/base_system.mk or build/make/tools/filelistdiff/allowlist to install or skip the following Soong only installed files.')
        print(f'{COLOR_WARNING}Soong only installed file(s):{COLOR_NORMAL}')
        for item in sorted(unique_in_soong):
            print('  '+item)

    if unique_in_kati or unique_in_soong:
        print('')
        sys.exit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument('kati_installed_file_list')
    parser.add_argument('soong_installed_file_list')
    parser.add_argument('system_module_name')
    parser.add_argument('--allowlists', nargs='+')
    args = parser.parse_args()

    find_unique_items(args.kati_installed_file_list, args.soong_installed_file_list, args.system_module_name, args.allowlists)