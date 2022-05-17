#!/usr/bin/python3
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

import os
import sys
import textwrap

sys.dont_write_bytecode = True
import common

def mkdirs(path):
    try:
        os.makedirs(path)
    except FileExistsError:
        pass


class InnerBuildSoong(common.Commands):
    def describe(self, args):
        mkdirs(args.out_dir)

        with open(os.path.join(args.out_dir, "tree_info.json"), "w") as f:
            f.write(textwrap.dedent("""\
            {
                "requires_ninja": true,
                "orchestrator_protocol_version": 1
            }"""))

    def export_api_contributions(self, args):
        contributions_dir = os.path.join(args.out_dir, "api_contributions")
        mkdirs(contributions_dir)

        if "system" in args.api_domain:
            with open(os.path.join(contributions_dir, "public_api-1.json"), "w") as f:
                # 'name: android' is android.jar
                f.write(textwrap.dedent("""\
                {
                    "name": "public_api",
                    "version": 1,
                    "api_domain": "system",
                    "cc_libraries": [
                        {
                            "name": "libhwui",
                            "headers": [
                                {
                                    "root": "frameworks/base/libs/hwui/apex/include",
                                    "files": [
                                        "android/graphics/jni_runtime.h",
                                        "android/graphics/paint.h",
                                        "android/graphics/matrix.h",
                                        "android/graphics/canvas.h",
                                        "android/graphics/renderthread.h",
                                        "android/graphics/bitmap.h",
                                        "android/graphics/region.h"
                                    ]
                                }
                            ],
                            "api": [
                                "frameworks/base/libs/hwui/libhwui.map.txt"
                            ]
                        }
                    ],
                    "java_libraries": [
                        {
                            "name": "android",
                            "api": [
                                "frameworks/base/core/api/current.txt"
                            ]
                        }
                    ],
                    "resource_libraries": [
                        {
                            "name": "android",
                            "api": "frameworks/base/core/res/res/values/public.xml"
                        }
                    ],
                    "host_executables": [
                        {
                            "name": "aapt2",
                            "binary": "out/host/bin/aapt2",
                            "runfiles": [
                                "../lib/todo.so"
                            ]
                        }
                    ]
                }"""))
        elif "com.android.bionic" in args.api_domain:
            with open(os.path.join(contributions_dir, "public_api-1.json"), "w") as f:
                # 'name: android' is android.jar
                f.write(textwrap.dedent("""\
                {
                    "name": "public_api",
                    "version": 1,
                    "api_domain": "system",
                    "cc_libraries": [
                        {
                            "name": "libc",
                            "headers": [
                                {
                                    "root": "bionic/libc/include",
                                    "files": [
                                        "stdio.h",
                                        "sys/klog.h"
                                    ]
                                }
                            ],
                            "api": "bionic/libc/libc.map.txt"
                        }
                    ],
                    "java_libraries": [
                        {
                            "name": "android",
                            "api": [
                                "frameworks/base/libs/hwui/api/current.txt"
                            ]
                        }
                    ]
                }"""))



def main(argv):
    return InnerBuildSoong().Run(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv))


# vim: sts=4:ts=4:sw=4
