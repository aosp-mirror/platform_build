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

# Configuration for Darwin (Mac OS X) on x86.
# Included by combo/select.mk

$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -m32
$(combo_2nd_arch_prefix)HOST_GLOBAL_LDFLAGS += -m32

ifneq ($(strip $(BUILD_HOST_static)),)
# Statically-linked binaries are desirable for sandboxed environment
$(combo_2nd_arch_prefix)HOST_GLOBAL_LDFLAGS += -static
endif # BUILD_HOST_static

# Workaround differences in inttypes.h between host and target.
# See bug 12708004.
$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS

include $(BUILD_COMBOS)/mac_version.mk

$(combo_2nd_arch_prefix)HOST_TOOLCHAIN_ROOT := prebuilts/gcc/darwin-x86/host/i686-apple-darwin-4.2.1
$(combo_2nd_arch_prefix)HOST_TOOLCHAIN_PREFIX := $($(combo_2nd_arch_prefix)HOST_TOOLCHAIN_ROOT)/bin/i686-apple-darwin$(gcc_darwin_version)
$(combo_2nd_arch_prefix)HOST_CC  := $($(combo_2nd_arch_prefix)HOST_TOOLCHAIN_PREFIX)-gcc
$(combo_2nd_arch_prefix)HOST_CXX := $($(combo_2nd_arch_prefix)HOST_TOOLCHAIN_PREFIX)-g++

define $(combo_var_prefix)transform-shared-lib-to-toc
$(call _gen_toc_command_for_macho,$(1),$(2))
endef

# gcc location for clang; to be updated when clang is updated
# HOST_TOOLCHAIN_ROOT is a Darwin-specific define
$(combo_2nd_arch_prefix)HOST_TOOLCHAIN_FOR_CLANG := $($(combo_2nd_arch_prefix)HOST_TOOLCHAIN_ROOT)

$(combo_2nd_arch_prefix)HOST_AR := $(AR)

$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -isysroot $(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version) -DMACOSX_DEPLOYMENT_TARGET=$(mac_sdk_version)
$(combo_2nd_arch_prefix)HOST_GLOBAL_CPPFLAGS += -isystem $(mac_sdk_path)/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1
$(combo_2nd_arch_prefix)HOST_GLOBAL_LDFLAGS += -isysroot $(mac_sdk_root) -Wl,-syslibroot,$(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version)

$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -fPIC -funwind-tables
$(combo_2nd_arch_prefix)HOST_NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

$(combo_2nd_arch_prefix)HOST_SHLIB_SUFFIX := .dylib
$(combo_2nd_arch_prefix)HOST_JNILIB_SUFFIX := .jnilib

$(combo_2nd_arch_prefix)HOST_GLOBAL_ARFLAGS := cqs

############################################################
## Macros after this line are shared by the 64-bit config.

HOST_CUSTOM_LD_COMMAND := true

define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_LD_DIRS) \
        $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
            $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
        ) \
        $(PRIVATE_ALL_OBJECTS) \
        $(addprefix -force_load , $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        -install_name @rpath/$(notdir $@) \
        -Wl,-rpath,@loader_path/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        -Wl,-rpath,@loader_path/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        $(PRIVATE_LDFLAGS)
endef

define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
        -Wl,-rpath,@loader_path/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        -Wl,-rpath,@loader_path/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        -o $@ \
        -Wl,-headerpad_max_install_names \
        $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_LD_DIRS) \
        $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
           $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
        ) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_LDLIBS)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef
