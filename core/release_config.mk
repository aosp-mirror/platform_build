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
# Determine which pass this is.
# -----------------------------------------------------------------
# On the first pass, we are asked for only PRODUCT_RELEASE_CONFIG_MAPS,
# on the second pass, we are asked for whatever else is wanted.
_final_product_config_pass:=
ifneq (PRODUCT_RELEASE_CONFIG_MAPS,$(DUMP_MANY_VARS))
    _final_product_config_pass:=true
endif

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
config_map_files := $(wildcard build/release/release_config_map.mk) \
    $(wildcard vendor/google_shared/build/release/release_config_map.mk) \
    $(if $(wildcard vendor/google/release/release_config_map.mk), \
        vendor/google/release/release_config_map.mk, \
        $(sort \
            $(wildcard device/*/release/release_config_map.mk) \
            $(wildcard device/*/*/release/release_config_map.mk) \
            $(wildcard vendor/*/release/release_config_map.mk) \
            $(wildcard vendor/*/*/release/release_config_map.mk) \
        ) \
    )

protobuf_map_files := build/release/release_config_map.textproto \
    $(wildcard vendor/google_shared/build/release/release_config_map.textproto) \
    $(if $(wildcard vendor/google/release/release_config_map.textproto), \
        vendor/google/release/release_config_map.textproto, \
        $(sort \
            $(wildcard device/*/release/release_config_map.textproto) \
            $(wildcard device/*/*/release/release_config_map.textproto) \
            $(wildcard vendor/*/release/release_config_map.textproto) \
            $(wildcard vendor/*/*/release/release_config_map.textproto) \
        ) \
    )

# Remove support for the legacy approach.
_must_protobuf := true

# PRODUCT_RELEASE_CONFIG_MAPS is set by Soong using an initial run of product
# config to capture only the list of config maps needed by the build.
# Keep them in the order provided, but remove duplicates.
# Treat .mk and .textproto as equal for duplicate elimination, but force
# protobuf if any PRODUCT_RELEASE_CONFIG_MAPS specify .textproto.
$(foreach map,$(PRODUCT_RELEASE_CONFIG_MAPS), \
    $(if $(filter $(basename $(map)),$(basename $(config_map_files))),, \
        $(eval config_map_files += $(map))) \
    $(if $(filter $(basename $(map)).textproto,$(map)),$(eval _must_protobuf := true)) \
)


# If we are missing the textproto version of any of $(config_map_files), we cannot use protobuf.
_can_protobuf := true
$(foreach map,$(config_map_files), \
    $(if $(wildcard $(basename $(map)).textproto),,$(eval _can_protobuf :=)) \
)
# If we are missing the mk version of any of $(protobuf_map_files), we must use protobuf.
$(foreach map,$(protobuf_map_files), \
    $(if $(wildcard $(basename $(map)).mk),,$(eval _must_protobuf := true)) \
)

ifneq (,$(_must_protobuf))
    ifeq (,$(_can_protobuf))
        # We must use protobuf, but we cannot use protobuf.
        $(error release config is a mixture of .scl and .textproto)
    endif
endif

_use_protobuf :=
ifneq (,$(_must_protobuf))
    _use_protobuf := true
else
    ifneq ($(_can_protobuf),)
        # Determine the default
        $(foreach map,$(config_map_files), \
            $(if $(wildcard $(dir $(map))/build_config/DEFAULT=proto),$(eval _use_protobuf := true)) \
            $(if $(wildcard $(dir $(map))/build_config/DEFAULT=make),$(eval _use_protobuf := )) \
        )
        # Update for this specific release config only (no inheritance).
        $(foreach map,$(config_map_files), \
            $(if $(wildcard $(dir $(map))/build_config/$(TARGET_RELEASE)=proto),$(eval _use_protobuf := true)) \
            $(if $(wildcard $(dir $(map))/build_config/$(TARGET_RELEASE)=make),$(eval _use_protobuf := )) \
        )
    endif
endif

ifneq (,$(_use_protobuf))
    # The .textproto files are the canonical source of truth.
    _args := $(foreach map,$(config_map_files), --map $(map) )
    ifneq (,$(_must_protobuf))
        # Disable the build flag in release-config.
        _args += --guard=false
    endif
    _args += --allow-missing=true
    ifneq (,$(TARGET_PRODUCT))
        _args += --product $(TARGET_PRODUCT)
    endif
    _flags_dir:=$(OUT_DIR)/soong/release-config
    _flags_file:=$(_flags_dir)/release_config-$(TARGET_PRODUCT)-$(TARGET_RELEASE).vars
    # release-config generates $(_flags_varmk)
    _flags_varmk:=$(_flags_file:.vars=.varmk)
    $(shell $(OUT_DIR)/release-config $(_args) >$(OUT_DIR)/release-config.out && touch -t 200001010000 $(_flags_varmk))
    $(if $(filter-out 0,$(.SHELLSTATUS)),$(error release-config failed to run))
    ifneq (,$(_final_product_config_pass))
        # Save the final version of the config.
        $(shell if ! cmp --quiet $(_flags_varmk) $(_flags_file); then cp $(_flags_varmk) $(_flags_file); fi)
        # This will also set ALL_RELEASE_CONFIGS_FOR_PRODUCT and _used_files for us.
        $(eval include $(_flags_file))
        $(KATI_extra_file_deps $(OUT_DIR)/release-config $(protobuf_map_files) $(_flags_file))
    else
        # This is the first pass of product config.
        $(eval include $(_flags_varmk))
    endif
    _used_files :=
    ifeq (,$(_must_protobuf)$(RELEASE_BUILD_FLAGS_IN_PROTOBUF))
        _use_protobuf :=
    else
        _base_all_release := all_release_configs-$(TARGET_PRODUCT)
        $(call dist-for-goals,droid,\
            $(_flags_dir)/$(_base_all_release).pb:build_flags/all_release_configs.pb \
            $(_flags_dir)/$(_base_all_release).textproto:build_flags/all_release_configs.textproto \
            $(_flags_dir)/$(_base_all_release).json:build_flags/all_release_configs.json \
            $(_flags_dir)/inheritance_graph-$(TARGET_PRODUCT).dot:build_flags/inheritance_graph-$(TARGET_PRODUCT).dot \
        )
# These are always created, add an empty rule for them to keep ninja happy.
$(_flags_dir)/inheritance_graph-$(TARGET_PRODUCT).dot:
	: created by $(OUT_DIR)/release-config
$(_flags_dir)/$(_base_all_release).pb $(_flags_dir)/$(_base_all_release).textproto $(_flags_dir)/$(_base_all_release).json:
	: created by $(OUT_DIR)/release-config
        _base_all_release :=
    endif
    _flags_dir:=
    _flags_file:=
    _flags_varmk:=
endif
ifeq (,$(_use_protobuf))
    # The .mk files are the canonical source of truth.


# Declare an alias release-config
#
# This should be used to declare a release as an alias of another, meaning no
# release config files should be present.
#
# $1 config name
# $2 release config for which it is an alias
define alias-release-config
    $(call _declare-release-config,$(1),,$(2),true)
endef

# Declare or extend a release-config.
#
# The order of processing is:
# 1. Recursively apply any overridden release configs.  Only apply each config
#    the first time we reach it.
# 2. Apply any files for this release config, in the order they were added to
#    the declaration.
#
# Example:
#   With these declarations:
#     $(declare-release-config foo, foo.scl)
#     $(declare-release-config bar, bar.scl, foo)
#     $(declare-release-config baz, baz.scl, bar)
#     $(declare-release-config bif, bif.scl, foo baz)
#     $(declare-release-config bop, bop.scl, bar baz)
#
#   TARGET_RELEASE:
#     - bar will use: foo.scl bar.scl
#     - baz will use: foo.scl bar.scl baz.scl
#     - bif will use: foo.scl bar.scl baz.scl bif.scl
#     - bop will use: foo.scl bar.scl baz.scl bop.scl
#
# $1 config name
# $2 release config files
# $3 overridden release config
define declare-release-config
    $(call _declare-release-config,$(1),$(2),$(3),)
