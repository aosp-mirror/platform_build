#
# Copyright (C) 2019 The Android Open Source Project
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

############################################################
# Internal build rules for native prebuilt modules
############################################################

my_strip_module := $(firstword \
  $(LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_STRIP_MODULE))

ifeq (SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS))
  ifeq ($(LOCAL_IS_HOST_MODULE)$(my_strip_module),)
    # Strip but not try to add debuglink
    my_strip_module := no_debuglink
  endif
endif

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

# Don't install static libraries by default.
ifndef LOCAL_UNINSTALLABLE_MODULE
ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
  LOCAL_UNINSTALLABLE_MODULE := true
endif
endif

my_check_elf_file_shared_lib_files :=

ifneq ($(filter true keep_symbols no_debuglink mini-debug-info,$(my_strip_module)),)
  ifdef LOCAL_IS_HOST_MODULE
    $(call pretty-error,Cannot strip/pack host module)
  endif
  ifeq ($(filter SHARED_LIBRARIES EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    $(call pretty-error,Can strip/pack only shared libraries or executables)
  endif
  ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
    $(call pretty-error,Cannot strip/pack scripts)
  endif
  # Set the arch-specific variables to set up the strip rules
  LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) := $(my_strip_module)
  include $(BUILD_SYSTEM)/dynamic_binary.mk
  built_module := $(linked_module)

  ifneq ($(LOCAL_SDK_VERSION),)
    # binary.mk filters out NDK_MIGRATED_LIBS from my_shared_libs, thus those NDK libs are not added
    # to DEPENDENCIES_ON_SHARED_LIBRARIES. Assign $(my_ndk_shared_libraries_fullpath) to
    # my_check_elf_file_shared_lib_files so that check_elf_file.py can see those NDK stub libs.
    my_check_elf_file_shared_lib_files := $(my_ndk_shared_libraries_fullpath)
  endif
else  # my_strip_module not true
  include $(BUILD_SYSTEM)/base_rules.mk
  built_module := $(LOCAL_BUILT_MODULE)

ifdef prebuilt_module_is_a_library
export_includes := $(intermediates)/export_includes
export_cflags := $(foreach d,$(LOCAL_EXPORT_C_INCLUDE_DIRS),-I $(d))
$(export_includes): PRIVATE_EXPORT_CFLAGS := $(export_cflags)
$(export_includes): $(LOCAL_EXPORT_C_INCLUDE_DEPS)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef export_cflags
	$(hide) echo "$(PRIVATE_EXPORT_CFLAGS)" >$@
else
	$(hide) touch $@
endif
export_cflags :=

include $(BUILD_SYSTEM)/allowed_ndk_types.mk

ifdef LOCAL_SDK_VERSION
my_link_type := native:ndk:$(my_ndk_stl_family):$(my_ndk_stl_link_type)
else ifdef LOCAL_USE_VNDK
    _name := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(filter $(_name),$(VNDK_CORE_LIBRARIES) $(VNDK_SAMEPROCESS_LIBRARIES) $(LLNDK_LIBRARIES)),)
        ifeq ($(filter $(_name),$(VNDK_PRIVATE_LIBRARIES)),)
            my_link_type := native:vndk
        else
            my_link_type := native:vndk_private
        endif
    else
        my_link_type := native:vendor
    endif
else ifneq ($(filter $(TARGET_RECOVERY_OUT)/%,$(LOCAL_MODULE_PATH)),)
my_link_type := native:recovery
else
my_link_type := native:platform
endif

# TODO: check dependencies of prebuilt files
my_link_deps :=

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common :=
include $(BUILD_SYSTEM)/link_type.mk
endif  # prebuilt_module_is_a_library

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef LOCAL_IS_HOST_MODULE
    ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
        my_system_shared_libraries :=
    else
        my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
    endif
else
    ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
        my_system_shared_libraries := libc libm libdl
    else
        my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
        my_system_shared_libraries := $(patsubst libc,libc libdl,$(my_system_shared_libraries))
    endif
endif

my_shared_libraries := \
    $(filter-out $(my_system_shared_libraries),$(LOCAL_SHARED_LIBRARIES)) \
    $(my_system_shared_libraries)

ifdef my_shared_libraries
# Extra shared libraries introduced by LOCAL_CXX_STL.
include $(BUILD_SYSTEM)/cxx_stl_setup.mk
ifdef LOCAL_USE_VNDK
  my_shared_libraries := $(foreach l,$(my_shared_libraries),\
    $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
endif
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
  $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))
endif
endif  # my_shared_libraries

# We need to enclose the above export_includes and my_built_shared_libraries in
# "my_strip_module not true" because otherwise the rules are defined in dynamic_binary.mk.
endif  # my_strip_module not true


# Check prebuilt ELF binaries.
include $(BUILD_SYSTEM)/check_elf_file.mk

ifeq ($(NATIVE_COVERAGE),true)
ifneq (,$(strip $(LOCAL_PREBUILT_COVERAGE_ARCHIVE)))
  $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(intermediates)/$(LOCAL_MODULE).gcnodir))
  ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
    ifdef LOCAL_IS_HOST_MODULE
      my_coverage_path := $($(my_prefix)OUT_COVERAGE)/$(patsubst $($(my_prefix)OUT)/%,%,$(my_module_path))
    else
      my_coverage_path := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
    endif
    my_coverage_path := $(my_coverage_path)/$(patsubst %.so,%,$(my_installed_module_stem)).gcnodir
    $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(my_coverage_path)))
    $(LOCAL_BUILT_MODULE): $(my_coverage_path)
  endif
else
# Coverage information is needed when static lib is a dependency of another
# coverage-enabled module.
ifeq (STATIC_LIBRARIES, $(LOCAL_MODULE_CLASS))
GCNO_ARCHIVE := $(LOCAL_MODULE).gcnodir
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS :=
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES :=
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_PREFIX := $(my_prefix)
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)
$(intermediates)/$(GCNO_ARCHIVE) :
	$(transform-o-to-static-lib)
endif
endif
endif

ifneq ($(filter init%rc,$(notdir $(LOCAL_INSTALLED_MODULE)))$(filter %/etc/init,$(dir $(LOCAL_INSTALLED_MODULE))),)
  $(eval $(call copy-init-script-file-checked,$(my_prebuilt_src_file),$(built_module)))
else ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target-strip-comments)
else
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target)
endif
ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	$(hide) chmod +x $@
endif

