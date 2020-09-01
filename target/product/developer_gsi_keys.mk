#
# Copyright (C) 2019 The Android Open-Source Project
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

# Device makers who are willing to support booting the public Developer-GSI
# in locked state can add the following line into a device.mk to inherit this
# makefile. This file will then install the up-to-date GSI public keys into
# the first-stage ramdisk to pass verified boot.
#
# In device/<company>/<board>/device.mk:
#   $(call inherit-product, $(SRC_TARGET_DIR)/product/developer_gsi_keys.mk)
#
# Currently, the developer GSI images can be downloaded from the following URL:
#   https://developer.android.com/topic/generic-system-image/releases
#
PRODUCT_PACKAGES += \
    q-developer-gsi.avbpubkey \
    r-developer-gsi.avbpubkey \
    s-developer-gsi.avbpubkey \
