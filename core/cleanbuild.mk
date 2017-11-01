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

# Absolute path of the present working direcotry.
# This overrides the shell variable $PWD, which does not necessarily points to
# the top of the source tree, for example when "make -C" is used in m/mm/mmm.
PWD := $(shell pwd)

TOP := .
TOPDIR :=

BUILD_SYSTEM := $(TOPDIR)build/make/core

# Set up various standard variables based on configuration
# and host information.
include $(BUILD_SYSTEM)/config.mk

include $(SOONG_MAKEVARS_MK)

include $(BUILD_SYSTEM)/clang/config.mk

# CTS-specific config.
-include cts/build/config.mk
# VTS-specific config.
-include test/vts/tools/vts-tradefed/build/config.mk
# device-tests-specific-config.
-include tools/tradefederation/build/suites/device-tests/config.mk
# general-tests-specific-config.
-include tools/tradefederation/build/suites/general-tests/config.mk

INTERNAL_CLEAN_STEPS :=

# Builds up a list of clean steps.  Creates a unique
# id for each step by taking makefile path, INTERNAL_CLEAN_BUILD_VERSION
# and appending an increasing number of '@' characters.
#
# $(1): shell command to run
# $(2): indicate to not use makefile path as part of step id if not empty.
#       $(2) should only be used in build/make/core/cleanspec.mk: just for compatibility.
define _add-clean-step
  $(if $(strip $(INTERNAL_CLEAN_BUILD_VERSION)),, \
      $(error INTERNAL_CLEAN_BUILD_VERSION not set))
  $(eval _acs_makefile_prefix := $(lastword $(MAKEFILE_LIST)))
  $(eval _acs_makefile_prefix := $(subst /,_,$(_acs_makefile_prefix)))
  $(eval _acs_makefile_prefix := $(subst .,-,$(_acs_makefile_prefix)))
  $(eval _acs_makefile_prefix := $(_acs_makefile_prefix)_acs)
  $(if $($(_acs_makefile_prefix)),,\
      $(eval $(_acs_makefile_prefix) := $(INTERNAL_CLEAN_BUILD_VERSION)))
  $(eval $(_acs_makefile_prefix) := $($(_acs_makefile_prefix))@)
  $(if $(strip $(2)),$(eval _acs_id := $($(_acs_makefile_prefix))),\
      $(eval _acs_id := $(_acs_makefile_prefix)$($(_acs_makefile_prefix))))
  $(eval INTERNAL_CLEAN_STEPS += $(_acs_id))
  $(eval INTERNAL_CLEAN_STEP.$(_acs_id) := $(1))
  $(eval _acs_id :=)
  $(eval _acs_makefile_prefix :=)
endef
define add-clean-step
$(eval # for build/make/core/cleanspec.mk, dont use makefile path as part of step id) \
$(if $(filter %/cleanspec.mk,$(lastword $(MAKEFILE_LIST))),\
    $(eval $(call _add-clean-step,$(1),true)),\
    $(eval $(call _add-clean-step,$(1))))
endef

# Defines INTERNAL_CLEAN_BUILD_VERSION and the individual clean steps.
# cleanspec.mk is outside of the core directory so that more people
# can have permission to touch it.
include $(BUILD_SYSTEM)/cleanspec.mk
INTERNAL_CLEAN_BUILD_VERSION := $(strip $(INTERNAL_CLEAN_BUILD_VERSION))
INTERNAL_CLEAN_STEPS := $(strip $(INTERNAL_CLEAN_STEPS))

# If the clean_steps.mk file is missing (usually after a clean build)
# then we won't do anything.
CURRENT_CLEAN_BUILD_VERSION := MISSING
CURRENT_CLEAN_STEPS := $(INTERNAL_CLEAN_STEPS)

# Read the current state from the file, if present.
# Will set CURRENT_CLEAN_BUILD_VERSION and CURRENT_CLEAN_STEPS.
#
clean_steps_file := $(PRODUCT_OUT)/clean_steps.mk
-include $(clean_steps_file)

ifeq ($(CURRENT_CLEAN_BUILD_VERSION),MISSING)
  # Do nothing
else ifneq ($(CURRENT_CLEAN_BUILD_VERSION),$(INTERNAL_CLEAN_BUILD_VERSION))
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

  # Rewrite the clean step for the second arch.
  ifdef TARGET_2ND_ARCH
  # $(1): the clean step cmd
  # $(2): the prefix to search for
  # $(3): the prefix to replace with
  define -cs-rewrite-cleanstep
  $(if $(filter $(2)/%,$(1)),\
    $(eval _crs_new_cmd := $(patsubst $(2)/%,$(3)/%,$(1)))\
    $(info Clean step: $(_crs_new_cmd))\
    $(shell $(_crs_new_cmd)))
  endef
  $(foreach step,$(steps), \
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_INTERMEDIATES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_SHARED_LIBRARIES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$(TARGET_OUT_VENDOR_SHARED_LIBRARIES),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES),$(TARGET_OUT_INTERMEDIATES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES),$(TARGET_OUT_SHARED_LIBRARIES))\
    $(call -cs-rewrite-cleanstep,$(INTERNAL_CLEAN_STEP.$(step)),$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES),$(TARGET_OUT_VENDOR_SHARED_LIBRARIES))\
    )
  endif
  _crs_new_cmd :=
  steps :=
endif

# Write the new state to the file.
#
ifneq ($(CURRENT_CLEAN_BUILD_VERSION)-$(CURRENT_CLEAN_STEPS),$(INTERNAL_CLEAN_BUILD_VERSION)-$(INTERNAL_CLEAN_STEPS))
$(shell mkdir -p $(dir $(clean_steps_file)))
$(file >$(clean_steps_file).tmp,CURRENT_CLEAN_BUILD_VERSION := $(INTERNAL_CLEAN_BUILD_VERSION)$(newline)CURRENT_CLEAN_STEPS := $(INTERNAL_CLEAN_STEPS)$(newline))
$(shell if ! cmp -s $(clean_steps_file).tmp $(clean_steps_file); then \
          mv $(clean_steps_file).tmp $(clean_steps_file); \
        else \
          rm $(clean_steps_file).tmp; \
        fi)
endif

CURRENT_CLEAN_BUILD_VERSION :=
CURRENT_CLEAN_STEPS :=
clean_steps_file :=
INTERNAL_CLEAN_STEPS :=
INTERNAL_CLEAN_BUILD_VERSION :=
