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

$(call record-module-type,STATIC_JAVA_LIBRARY)
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_IS_STATIC_JAVA_LIBRARY := true
LOCAL_MODULE_CLASS := JAVA_LIBRARIES

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

my_res_package :=

ifdef LOCAL_AAPT2_ONLY
LOCAL_USE_AAPT2 := true
endif

# Process Support Library dependencies.
include $(BUILD_SYSTEM)/support_libraries.mk

# Hack to build static Java library with Android resource
# See bug 5714516
all_resources :=
need_compile_res :=
# A static Java library needs to explicily set LOCAL_RESOURCE_DIR.
ifdef LOCAL_RESOURCE_DIR
need_compile_res := true
LOCAL_RESOURCE_DIR := $(foreach d,$(LOCAL_RESOURCE_DIR),$(call clean-path,$(d)))
endif
ifdef LOCAL_USE_AAPT2
ifneq ($(LOCAL_STATIC_ANDROID_LIBRARIES),)
need_compile_res := true
endif
endif

ifeq ($(need_compile_res),true)
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

ifneq ($(filter custom,$(LOCAL_PROGUARD_ENABLED)),custom)
  proguard_options_file := $(intermediates.COMMON)/proguard_options
endif

LOCAL_PROGUARD_FLAGS := $(addprefix -include ,$(proguard_options_file)) $(LOCAL_PROGUARD_FLAGS)

R_file_stamp := $(intermediates.COMMON)/src/R.stamp
LOCAL_INTERMEDIATE_TARGETS += $(R_file_stamp)

ifdef LOCAL_USE_AAPT2
# For library we treat all the resource equal with no overlay.
my_res_resources := $(all_resources)
my_overlay_resources :=
# For libraries put everything in the COMMON intermediate directory.
my_res_package := $(intermediates.COMMON)/package-res.apk

LOCAL_INTERMEDIATE_TARGETS += $(my_res_package)
endif  # LOCAL_USE_AAPT2
endif  # need_compile_res

all_res_assets := $(all_resources)

include $(BUILD_SYSTEM)/java_renderscript.mk

ifeq (true,$(need_compile_res))
include $(BUILD_SYSTEM)/android_manifest.mk

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

framework_res_package_export :=
# Please refer to package.mk
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
ifneq ($(filter-out current system_current test_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current test_current,$(LOCAL_SDK_RES_VERSION))),)
framework_res_package_export := \
    $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_RES_VERSION)/android.jar
else
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
endif
endif

ifdef LOCAL_USE_AAPT2
import_proguard_flag_files := $(strip $(foreach l,$(LOCAL_STATIC_ANDROID_LIBRARIES),\
    $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/export_proguard_flags))
$(intermediates.COMMON)/export_proguard_flags: $(import_proguard_flag_files) $(addprefix $(LOCAL_PATH)/,$(LOCAL_EXPORT_PROGUARD_FLAG_FILES))
	@echo "Export proguard flags: $@"
	rm -f $@
	touch $@
	for f in $+; do \
		echo -e "\n# including $$f" >>$@; \
		cat $$f >>$@; \
	done
import_proguard_flag_files :=
endif

include $(BUILD_SYSTEM)/aapt_flags.mk

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_AAPT_CHARACTERISTICS := $(TARGET_AAPT_CHARACTERISTICS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_PACKAGE_NAME := $(LOCAL_MANIFEST_PACKAGE_NAME)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_INSTRUMENTATION_FOR := $(LOCAL_MANIFEST_INSTRUMENTATION_FOR)

# add --non-constant-id to prevent inlining constants.
# AAR needs text symbol file R.txt.
ifdef LOCAL_USE_AAPT2
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) --static-lib --output-text-symbols $(intermediates.COMMON)/R.txt
ifndef LOCAL_AAPT_NAMESPACES
  $(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_FLAGS += --no-static-lib-packages
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_TARGET_AAPT_CHARACTERISTICS :=
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) --non-constant-id --output-text-symbols $(intermediates.COMMON)

