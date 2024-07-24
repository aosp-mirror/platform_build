# Copyright (C) 2022 The Android Open Source Project
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

# This device is suitable for soong-only build that builds for all the architectures
# needed for the ndk. It is not going to work for normal `lunch <foo> && m` workflows.

PRODUCT_NAME := ndk
PRODUCT_BRAND := Android
PRODUCT_DEVICE := ndk

PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO := true
