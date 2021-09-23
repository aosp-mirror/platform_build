#
# Copyright (C) 2009 The Android Open Source Project
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

PRODUCT_COPY_FILES += \
    kernel/prebuilts/5.10/x86_64/kernel-5.10:kernel-5.10 \

$(call dist-for-goals, dist_files, kernel/prebuilts/5.10/x86_64/prebuilt-info.txt:kernel/5.10/prebuilt-info.txt)

ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
PRODUCT_COPY_FILES += \
    kernel/prebuilts/5.10/x86_64/kernel-5.10-allsyms:kernel-5.10-allsyms \

endif

PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_RECOVERY_IMAGE := false

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
