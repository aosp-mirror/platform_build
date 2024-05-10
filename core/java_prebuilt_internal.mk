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
# Internal build rules for JAVA_LIBRARIES prebuilt modules
############################################################

ifneq (JAVA_LIBRARIES,$(LOCAL_MODULE_CLASS))
$(call pretty-error,java_prebuilt_internal.mk is for JAVA_LIBRARIES modules only)
endif

include $(BUILD_SYSTEM)/base_rules.mk
built_module := $(LOCAL_BUILT_MODULE)

ifeq (,$(LOCAL_IS_HOST_MODULE)$(filter true,$(LOCAL_UNINSTALLABLE_MODULE)))
  prebuilt_module_is_dex_javalib := true
else
  prebuilt_module_is_dex_javalib :=
endif

ifeq ($(prebuilt_module_is_dex_javalib),true)
my_dex_jar := $(my_prebuilt_src_file)
# This is a target shared library, i.e. a jar with classes.dex.

$(foreach pair,$(PRODUCT_BOOT_JARS), \
  $(if $(filter $(LOCAL_MODULE),$(call word-colon,2,$(pair))), \
    $(call pretty-error,Modules in PRODUCT_BOOT_JARS must be defined in Android.bp files)))

ALL_MODULES.$(my_register_name).CLASSES_JAR := $(common_classes_jar)

#######################################
# defines built_odex along with rule to install odex
my_manifest_or_apk := $(my_prebuilt_src_file)
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
my_manifest_or_apk :=
#######################################
$(built_module) : $(my_prebuilt_src_file)
	$(call copy-file-to-target)

else  # ! prebuilt_module_is_dex_javalib
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target)
endif # ! prebuilt_module_is_dex_javalib

my_src_jar := $(my_prebuilt_src_file)

ifdef LOCAL_IS_HOST_MODULE
# for host java libraries deps should be in the common dir, so we make a copy in
# the common dir.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_header_jar := $(intermediates.COMMON)/classes-header.jar

$(common_classes_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar): PRIVATE_PREFIX := $(my_prefix)

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

ifneq ($(TURBINE_ENABLED),false)
$(common_header_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)
endif

else # !LOCAL_IS_HOST_MODULE
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_header_jar := $(intermediates.COMMON)/classes-header.jar
common_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
common_javalib_jar := $(intermediates.COMMON)/javalib.jar

$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_PREFIX := $(my_prefix)

ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
else ifneq (,$(call has-system-sdk-version,$(LOCAL_SDK_VERSION)))
my_link_type := java:system
else ifeq ($(LOCAL_SDK_VERSION),core_current)
my_link_type := java:core
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
else
my_link_type := java:platform
endif

# TODO: check dependencies of prebuilt files
my_link_deps :=

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk

ifeq ($(prebuilt_module_is_dex_javalib),true)
# For prebuilt shared Java library we don't have classes.jar.
$(common_javalib_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

else  # ! prebuilt_module_is_dex_javalib

my_src_aar := $(filter %.aar, $(my_prebuilt_src_file))
ifneq ($(my_src_aar),)
# This is .aar file, archive of classes.jar and Android resources.

my_src_jar := $(intermediates.COMMON)/aar/classes.jar
my_src_proguard_options := $(intermediates.COMMON)/aar/proguard.txt
my_src_android_manifest := $(intermediates.COMMON)/aar/AndroidManifest.xml

$(my_src_jar) : .KATI_IMPLICIT_OUTPUTS := $(my_src_proguard_options)
$(my_src_jar) : .KATI_IMPLICIT_OUTPUTS += $(my_src_android_manifest)
$(my_src_jar) : $(my_src_aar)
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@) $(dir $@)/res
	$(hide) unzip -qoDD -d $(dir $@) $<
	# Make sure the proguard and AndroidManifest.xml files exist
	$(hide) touch $(dir $@)/proguard.txt
	$(hide) touch $(dir $@)/AndroidManifest.xml

my_prebuilt_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml
$(eval $(call copy-one-file,$(my_src_android_manifest),$(my_prebuilt_android_manifest)))
$(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_prebuilt_android_manifest))

endif

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

ifneq ($(TURBINE_ENABLED),false)
$(common_header_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)
endif

$(common_classes_pre_proguard_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

$(common_javalib_jar) : $(common_classes_jar)
	$(transform-prebuilt-to-target)

include $(BUILD_SYSTEM)/force_aapt2.mk

ifneq ($(my_src_aar),)

$(intermediates.COMMON)/export_proguard_flags : $(my_src_proguard_options)
	$(transform-prebuilt-to-target)

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

framework_res_package_export :=
# Please refer to package.mk
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
ifneq ($(filter-out current system_current test_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_USE_PREBUILT_SDKS),$(filter current system_current test_current,$(LOCAL_SDK_RES_VERSION))),)
framework_res_package_export := \
    $(call resolve-prebuilt-sdk-jar-path,$(LOCAL_SDK_RES_VERSION))
else
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
endif
endif

my_res_package := $(intermediates.COMMON)/package-res.apk

# We needed only very few PRIVATE variables and aapt2.mk input variables. Reset the unnecessary ones.
$(my_res_package): PRIVATE_AAPT2_CFLAGS :=
$(my_res_package): PRIVATE_AAPT_FLAGS := --static-lib --no-static-lib-packages --auto-add-overlay
$(my_res_package): PRIVATE_ANDROID_MANIFEST := $(my_src_android_manifest)
$(my_res_package): PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)
$(my_res_package): PRIVATE_SOURCE_INTERMEDIATES_DIR :=
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
$(my_res_package): PRIVATE_TARGET_AAPT_CHARACTERISTICS :=
$(my_res_package) : $(framework_res_package_export)
$(my_res_package) : $(my_src_android_manifest)

full_android_manifest :=
my_res_resources :=
my_overlay_resources :=
my_compiled_res_base_dir := $(intermediates.COMMON)/flat-res
R_file_stamp :=
proguard_options_file :=
my_generated_res_dirs := $(intermediates.COMMON)/aar/res
my_generated_res_dirs_deps := $(my_src_jar)
include $(BUILD_SYSTEM)/aapt2.mk

# Make sure my_res_package is created when you run mm/mmm.
$(built_module) : $(my_res_package)
endif  # $(my_src_aar)

# make sure the classes.jar and javalib.jar are built before $(LOCAL_BUILT_MODULE)
$(built_module) : $(common_javalib_jar)

my_exported_sdk_libs_file := $(intermediates.COMMON)/exported-sdk-libs
$(my_exported_sdk_libs_file): PRIVATE_EXPORTED_SDK_LIBS := $(LOCAL_EXPORT_SDK_LIBRARIES)
$(my_exported_sdk_libs_file):
	@echo "Export SDK libs $@"
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(if $(PRIVATE_EXPORTED_SDK_LIBS),\
		$(hide) echo $(PRIVATE_EXPORTED_SDK_LIBS) | tr ' ' '\n' > $@,\
		$(hide) touch $@)

endif # ! prebuilt_module_is_dex_javalib
endif # LOCAL_IS_HOST_MODULE is not set
