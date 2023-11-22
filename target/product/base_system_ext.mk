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

# Base modules and settings for the system_ext partition.
PRODUCT_PACKAGES += \
    fs_config_dirs_system_ext \
    fs_config_files_system_ext \
    group_system_ext \
    passwd_system_ext \
    selinux_policy_system_ext \
    system_ext_manifest.xml \

# Base modules when shipping api level is less than or equal to 34
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_34 += \
    hwservicemanager \
    android.hidl.allocator@1.0-service \
