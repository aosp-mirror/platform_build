#
# Copyright (C) 2006 The Android Open Source Project
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

# Select a combo based on the compiler being used.
#
# Inputs:
#	combo_target -- prefix for final variables (HOST_ or TARGET_)
#	combo_2nd_arch_prefix -- it's defined if this is loaded for the 2nd arch.
#

ifeq ($(combo_target),HOST_)
  combo_os_arch := $(HOST_OS)
else
  # Build a target string like "linux-arm" or "darwin-x86".
  combo_os_arch := $($(combo_target)OS)-$($(combo_target)$(combo_2nd_arch_prefix)ARCH)
endif

combo_var_prefix := $(combo_2nd_arch_prefix)$(combo_target)

# Set reasonable defaults for the various variables
ifeq ($(combo_target),HOST_CROSS_)
$(KATI_obsolete_var \
  $(combo_var_prefix)GLOBAL_ARFLAGS \
  $(combo_var_prefix)STATIC_LIB_SUFFIX \
  $(combo_var_prefix)transform-shared-lib-to-toc \
  ,HOST_CROSS builds are not supported in Make)
else

$(combo_var_prefix)GLOBAL_ARFLAGS := crsPD --format=gnu

$(combo_var_prefix)STATIC_LIB_SUFFIX := .a

# Now include the combo for this specific target.
include $(BUILD_COMBOS)/$(combo_target)$(combo_os_arch).mk

endif
