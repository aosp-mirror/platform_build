#
# Copyright (C) 2008 The Android Open Source Project
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
ifneq ($(TARGET_SIMULATOR),true)
ifneq ($(DISABLE_DEXPREOPT),true)

LOCAL_PATH := $(my-dir)
include $(CLEAR_VARS)
LOCAL_PREBUILT_EXECUTABLES := dexpreopt.py
include $(BUILD_SYSTEM)/host_prebuilt.mk
DEXPREOPT := $(LOCAL_INSTALLED_MODULE)

# The script uses some other tools; make sure that they're
# installed along with it.
tools := \
	emulator$(HOST_EXECUTABLE_SUFFIX)

$(DEXPREOPT): | $(addprefix $(HOST_OUT_EXECUTABLES)/,$(tools))

subdir_makefiles := \
		$(LOCAL_PATH)/dexopt-wrapper/Android.mk \
		$(LOCAL_PATH)/afar/Android.mk
include $(subdir_makefiles)

endif # !disable_dexpreopt
endif # !sim
