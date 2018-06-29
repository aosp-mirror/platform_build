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

_selinux_policy_whitelist := \
  vendor/etc/selinux/vndservice_contexts \
  vendor/etc/selinux/plat_pub_versioned.cil \
  vendor/etc/selinux/plat_sepolicy_vers.txt \
  vendor/etc/selinux/precompiled_sepolicy \
  vendor/etc/selinux/precompiled_sepolicy.plat_and_mapping.sha256 \
  vendor/etc/selinux/vendor_file_contexts \
  vendor/etc/selinux/vendor_hwservice_contexts \
  vendor/etc/selinux/vendor_mac_permissions.xml \
  vendor/etc/selinux/vendor_property_contexts \
  vendor/etc/selinux/vendor_seapp_contexts \
  vendor/etc/selinux/vendor_sepolicy.cil \

_base_mk_whitelist := \
  $(_selinux_policy_whitelist) \
  recovery/root/etc/mke2fs.conf \
  root/init \
  root/init.environ.rc \
  root/init.rc \
  root/init.usb.configfs.rc \
  root/init.usb.rc \
  root/init.zygote32.rc \
  root/sbin/charger \
  root/ueventd.rc \
  vendor/lib/mediadrm/libdrmclearkeyplugin.so \
  vendor/lib64/mediadrm/libdrmclearkeyplugin.so \

_my_whitelist := $(_base_mk_whitelist)

$(call require-artifacts-in-path, $(TARGET_COPY_OUT_SYSTEM), $(_my_whitelist))
