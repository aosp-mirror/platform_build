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

###########################################################
## Standard rules for building an application package.
##
## Additional inputs from base_rules.make:
## LOCAL_PACKAGE_NAME: The name of the package; the directory
## will be called this.
##
## MODULE, MODULE_PATH, and MODULE_SUFFIX will
## be set for you.
###########################################################

# If this makefile is being read from within an inheritance,
# use the new values.
skip_definition:=
ifdef LOCAL_PACKAGE_OVERRIDES
  package_overridden := $(call set-inherited-package-variables)
  ifeq ($(strip $(package_overridden)),)
    skip_definition := true
  endif
endif

ifndef skip_definition

LOCAL_PACKAGE_NAME := $(strip $(LOCAL_PACKAGE_NAME))
ifeq ($(LOCAL_PACKAGE_NAME),)
$(error $(LOCAL_PATH): Package modules must define LOCAL_PACKAGE_NAME)
endif

ifneq ($(strip $(LOCAL_MODULE_SUFFIX)),)
$(error $(LOCAL_PATH): Package modules may not define LOCAL_MODULE_SUFFIX)
endif
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)

ifneq ($(strip $(LOCAL_MODULE)),)
$(error $(LOCAL_PATH): Package modules may not define LOCAL_MODULE)
endif
LOCAL_MODULE := $(LOCAL_PACKAGE_NAME)

ifneq ($(strip $(LOCAL_MODULE_CLASS)),)
$(error $(LOCAL_PATH): Package modules may not set LOCAL_MODULE_CLASS)
endif
LOCAL_MODULE_CLASS := APPS

# Package LOCAL_MODULE_TAGS default to optional
LOCAL_MODULE_TAGS := $(strip $(LOCAL_MODULE_TAGS))
ifeq ($(LOCAL_MODULE_TAGS),)
LOCAL_MODULE_TAGS := optional
endif

ifeq ($(filter tests, $(LOCAL_MODULE_TAGS)),)
# Force localization check if it's not tagged as tests.
LOCAL_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) -z
endif

ifdef LOCAL_PACKAGE_SPLITS
LOCAL_AAPT_FLAGS += $(addprefix --split ,$(LOCAL_PACKAGE_SPLITS))
endif

need_compile_asset :=
ifeq (,$(LOCAL_ASSET_DIR))
LOCAL_ASSET_DIR := $(LOCAL_PATH)/assets
else
need_compile_asset := true
endif

# LOCAL_RESOURCE_DIR may point to resource generated during the build
need_compile_res :=
ifeq (,$(LOCAL_RESOURCE_DIR))
  LOCAL_RESOURCE_DIR := $(LOCAL_PATH)/res
else
  need_compile_res := true
endif

package_resource_overlays := $(strip \
    $(wildcard $(foreach dir, $(PRODUCT_PACKAGE_OVERLAYS), \
      $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))) \
    $(wildcard $(foreach dir, $(DEVICE_PACKAGE_OVERLAYS), \
      $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))))

LOCAL_RESOURCE_DIR := $(package_resource_overlays) $(LOCAL_RESOURCE_DIR)

all_assets := $(strip \
    $(foreach dir, $(LOCAL_ASSET_DIR), \
      $(addprefix $(dir)/, \
        $(patsubst assets/%,%, \
          $(call find-subdir-assets, $(dir)) \
         ) \
       ) \
     ))

ifneq ($(all_assets),)
need_compile_asset := true
endif

all_resources := $(strip \
    $(foreach dir, $(LOCAL_RESOURCE_DIR), \
      $(addprefix $(dir)/, \
        $(patsubst res/%,%, \
          $(call find-subdir-assets,$(dir)) \
         ) \
       ) \
     ))

ifneq ($(all_resources),)
  need_compile_res := true
endif

all_res_assets := $(strip $(all_assets) $(all_resources))

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

