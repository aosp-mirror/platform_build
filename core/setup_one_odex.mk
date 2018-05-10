#
# Copyright (C) 2014 The Android Open Source Project
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

# Set up variables and dependency for one odex file
# Input variables: my_2nd_arch_prefix
# Output(modified) variables: built_odex, installed_odex, built_installed_odex

my_built_odex := $(call get-odex-file-path,$($(my_2nd_arch_prefix)DEX2OAT_TARGET_ARCH),$(LOCAL_BUILT_MODULE))
ifdef LOCAL_DEX_PREOPT_IMAGE_LOCATION
my_dex_preopt_image_location := $(LOCAL_DEX_PREOPT_IMAGE_LOCATION)
else
my_dex_preopt_image_location := $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_LOCATION)
endif
my_dex_preopt_image_filename := $(call get-image-file-path,$($(my_2nd_arch_prefix)DEX2OAT_TARGET_ARCH),$(my_dex_preopt_image_location))

# If LOCAL_ENFORCE_USES_LIBRARIES is not set, default to true if either of LOCAL_USES_LIBRARIES or
# LOCAL_OPTIONAL_USES_LIBRARIES are specified.
ifeq (,$(LOCAL_ENFORCE_USES_LIBRARIES))
# Will change the default to true unconditionally in the future.
ifneq (,$(LOCAL_OPTIONAL_USES_LIBRARIES))
LOCAL_ENFORCE_USES_LIBRARIES := true
endif
ifneq (,$(LOCAL_USES_LIBRARIES))
LOCAL_ENFORCE_USES_LIBRARIES := true
endif
endif

my_uses_libraries := $(LOCAL_USES_LIBRARIES)
my_optional_uses_libraries := $(LOCAL_OPTIONAL_USES_LIBRARIES)
my_missing_uses_libraries := $(INTERNAL_PLATFORM_MISSING_USES_LIBRARIES)

# If we have either optional or required uses-libraries, set up the class loader context
# accordingly.
my_lib_names :=
my_optional_lib_names :=
my_filtered_optional_uses_libraries :=
my_system_dependencies :=
my_stored_preopt_class_loader_context_libs :=
my_conditional_uses_libraries_host :=
my_conditional_uses_libraries_target :=

ifneq (true,$(LOCAL_ENFORCE_USES_LIBRARIES))
  # Pass special class loader context to skip the classpath and collision check.
  # This will get removed once LOCAL_USES_LIBRARIES is enforced.
  # Right now LOCAL_USES_LIBRARIES is opt in, for the case where it's not specified we still default
  # to the &.
  my_dex_preopt_class_loader_context := \&
else
  # Compute the filtered optional uses libraries by removing ones that are not supposed to exist.
  my_filtered_optional_uses_libraries := \
      $(filter-out $(my_missing_uses_libraries), $(my_optional_uses_libraries))
  my_filtered_uses_libraries := $(my_uses_libraries) $(my_filtered_optional_uses_libraries)

  # These are the ones we are verifying in the make rule, use the unfiltered libraries.
  my_lib_names := $(my_uses_libraries)
  my_optional_lib_names := $(my_optional_uses_libraries)

  # Calculate system build dependencies based on the filtered libraries.
  my_intermediate_libs := $(foreach lib_name, $(my_lib_names) $(my_filtered_optional_uses_libraries), \
    $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib_name),,COMMON)/javalib.jar)
  my_dex_preopt_system_dependencies := $(my_intermediate_libs)
  my_dex_preopt_class_loader_context := $(call normalize-path-list,$(my_intermediate_libs))

  # The class loader context checksums are filled in by dex2oat.
  my_stored_preopt_class_loader_context_libs := $(call normalize-path-list, \
      $(foreach lib_name,$(my_filtered_uses_libraries),/system/framework/$(lib_name).jar))

  # Fix up org.apache.http.legacy.boot since it should be org.apache.http.legacy in the manifest.
  my_lib_names := $(patsubst org.apache.http.legacy.boot,org.apache.http.legacy,$(my_lib_names))
  my_optional_lib_names := $(patsubst org.apache.http.legacy.boot,org.apache.http.legacy,$(my_optional_lib_names))
  ifeq (,$(filter org.apache.http.legacy,$(my_lib_names) $(my_optional_lib_names)))
    my_conditional_uses_libraries_host := $(call intermediates-dir-for,JAVA_LIBRARIES,org.apache.http.legacy.boot,,COMMON)/javalib.jar
    my_conditional_uses_libraries_target := /system/framework/org.apache.http.legacy.boot.jar
  endif