my_srcjar := $(intermediates.COMMON)/aapt.srcjar
LOCAL_SRCJARS += $(my_srcjar)
$(R_file_stamp): PRIVATE_SRCJAR := $(my_srcjar)
$(R_file_stamp): PRIVATE_JAVA_GEN_DIR := $(intermediates.COMMON)/aapt
$(R_file_stamp): .KATI_IMPLICIT_OUTPUTS := $(my_srcjar)
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RESOURCE_PUBLICS_OUTPUT := $(intermediates.COMMON)/public_resources.xml
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASSET_DIR :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_PACKAGE_NAME :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MANIFEST_INSTRUMENTATION_FOR :=

ifdef LOCAL_USE_AAPT2
  # One more level with name res so we can zip up the flat resources that can be linked by apps.
  my_compiled_res_base_dir := $(intermediates.COMMON)/flat-res/res
  ifneq (,$(renderscript_target_api))
    ifneq ($(call math_gt_or_eq,$(renderscript_target_api),21),true)
      my_generated_res_zips := $(rs_generated_res_zip)
    endif  # renderscript_target_api < 21
  endif  # renderscript_target_api is set
  include $(BUILD_SYSTEM)/aapt2.mk
  $(my_res_package) : $(framework_res_package_export)
  $(my_res_package): .KATI_IMPLICIT_OUTPUTS += $(intermediates.COMMON)/R.txt
else
  $(R_file_stamp): .KATI_IMPLICIT_OUTPUTS += $(intermediates.COMMON)/R.txt
  $(R_file_stamp): PRIVATE_RESOURCE_LIST := $(all_resources)
  $(R_file_stamp) : $(all_resources) $(full_android_manifest) $(AAPT) $(SOONG_ZIP) \
    $(framework_res_package_export) $(rs_generated_res_zip)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	$(create-resource-java-files)
	$(hide) find $(PRIVATE_JAVA_GEN_DIR) -name R.java | xargs cat > $@
endif  # LOCAL_USE_AAPT2

endif # need_compile_res

include $(BUILD_SYSTEM)/java_library.mk

ifeq (true,$(need_compile_res))

$(LOCAL_BUILT_MODULE): $(R_file_stamp)
$(java_source_list_file): $(R_file_stamp)
$(full_classes_compiled_jar): $(R_file_stamp)
$(full_classes_turbine_jar): $(R_file_stamp)


# if we have custom proguarding done use the proguarded classes jar instead of the normal classes jar
ifeq ($(filter custom,$(LOCAL_PROGUARD_ENABLED)),custom)
aar_classes_jar = $(full_classes_jar)
else
aar_classes_jar = $(full_classes_pre_proguard_jar)
endif

# Rule to build AAR, archive including classes.jar, resource, etc.
built_aar := $(intermediates.COMMON)/javalib.aar
$(built_aar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(built_aar): PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)
$(built_aar): PRIVATE_CLASSES_JAR := $(aar_classes_jar)
$(built_aar): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(built_aar): PRIVATE_R_TXT := $(intermediates.COMMON)/R.txt
$(built_aar): $(JAR_ARGS)
$(built_aar) : $(aar_classes_jar) $(full_android_manifest) $(intermediates.COMMON)/R.txt
	@echo "target AAR:  $(PRIVATE_MODULE) ($@)"
	$(hide) rm -rf $(dir $@)aar && mkdir -p $(dir $@)aar/res
	$(hide) cp $(PRIVATE_ANDROID_MANIFEST) $(dir $@)aar/AndroidManifest.xml
	$(hide) cp $(PRIVATE_CLASSES_JAR) $(dir $@)aar/classes.jar
	# Note: Use "cp -n" to honor the resource overlay rules, if multiple res dirs exist.
	$(hide) $(foreach res,$(PRIVATE_RESOURCE_DIR),cp -Rfn $(res)/* $(dir $@)aar/res;)
	$(hide) cp $(PRIVATE_R_TXT) $(dir $@)aar/R.txt
	$(hide) $(JAR) -cMf $@ \
	  $(call jar-args-sorted-files-in-directory,$(dir $@)aar)

# Register the aar file.
ALL_MODULES.$(LOCAL_MODULE).AAR := $(built_aar)
endif  # need_compile_res

# Reset internal variables.
aar_classes_jar :=
all_res_assets :=
LOCAL_IS_STATIC_JAVA_LIBRARY :=
