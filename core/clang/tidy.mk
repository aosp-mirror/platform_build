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

# Default filter contains current directory $1 and optional DEFAULT_TIDY_HEADER_DIRS.
define default_tidy_header_filter
  -header-filter=$(if $(DEFAULT_TIDY_HEADER_DIRS),"($1/|$(DEFAULT_TIDY_HEADER_DIRS))",$1/)
endef
