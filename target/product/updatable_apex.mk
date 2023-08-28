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

# com.android.apex.cts.shim.v1_prebuilt overrides CtsShimPrebuilt
# and CtsShimPrivPrebuilt since they are packaged inside the APEX.
PRODUCT_PACKAGES += com.android.apex.cts.shim.v1_prebuilt
PRODUCT_SYSTEM_PROPERTIES := ro.apex.updatable=true

# Use compressed apexes in pre-installed partitions.
# Note: this doesn't mean that all pre-installed apexes will be compressed.
#  Whether an apex is compressed or not is controlled at apex Soong module
#  via compresible property.
PRODUCT_COMPRESSED_APEX := true
