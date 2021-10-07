#
# Copyright (C) 2007 The Android Open Source Project
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

PRODUCT_SOONG_NAMESPACES += device/generic/goldfish # for libwifi-hal-emu
PRODUCT_SOONG_NAMESPACES += device/generic/goldfish-opengl # for goldfish deps.

# This is a generic phone product that isn't specialized for a specific device.
# It includes the base Android platform.

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := generic

allowed_list := product_manifest.xml

# TODO(b/182105280): When ART prebuilts are used in this product, Soong doesn't
# produce any Android.mk entries for them. Exclude them until that problem is
# fixed.
allowed_list += com.android.art com.android.art.debug

$(call enforce-product-packages-exist,$(allowed_list))
