#
# Copyright (C) 2021 The Android Open Source Project
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

$(call inherit-product, $(SRC_TARGET_DIR)/product/default_art_config.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_default.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/cfi-common.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/memtag-common.mk)

# Enables treble, which enabled certain -D compilation flags. In particular, libhidlbase
# uses -DENFORCE_VINTF_MANIFEST. See b/185759877
PRODUCT_SHIPPING_API_LEVEL := 29

# Builds using a module product should build modules from source, even if
# BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE says otherwise.
PRODUCT_MODULE_BUILD_FROM_SOURCE := true

# Build sdk from source if the branch is not using slim manifests.
ifneq (,$(strip $(wildcard frameworks/base/Android.bp)))
  UNBUNDLED_BUILD_SDKS_FROM_SOURCE := true
endif

PRODUCT_BRAND := Android
