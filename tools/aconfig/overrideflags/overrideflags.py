#!/usr/bin/env python3
#
# Copyright (C) 2023 The Android Open Source Project
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
"""Create Aconfig value building rules.

This script will help to create Aconfig flag value building rules. It will
parse necessary information in the value file to create the building rules, but
it will not validate the value file. The validation will defer to the building
system.
"""

import argparse
import pathlib
import re
import sys


_VALUE_LIST_TEMPLATE: str = """
ACONFIG_VALUES_LIST_LOCAL = [{}]
"""

_ACONFIG_VALUES_TEMPLATE: str = """
aconfig_values {{
    name: "{}",
    package: "{}",
    srcs: [
        "{}",
    ]
}}
"""

_ACONFIG_VALUES_NAME_SUFFIX: str = "aconfig-local-override-{}"

_PACKAGE_REGEX = re.compile(r"^package\:\s*\"([\w\d\.]+)\"")
_ANDROID_BP_FILE_NAME = r"Android.bp"


def _parse_packages(file: pathlib.Path) -> set[str]:
  packages = set()
  with open(file) as f:
    for line in f:
      line = line.strip()
      package_match = _PACKAGE_REGEX.match(line)
      if package_match is None:
        continue
      package_name = package_match.group(1)
      packages.add(package_name)

  return packages


def _create_android_bp(packages: set[str], file_name: str) -> str:
  android_bp = ""
  value_list = ",\n    ".join(
      map(f'"{_ACONFIG_VALUES_NAME_SUFFIX}"'.format, packages)
  )
  if value_list:
    value_list = "\n    " + value_list + "\n"
  android_bp += _VALUE_LIST_TEMPLATE.format(value_list) + "\n"

  for package in packages:
    android_bp += _ACONFIG_VALUES_TEMPLATE.format(
        _ACONFIG_VALUES_NAME_SUFFIX.format(package), package, file_name
    )
    android_bp += "\n"

  return android_bp


def _write_android_bp(new_android_bp: str, out: pathlib.Path) -> None:
  if not out.is_dir():
    out.mkdir(parents=True, exist_ok=True)

  output = out.joinpath(_ANDROID_BP_FILE_NAME)
  with open(output, "r+", encoding="utf8") as file:
    lines = []
    for line in file:
      line = line.rstrip("\n")
      if line.startswith("ACONFIG_VALUES_LIST_LOCAL"):
        break
      lines.append(line)
    # Overwrite the file with the updated contents.
    file.seek(0)
    file.truncate()
    file.write("\n".join(lines))
    file.write(new_android_bp)


def main(args):
  """Program entry point."""
  args_parser = argparse.ArgumentParser()
  args_parser.add_argument(
      "--overrides",
      required=True,
      help="The path to override file.",
  )
  args_parser.add_argument(
      "--out",
      required=True,
      help="The path to output directory.",
  )

  args = args_parser.parse_args(args)
  file = pathlib.Path(args.overrides)
  out = pathlib.Path(args.out)
  if not file.is_file():
    raise FileNotFoundError(f"File '{file}' is not found")

  packages = _parse_packages(file)
  new_android_bp = _create_android_bp(packages, file.name)
  _write_android_bp(new_android_bp, out)


if __name__ == "__main__":
  main(sys.argv[1:])
