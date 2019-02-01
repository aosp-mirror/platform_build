#
# Copyright (C) 2013 The Android Open Source Project
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

# This product is the base of a generic media-capable device, which
# means most android products, but excludes wearables.
#
# Note: Do not add any contents directly to this file. Choose either
# media_<x> depending on partition also consider base_<x>.mk or
# handheld_<x>.mk.

$(call inherit-product, $(SRC_TARGET_DIR)/product/media_system.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/media_vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/media_product.mk)

PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := core
