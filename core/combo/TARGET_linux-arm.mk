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

KNOWN_ARMv8_CORES := cortex-a53 cortex-a53.a57 cortex-a55 cortex-a73 cortex-a75 cortex-a76
KNOWN_ARMv8_CORES += kryo kryo385 exynos-m1 exynos-m2

KNOWN_ARMv82a_CORES := cortex-a55 cortex-a75 kryo385

ifeq (,$(strip $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT)))
  TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT := generic
endif

# This quickly checks TARGET_2ND_ARCH_VARIANT against the lists above.
ifneq (,$(filter $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT), $(KNOWN_ARMv82a_CORES)))
  ifeq (,$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
    TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := armv8-2a
  else ifneq (armv8-2a,$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
    $(error Incorrect TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT, $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT). Use armv8-2a instead.)
  endif
else ifneq (,$(filter $(TARGET_$(combo_2nd_arch_prefix)CPU_VARIANT), $(KNOWN_ARMv8_CORES)))
  ifeq (,$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
    TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := armv8-a
  else ifneq ($(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT),armv8-a)
    $(error Incorrect TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT, $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT). Use armv8-a instead.)
  endif
endif

ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT)),)
  $(error TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT must be set)
endif

# NEON is mandatory, see: https://developer.android.com/ndk/guides/abis#v7a
ARCH_ARM_HAVE_VFP               := true
ARCH_ARM_HAVE_VFP_D32           := true
ARCH_ARM_HAVE_NEON              := true

define $(combo_var_prefix)transform-shared-lib-to-toc
$(call _gen_toc_command_for_elf,$(1),$(2))
endef

$(combo_2nd_arch_prefix)TARGET_PACK_MODULE_RELOCATIONS := true

$(combo_2nd_arch_prefix)TARGET_LINKER := /system/bin/linker
