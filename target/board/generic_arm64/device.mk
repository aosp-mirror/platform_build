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
    kernel/prebuilts/4.19/arm64/Image.gz:kernel-4.19-gz \
    device/google/cuttlefish_kernel/5.4-arm64/kernel-5.4:kernel-5.4 \
    device/google/cuttlefish_kernel/5.4-arm64/kernel-5.4-gz:kernel-5.4-gz \
    device/google/cuttlefish_kernel/5.4-arm64/kernel-5.4-lz4:kernel-5.4-lz4

# Adjust the Dalvik heap to be appropriate for a tablet.
$(call inherit-product-if-exists, frameworks/base/build/tablet-dalvik-heap.mk)
$(call inherit-product-if-exists, frameworks/native/build/tablet-dalvik-heap.mk)
