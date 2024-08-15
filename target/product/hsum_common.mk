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

# Contains common default elements for devices running in Headless System User Mode.

# Should generally be inherited first as using an HSUM configuration can affect downstream choices
# (such as ensuring that the HSUM-variants of packages are selected).

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.fw.mu.headless_system_user=true

# Variable for elsewhere choosing the appropriate products based on HSUM status.
PRODUCT_USE_HSUM := true

PRODUCT_PACKAGES += \
    HsumDefaultConfigOverlay
