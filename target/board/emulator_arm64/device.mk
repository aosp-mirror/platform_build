#
# Copyright (C) 2020 The Android Open Source Project
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

# Cuttlefish has GKI kernel prebuilts, so use those for the GKI boot.img.
ifeq ($(TARGET_PREBUILT_KERNEL),)
    LOCAL_KERNEL := device/google/cuttlefish_kernel/5.4-arm64/kernel
else
    LOCAL_KERNEL := $(TARGET_PREBUILT_KERNEL)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_KERNEL):kernel

# Adjust the Dalvik heap to be appropriate for a tablet.
$(call inherit-product-if-exists, frameworks/base/build/tablet-dalvik-heap.mk)
$(call inherit-product-if-exists, frameworks/native/build/tablet-dalvik-heap.mk)
