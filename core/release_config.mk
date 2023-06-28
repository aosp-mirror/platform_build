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


# -----------------------------------------------------------------
# Choose the flag files
# -----------------------------------------------------------------
# Release configs are defined in reflease_config_map files, which map
# the short name (e.g. -next) used in lunch to the starlark files
# defining the build flag values.
#
# (If you're thinking about aconfig flags, there is one build flag,
# RELEASE_ACONFIG_VALUE_SETS, that sets which aconfig_value_set
# module to use to set the aconfig flag values.)
#
# The short release config names *can* appear multiple times, to allow
# for AOSP and vendor specific flags under the same name, but the
# individual flag values must appear in exactly one config.  Vendor
# does not override AOSP, or anything like that.  This is because
# vendor code usually includes prebuilts, and having vendor compile
# with different flags from AOSP increases the likelihood of flag
# mismatch.

# Do this first, because we're going to unset TARGET_RELEASE before
# including anyone, so they don't start making conditionals based on it.
# This logic is in make because starlark doesn't understand optional
# vendor files.

# If this is a google source tree, restrict it to only the one file
# which has OWNERS control.  If it isn't let others define their own.
# TODO: Remove wildcard for build/release one when all branch manifests
# have updated.
config_map_files := $(wildcard build/release/release_config_map.mk) \
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
    $(if $(strip $(2)),,  \
        $(error declare-release-config: config $(strip $(1)) must have release config files) \
    )
    $(eval _all_release_configs := $(sort $(_all_release_configs) $(strip $(1))))
    $(eval _all_release_configs.$(strip $(1)).DECLARED_IN := $(_included) $(_all_release_configs.$(strip $(1)).DECLARED_IN))
    $(eval _all_release_configs.$(strip $(1)).FILES := $(_all_release_configs.$(strip $(1)).FILES) $(strip $(2)))
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
    $(error No release config found for TARGET_RELEASE: $(TARGET_RELEASE). Available releases are: $(_all_release_configs))
else
    # Choose flag files
    # Don't sort this, use it in the order they gave us.
    flag_value_files := $(_all_release_configs.$(TARGET_RELEASE).FILES)
endif
else
# Useful for finding scripts etc that aren't passing or setting TARGET_RELEASE
ifneq ($(FAIL_IF_NO_RELEASE_CONFIG),)
    $(error FAIL_IF_NO_RELEASE_CONFIG was set and TARGET_RELEASE was not)
endif
flag_value_files :=
endif

# Unset variables so they can't use them
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
# Flag declarations and values
# -----------------------------------------------------------------
# This part is in starlark.  We generate a root starlark file that loads
# all of the flags declaration files that we found, and the flag_value_files
# that we chose from the config map above.  Then we run that, and load the
# results of that into the make environment.

# If this is a google source tree, restrict it to only the one file
# which has OWNERS control.  If it isn't let others define their own.
# TODO: Remove wildcard for build/release one when all branch manifests
# have updated.
flag_declaration_files := $(wildcard build/release/build_flags.bzl) \
    $(if $(wildcard vendor/google/release/build_flags.bzl), \
        vendor/google/release/build_flags.bzl, \
        $(sort \
            $(wildcard device/*/release/build_flags.bzl) \
            $(wildcard device/*/*/release/build_flags.bzl) \
            $(wildcard vendor/*/release/build_flags.bzl) \
            $(wildcard vendor/*/*/release/build_flags.bzl) \
        ) \
    )


# Because starlark can't find files with $(wildcard), write an entrypoint starlark script that
# contains the result of the above wildcards for the starlark code to use.
filename_to_starlark=$(subst /,_,$(subst .,_,$(1)))
_c:=load("//build/make/core/release_config.bzl", "release_config")
_c+=$(newline)def add(d, k, v):
_c+=$(newline)$(space)d = dict(d)
_c+=$(newline)$(space)d[k] = v
_c+=$(newline)$(space)return d
_c+=$(foreach f,$(flag_declaration_files),$(newline)load("$(f)", flags_$(call filename_to_starlark,$(f)) = "flags"))
_c+=$(newline)all_flags = [] $(foreach f,$(flag_declaration_files),+ [add(x, "declared_in", "$(f)") for x in flags_$(call filename_to_starlark,$(f))])
_c+=$(foreach f,$(flag_value_files),$(newline)load("//$(f)", values_$(call filename_to_starlark,$(f)) = "values"))
_c+=$(newline)all_values = [] $(foreach f,$(flag_value_files),+ [add(x, "set_in", "$(f)") for x in values_$(call filename_to_starlark,$(f))])
_c+=$(newline)variables_to_export_to_make = release_config(all_flags, all_values)
$(file >$(OUT_DIR)/release_config_entrypoint.bzl,$(_c))
_c:=
filename_to_starlark:=

# Exclude the entrypoint file as a dependency (by passing it as the 2nd argument) so that we don't
# rerun kati every build. Kati will replay the $(file) command that generates it every build,
# updating its timestamp.
#
# We also need to pass --allow_external_entrypoint to rbcrun in case the OUT_DIR is set to something
# outside of the source tree.
$(call run-starlark,$(OUT_DIR)/release_config_entrypoint.bzl,$(OUT_DIR)/release_config_entrypoint.bzl,--allow_external_entrypoint)

