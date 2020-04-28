#!/usr/bin/env python
#
# Copyright (C) 2016 The Android Open Source Project
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

"""Utility to verify modules link against acceptable module types"""

from __future__ import print_function
import argparse
import os
import sys

WARNING_MSG = ('\033[1m%(makefile)s: \033[35mwarning:\033[0m\033[1m '
    '%(module)s (%(type)s) should not link to %(dep_name)s (%(dep_type)s)'
    '\033[0m')
ERROR_MSG = ('\033[1m%(makefile)s: \033[31merror:\033[0m\033[1m '
    '%(module)s (%(type)s) should not link to %(dep_name)s (%(dep_type)s)'
    '\033[0m')

def parse_args():
    """Parse commandline arguments."""
    parser = argparse.ArgumentParser(description='Check link types')
    parser.add_argument('--makefile', help='Makefile defining module')
    parser.add_argument('--module', help='The module being checked')
    parser.add_argument('--type', help='The link type of module')
    parser.add_argument('--allowed', help='Allow deps to use these types',
                        action='append', default=[], metavar='TYPE')
    parser.add_argument('--warn', help='Warn if deps use these types',
                        action='append', default=[], metavar='TYPE')
    parser.add_argument('deps', help='The dependencies to check',
                        metavar='DEP', nargs='*')
    return parser.parse_args()

def print_msg(msg, args, dep_name, dep_type):
    """Print a warning or error message"""
    print(msg % {
          "makefile": args.makefile,
          "module": args.module,
          "type": args.type,
          "dep_name": dep_name,
          "dep_type": dep_type}, file=sys.stderr)

def main():
    """Program entry point."""
    args = parse_args()

    failed = False
    for dep in args.deps:
        dep_name = os.path.basename(os.path.dirname(dep))
        if dep_name.endswith('_intermediates'):
            dep_name = dep_name[:len(dep_name)-len('_intermediates')]

        with open(dep, 'r') as dep_file:
            dep_types = dep_file.read().strip().split(' ')

        for dep_type in dep_types:
            if dep_type in args.allowed:
                continue
            if dep_type in args.warn:
                print_msg(WARNING_MSG, args, dep_name, dep_type)
            else:
                print_msg(ERROR_MSG, args, dep_name, dep_type)
                failed = True

    if failed:
        sys.exit(1)

if __name__ == '__main__':
    main()
