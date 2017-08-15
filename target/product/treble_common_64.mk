#
# Copyright (C) 2017 The Android Open-Source Project
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

# PRODUCT_PROPERTY_OVERRIDES cannot be used here because sysprops will be at
# /vendor/[build|default].prop when build split is on. In order to have sysprops
# on the generic system image, place them in build/make/target/board/
# treble_system.prop.

include build/make/target/product/treble_common.mk

# For now this will allow 64-bit apps, but still compile all apps with JNI
# for 32-bit only.

# Copy the 64-bit primary, 32-bit secondary zygote startup script
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote64_32.rc:root/init.zygote64_32.rc

# Set the zygote property to select the 64-bit primary, 32-bit secondary script
# This line must be parsed before the one in core_minimal.mk
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote64_32

TARGET_SUPPORTS_32_BIT_APPS := true
TARGET_SUPPORTS_64_BIT_APPS := true