endef

define _declare-release-config
    $(if $(strip $(2)$(3)),,  \
        $(error declare-release-config: config $(strip $(1)) must have release config files, override another release config, or both) \
    )
    $(if $(strip $(4)),$(eval _all_release_configs.$(strip $(1)).ALIAS := true))
    $(eval ALL_RELEASE_CONFIGS_FOR_PRODUCT := $(sort $(ALL_RELEASE_CONFIGS_FOR_PRODUCT) $(strip $(1))))
    $(if $(strip $(3)), \
      $(if $(filter $(ALL_RELEASE_CONFIGS_FOR_PRODUCT), $(strip $(3))),
        $(if $(filter $(_all_release_configs.$(strip $(1)).OVERRIDES),$(strip $(3))),,
          $(eval _all_release_configs.$(strip $(1)).OVERRIDES := $(_all_release_configs.$(strip $(1)).OVERRIDES) $(strip $(3)))), \
        $(error No release config $(strip $(3))) \
      ) \
    )
    $(eval _all_release_configs.$(strip $(1)).DECLARED_IN := $(_included) $(_all_release_configs.$(strip $(1)).DECLARED_IN))
    $(eval _all_release_configs.$(strip $(1)).FILES := $(_all_release_configs.$(strip $(1)).FILES) $(strip $(2)))
endef

# Include the config map files and populate _flag_declaration_files.
# If the file is found more than once, only include it the first time.
_flag_declaration_files :=
_included_config_map_files :=
$(foreach f, $(config_map_files), \
    $(eval FLAG_DECLARATION_FILES:= ) \
    $(if $(filter $(_included_config_map_files),$(f)),,\
        $(eval _included := $(f)) \
        $(eval include $(f)) \
        $(eval _flag_declaration_files += $(FLAG_DECLARATION_FILES)) \
        $(eval _included_config_map_files += $(f)) \
    ) \
)
FLAG_DECLARATION_FILES :=

# Verify that all inherited/overridden release configs are declared.
$(foreach config,$(ALL_RELEASE_CONFIGS_FOR_PRODUCT),\
  $(foreach r,$(all_release_configs.$(r).OVERRIDES),\
    $(if $(strip $(_all_release_configs.$(r).FILES)$(_all_release_configs.$(r).OVERRIDES)),,\
    $(error Release config $(config) [declared in: $(_all_release_configs.$(r).DECLARED_IN)] inherits from non-existent $(r).)\
)))
# Verify that alias configs do not have config files.
$(foreach r,$(ALL_RELEASE_CONFIGS_FOR_PRODUCT),\
  $(if $(_all_release_configs.$(r).ALIAS),$(if $(_all_release_configs.$(r).FILES),\
    $(error Alias release config "$(r)" may not specify release config files $(_all_release_configs.$(r).FILES))\
)))

# Use makefiles
endif

ifeq ($(TARGET_RELEASE),)
    # We allow some internal paths to explicitly set TARGET_RELEASE to the
    # empty string.  For the most part, 'make' treats unset and empty string as
    # the same.  But the following line differentiates, and will only assign
    # if the variable was completely unset.
    TARGET_RELEASE ?= was_unset
    ifeq ($(TARGET_RELEASE),was_unset)
        $(error No release config set for target; please set TARGET_RELEASE, or if building on the command line use 'lunch <target>-<release>-<build_type>', where release is one of: $(ALL_RELEASE_CONFIGS_FOR_PRODUCT))
    endif
    # Instead of leaving this string empty, we want to default to a valid
    # setting.  Full builds coming through this path is a bug, but in case
    # of such a bug, we want to at least get consistent, valid results.
    TARGET_RELEASE = trunk_staging
endif

# During pass 1 of product config, using a non-existent release config is not an error.
# We can safely assume that we are doing pass 1 if DUMP_MANY_VARS=="PRODUCT_RELEASE_CONFIG_MAPS".
ifneq (,$(_final_product_config_pass))
    ifeq ($(filter $(ALL_RELEASE_CONFIGS_FOR_PRODUCT), $(TARGET_RELEASE)),)
        $(error No release config found for TARGET_RELEASE: $(TARGET_RELEASE). Available releases are: $(ALL_RELEASE_CONFIGS_FOR_PRODUCT))
    endif
