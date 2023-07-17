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
#

# This is a simple product that uses configures the minimum amount
# needed to build the SDK (without the emulator).

$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_default.mk)

PRODUCT_NAME := sdk
PRODUCT_BRAND := Android
PRODUCT_DEVICE := mainline_x86
