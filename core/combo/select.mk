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

# Build a target string like "linux-arm" or "darwin-x86".
combo_os_arch := $($(combo_target)OS)-$($(combo_target)$(combo_2nd_arch_prefix)ARCH)

combo_var_prefix := $(combo_2nd_arch_prefix)$(combo_target)

# Set reasonable defaults for the various variables

$(combo_var_prefix)CC := $(CC)
$(combo_var_prefix)CXX := $(CXX)
$(combo_var_prefix)AR := $(AR)
$(combo_var_prefix)STRIP := $(STRIP)

$(combo_var_prefix)GLOBAL_CFLAGS := -fno-exceptions -Wno-multichar
$(combo_var_prefix)RELEASE_CFLAGS := -O2 -g -fno-strict-aliasing
$(combo_var_prefix)GLOBAL_CPPFLAGS :=
$(combo_var_prefix)GLOBAL_LDFLAGS :=
$(combo_var_prefix)GLOBAL_ARFLAGS := crsPD
$(combo_var_prefix)GLOBAL_LD_DIRS :=

$(combo_var_prefix)EXECUTABLE_SUFFIX :=
$(combo_var_prefix)SHLIB_SUFFIX := .so
$(combo_var_prefix)JNILIB_SUFFIX := $($(combo_var_prefix)SHLIB_SUFFIX)
$(combo_var_prefix)STATIC_LIB_SUFFIX := .a

# Now include the combo for this specific target.
include $(BUILD_COMBOS)/$(combo_target)$(combo_os_arch).mk
