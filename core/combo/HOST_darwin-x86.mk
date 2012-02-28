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

ifneq ($(strip $(BUILD_HOST_64bit)),)
# By default we build everything in 32-bit, because it gives us
# more consistency between the host tools and the target.
# BUILD_HOST_64bit=1 overrides it for tool like emulator
# which can benefit from 64-bit host arch.
HOST_GLOBAL_CFLAGS += -m64
HOST_GLOBAL_LDFLAGS += -m64
else
HOST_GLOBAL_CFLAGS += -m32
HOST_GLOBAL_LDFLAGS += -m32
endif # BUILD_HOST_64bit

# Use the Mac OSX SDK 10.5 if the build host is 10.6
build_mac_version := $(shell sw_vers -productVersion)
ifneq ($(filter 10.6.%, $(build_mac_version)),)
sdk_105_root := /Developer/SDKs/MacOSX10.5.sdk
ifeq ($(wildcard $(sdk_105_root)),)
$(warning *****************************************************)
$(warning * You are building on Mac OSX 10.6.)
$(warning * Can not find SDK 10.5 at $(sdk_105_root))
$(warning *****************************************************)
$(error Stop.)
endif

HOST_GLOBAL_CFLAGS += -isysroot $(sdk_105_root) -mmacosx-version-min=10.5
HOST_GLOBAL_LDFLAGS += -isysroot $(sdk_105_root) -mmacosx-version-min=10.5
endif # build_mac_version is 10.6

HOST_GLOBAL_CFLAGS += -fPIC
HOST_NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

HOST_CC := $(CC)
HOST_CXX := $(CXX)
HOST_AR := $(AR)
HOST_STRIP := $(STRIP)
HOST_STRIP_COMMAND = $(HOST_STRIP) --strip-debug $< -o $@

HOST_SHLIB_SUFFIX := .dylib
HOST_JNILIB_SUFFIX := .jnilib

HOST_GLOBAL_CFLAGS += \
	-include $(call select-android-config-h,darwin-x86)
ifneq ($(filter 10.7.%, $(build_mac_version)),)
       HOST_RUN_RANLIB_AFTER_COPYING := false
else
       HOST_RUN_RANLIB_AFTER_COPYING := true
       PRE_LION_DYNAMIC_LINKER_OPTIONS := -Wl,-dynamic
endif
HOST_GLOBAL_ARFLAGS := cqs

HOST_CUSTOM_LD_COMMAND := true

# Workaround for lack of "-Wl,--whole-archive" in MacOS's linker.
define _darwin-extract-and-include-single-whole-static-lib
@echo "preparing StaticLib: $(PRIVATE_MODULE) [including $(1)]"
$(hide) ldir=$(PRIVATE_INTERMEDIATES_DIR)/WHOLE/$(basename $(notdir $(1)))_objs;\
    mkdir -p $$ldir; \
    for f in `$(HOST_AR) t $(1)`; do \
        $(HOST_AR) p $(1) $$f > $$ldir/$$f; \
    done ;

endef

define darwin-extract-and-include-whole-static-libs
$(if $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), $(hide) rm -rf $(PRIVATE_INTERMEDIATES_DIR)/WHOLE)
$(foreach lib,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), \
    $(call _darwin-extract-and-include-single-whole-static-lib, $(lib)))
endef

define transform-host-o-to-shared-lib-inner
$(call darwin-extract-and-include-whole-static-libs)
$(hide) $(PRIVATE_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(if $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), `find $(PRIVATE_INTERMEDIATES_DIR)/WHOLE -name '*.o' 2>/dev/null`) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        -install_name @rpath/$(notdir $@) \
        -Wl,-rpath,@loader_path/../lib \
        $(PRIVATE_LDFLAGS) \
        $(HOST_LIBGCC)
endef

define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
        -Wl,-rpath,@loader_path/../lib \
        -o $@ \
        $(PRE_LION_DYNAMIC_LINKER_OPTIONS) -headerpad_max_install_names \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_LDLIBS) \
        $(HOST_LIBGCC)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef
