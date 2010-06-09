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

ifneq ($(BUILD_TINY_ANDROID), true)

.PHONY: checkapi

# eval this to define a rule that runs apicheck.
#
# Args:
#    $(1)  target
#    $(2)  stable api xml file
#    $(3)  api xml file to be tested
#    $(4)  arguments for apicheck
#    $(5)  command to run if apicheck failed
define check-api
$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(strip $(1))-timestamp: $(2) $(3) $(APICHECK)
	@echo "Checking API:" $(1)
	$(hide) ( $(APICHECK) $(4) $(2) $(3) || ( $(5) ; exit 38 ) )
	$(hide) mkdir -p $$(dir $$@)
	$(hide) touch $$@
checkapi: $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(strip $(1))-timestamp
endef

# Run the checkapi rules by default.
droidcore: checkapi

last_released_sdk_version := $(lastword $(call numerically_sort,\
    $(patsubst $(SRC_API_DIR)/%.xml,%, \
    $(filter-out $(SRC_API_DIR)/current.xml, \
    $(wildcard $(SRC_API_DIR)/*.xml)))))

# INTERNAL_PLATFORM_API_FILE is the one build by droiddoc.

# Check that the API we're building hasn't broken the last-released
# SDK version.
$(eval $(call check-api, \
	checkapi-last, \
	$(SRC_API_DIR)/$(last_released_sdk_version).xml, \
	$(INTERNAL_PLATFORM_API_FILE), \
	-hide 2 -hide 3 -hide 4 -hide 5 -hide 6 -hide 24 -hide 25 \
	-error 7 -error 8 -error 9 -error 10 -error 11 -error 12 -error 13 -error 14 -error 15 \
	-error 16 -error 17 -error 18 , \
	cat $(BUILD_SYSTEM)/apicheck_msg_last.txt \
	))

# Check that the API we're building hasn't changed from the not-yet-released
# SDK version.
$(eval $(call check-api, \
	checkapi-current, \
	$(SRC_API_DIR)/current.xml, \
	$(INTERNAL_PLATFORM_API_FILE), \
	-error 2 -error 3 -error 4 -error 5 -error 6 \
	-error 7 -error 8 -error 9 -error 10 -error 11 -error 12 -error 13 -error 14 -error 15 \
	-error 16 -error 17 -error 18 -error 19 -error 20 -error 21 -error 23 -error 24 \
	-error 25 , \
	cat $(BUILD_SYSTEM)/apicheck_msg_current.txt \
	))

.PHONY: update-api
update-api: $(INTERNAL_PLATFORM_API_FILE) | $(ACP)
	@echo Copying current.xml
	$(hide) $(ACP) $(INTERNAL_PLATFORM_API_FILE) $(SRC_API_DIR)/current.xml

endif
