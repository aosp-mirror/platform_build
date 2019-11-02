#
# Copyright (C) 2018 The Android Open Source Project
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

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/mainline.mk)
whitelist := product_manifest.xml
$(call enforce-product-packages-exist,$(whitelist))

PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed

# Modules that should probably be moved to /product
PRODUCT_ARTIFACT_PATH_REQUIREMENT_WHITELIST += \
  system/bin/healthd \
  system/etc/init/healthd.rc \
  system/etc/vintf/manifest/manifest_healthd.xml \

PRODUCT_SHIPPING_API_LEVEL := 29

PRODUCT_RESTRICT_VENDOR_FILES := all

PRODUCT_NAME := mainline_arm64
PRODUCT_DEVICE := mainline_arm64
PRODUCT_BRAND := generic
