# Copyright (C) 2007 The Android Open Source Project
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

INTERNAL_CLEAN_STEPS :=

# Builds up a list of clean steps.  Creates a unique
# id for each step by taking INTERNAL_CLEAN_BUILD_VERSION
# and appending an increasing number of '@' characters.
#
# $(1): shell command to run
define _add-clean-step
  $(if $(strip $(INTERNAL_CLEAN_BUILD_VERSION)),, \
      $(error INTERNAL_CLEAN_BUILD_VERSION not set))
  $(eval _acs_id := $(strip $(lastword $(INTERNAL_CLEAN_STEPS))))
  $(if $(_acs_id),,$(eval _acs_id := $(INTERNAL_CLEAN_BUILD_VERSION)))
  $(eval _acs_id := $(_acs_id)@)
  $(eval INTERNAL_CLEAN_STEPS += $(_acs_id))
  $(eval INTERNAL_CLEAN_STEP.$(_acs_id) := $(1))
  $(eval _acs_id :=)
endef
define add-clean-step
$(if $(call _add-clean-step,$(1)),)
endef

# Defines INTERNAL_CLEAN_BUILD_VERSION and the individual clean steps.
# cleanspec.mk is outside of the core directory so that more people
# can have permission to touch it.
include build/cleanspec.mk
INTERNAL_CLEAN_BUILD_VERSION := $(strip $(INTERNAL_CLEAN_BUILD_VERSION))

# If the clean_steps.mk file is missing (usually after a clean build)
# then we won't do anything.
CURRENT_CLEAN_BUILD_VERSION := $(INTERNAL_CLEAN_BUILD_VERSION)
CURRENT_CLEAN_STEPS := $(INTERNAL_CLEAN_STEPS)

# Read the current state from the file, if present.
# Will set CURRENT_CLEAN_BUILD_VERSION and CURRENT_CLEAN_STEPS.
#
clean_steps_file := $(PRODUCT_OUT)/clean_steps.mk
-include $(clean_steps_file)

ifneq ($(CURRENT_CLEAN_BUILD_VERSION),$(INTERNAL_CLEAN_BUILD_VERSION))
  # The major clean version is out-of-date.  Do a full clean, and
  # don't even bother with the clean steps.
  $(info *** A clean build is required because of a recent change.)
  $(shell rm -rf $(OUT_DIR))
  $(info *** Done with the cleaning, now starting the real build.)
else
  # The major clean version is correct.  Find the list of clean steps
  # that we need to execute to get up-to-date.
  steps := \
      $(filter-out $(CURRENT_CLEAN_STEPS),$(INTERNAL_CLEAN_STEPS))
  $(foreach step,$(steps), \
    $(info Clean step: $(INTERNAL_CLEAN_STEP.$(step))) \
    $(shell $(INTERNAL_CLEAN_STEP.$(step))) \
   )
  steps :=
endif
CURRENT_CLEAN_BUILD_VERSION :=
CURRENT_CLEAN_STEPS :=

# Write the new state to the file.
#
$(shell \
  mkdir -p $(dir $(clean_steps_file)) && \
  echo "CURRENT_CLEAN_BUILD_VERSION := $(INTERNAL_CLEAN_BUILD_VERSION)" > \
      $(clean_steps_file) ;\
  echo "CURRENT_CLEAN_STEPS := $(INTERNAL_CLEAN_STEPS)" >> \
      $(clean_steps_file) \
 )

clean_steps_file :=
INTERNAL_CLEAN_STEPS :=
INTERNAL_CLEAN_BUILD_VERSION :=
