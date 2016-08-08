#
# Copyright (C) 2016 The Android Open Source Project
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

# Most Android source files are not clang-tidy clean yet.
# Global tidy checks include only google*, performance*,
# and misc-macro-parentheses, but not google-readability*
# or google-runtime-references.
DEFAULT_GLOBAL_TIDY_CHECKS := \
  $(subst $(space),, \
    -*,google*,performance*,misc-macro-parentheses \
    ,-google-readability*,-google-runtime-references \
  )

# There are too many clang-tidy warnings in external and vendor projects.
# Enable only some google checks for these projects.
DEFAULT_EXTERNAL_VENDOR_TIDY_CHECKS := \
  $(subst $(space),, \
    -*,google*,-google-build-using-namespace \
    ,-google-readability*,-google-runtime-references \
    ,-google-explicit-constructor,-google-runtime-int \
  )

# Every word in DEFAULT_LOCAL_TIDY_CHECKS list has the following format:
#   <local_path_prefix>:,<tidy-checks>
# The last matched local_path_prefix should be the most specific to be used.
DEFAULT_LOCAL_TIDY_CHECKS := \
  external/:$(DEFAULT_EXTERNAL_VENDOR_TIDY_CHECKS) \
  external/google:$(DEFAULT_GLOBAL_TIDY_CHECKS) \
  external/webrtc:$(DEFAULT_GLOBAL_TIDY_CHECKS) \
  hardware/qcom:$(DEFAULT_EXTERNAL_VENDOR_TIDY_CHECKS) \
  vendor/:$(DEFAULT_EXTERNAL_VENDOR_TIDY_CHECKS) \
  vendor/google:$(DEFAULT_GLOBAL_TIDY_CHECKS) \

# Returns 2nd word of $(1) if $(2) has prefix of the 1st word of $(1).
define find_default_local_tidy_check2
$(if $(filter $(word 1,$(1))%,$(2)/),$(word 2,$(1)))
endef

# Returns 2nd part of $(1) if $(2) has prefix of the 1st part of $(1).
define find_default_local_tidy_check
$(call find_default_local_tidy_check2,$(subst :,$(space),$(1)),$(2))
endef

# Returns the default tidy check list for local project path $(1).
# Match $(1) with all patterns in DEFAULT_LOCAL_TIDY_CHECKS and use the last
# most specific pattern.
define default_global_tidy_checks
$(lastword \
  $(DEFAULT_GLOBAL_TIDY_CHECKS) \
  $(foreach pattern,$(DEFAULT_LOCAL_TIDY_CHECKS), \
    $(call find_default_local_tidy_check,$(pattern),$(1)) \
  ) \
)
endef
