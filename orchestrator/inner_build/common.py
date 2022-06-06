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

import argparse
import sys

def _parse_arguments(argv):
    argv = argv[1:]
    """Return an argparse options object."""
    # Top-level parser
    parser = argparse.ArgumentParser(prog=".inner_build")

    parser.add_argument("--out_dir", action="store", required=True,
            help="root of the output directory for this inner tree's API contributions")

    parser.add_argument("--api_domain", action="append", required=True,
            help="which API domains are to be built in this inner tree")

    subparsers = parser.add_subparsers(required=True, dest="command",
            help="subcommands")

    # inner_build describe command
    describe_parser = subparsers.add_parser("describe",
            help="describe the capabilities of this inner tree's build system")

    # create the parser for the "b" command
    export_parser = subparsers.add_parser("export_api_contributions",
            help="export the API contributions of this inner tree")

    # create the parser for the "b" command
    export_parser = subparsers.add_parser("analyze",
            help="main build analysis for this inner tree")

    # Parse the arguments
    return parser.parse_args(argv)


class Commands(object):
    def Run(self, argv):
        """Parse the command arguments and call the corresponding subcommand method on
        this object.

        Throws AttributeError if the method for the command wasn't found.
        """
        args = _parse_arguments(argv)
        return getattr(self, args.command)(args)

