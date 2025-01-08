#!/usr/bin/env python3
#
# Copyright (C) 2016 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import os
import sys

def main():
    try:
        product_out = os.environ["ANDROID_PRODUCT_OUT"]
    except KeyError:
        sys.stderr.write("Can't get ANDROID_PRODUCT_OUT. Run lunch first.\n")
        sys.exit(1)

    filename = os.path.join(product_out, "module-info.json")
    try:
        with open(filename) as f:
            modules = json.load(f)
    except FileNotFoundError:
        sys.stderr.write(f"File not found: {filename}\n")
        sys.exit(1)
    except json.JSONDecodeError:
        sys.stderr.write(f"Invalid json: {filename}\n")
        return None

    classes = {}

    for name, info in modules.items():
        make = info.get("make")
        make_gen = info.get("make_generated_module_info")
        if not make and make_gen:
            classes.setdefault(frozenset(info.get("class")), []).append(name)

    for cl, names in classes.items():
        print(" ".join(cl))
        for name in names:
            print(" ", name)

if __name__ == "__main__":
    main()
