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
            with open(os.path.join(contributions_dir, "api_a-1.json"), "w") as f:
                # 'name: android' is android.jar
                f.write(textwrap.dedent("""\
                {
                    "name": "api_a",
                    "version": 1,
                    "api_domain": "system",
                    "cc_libraries": [
                        {
                            "name": "libhello1",
                            "headers": [
                                {
                                    "root": "build/build/make/orchestrator/test_workspace/inner_tree_1",
                                    "files": [
                                        "hello1.h"
                                    ]
                                }
                            ],
                            "api": [
                                "build/build/make/orchestrator/test_workspace/inner_tree_1/libhello1"
                            ]
                        }
                    ]
                }"""))

    def analyze(self, args):
        if "system" in args.api_domain:
            # Nothing to export in this demo
            # Write a fake inner_tree.ninja; what the inner tree would have generated
            with open(os.path.join(args.out_dir, "inner_tree.ninja"), "w") as f:
                # TODO: Note that this uses paths relative to the workspace not the iner tree
                # for demo purposes until we get the ninja chdir change in.
                f.write(textwrap.dedent("""\
                    rule compile_c
                        command = mkdir -p ${out_dir} && g++ -c ${cflags} -o ${out} ${in}
                    rule link_so
                        command = mkdir -p ${out_dir} && gcc -shared -o ${out} ${in}
                    build %(OUT_DIR)s/libhello1/hello1.o: compile_c build/build/make/orchestrator/test_workspace/inner_tree_1/libhello1/hello1.c
                        out_dir = %(OUT_DIR)s/libhello1
                        cflags = -Ibuild/build/make/orchestrator/test_workspace/inner_tree_1/libhello1/include
                    build %(OUT_DIR)s/libhello1/libhello1.so: link_so %(OUT_DIR)s/libhello1/hello1.o
                        out_dir = %(OUT_DIR)s/libhello1
                    build system: phony %(OUT_DIR)s/libhello1/libhello1.so
                """ % { "OUT_DIR": args.out_dir }))
            with open(os.path.join(args.out_dir, "build_targets.json"), "w") as f:
                f.write(textwrap.dedent("""\
                {
                    "staging": [
                        {
                            "dest": "staging/system/lib/libhello1.so",
                            "obj": "libhello1/libhello1.so"
                        }
                    ]
                }""" % { "OUT_DIR": args.out_dir }))

def main(argv):
    return InnerBuildSoong().Run(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv))


# vim: sts=4:ts=4:sw=4
