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


# Since products and build variants (unfortunately) share the same
# PRODUCT_OUT staging directory, things can get out of sync if different
# build configurations are built in the same tree.  The following logic
# will notice when the configuration has changed and remove the files
# necessary to keep things consistent.

previous_build_config_file := $(PRODUCT_OUT)/previous_build_config.mk

# TODO: this special case for the sdk is only necessary while "sdk"
# is a valid make target.  Eventually, it will just be a product, at
# which point TARGET_PRODUCT will handle it and we can avoid this check
# of MAKECMDGOALS.  The "addprefix" is just to keep things pretty.
ifneq ($(TARGET_PRODUCT),sdk)
  building_sdk := $(addprefix -,$(filter sdk,$(MAKECMDGOALS)))
else
  # Don't bother with this extra part when explicitly building the sdk product.
  building_sdk :=
endif

# A change in the list of locales warrants an installclean, too.
locale_list := $(subst $(space),$(comma),$(strip $(PRODUCT_LOCALES)))

current_build_config := \
    $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)$(building_sdk)-{$(locale_list)}
building_sdk :=
locale_list :=
force_installclean := false

# Read the current state from the file, if present.
# Will set PREVIOUS_BUILD_CONFIG.
#
PREVIOUS_BUILD_CONFIG :=
-include $(previous_build_config_file)
PREVIOUS_BUILD_CONFIG := $(strip $(PREVIOUS_BUILD_CONFIG))
ifdef PREVIOUS_BUILD_CONFIG
  ifneq "$(current_build_config)" "$(PREVIOUS_BUILD_CONFIG)"
    $(info *** Build configuration changed: "$(PREVIOUS_BUILD_CONFIG)" -> "$(current_build_config)")
    ifneq ($(DISABLE_AUTO_INSTALLCLEAN),true)
      force_installclean := true
    else
      $(info DISABLE_AUTO_INSTALLCLEAN is set; skipping auto-clean. Your tree may be in an inconsistent state.)
    endif
  endif
endif  # else, this is the first build, so no need to clean.
PREVIOUS_BUILD_CONFIG :=

# Write the new state to the file.
#
$(shell \
  mkdir -p $(dir $(previous_build_config_file)) && \
  echo "PREVIOUS_BUILD_CONFIG := $(current_build_config)" > \
      $(previous_build_config_file) \
 )
previous_build_config_file :=
current_build_config :=

#
# installclean logic
#

# The files/dirs to delete during an installclean.  This includes the
# non-common APPS directory, which may contain the wrong resources.
# Use "./" in front of the paths to avoid accidentally deleting random
# parts of the filesystem if any of the *_OUT vars resolve to blank.
#
# Deletes all of the files that change between different build types,
# like "make user" vs. "make sdk".  This lets you work with different
# build types without having to do a full clean each time.  E.g.:
#
#     $ make -j8 all
#     $ make installclean
#     $ make -j8 user
#     $ make installclean
#     $ make -j8 sdk
#
installclean_files := \
	./$(HOST_OUT)/obj/NOTICE_FILES \
	./$(HOST_OUT)/sdk \
	./$(PRODUCT_OUT)/*.img \
	./$(PRODUCT_OUT)/*.txt \
	./$(PRODUCT_OUT)/*.xlb \
	./$(PRODUCT_OUT)/*.zip \
	./$(PRODUCT_OUT)/data \
	./$(PRODUCT_OUT)/obj/lib \
	./$(PRODUCT_OUT)/obj/APPS \
	./$(PRODUCT_OUT)/obj/NOTICE_FILES \
	./$(PRODUCT_OUT)/obj/PACKAGING \
	./$(PRODUCT_OUT)/recovery \
	./$(PRODUCT_OUT)/root \
	./$(PRODUCT_OUT)/symbols/system/lib \
	./$(PRODUCT_OUT)/system

# The files/dirs to delete during a dataclean, which removes any files
# in the staging and emulator data partitions.
dataclean_files := \
	./$(PRODUCT_OUT)/data/* \
	./$(PRODUCT_OUT)/data-qemu/* \
	./$(PRODUCT_OUT)/userdata-qemu.img

# Define the rules for commandline invocation.
.PHONY: dataclean
dataclean: FILES := $(dataclean_files)
dataclean:
	$(hide) rm -rf $(FILES)
	@echo "Deleted emulator userdata images."

.PHONY: installclean
installclean: FILES := $(installclean_files)
installclean: dataclean
	$(hide) rm -rf $(FILES)
	@echo "Deleted images and staging directories."

ifeq "$(force_installclean)" "true"
  $(info *** Forcing "make installclean"...)
  $(shell rm -rf $(dataclean_files) $(installclean_files))
  $(info *** Done with the cleaning, now starting the real build.)
endif
force_installclean :=
