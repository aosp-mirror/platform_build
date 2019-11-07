#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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
Check dynamic partition sizes.

usage: check_partition_sizes [info.txt]

Check dump-super-partitions-info procedure for expected keys in info.txt. In
addition, *_image (e.g. system_image, vendor_image, etc.) must be defined for
each partition in dynamic_partition_list.

Exit code is 0 if successful and non-zero if any failures.
"""

from __future__ import print_function

import logging
import sys

import common
import sparse_img

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

class Expression(object):
  def __init__(self, desc, expr, value=None):
    # Human-readable description
    self.desc = str(desc)
    # Numeric expression
    self.expr = str(expr)
    # Value of expression
    self.value = int(expr) if value is None else value

  def CheckLe(self, other, level=logging.ERROR):
    format_args = (self.desc, other.desc, self.expr, self.value,
                   other.expr, other.value)
    if self.value <= other.value:
      logger.info("%s is less than or equal to %s:\n%s == %d <= %s == %d",
                  *format_args)
    else:
      msg = "{} is greater than {}:\n{} == {} > {} == {}".format(*format_args)
      if level == logging.ERROR:
        raise RuntimeError(msg)
      else:
        logger.log(level, msg)

  def CheckEq(self, other):
    format_args = (self.desc, other.desc, self.expr, self.value,
                   other.expr, other.value)
    if self.value == other.value:
      logger.info("%s equals %s:\n%s == %d == %s == %d", *format_args)
    else:
      raise RuntimeError("{} does not equal {}:\n{} == {} != {} == {}".format(
          *format_args))


# A/B feature flags
class DeviceType(object):
  NONE = 0
  AB = 1
  RVAB = 2 # retrofit Virtual-A/B
  VAB = 3

  @staticmethod
  def Get(info_dict):
    if info_dict.get("ab_update") != "true":
      return DeviceType.NONE
    if info_dict.get("virtual_ab_retrofit") == "true":
      return DeviceType.RVAB
    if info_dict.get("virtual_ab") == "true":
      return DeviceType.VAB
    return DeviceType.AB


# Dynamic partition feature flags
class Dap(object):
  NONE = 0
  RDAP = 1
  DAP = 2

  @staticmethod
  def Get(info_dict):
    if info_dict.get("use_dynamic_partitions") != "true":
      return Dap.NONE
    if info_dict.get("dynamic_partition_retrofit") == "true":
      return Dap.RDAP
    return Dap.DAP


class DynamicPartitionSizeChecker(object):
  def __init__(self, info_dict):
    if "super_partition_size" in info_dict:
      if "super_partition_warn_limit" not in info_dict:
        info_dict["super_partition_warn_limit"] = \
            int(info_dict["super_partition_size"]) * 95 // 100
      if "super_partition_error_limit" not in info_dict:
        info_dict["super_partition_error_limit"] = \
            int(info_dict["super_partition_size"])
    self.info_dict = info_dict


  def _ReadSizeOfPartition(self, name):
    # Tests uses *_image_size instead (to avoid creating empty sparse images
    # on disk)
    if name + "_image_size" in self.info_dict:
      return int(self.info_dict[name + "_image_size"])
    return sparse_img.GetImagePartitionSize(self.info_dict[name + "_image"])


  # Round result to BOARD_SUPER_PARTITION_ALIGNMENT
  def _RoundPartitionSize(self, size):
    alignment = self.info_dict.get("super_partition_alignment")
    if alignment is None:
      return size
    return (size + alignment - 1) // alignment * alignment


  def _CheckSuperPartitionSize(self):
    info_dict = self.info_dict
    super_block_devices = \
        info_dict.get("super_block_devices", "").strip().split()
    size_list = [int(info_dict.get("super_{}_device_size".format(b), "0"))
                 for b in super_block_devices]
    sum_size = Expression("sum of super partition block device sizes",
                          "+".join(str(size) for size in size_list),
                          sum(size_list))
    super_partition_size = Expression("BOARD_SUPER_PARTITION_SIZE",
                                      info_dict["super_partition_size"])
    sum_size.CheckEq(super_partition_size)

  def _CheckSumOfPartitionSizes(self, max_size, partition_names,
                                warn_size=None, error_size=None):
    partition_size_list = [self._RoundPartitionSize(
        self._ReadSizeOfPartition(p)) for p in partition_names]
    sum_size = Expression("sum of sizes of {}".format(partition_names),
                          "+".join(str(size) for size in partition_size_list),
                          sum(partition_size_list))
    sum_size.CheckLe(max_size)
    if error_size:
      sum_size.CheckLe(error_size)
    if warn_size:
      sum_size.CheckLe(warn_size, level=logging.WARNING)

  def _NumDeviceTypesInSuper(self):
    slot = DeviceType.Get(self.info_dict)
    dap = Dap.Get(self.info_dict)

    if dap == Dap.NONE:
      raise RuntimeError("check_partition_sizes should only be executed on "
                         "builds with dynamic partitions enabled")

    # Retrofit dynamic partitions: 1 slot per "super", 2 "super"s on the device
    if dap == Dap.RDAP:
      if slot != DeviceType.AB:
        raise RuntimeError("Device with retrofit dynamic partitions must use "
                           "regular (non-Virtual) A/B")
      return 1

    # Launch DAP: 1 super on the device
    assert dap == Dap.DAP

    # DAP + A/B: 2 slots in super
    if slot == DeviceType.AB:
      return 2

    # DAP + retrofit Virtual A/B: same as A/B
    if slot == DeviceType.RVAB:
      return 2

    # DAP + Launch Virtual A/B: 1 *real* slot in super (2 virtual slots)
    if slot == DeviceType.VAB:
      return 1

    # DAP + non-A/B: 1 slot in super
    assert slot == DeviceType.NONE
    return 1

  def _CheckAllPartitionSizes(self):
    info_dict = self.info_dict
    num_slots = self._NumDeviceTypesInSuper()
    size_limit_suffix = (" / %d" % num_slots) if num_slots > 1 else ""

    # Check sum(all partitions) <= super partition (/ 2 for A/B devices launched
    # with dynamic partitions)
    if "super_partition_size" in info_dict and \
        "dynamic_partition_list" in info_dict:
      max_size = Expression(
          "BOARD_SUPER_PARTITION_SIZE{}".format(size_limit_suffix),
          int(info_dict["super_partition_size"]) // num_slots)
      warn_limit = Expression(
          "BOARD_SUPER_PARTITION_WARN_LIMIT{}".format(size_limit_suffix),
          int(info_dict["super_partition_warn_limit"]) // num_slots)
      error_limit = Expression(
          "BOARD_SUPER_PARTITION_ERROR_LIMIT{}".format(size_limit_suffix),
          int(info_dict["super_partition_error_limit"]) // num_slots)
      self._CheckSumOfPartitionSizes(
          max_size, info_dict["dynamic_partition_list"].strip().split(),
          warn_limit, error_limit)

    groups = info_dict.get("super_partition_groups", "").strip().split()

    # For each group, check sum(partitions in group) <= group size
    for group in groups:
      if "super_{}_group_size".format(group) in info_dict and \
          "super_{}_partition_list".format(group) in info_dict:
        group_size = Expression(
            "BOARD_{}_SIZE".format(group),
            int(info_dict["super_{}_group_size".format(group)]))
        self._CheckSumOfPartitionSizes(
            group_size,
            info_dict["super_{}_partition_list".format(group)].strip().split())

    # Check sum(all group sizes) <= super partition (/ 2 for A/B devices
    # launched with dynamic partitions)
    if "super_partition_size" in info_dict:
      group_size_list = [int(info_dict.get(
          "super_{}_group_size".format(group), 0)) for group in groups]
      sum_size = Expression("sum of sizes of {}".format(groups),
                            "+".join(str(size) for size in group_size_list),
                            sum(group_size_list))
      max_size = Expression(
          "BOARD_SUPER_PARTITION_SIZE{}".format(size_limit_suffix),
          int(info_dict["super_partition_size"]) // num_slots)
      sum_size.CheckLe(max_size)

  def Run(self):
    self._CheckAllPartitionSizes()
    if self.info_dict.get("dynamic_partition_retrofit") == "true":
      self._CheckSuperPartitionSize()


def CheckPartitionSizes(inp):
  if isinstance(inp, str):
    info_dict = common.LoadDictionaryFromFile(inp)
    return DynamicPartitionSizeChecker(info_dict).Run()
  if isinstance(inp, dict):
    return DynamicPartitionSizeChecker(inp).Run()
  raise ValueError("{} is not a dictionary or a valid path".format(inp))


def main(argv):
  args = common.ParseOptions(argv, __doc__)
  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)
  common.InitLogging()
  CheckPartitionSizes(args[0])


if __name__ == "__main__":
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError:
    logger.exception("\n   ERROR:\n")
    sys.exit(1)
  finally:
    common.Cleanup()
