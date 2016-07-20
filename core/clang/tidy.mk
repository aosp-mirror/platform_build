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
# Global tidy checks include only google* and misc-macro-parentheses,
# but not google-readability* or google-runtime-references.
DEFAULT_GLOBAL_TIDY_CHECKS := \
  -*,google*,-google-readability*,-google-runtime-references,misc-macro-parentheses

# Disable style rules usually not followed by external projects.
# Every word in DEFAULT_LOCAL_TIDY_CHECKS list has the following format:
#   <local_path_prefix>:,<tidy-check-pattern>
# The tidy-check-patterns of all matching local_path_prefixes will be used.
# For example, external/google* projects will have:
#   ,-google-build-using-namespace,-google-explicit-constructor
#   ,-google-runtime-int,-misc-macro-parentheses,
#   ,google-runtime-int,misc-macro-parentheses
# where google-runtime-int and misc-macro-parentheses are enabled at the end.
DEFAULT_LOCAL_TIDY_CHECKS := \
  external/:,-google-build-using-namespace \
  external/:,-google-explicit-constructor,-google-runtime-int \
  external/:,-misc-macro-parentheses \
  external/google:,google-runtime-int,misc-macro-parentheses \
  external/webrtc/:,google-runtime-int \
  hardware/qcom:,-google-build-using-namespace \
  hardware/qcom:,-google-explicit-constructor,-google-runtime-int \
  vendor/lge:,-google-build-using-namespace,-misc-macro-parentheses \
  vendor/lge:,-google-explicit-constructor,-google-runtime-int \
  vendor/widevine:,-google-build-using-namespace,-misc-macro-parentheses \
  vendor/widevine:,-google-explicit-constructor,-google-runtime-int \

# Returns 2nd word of $(1) if $(2) has prefix of the 1st word of $(1).
define find_default_local_tidy_check2
$(if $(filter $(word 1,$(1))%,$(2)/),$(word 2,$(1)))
endef

# Returns 2nd part of $(1) if $(2) has prefix of the 1st part of $(1).
define find_default_local_tidy_check
$(call find_default_local_tidy_check2,$(subst :,$(space),$(1)),$(2))
endef

# Returns concatenated tidy check patterns from the
# DEFAULT_GLOBAL_TIDY_CHECKS and all matched patterns
# in DEFAULT_LOCAL_TIDY_CHECKS based on given directory path $(1).
define default_global_tidy_checks
$(subst $(space),, \
  $(DEFAULT_GLOBAL_TIDY_CHECKS) \
  $(foreach pattern,$(DEFAULT_LOCAL_TIDY_CHECKS), \
    $(call find_default_local_tidy_check,$(pattern),$(1)) \
  ) \
)
endef
