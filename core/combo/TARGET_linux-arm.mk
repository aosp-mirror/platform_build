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

# Configuration for Linux on ARM.
# Included by combo/select.mk

# You can set TARGET_ARCH_VARIANT to use an arch version other
# than ARMv5TE. Each value should correspond to a file named
# $(BUILD_COMBOS)/arch/<name>.mk which must contain
# makefile variable definitions. Their
# purpose is to allow module Android.mk files to selectively compile
# different versions of code based upon the funtionality and
# instructions available in a given architecture version.
#
# The blocks also define specific arch_variant_cflags, which
# include defines, and compiler settings for the given architecture
# version.
#
ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)),)
TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT := generic
endif

KNOWN_ARMv8_CORES := cortex-a53 cortex-a53.a57 cortex-a73
KNOWN_ARMv8_CORES += kryo denver64 exynos-m1 exynos-m2

# Many devices (incorrectly) use armv7-a-neon as the 2nd architecture variant
# for cores that implement armv8-a ISAs. The following sets it to armv8-a.
ifneq (,$(filter $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT), $(KNOWN_ARMv8_CORES)))
  ifneq ($(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT),armv8-a)
    $(warning $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT) is armv8-a.)
    ifneq (,$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
      $(warning TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT, $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT), ignored! Use armv8-a instead.)
    endif
    # Overwrite TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT
    TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := armv8-a
  endif
endif

ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT)),)
TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := armv5te
endif

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_$(combo_2nd_arch_prefix)ARCH)/$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown ARM architecture version: $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)
include $(BUILD_SYSTEM)/combo/fdo.mk

define $(combo_var_prefix)transform-shared-lib-to-toc
$(call _gen_toc_command_for_elf,$(1),$(2))
endef

$(combo_2nd_arch_prefix)TARGET_PACK_MODULE_RELOCATIONS := true

$(combo_2nd_arch_prefix)TARGET_LINKER := /system/bin/linker
