#!/usr/bin/env python3
#
# Copyright (C) 2022 The Android Open Source Project
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
Checks and generates a report for gts modules that should be open-sourced.

Usage:
  generate_gts_open_source_report.py
    --gts-test-metalic [android-gts meta_lic]
    --checkshare [COMPLIANCE_CHECKSHARE]
    --gts-test-dir [directory of android-gts]
    --output [output file]

Output example:
  GTS-Modules: PASS/FAIL
    GtsIncrementalInstallTestCases_BackgroundProcess
    GtsUnsignedNetworkStackTestCases
"""
import sys
import argparse
import subprocess
import re

def _get_args():
    """Parses input arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--gts-test-metalic', required=True,
        help='license meta_lic file path of android-gts.zip')
    parser.add_argument(
        '--checkshare', required=True,
        help='path of the COMPLIANCE_CHECKSHARE tool')
    parser.add_argument(
        '--gts-test-dir', required=True,
        help='directory of android-gts')
    parser.add_argument(
        '-o', '--output', required=True,
        help='file path of the output report')
    return parser.parse_args()

def _check_gts_test(checkshare: str, gts_test_metalic: str,
                    gts_test_dir: str) -> tuple[str, set[str]]:
    """Checks android-gts license.

    Args:
      checkshare: path of the COMPLIANCE_CHECKSHARE tool
      gts_test_metalic: license meta_lic file path of android-gts.zip
      gts_test_dir: directory of android-gts

    Returns:
      Check result (PASS when android-gts doesn't need to be shared,
      FAIL when some gts modules need to be shared) and gts modules
      that need to be shared.
    """
    cmd = f'{checkshare} {gts_test_metalic}'
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    _, str_stderr = map(lambda b: b.decode(), proc.communicate())
    if proc.returncode == 0:
        return 'PASS', []
    open_source_modules = set()
    for error_line in str_stderr.split('\n'):
        # Skip the empty liness
        if not error_line:
            continue
        module_meta_lic = error_line.strip().split()[0]
        groups = re.fullmatch(
            re.compile(f'.*/{gts_test_dir}/(.*)'), module_meta_lic)
        if groups:
            open_source_modules.add(
                groups[1].removesuffix('.meta_lic'))
    return 'FAIL', open_source_modules


def main(argv):
    args = _get_args()

    gts_test_metalic = args.gts_test_metalic
    output_file = args.output
    checkshare = args.checkshare
    gts_test_dir = args.gts_test_dir

    with open(output_file, 'w') as file:
        result, open_source_modules = _check_gts_test(
            checkshare, gts_test_metalic, gts_test_dir)
        file.write(f'GTS-Modules: {result}\n')
        for open_source_module in open_source_modules:
            file.write(f'\t{open_source_module}\n')

if __name__ == "__main__":
    main(sys.argv)
