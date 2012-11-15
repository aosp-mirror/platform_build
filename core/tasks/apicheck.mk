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
# Rules for running apicheck to confirm that you haven't broken
# api compatibility or added apis illegally.
#

# skip api check for TINY_ANDROID and PDK buid
ifeq (,$(filter true, $(BUILD_TINY_ANDROID) $(TARGET_BUILD_PDK)))

.PHONY: checkapi

# Run the checkapi rules by default.
droidcore: checkapi

last_released_sdk_version := $(lastword $(call numerically_sort, \
            $(filter-out current, \
                $(patsubst $(SRC_API_DIR)/%.txt,%, $(wildcard $(SRC_API_DIR)/*.txt)) \
             )\
        ))

# INTERNAL_PLATFORM_API_FILE is the one build by droiddoc.
# Note that since INTERNAL_PLATFORM_API_FILE is the byproduct of api-stubs module,
# (See frameworks/base/Android.mk)
# we need to add api-stubs as additional dependency of the api check.

# Check that the API we're building hasn't broken the last-released
# SDK version.
$(eval $(call check-api, \
    checkapi-last, \
    $(SRC_API_DIR)/$(last_released_sdk_version).txt, \
    $(INTERNAL_PLATFORM_API_FILE), \
    -hide 2 -hide 3 -hide 4 -hide 5 -hide 6 -hide 24 -hide 25 \
    -error 7 -error 8 -error 9 -error 10 -error 11 -error 12 -error 13 -error 14 -error 15 \
    -error 16 -error 17 -error 18 , \
    cat $(BUILD_SYSTEM)/apicheck_msg_last.txt, \
    checkapi, \
    $(call doc-timestamp-for,api-stubs) \
    ))

# Check that the API we're building hasn't changed from the not-yet-released
# SDK version.
$(eval $(call check-api, \
    checkapi-current, \
    $(SRC_API_DIR)/current.txt, \
    $(INTERNAL_PLATFORM_API_FILE), \
    -error 2 -error 3 -error 4 -error 5 -error 6 \
    -error 7 -error 8 -error 9 -error 10 -error 11 -error 12 -error 13 -error 14 -error 15 \
    -error 16 -error 17 -error 18 -error 19 -error 20 -error 21 -error 23 -error 24 \
    -error 25 , \
    cat $(BUILD_SYSTEM)/apicheck_msg_current.txt, \
    checkapi, \
    $(call doc-timestamp-for,api-stubs) \
    ))

.PHONY: update-api
update-api: $(INTERNAL_PLATFORM_API_FILE) | $(ACP)
	@echo Copying current.txt
	$(hide) $(ACP) $(INTERNAL_PLATFORM_API_FILE) $(SRC_API_DIR)/current.txt

endif
