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

define $(combo_var_prefix)transform-shared-lib-to-toc
$(call _gen_toc_command_for_macho,$(1),$(2))
endef

$(combo_2nd_arch_prefix)HOST_GLOBAL_ARFLAGS := cqs

############################################################
## Macros after this line are shared by the 64-bit config.

HOST_CUSTOM_LD_COMMAND := true

define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
            $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
        ) \
        $(PRIVATE_ALL_OBJECTS) \
        $(addprefix -force_load , $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(PRIVATE_ALL_SHARED_LIBRARIES) \
        $(PRIVATE_ALL_STATIC_LIBRARIES) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        -install_name @rpath/$(notdir $@) \
        -Wl,-rpath,@loader_path/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        -Wl,-rpath,@loader_path/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES)) \
        $(PRIVATE_LDFLAGS)
endef

define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
        $(foreach path,$(PRIVATE_RPATHS), \
          -Wl,-rpath,@loader_path/$(path)) \
        -o $@ \
        -Wl,-headerpad_max_install_names \
        $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
           $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
        ) \
        $(PRIVATE_ALL_SHARED_LIBRARIES) \
        $(PRIVATE_ALL_OBJECTS) \
        $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
        $(PRIVATE_ALL_STATIC_LIBRARIES) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_LDLIBS)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef
