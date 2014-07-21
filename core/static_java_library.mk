#
# Copyright (C) 2008 The Android Open Source Project
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

# Standard rules for building a "static" java library.
# Static java libraries are not installed, nor listed on any
# classpaths.  They can, however, be included wholesale in
# other java modules.

LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_IS_STATIC_JAVA_LIBRARY := true
LOCAL_MODULE_CLASS := JAVA_LIBRARIES

# Hack to build static Java library with Android resource
# See bug 5714516
all_resources :=
need_compile_res :=
# A static Java library needs to explicily set LOCAL_RESOURCE_DIR.
ifdef LOCAL_RESOURCE_DIR
need_compile_res := true
all_resources := $(strip \
    $(foreach dir, $(LOCAL_RESOURCE_DIR), \
      $(addprefix $(dir)/, \
        $(patsubst res/%,%, \
          $(call find-subdir-assets,$(dir)) \
        ) \
      ) \
    ))

# By default we should remove the R/Manifest classes from a static Java library,
# because they will be regenerated in the app that uses it.
# But if the static Java library will be used by a library, then we may need to
# keep the generated classes with "LOCAL_JAR_EXCLUDE_FILES := none".
ifndef LOCAL_JAR_EXCLUDE_FILES
LOCAL_JAR_EXCLUDE_FILES := $(ANDROID_RESOURCE_GENERATED_CLASSES)
endif
ifeq (none,$(LOCAL_JAR_EXCLUDE_FILES))
LOCAL_JAR_EXCLUDE_FILES :=
endif

proguard_options_file :=

intermediates.COMMON := $(call local-intermediates-dir,COMMON)
ifneq ($(LOCAL_PROGUARD_ENABLED),custom)
  proguard_options_file := $(intermediates.COMMON)/proguard_options
endif
LOCAL_PROGUARD_FLAGS := $(addprefix -include ,$(proguard_options_file)) $(LOCAL_PROGUARD_FLAGS)

endif  # LOCAL_RESOURCE_DIR

all_res_assets := $(all_resources)

include $(BUILD_SYSTEM)/java_library.mk

ifeq (true,$(need_compile_res))
R_file_stamp := $(LOCAL_INTERMEDIATE_SOURCE_DIR)/R.stamp

include $(BUILD_SYSTEM)/android_manifest.mk

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

framework_res_package_export :=
framework_res_package_export_deps :=
# Please refer to package.mk
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
ifneq ($(filter-out current system_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current,$(LOCAL_SDK_RES_VERSION))),)
framework_res_package_export := \
    $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_RES_VERSION)/android.jar
framework_res_package_export_deps := $(framework_res_package_export)
else
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
framework_res_package_export_deps := \
    $(dir $(framework_res_package_export))src/R.stamp
endif
endif

$(R_file_stamp): PRIVATE_MODULE := $(LOCAL_MODULE)
# add --non-constant-id to prevent inlining constants.
$(R_file_stamp): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) --non-constant-id
$(R_file_stamp): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(LOCAL_INTERMEDIATE_SOURCE_DIR)
$(R_file_stamp): PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)
$(R_file_stamp): PRIVATE_RESOURCE_PUBLICS_OUTPUT := $(intermediates.COMMON)/public_resources.xml
$(R_file_stamp): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(R_file_stamp): PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)
ifneq (,$(filter-out current system_current, $(LOCAL_SDK_VERSION)))
$(R_file_stamp): PRIVATE_DEFAULT_APP_TARGET_SDK := $(LOCAL_SDK_VERSION)
else
$(R_file_stamp): PRIVATE_DEFAULT_APP_TARGET_SDK := $(DEFAULT_APP_TARGET_SDK)
endif
$(R_file_stamp): PRIVATE_ASSET_DIR :=
$(R_file_stamp): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(R_file_stamp): PRIVATE_MANIFEST_PACKAGE_NAME :=
$(R_file_stamp): PRIVATE_MANIFEST_INSTRUMENTATION_FOR :=

$(R_file_stamp) : $(all_resources) $(full_android_manifest) $(AAPT) $(framework_res_package_export_deps)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	$(create-resource-java-files)
	$(hide) find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name R.java | xargs cat > $@

$(LOCAL_BUILT_MODULE): $(R_file_stamp)
ifneq ($(full_classes_jar),)
$(full_classes_compiled_jar): $(R_file_stamp)
endif

endif  # need_compile_res

# Reset internal variables.
all_res_assets :=
LOCAL_IS_STATIC_JAVA_LIBRARY :=
