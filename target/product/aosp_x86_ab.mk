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

include build/make/target/product/treble_common_32.mk

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := system
PRODUCT_PACKAGES += \
    update_engine \
    update_verifier

PRODUCT_NAME := aosp_x86_ab
PRODUCT_DEVICE := generic_x86_ab
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on x86
