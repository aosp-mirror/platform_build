#
# Copyright (C) 2020 The Android Open Source Project
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
#

# This makefile installs contents of the generic ramdisk.
# Inherit from this makefile to declare that this product uses generic ramdisk.
# This makefile checks that other makefiles must not install things to the
# ramdisk.

# Ramdisk
PRODUCT_PACKAGES += \
    init_first_stage \
    snapuserd_ramdisk \

# Debug ramdisk
PRODUCT_PACKAGES += \
    adb_debug.prop \
    userdebug_plat_sepolicy.cil \


# For targets using dedicated recovery partition, generic ramdisk
# might be relocated to recovery partition
_my_paths := \
    $(TARGET_COPY_OUT_RAMDISK)/ \
    $(TARGET_COPY_OUT_DEBUG_RAMDISK)/ \
    system/usr/share/zoneinfo/tz_version \
    system/usr/share/zoneinfo/tzdata \
    $(TARGET_COPY_OUT_RECOVERY)/root/first_stage_ramdisk/system \


# We use the "relaxed" version here because tzdata / tz_version is only produced
# by this makefile on a subset of devices.
# TODO: remove this
$(call require-artifacts-in-path-relaxed, $(_my_paths), )
