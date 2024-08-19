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

def find_unique_items(kati_installed_files, soong_installed_files, allowlist, system_module_name):
    with open(kati_installed_files, 'r') as kati_list_file, \
            open(soong_installed_files, 'r') as soong_list_file, \
            open(allowlist, 'r') as allowlist_file:
        kati_files = set(kati_list_file.read().split())
        soong_files = set(soong_list_file.read().split())
        allowed_files = set(filter(lambda x: len(x), map(lambda x: x.lstrip().split('#',1)[0].rstrip() , allowlist_file.read().split('\n'))))

    def is_unknown_diff(filepath):
        return not filepath in allowed_files

    unique_in_kati = set(filter(is_unknown_diff, kati_files - soong_files))
    unique_in_soong = set(filter(is_unknown_diff, soong_files - kati_files))

    if unique_in_kati:
        print(f'{COLOR_ERROR}Please add following modules into system image module {system_module_name}.{COLOR_NORMAL}')
        print(f'{COLOR_WARNING}KATI only module(s):{COLOR_NORMAL}')
        for item in sorted(unique_in_kati):
            print(item)

    if unique_in_soong:
        if unique_in_kati:
            print('')

        print(f'{COLOR_ERROR}Please add following modules into build/make/target/product/base_system.mk.{COLOR_NORMAL}')
        print(f'{COLOR_WARNING}Soong only module(s):{COLOR_NORMAL}')
        for item in sorted(unique_in_soong):
            print(item)

    if unique_in_kati or unique_in_soong:
        print('')
        print(f'{COLOR_ERROR}FAILED: System image from KATI and SOONG differs from installed file list.{COLOR_NORMAL}')
        sys.exit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument('kati_installed_file_list')
    parser.add_argument('soong_installed_file_list')
    parser.add_argument('allowlist')
    parser.add_argument('system_module_name')
    args = parser.parse_args()

    find_unique_items(args.kati_installed_file_list, args.soong_installed_file_list, args.allowlist, args.system_module_name)