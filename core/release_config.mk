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
config_map_files := $(wildcard build/release/release_config_map.bzl) \
    $(if $(wildcard vendor/google/release/release_config_map.bzl), \
        vendor/google/release/release_config_map.bzl, \
        $(sort \
            $(wildcard device/*/release/release_config_map.bzl) \
            $(wildcard device/*/*/release/release_config_map.bzl) \
            $(wildcard vendor/*/release/release_config_map.bzl) \
            $(wildcard vendor/*/*/release/release_config_map.bzl) \
        ) \
    )

# Because starlark can't find files with $(wildcard), write an entrypoint starlark script that
# contains the result of the above wildcards for the starlark code to use.
filename_to_starlark=$(subst /,_,$(subst .,_,$(1)))
_c:=load("//build/make/core/release_config.bzl", "release_config")
_c+=$(foreach f,$(flag_declaration_files),$(newline)load("//$(f)", flags_$(call filename_to_starlark,$(f)) = "flags"))
_c+=$(foreach f,$(config_map_files),$(newline)load("//$(f)", config_maps_$(call filename_to_starlark,$(f)) = "config_maps"))
_c+=$(newline)all_flags = [] $(foreach f,$(flag_declaration_files),+ flags_$(call filename_to_starlark,$(f)))
_c+=$(newline)all_config_maps = [$(foreach f,$(config_map_files),config_maps_$(call filename_to_starlark,$(f))$(comma))]
_c+=$(newline)target_release = "$(TARGET_RELEASE)"
_c+=$(newline)fail_if_no_release_config = True if "$(FAIL_IF_NO_RELEASE_CONFIG)" else False
_c+=$(newline)variables_to_export_to_make = release_config(target_release, all_flags, all_config_maps, fail_if_no_release_config)
$(file >$(OUT_DIR)/release_config_entrypoint.bzl,$(_c))
_c:=
filename_to_starlark:=

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

# Exclude the entrypoint file as a dependency (by passing it as the 2nd argument) so that we don't
# rerun kati every build. Kati will replay the $(file) command that generates it every build,
# updating its timestamp.
$(call run-starlark,$(OUT_DIR)/release_config_entrypoint.bzl,$(OUT_DIR)/release_config_entrypoint.bzl)
