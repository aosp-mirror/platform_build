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

# TODO(hansson): change inheritance to core_minimal, then generic_no_telephony
$(call inherit-product, $(SRC_TARGET_DIR)/product/base_system.mk)

PRODUCT_NAME := mainline_system
PRODUCT_BRAND := generic
PRODUCT_SHIPPING_API_LEVEL := 28

_base_mk_whitelist := \
  recovery/root/etc/mke2fs.conf \
  vendor/lib/mediadrm/libdrmclearkeyplugin.so \
  vendor/lib/soundfx/libdynproc.so \
  vendor/lib64/mediadrm/libdrmclearkeyplugin.so \
  vendor/lib64/soundfx/libdynproc.so \

_my_whitelist := $(_base_mk_whitelist)

# Both /system and / are in system.img when PRODUCT_SHIPPING_API_LEVEL>=28.
_my_paths := \
  $(TARGET_COPY_OUT_ROOT) \
  $(TARGET_COPY_OUT_SYSTEM) \

$(call require-artifacts-in-path, $(_my_paths), $(_my_whitelist))
