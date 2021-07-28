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

PRODUCT_COPY_FILES += \
    kernel/prebuilts/4.19/arm64/kernel-4.19-gz:kernel-4.19-gz \
    kernel/prebuilts/5.4/arm64/kernel-5.4:kernel-5.4 \
    kernel/prebuilts/5.4/arm64/kernel-5.4-gz:kernel-5.4-gz \
    kernel/prebuilts/5.4/arm64/kernel-5.4-lz4:kernel-5.4-lz4 \
    kernel/prebuilts/5.10/arm64/kernel-5.10:kernel-5.10 \
    kernel/prebuilts/5.10/arm64/kernel-5.10-gz:kernel-5.10-gz \
    kernel/prebuilts/5.10/arm64/kernel-5.10-lz4:kernel-5.10-lz4 \
    kernel/prebuilts/mainline/arm64/kernel-mainline-allsyms:kernel-mainline \
    kernel/prebuilts/mainline/arm64/kernel-mainline-gz-allsyms:kernel-mainline-gz \
    kernel/prebuilts/mainline/arm64/kernel-mainline-lz4-allsyms:kernel-mainline-lz4 \

$(call dist-for-goals, dist_files, kernel/prebuilts/4.19/arm64/prebuilt-info.txt:kernel/4.19/prebuilt-info.txt)
$(call dist-for-goals, dist_files, kernel/prebuilts/5.4/arm64/prebuilt-info.txt:kernel/5.4/prebuilt-info.txt)
$(call dist-for-goals, dist_files, kernel/prebuilts/5.10/arm64/prebuilt-info.txt:kernel/5.10/prebuilt-info.txt)
$(call dist-for-goals, dist_files, kernel/prebuilts/mainline/arm64/prebuilt-info.txt:kernel/mainline/prebuilt-info.txt)

ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
PRODUCT_COPY_FILES += \
    kernel/prebuilts/4.19/arm64/kernel-4.19-gz-allsyms:kernel-4.19-gz-allsyms \
    kernel/prebuilts/5.4/arm64/kernel-5.4-allsyms:kernel-5.4-allsyms \
    kernel/prebuilts/5.4/arm64/kernel-5.4-gz-allsyms:kernel-5.4-gz-allsyms \
    kernel/prebuilts/5.4/arm64/kernel-5.4-lz4-allsyms:kernel-5.4-lz4-allsyms \
    kernel/prebuilts/5.10/arm64/kernel-5.10-allsyms:kernel-5.10-allsyms \
    kernel/prebuilts/5.10/arm64/kernel-5.10-gz-allsyms:kernel-5.10-gz-allsyms \
    kernel/prebuilts/5.10/arm64/kernel-5.10-lz4-allsyms:kernel-5.10-lz4-allsyms \

endif

PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_RECOVERY_IMAGE := false

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_ramdisk.mk)
