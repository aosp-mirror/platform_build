# Copyright (C) 2023 The Android Open Source Project
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

# Partitions that get build system flag summaries
_FLAG_PARTITIONS := system vendor system_ext product

# All possible release flags. Defined in the flags.mk files
# throughout the tree
_ALL_RELEASE_FLAGS :=

# -----------------------------------------------------------------
# Choose the flag files
# Do this first, because we're going to unset TARGET_RELEASE before
# including anyone, so they don't start making conditionals based on it.

# If this is a google source tree, restrict it to only the one file
# which has OWNERS control.  If it isn't let others define their own.
config_map_files := build/make/release/release_config_map.mk \
    $(if $(wildcard vendor/google/release/release_config_map.mk), \
        vendor/google/release/release_config_map.mk, \
        $(sort \
            $(wildcard device/*/release/release_config_map.mk) \
            $(wildcard device/*/*/release/release_config_map.mk) \
            $(wildcard vendor/*/release/release_config_map.mk) \
            $(wildcard vendor/*/*/release/release_config_map.mk) \
        ) \
    )

# $1 config name
# $2 release config files
define declare-release-config
    $(eval # No duplicates)
    $(if $(filter $(_all_release_configs), $(strip $(1))), \
        $(error declare-release-config: config $(strip $(1)) declared in: $(_included) Previously declared here: $(_all_release_configs.$(strip $(1)).DECLARED_IN)) \
    )
    $(eval # Must have release config files)
    $(if $(strip $(2)),,  \
        $(error declare-release-config: config $(strip $(1)) must have release config files) \
    )
    $(eval _all_release_configs := $(sort $(_all_release_configs) $(strip $(1))))
    $(eval _all_release_configs.$(strip $(1)).DECLARED_IN := $(_included))
    $(eval _all_release_configs.$(strip $(1)).FILES := $(strip $(2)))
endef

# Include the config map files
$(foreach f, $(config_map_files), \
    $(eval _included := $(f)) \
    $(eval include $(f)) \
)

# If TARGET_RELEASE is set, fail if there is no matching release config
# If it isn't set, no release config files will be included and all flags
# will get their default values.
ifneq ($(TARGET_RELEASE),)
ifeq ($(filter $(_all_release_configs), $(TARGET_RELEASE)),)
    $(error No release config found for TARGET_RELEASE: $(TARGET_RELEASE))
else
    # Choose flag files
    # Don't sort this, use it in the order they gave us.
    _release_config_files := $(_all_release_configs.$(TARGET_RELEASE).FILES)
endif
else
# Useful for finding scripts etc that aren't passing or setting TARGET_RELEASE
ifneq ($(FAIL_IF_NO_RELEASE_CONFIG),)
    $(error FAIL_IF_NO_RELEASE_CONFIG was set and TARGET_RELEASE was not)
endif
_release_config_files :=
endif

# Unset variables so they can't use it
define declare-release-config
$(error declare-release-config can only be called from inside release_config_map.mk files)
endef

# TODO: Remove this check after enough people have sourced lunch that we don't
# need to worry about it trying to do get_build_vars TARGET_RELEASE. Maybe after ~9/2023
ifneq ($(CALLED_FROM_SETUP),true)
define TARGET_RELEASE
$(error TARGET_RELEASE may not be accessed directly. Use individual flags.)
endef
else
TARGET_RELEASE:=
endif
.KATI_READONLY := TARGET_RELEASE

$(foreach config, $(_all_release_configs), \
    $(eval _all_release_configs.$(config).DECLARED_IN:= ) \
    $(eval _all_release_configs.$(config).FILES:= ) \
)
_all_release_configs:=
config_map_files:=

# -----------------------------------------------------------------
# Declare the flags

# $1 partition(s)
# $2 flag name. Must start with RELEASE_
# $3 default. True or false
define declare-build-flag
    $(if $(filter-out all $(_FLAG_PARTITIONS), $(strip $(1))), \
        $(error declare-build-flag: invalid partitions: $(strip $(1))) \
    )
    $(if $(and $(filter all,$(strip $(1))),$(filter-out all, $(strip $(1)))), \
        $(error declare-build-flag: "all" can't be combined with other partitions: $(strip $(1))), \
        $(eval declare-build-flag.partition := $(_FLAG_PARTITIONS)) \
    )
    $(if $(filter-out RELEASE_%, $(strip $(2))), \
        $(error declare-build-flag: Release flag names must start with RELEASE_: $(strip $(2))) \
    )
    $(eval _ALL_RELEASE_FLAGS += $(strip $(2)))
    $(foreach partition, $(declare-build-flag.partition), \
        $(eval _ALL_RELEASE_FLAGS.PARTITIONS.$(partition) := $(sort \
            $(_ALL_RELEASE_FLAGS.PARTITIONS.$(partition)) $(strip $(2)))) \
    )
    $(eval _ALL_RELEASE_FLAGS.$(strip $(2)).PARTITIONS := $(declare-build-flag.partition))
    $(eval _ALL_RELEASE_FLAGS.$(strip $(2)).DEFAULT := $(strip $(3)))
    $(eval _ALL_RELEASE_FLAGS.$(strip $(2)).DECLARED_IN := $(_included))
    $(eval _ALL_RELEASE_FLAGS.$(strip $(2)).VALUE := $(strip $(3)))
    $(eval _ALL_RELEASE_FLAGS.$(strip $(2)).SET_IN := $(_included))
    $(eval declare-build-flag.partition:=)
endef


# Choose the files
# If this is a google source tree, restrict it to only the one file
# which has OWNERS control.  If it isn't let others define their own.
flag_declaration_files := build/make/release/flags.mk \
    $(if $(wildcard vendor/google/release/flags.mk), \
        vendor/google/release/flags.mk, \
        $(sort \
            $(wildcard device/*/release/flags.mk) \
            $(wildcard device/*/*/release/flags.mk) \
            $(wildcard vendor/*/release/flags.mk) \
            $(wildcard vendor/*/*/release/flags.mk) \
        ) \
    )

# Include the files
$(foreach f, $(flag_declaration_files), \
    $(eval _included := $(f)) \
    $(eval include $(f)) \
)

# Don't let anyone declare build flags after here
define declare-build-flag
$(error declare-build-flag can only be called from inside flag definition files.)
endef

# No more flags from here on
.KATI_READONLY := _ALL_RELEASE_FLAGS

# -----------------------------------------------------------------
# Set the flags

# $(1): Flag name. Must start with RELEASE_ and have been defined by declare-build-flag
# $(2): Value. True or false
define set-build-flag
    $(if $(filter-out $(_ALL_RELEASE_FLAGS), $(strip $(1))), \
        $(error set-build-flag: Undeclared build flag: $(strip $(1))) \
    )
    $(eval _ALL_RELEASE_FLAGS.$(strip $(1)).VALUE := $(strip $(2)))
    $(eval _ALL_RELEASE_FLAGS.$(strip $(1)).SET_IN := $(_included))
endef

# Include the files (if there are any)
$(foreach f, $(_release_config_files), \
    $(eval _included := $(f)) \
    $(eval include $(f)) \
)

# Don't let anyone declare build flags after here
define set-build-flag
$(error set-build-flag can only be called from inside release config files.)
endef

# Set the flag values, and don't allow any one to modify them.
$(foreach flag, $(_ALL_RELEASE_FLAGS), \
    $(eval $(flag) := $(_ALL_RELEASE_FLAGS.$(flag).VALUE)) \
    $(eval .KATI_READONLY := $(flag)) \
)

# -----------------------------------------------------------------
# Clear out vars
flag_declaration_files:=
flag_files:=
_included:=
_release_config_files:=