endif

ifeq (,$(_use_protobuf))
# Choose flag files
# Don't sort this, use it in the order they gave us.
# Do allow duplicate entries, retaining only the first usage.
flag_value_files :=

# Apply overrides recursively
#
# $1 release config that we override
applied_releases :=
define _apply-release-config-overrides
$(foreach r,$(1), \
  $(if $(filter $(r),$(applied_releases)),, \
    $(foreach o,$(_all_release_configs.$(r).OVERRIDES),$(call _apply-release-config-overrides,$(o)))\
    $(eval applied_releases += $(r))\
    $(foreach f,$(_all_release_configs.$(r).FILES), \
      $(if $(filter $(f),$(flag_value_files)),,$(eval flag_value_files += $(f)))\
    )\
  )\
)
endef
$(call _apply-release-config-overrides,$(TARGET_RELEASE))
# Unset variables so they can't use them
define declare-release-config
$(error declare-release-config can only be called from inside release_config_map.mk files)
endef
define _apply-release-config-overrides
$(error invalid use of apply-release-config-overrides)
endef

# use makefiles
endif

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

ifeq (,$(_use_protobuf))
$(foreach config, $(ALL_RELEASE_CONFIGS_FOR_PRODUCT), \
    $(eval _all_release_configs.$(config).DECLARED_IN:= ) \
    $(eval _all_release_configs.$(config).FILES:= ) \
)
applied_releases:=
# use makefiles
endif
config_map_files:=
protobuf_map_files:=


ifeq (,$(_use_protobuf))
# -----------------------------------------------------------------
# Flag declarations and values
# -----------------------------------------------------------------
# This part is in starlark.  We generate a root starlark file that loads
# all of the flags declaration files that we found, and the flag_value_files
# that we chose from the config map above.  Then we run that, and load the
# results of that into the make environment.

# _flag_declaration_files is the combined list of FLAG_DECLARATION_FILES set by
# release_config_map.mk files above.

# Because starlark can't find files with $(wildcard), write an entrypoint starlark script that
# contains the result of the above wildcards for the starlark code to use.
filename_to_starlark=$(subst /,_,$(subst .,_,$(1)))
_c:=load("//build/make/core/release_config.scl", "release_config")
_c+=$(newline)def add(d, k, v):
_c+=$(newline)$(space)d = dict(d)
_c+=$(newline)$(space)d[k] = v
_c+=$(newline)$(space)return d
_c+=$(foreach f,$(_flag_declaration_files),$(newline)load("$(f)", flags_$(call filename_to_starlark,$(f)) = "flags"))
_c+=$(newline)all_flags = [] $(foreach f,$(_flag_declaration_files),+ [add(x, "declared_in", "$(f)") for x in flags_$(call filename_to_starlark,$(f))])
_c+=$(foreach f,$(flag_value_files),$(newline)load("//$(f)", values_$(call filename_to_starlark,$(f)) = "values"))
_c+=$(newline)all_values = [] $(foreach f,$(flag_value_files),+ [add(x, "set_in", "$(f)") for x in values_$(call filename_to_starlark,$(f))])
_c+=$(newline)variables_to_export_to_make = release_config(all_flags, all_values)
$(file >$(OUT_DIR)/release_config_entrypoint.scl,$(_c))
_c:=
filename_to_starlark:=

# Exclude the entrypoint file as a dependency (by passing it as the 2nd argument) so that we don't
# rerun kati every build. Kati will replay the $(file) command that generates it every build,
# updating its timestamp.
#
# We also need to pass --allow_external_entrypoint to rbcrun in case the OUT_DIR is set to something
# outside of the source tree.
$(call run-starlark,$(OUT_DIR)/release_config_entrypoint.scl,$(OUT_DIR)/release_config_entrypoint.scl,--allow_external_entrypoint)

# use makefiles
endif
_can_protobuf :=
_must_protobuf :=
_use_protobuf :=