endif

# Always depend on org.apache.http.legacy.boot since it may get used by dex2oat-one-file for apps
# targetting <SDK 28(P).
my_always_depend_libraries := $(call intermediates-dir-for,JAVA_LIBRARIES,org.apache.http.legacy.boot,,COMMON)/javalib.jar

$(my_built_odex): $(AAPT)
$(my_built_odex): $(my_always_depend_libraries)
$(my_built_odex): $(my_dex_preopt_system_dependencies)
$(my_built_odex): PRIVATE_ENFORCE_USES_LIBRARIES := $(LOCAL_ENFORCE_USES_LIBRARIES)
$(my_built_odex): PRIVATE_CONDITIONAL_USES_LIBRARIES_HOST := $(my_conditional_uses_libraries_host)
$(my_built_odex): PRIVATE_CONDITIONAL_USES_LIBRARIES_TARGET := $(my_conditional_uses_libraries_target)
$(my_built_odex): PRIVATE_USES_LIBRARY_NAMES := $(my_lib_names)
$(my_built_odex): PRIVATE_OPTIONAL_USES_LIBRARY_NAMES := $(my_optional_lib_names)
$(my_built_odex): PRIVATE_2ND_ARCH_VAR_PREFIX := $(my_2nd_arch_prefix)
$(my_built_odex): PRIVATE_DEX_LOCATION := $(patsubst $(PRODUCT_OUT)%,%,$(LOCAL_INSTALLED_MODULE))
$(my_built_odex): PRIVATE_DEX_PREOPT_IMAGE_LOCATION := $(my_dex_preopt_image_location)
$(my_built_odex): PRIVATE_DEX2OAT_CLASS_LOADER_CONTEXT := $(my_dex_preopt_class_loader_context)
$(my_built_odex): PRIVATE_DEX2OAT_STORED_CLASS_LOADER_CONTEXT_LIBS := $(my_stored_preopt_class_loader_context_libs)
$(my_built_odex) : $($(my_2nd_arch_prefix)DEXPREOPT_ONE_FILE_DEPENDENCY_BUILT_BOOT_PREOPT) \
    $(DEXPREOPT_ONE_FILE_DEPENDENCY_TOOLS) \
    $(my_dex_preopt_image_filename)

my_installed_odex := $(call get-odex-installed-file-path,$($(my_2nd_arch_prefix)DEX2OAT_TARGET_ARCH),$(LOCAL_INSTALLED_MODULE))

my_built_vdex := $(patsubst %.odex,%.vdex,$(my_built_odex))
my_installed_vdex := $(patsubst %.odex,%.vdex,$(my_installed_odex))
my_installed_art := $(patsubst %.odex,%.art,$(my_installed_odex))

ifndef LOCAL_DEX_PREOPT_APP_IMAGE
# Local override not defined, use the global one.
ifeq (true,$(WITH_DEX_PREOPT_APP_IMAGE))
  LOCAL_DEX_PREOPT_APP_IMAGE := true
endif
endif

ifeq (true,$(LOCAL_DEX_PREOPT_APP_IMAGE))
my_built_art := $(patsubst %.odex,%.art,$(my_built_odex))
$(my_built_odex): PRIVATE_ART_FILE_PREOPT_FLAGS := --app-image-file=$(my_built_art) \
    --image-format=lz4
$(eval $(call copy-one-file,$(my_built_art),$(my_installed_art)))
built_art += $(my_built_art)
installed_art += $(my_installed_art)
built_installed_art += $(my_built_art):$(my_installed_art)
endif

$(eval $(call copy-one-file,$(my_built_odex),$(my_installed_odex)))
$(eval $(call copy-one-file,$(my_built_vdex),$(my_installed_vdex)))

built_odex += $(my_built_odex)
built_vdex += $(my_built_vdex)

installed_odex += $(my_installed_odex)
installed_vdex += $(my_installed_vdex)

built_installed_odex += $(my_built_odex):$(my_installed_odex)
built_installed_vdex += $(my_built_vdex):$(my_installed_vdex)
