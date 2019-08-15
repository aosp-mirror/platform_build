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

############################################################
# Internal build rules for misc prebuilt modules that don't need additional processing
############################################################

prebuilt_module_classes := SCRIPT ETC DATA
ifeq ($(filter $(prebuilt_module_classes),$(LOCAL_MODULE_CLASS)),)
$(call pretty-error,misc_prebuilt_internal.mk is for $(prebuilt_module_classes) modules only)
endif

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target)

built_module := $(LOCAL_BUILT_MODULE)