# If no assets or resources were found, clear the directory variables so
# we don't try to build them.
ifneq (true,$(need_compile_asset))
LOCAL_ASSET_DIR:=
endif
ifneq (true,$(need_compile_res))
LOCAL_RESOURCE_DIR:=
R_file_stamp :=
else
# Make sure that R_file_stamp inherits the proper PRIVATE vars.
# If R.stamp moves, be sure to update the framework makefile,
# which has intimate knowledge of its location.
R_file_stamp := $(intermediates.COMMON)/src/R.stamp
LOCAL_INTERMEDIATE_TARGETS += $(R_file_stamp)
endif

LOCAL_BUILT_MODULE_STEM := package.apk
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk

LOCAL_PROGUARD_ENABLED:=$(strip $(LOCAL_PROGUARD_ENABLED))
ifndef LOCAL_PROGUARD_ENABLED
ifneq ($(DISABLE_PROGUARD),true)
    LOCAL_PROGUARD_ENABLED :=full
endif
endif
ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
    # the package explicitly request to disable proguard.
    LOCAL_PROGUARD_ENABLED :=
endif
proguard_options_file :=
ifneq ($(LOCAL_PROGUARD_ENABLED),custom)
ifeq ($(need_compile_res),true)
    proguard_options_file := $(intermediates.COMMON)/proguard_options
endif # need_compile_res
endif # !custom
LOCAL_PROGUARD_FLAGS := $(addprefix -include ,$(proguard_options_file)) $(LOCAL_PROGUARD_FLAGS)

ifeq (true,$(EMMA_INSTRUMENT))
ifndef LOCAL_EMMA_INSTRUMENT
# No emma for test apks.
ifeq (,$(filer tests,$(LOCAL_MODULE_TAGS))$(LOCAL_INSTRUMENTATION_FOR))
LOCAL_EMMA_INSTRUMENT := true
endif # No test apk
endif # LOCAL_EMMA_INSTRUMENT is not set
else
LOCAL_EMMA_INSTRUMENT := false
endif # EMMA_INSTRUMENT is true

ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
LOCAL_STATIC_JAVA_LIBRARIES += emma
else
ifdef LOCAL_SDK_VERSION
ifdef TARGET_BUILD_APPS
# In unbundled build merge the emma library into the apk.
LOCAL_STATIC_JAVA_LIBRARIES += emma
else
# If build against the SDK in full build, core.jar is not used,
# we have to use prebiult emma.jar to make Proguard happy;
# Otherwise emma classes are included in core.jar.
LOCAL_PROGUARD_FLAGS += -libraryjars $(EMMA_JAR)
endif # full build
endif # LOCAL_SDK_VERSION
endif # EMMA_INSTRUMENT_STATIC
endif # LOCAL_EMMA_INSTRUMENT

rs_compatibility_jni_libs :=

include $(BUILD_SYSTEM)/android_manifest.mk

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)
ifneq (,$(filter-out current system_current, $(LOCAL_SDK_VERSION)))
$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_DEFAULT_APP_TARGET_SDK := $(LOCAL_SDK_VERSION)
else
$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_DEFAULT_APP_TARGET_SDK := $(DEFAULT_APP_TARGET_SDK)
endif

ifeq ($(need_compile_res),true)

# Since we don't know where the real R.java file is going to end up,
# we need to use another file to stand in its place.  We'll just
# copy the generated file to src/R.stamp, which means it will
# have the same contents and timestamp as the actual file.
#
# At the same time, this will copy the R.java file to a central
# 'R' directory to make it easier to add the files to an IDE.
#

$(R_file_stamp): PRIVATE_RESOURCE_PUBLICS_OUTPUT := \
			$(intermediates.COMMON)/public_resources.xml
$(R_file_stamp): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(R_file_stamp): $(all_res_assets) $(full_android_manifest) $(RenderScript_file_stamp) $(AAPT) | $(ACP)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	@rm -f $@
	$(create-resource-java-files)
	$(hide) for GENERATED_MANIFEST_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
					-name Manifest.java 2> /dev/null`; do \
		dir=`awk '/package/{gsub(/\./,"/",$$2);gsub(/;/,"",$$2);print $$2;exit}' $$GENERATED_MANIFEST_FILE`; \
		mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
		$(ACP) -fp $$GENERATED_MANIFEST_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
	done;
	$(hide) for GENERATED_R_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
					-name R.java 2> /dev/null`; do \
		dir=`awk '/package/{gsub(/\./,"/",$$2);gsub(/;/,"",$$2);print $$2;exit}' $$GENERATED_R_FILE`; \
		mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
		$(ACP) -fp $$GENERATED_R_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir \
			|| exit 31; \
		$(ACP) -fp $$GENERATED_R_FILE $@ || exit 32; \
	done; \

$(proguard_options_file): $(R_file_stamp)

resource_export_package :=
ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
# Put this module's resources into a PRODUCT-agnositc package that
# other packages can use to build their own PRODUCT-agnostic R.java (etc.)
# files.
resource_export_package := $(intermediates.COMMON)/package-export.apk
$(R_file_stamp): $(resource_export_package)

# add-assets-to-package looks at PRODUCT_AAPT_CONFIG, but this target
# can't know anything about PRODUCT.  Clear it out just for this target.
$(resource_export_package): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(resource_export_package): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
$(resource_export_package): $(all_res_assets) $(full_android_manifest) $(RenderScript_file_stamp) $(AAPT)
	@echo "target Export Resources: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-assets-to-package)
endif

# Other modules should depend on the BUILT module if
# they want to use this module's R.java file.
$(LOCAL_BUILT_MODULE): $(R_file_stamp)

ifneq ($(full_classes_jar),)
# If full_classes_jar is non-empty, we're building sources.
# If we're building sources, the initial javac step (which
# produces full_classes_compiled_jar) needs to ensure the
# R.java and Manifest.java files have been generated first.
$(full_classes_compiled_jar): $(R_file_stamp)
endif

endif  # need_compile_res

ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
# We need to explicitly clear this var so that we don't
# inherit the value from whomever caused us to be built.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_AAPT_INCLUDES :=
else
# Most packages should link against the resources defined by framework-res.
# Even if they don't have their own resources, they may use framework
# resources.
ifneq ($(filter-out current system_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current,$(LOCAL_SDK_RES_VERSION))),)
# for released sdk versions, the platform resources were built into android.jar.
framework_res_package_export := \
    $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_RES_VERSION)/android.jar
framework_res_package_export_deps := $(framework_res_package_export)
else # LOCAL_SDK_RES_VERSION
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
# We can't depend directly on the export.apk file; it won't get its
# PRIVATE_ vars set up correctly if we do.  Instead, depend on the
# corresponding R.stamp file, which lists the export.apk as a dependency.
framework_res_package_export_deps := \
    $(dir $(framework_res_package_export))src/R.stamp
endif # LOCAL_SDK_RES_VERSION
all_library_res_package_exports := \
    $(framework_res_package_export) \
    $(foreach lib,$(LOCAL_RES_LIBRARIES),\
        $(call intermediates-dir-for,APPS,$(lib),,COMMON)/package-export.apk)

all_library_res_package_export_deps := \
    $(framework_res_package_export_deps) \
    $(foreach lib,$(LOCAL_RES_LIBRARIES),\
        $(call intermediates-dir-for,APPS,$(lib),,COMMON)/src/R.stamp)

$(resource_export_package) $(R_file_stamp) $(LOCAL_BUILT_MODULE): $(all_library_res_package_export_deps)
$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_AAPT_INCLUDES := $(all_library_res_package_exports)
endif # LOCAL_NO_STANDARD_LIBRARIES

ifneq ($(full_classes_jar),)
$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): $(built_dex)
endif # full_classes_jar

include $(BUILD_SYSTEM)/install_jni_libs.mk

# Pick a key to sign the package with.  If this package hasn't specified
# an explicit certificate, use the default.
# Secure release builds will have their packages signed after the fact,
# so it's ok for these private keys to be in the clear.
ifeq ($(LOCAL_CERTIFICATE),)
    LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
endif

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The special value "EXTERNAL" means that we will sign it with the
  # default devkey, apply predexopt, but then expect the final .apk
  # (after dexopting) to be signed by an outside tool.
  LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
  PACKAGES.$(LOCAL_PACKAGE_NAME).EXTERNAL_KEY := 1
endif

