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

# This is a set of common components to enable CFI for (across
# compatible product configs)
PRODUCT_CFI_INCLUDE_PATHS :=  \
    device/google/cuttlefish/guest/libs/wpa_supplicant_8_lib \
    external/tinyxml2 \
    external/wpa_supplicant_8 \
    frameworks/av/camera \
    frameworks/av/media \
    frameworks/av/services \
    frameworks/minikin \
    hardware/broadcom/wlan/bcmdhd/wpa_supplicant_8_lib \
    hardware/interfaces/nfc \
    hardware/qcom/wlan/qcwcn/wpa_supplicant_8_lib \
    harware/interfaces/keymaster \
    system/bt \
    system/chre \
    system/core/libnetutils \
    system/core/libziparchive \
    system/gatekeeper \
    system/keymaster \
    system/nfc \
    system/security \
