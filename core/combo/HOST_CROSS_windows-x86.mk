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

# Settings to use MinGW as a cross-compiler under Linux
# Included by combo/select.make

$(combo_var_prefix)C_INCLUDES += prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/include
$(combo_var_prefix)C_INCLUDES += prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/lib/gcc/x86_64-w64-mingw32/4.8.3/include

define $(combo_var_prefix)transform-shared-lib-to-toc
$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OBJDUMP) -x $(1) | grep "^Name" | cut -f3 -d" " > $(2)
$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)NM) -g -f p $(1) | cut -f1-2 -d" " >> $(2)
endef

$(combo_var_prefix)SHLIB_SUFFIX := .dll
$(combo_var_prefix)EXECUTABLE_SUFFIX := .exe

$(combo_var_prefix)IS_64_BIT :=

# The mingw gcc is 4.8, 4.9 is required for color diagnostics
$(combo_var_prefix)UNKNOWN_CFLAGS := -fdiagnostics-color
