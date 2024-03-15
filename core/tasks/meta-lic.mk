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

# Declare license metadata for non-module files released with products.

# Moved here from frameworks/av/media/Android.mk
$(eval $(call declare-1p-copy-files,frameworks/av/media/libeffects,audio_effects.conf))
$(eval $(call declare-1p-copy-files,frameworks/av/media/libeffects,audio_effects.xml))
$(eval $(call declare-1p-copy-files,frameworks/av/media/libstagefright,))

# Moved here from frameworks/av/services/Android.mk
$(eval $(call declare-1p-copy-files,frameworks/av/services/audiopolicy,))
