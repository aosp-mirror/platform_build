#
# Copyright (C) 2019 The Android Open Source Project
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

# Do not modify this file. It's just alias of generic_system_x86_64.mk
# Will be removed when renaming from mainline_system to generic_system
# complete

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system_x86_64.mk)

PRODUCT_NAME := mainline_system_x86_64
