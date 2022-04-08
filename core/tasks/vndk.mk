# Copyright (C) 2017 The Android Open Source Project
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

current_makefile := $(lastword $(MAKEFILE_LIST))

# BOARD_VNDK_VERSION must be set to 'current' in order to generate a VNDK snapshot.
ifeq ($(BOARD_VNDK_VERSION),current)

# PLATFORM_VNDK_VERSION must be set.
ifneq (,$(PLATFORM_VNDK_VERSION))

# BOARD_VNDK_RUNTIME_DISABLE must not be set to 'true'.
ifneq ($(BOARD_VNDK_RUNTIME_DISABLE),true)

.PHONY: vndk
vndk: $(SOONG_VNDK_SNAPSHOT_ZIP)

$(call dist-for-goals, vndk, $(SOONG_VNDK_SNAPSHOT_ZIP))

else # BOARD_VNDK_RUNTIME_DISABLE is set to 'true'
error_msg := "CANNOT generate VNDK snapshot. BOARD_VNDK_RUNTIME_DISABLE must not be set to 'true'."
endif # BOARD_VNDK_RUNTIME_DISABLE

else # PLATFORM_VNDK_VERSION is NOT set
error_msg := "CANNOT generate VNDK snapshot. PLATFORM_VNDK_VERSION must be set."
endif # PLATFORM_VNDK_VERSION

else # BOARD_VNDK_VERSION is NOT set to 'current'
error_msg := "CANNOT generate VNDK snapshot. BOARD_VNDK_VERSION must be set to 'current'."
endif # BOARD_VNDK_VERSION

ifneq (,$(error_msg))

.PHONY: vndk
vndk: PRIVATE_MAKEFILE := $(current_makefile)
vndk:
	$(call echo-error,$(PRIVATE_MAKEFILE),$(error_msg))
	exit 1

endif