# If this is not an absolute certificate, assign it to a generic one.
ifeq ($(dir $(strip $(LOCAL_CERTIFICATE))),./)
    LOCAL_CERTIFICATE := $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))$(LOCAL_CERTIFICATE)
endif
private_key := $(LOCAL_CERTIFICATE).pk8
certificate := $(LOCAL_CERTIFICATE).x509.pem

$(LOCAL_BUILT_MODULE): $(private_key) $(certificate) $(SIGNAPK_JAR)
$(LOCAL_BUILT_MODULE): PRIVATE_PRIVATE_KEY := $(private_key)
$(LOCAL_BUILT_MODULE): PRIVATE_CERTIFICATE := $(certificate)

PACKAGES.$(LOCAL_PACKAGE_NAME).PRIVATE_KEY := $(private_key)
PACKAGES.$(LOCAL_PACKAGE_NAME).CERTIFICATE := $(certificate)

$(LOCAL_BUILT_MODULE): PRIVATE_ADDITIONAL_CERTIFICATES := $(foreach c,\
    $(LOCAL_ADDITIONAL_CERTIFICATES), $(c).x509.pem $(c).pk8)

# Define the rule to build the actual package.
$(LOCAL_BUILT_MODULE): $(AAPT) | $(ZIPALIGN)
# PRIVATE_JNI_SHARED_LIBRARIES is a list of <abi>:<path_of_built_lib>.
$(LOCAL_BUILT_MODULE): PRIVATE_JNI_SHARED_LIBRARIES := $(jni_shared_libraries_with_abis)
# PRIVATE_JNI_SHARED_LIBRARIES_ABI is a list of ABI names.
$(LOCAL_BUILT_MODULE): PRIVATE_JNI_SHARED_LIBRARIES_ABI := $(jni_shared_libraries_abis)
ifneq ($(TARGET_BUILD_APPS),)
    # Include all resources for unbundled apps.
    LOCAL_AAPT_INCLUDE_ALL_RESOURCES := true
endif
ifeq ($(LOCAL_AAPT_INCLUDE_ALL_RESOURCES),true)
    $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_CONFIG :=
    $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
else
    $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_CONFIG := $(PRODUCT_AAPT_CONFIG)
ifdef LOCAL_PACKAGE_SPLITS
    $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
else
    $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG := $(PRODUCT_AAPT_PREF_CONFIG)
endif
endif
$(LOCAL_BUILT_MODULE): $(all_res_assets) $(jni_shared_libraries) $(full_android_manifest)
	@echo "target Package: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-assets-to-package)
ifneq ($(jni_shared_libraries),)
	$(add-jni-shared-libs-to-package)
endif
ifneq ($(full_classes_jar),)
	$(add-dex-to-package)
endif
	$(add-carried-java-resources)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif
	$(sign-package)
ifdef LOCAL_DEX_PREOPT
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif
endif
	@# Alignment must happen after all other zip operations.
	$(align-package)

###############################
## Build dpi-specific apks, if it's apps_only build.
ifdef TARGET_BUILD_APPS
ifdef LOCAL_DPI_VARIANTS
$(foreach d, $(LOCAL_DPI_VARIANTS), \
  $(eval my_dpi := $(d)) \
  $(eval include $(BUILD_SYSTEM)/dpi_specific_apk.mk))
endif
endif

###############################
## Rule to build the odex file
ifdef LOCAL_DEX_PREOPT
$(built_odex): PRIVATE_DEX_FILE := $(built_dex)
# Use pattern rule - we may have multiple built odex files.
$(built_odex) : $(dir $(LOCAL_BUILT_MODULE))% : $(built_dex)
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(add-dex-to-package)
	$(hide) mv $@ $@.input
	$(call dexpreopt-one-file,$@.input,$@)
	$(hide) rm $@.input
endif

###############################
## APK splits
ifdef LOCAL_PACKAGE_SPLITS
# LOCAL_PACKAGE_SPLITS is a list of resource labels.
# aapt will convert comma inside resource lable to underscore in the file names.
my_split_suffixes := $(subst $(comma),_,$(LOCAL_PACKAGE_SPLITS))
built_apk_splits := $(foreach s,$(my_split_suffixes),$(built_module_path)/package_$(s).apk)
installed_apk_splits := $(foreach s,$(my_split_suffixes),$(my_module_path)/$(LOCAL_MODULE)_$(s).apk)

