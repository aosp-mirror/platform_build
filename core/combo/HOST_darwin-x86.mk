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

# We build everything in 32-bit, because some host tools are
# 32-bit-only anyway (emulator, acc), and because it gives us
# more consistency between the host tools and the target.
HOST_GLOBAL_CFLAGS += -m32
HOST_GLOBAL_LDFLAGS += -m32

HOST_GLOBAL_CFLAGS += -fPIC
HOST_NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

HOST_CC := $(CC)
HOST_CXX := $(CXX)
HOST_AR := $(AR)

HOST_SHLIB_SUFFIX := .dylib
HOST_JNILIB_SUFFIX := .jnilib

HOST_GLOBAL_CFLAGS += \
	-include $(call select-android-config-h,darwin-x86)
HOST_RUN_RANLIB_AFTER_COPYING := true
HOST_GLOBAL_ARFLAGS := cqs

HOST_CUSTOM_LD_COMMAND := true

define transform-host-o-to-shared-lib-inner
    $(HOST_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        $(PRIVATE_LDFLAGS) \
        $(HOST_LIBGCC)
endef

define transform-host-o-to-executable-inner
$(HOST_CXX) \
        -o $@ \
        -Wl,-dynamic -headerpad_max_install_names \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_LDLIBS) \
        $(HOST_LIBGCC)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef
