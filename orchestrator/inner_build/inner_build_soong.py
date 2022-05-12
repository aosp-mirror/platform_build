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

sys.dont_write_bytecode = True
import common

class InnerBuildSoong(common.Commands):
    def describe(self, args):
        pass


    def export_api_contributions(self, args):
        pass


def main(argv):
    return InnerBuildSoong().Run(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
