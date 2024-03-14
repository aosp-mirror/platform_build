#
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

# Extension of window_extensions_base.mk to enable the activity embedding
# feature for all apps by default. All large screen devices must inherit
# this in build. Optional for other form factors.
#
# Indicated whether the Activity Embedding feature should be guarded by
# Android 15 to avoid app compat impact.
# If true (or not set), the feature is only enabled for apps with target
# SDK of Android 15 or above.
# If false, the feature is enabled for all apps.
PRODUCT_PRODUCT_PROPERTIES += \
    persist.wm.extensions.activity_embedding_guard_with_android_15=false