# The splits should have been built in the same command building the base apk.
# This rule just runs signing and zipalign etc.
# Note that we explicily check the existence of the split apk and remove the
# built base apk if the split apk isn't there.
# That way the build system will rerun the aapt after the user changes the splitting parameters.
$(built_apk_splits): PRIVATE_PRIVATE_KEY := $(private_key)
$(built_apk_splits): PRIVATE_CERTIFICATE := $(certificate)
$(built_apk_splits) : $(built_module_path)/%.apk : $(LOCAL_BUILT_MODULE)
	$(hide) if [ ! -f $@ ]; then \
	  echo 'No $@ generated, check your apk splitting parameters.' 1>&2; \
	  rm $<; exit 1; \
	fi
	$(sign-package)
	$(align-package)

# Rules to install the splits
$(installed_apk_splits) : $(my_module_path)/$(LOCAL_MODULE)_%.apk : $(built_module_path)/package_%.apk | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-new-target)

# Register the additional built and installed files.
ALL_MODULES.$(my_register_name).INSTALLED += $(installed_apk_splits)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += \
  $(foreach s,$(my_split_suffixes),$(built_module_path)/package_$(s).apk:$(my_module_path)/$(LOCAL_MODULE)_$(s).apk)

# Make sure to install the splits when you run "make <module_name>".
$(my_register_name): $(installed_apk_splits)
endif # LOCAL_PACKAGE_SPLITS

# Save information about this package
PACKAGES.$(LOCAL_PACKAGE_NAME).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))
PACKAGES.$(LOCAL_PACKAGE_NAME).RESOURCE_FILES := $(all_resources)
ifdef package_resource_overlays
PACKAGES.$(LOCAL_PACKAGE_NAME).RESOURCE_OVERLAYS := $(package_resource_overlays)
endif

PACKAGES := $(PACKAGES) $(LOCAL_PACKAGE_NAME)

# Dist the files that can be bundled in system.img.
# They include the jni shared libraries and the apk with jni libraries stripped.
ifeq ($(LOCAL_DIST_BUNDLED_BINARIES),true)
ifneq ($(filter $(LOCAL_PACKAGE_NAME),$(TARGET_BUILD_APPS)),)
ifneq ($(strip $(jni_shared_libraries)),)
dist_subdir := bundled_$(LOCAL_PACKAGE_NAME)
$(foreach f, $(jni_shared_libraries), \
  $(call dist-for-goals, apps_only, $(f):$(dist_subdir)/$(notdir $(f))))

apk_jni_stripped := $(intermediates)/jni_stripped/package.apk
$(apk_jni_stripped): PRIVATE_JNI_SHARED_LIBRARIES := $(notdir $(jni_shared_libraries))
$(apk_jni_stripped) : $(LOCAL_BUILT_MODULE) | $(ZIPALIGN)
	@rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) cp $< $@
	$(hide) zip -d $@ $(foreach f,$(PRIVATE_JNI_SHARED_LIBRARIES),\*/$(f))
	$(call align-package)

$(call dist-for-goals, apps_only, $(apk_jni_stripped):$(dist_subdir)/$(LOCAL_PACKAGE_NAME).apk)

endif  # jni_shared_libraries
endif  # apps_only build
endif  # LOCAL_DIST_BUNDLED_BINARIES

# Lint phony targets
.PHONY: lint-$(LOCAL_PACKAGE_NAME)
lint-$(LOCAL_PACKAGE_NAME): PRIVATE_PATH := $(LOCAL_PATH)
lint-$(LOCAL_PACKAGE_NAME): PRIVATE_LINT_FLAGS := $(LOCAL_LINT_FLAGS)
lint-$(LOCAL_PACKAGE_NAME) :
	@echo lint $(PRIVATE_PATH)
	$(LINT) $(PRIVATE_LINT_FLAGS) $(PRIVATE_PATH)

lintall : lint-$(LOCAL_PACKAGE_NAME)

endif # skip_definition

# Reset internal variables.
all_res_assets :=
