#!/usr/bin/env python
#
# Copyright (C) 2014 The Android Open Source Project
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

from __future__ import print_function

import logging
import os
import sys

import common

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS


def main(argv):
  args = common.ParseOptions(argv, __doc__)
  input_dir, output_dir = args

  common.InitLogging()

  OPTIONS.info_dict = common.LoadInfoDict(input_dir)

  recovery_img = common.GetBootableImage("recovery.img", "recovery.img",
                                         input_dir, "RECOVERY")
  boot_img = common.GetBootableImage("boot.img", "boot.img",
                                     input_dir, "BOOT")

  if not recovery_img or not boot_img:
    sys.exit(0)

  def output_sink(fn, data):
    with open(os.path.join(output_dir, "SYSTEM", *fn.split("/")), "wb") as f:
      f.write(data)

  common.MakeRecoveryPatch(input_dir, output_sink, recovery_img, boot_img)


if __name__ == '__main__':
  main(sys.argv[1:])
