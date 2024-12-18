#
# Copyright (C) 2024 The Android Open Source Project
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

# The base version of window_extensions.mk to be included on all non-wearable
# devices. Devices that don't support multi-window can choose to drop this.
#
# Note: by default the Activity Embedding feature is guarded by app's
# targetSDK on Android 15 to avoid app compat impact.
#
# Large screen devices must inherit window_extensions.mk to enable the
# Activity Embedding feature for all apps.

# /system_ext packages
PRODUCT_PACKAGES += \
    androidx.window.extensions \
    androidx.window.sidecar

# properties
PRODUCT_PRODUCT_PROPERTIES += \
    persist.wm.extensions.enabled=true
