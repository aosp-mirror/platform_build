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

intermediates := $(call local-intermediates-dir)
intermediates.COMMON := $(call local-intermediates-dir,COMMON)

# Package LOCAL_MODULE_TAGS default to optional
LOCAL_MODULE_TAGS := $(strip $(LOCAL_MODULE_TAGS))
ifeq ($(LOCAL_MODULE_TAGS),)
LOCAL_MODULE_TAGS := optional
endif

ifeq ($(filter tests, $(LOCAL_MODULE_TAGS)),)
# Force localization check if it's not tagged as tests.
LOCAL_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) -z
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
  LOCAL_RESOURCE_DIR := $(foreach d,$(LOCAL_RESOURCE_DIR),$(call clean-path,$(d)))
endif

package_resource_overlays := $(strip \
    $(wildcard $(foreach dir, $(PRODUCT_PACKAGE_OVERLAYS), \
      $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))) \
    $(wildcard $(foreach dir, $(DEVICE_PACKAGE_OVERLAYS), \
      $(addprefix $(dir)/, $(LOCAL_RESOURCE_DIR)))))

enforce_rro_enabled :=
ifneq ($(PRODUCT_ENFORCE_RRO_TARGETS),)
  ifneq ($(package_resource_overlays),)
    ifeq ($(PRODUCT_ENFORCE_RRO_TARGETS),*)
      enforce_rro_enabled := true
    else ifneq (,$(filter $(LOCAL_PACKAGE_NAME), $(PRODUCT_ENFORCE_RRO_TARGETS)))
      enforce_rro_enabled := true
    endif
  endif

  ifdef enforce_rro_enabled
    ifeq (,$(LOCAL_MODULE_PATH))
      ifeq (true,$(LOCAL_PROPRIETARY_MODULE))
        enforce_rro_enabled :=
      else ifeq (true,$(LOCAL_OEM_MODULE))
        enforce_rro_enabled :=
      else ifeq (true,$(LOCAL_ODM_MODULE))
        enforce_rro_enabled :=
      else ifeq (true,$(LOCAL_PRODUCT_MODULE))
        enforce_rro_enabled :=
      endif
    else ifeq ($(filter $(TARGET_OUT)/%,$(LOCAL_MODULE_PATH)),)
      enforce_rro_enabled :=
    endif
  endif
endif

ifdef enforce_rro_enabled
  ifneq ($(PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS),)
    static_only_resource_overlays := $(filter $(addsuffix %,$(PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS)),$(package_resource_overlays))
    ifneq ($(static_only_resource_overlays),)
      package_resource_overlays := $(filter-out $(static_only_resource_overlays),$(package_resource_overlays))
      LOCAL_RESOURCE_DIR := $(static_only_resource_overlays) $(LOCAL_RESOURCE_DIR)
      ifeq ($(package_resource_overlays),)
        enforce_rro_enabled :=
      endif
    endif
  endif
else
LOCAL_RESOURCE_DIR := $(package_resource_overlays) $(LOCAL_RESOURCE_DIR)
endif

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

ifdef LOCAL_AAPT2_ONLY
LOCAL_USE_AAPT2 := true
endif

my_res_package :=
ifdef LOCAL_USE_AAPT2
# In aapt2 the last takes precedence.
my_resource_dirs := $(call reverse-list,$(LOCAL_RESOURCE_DIR))
my_res_dir :=
my_overlay_res_dirs :=

ifneq ($(LOCAL_STATIC_ANDROID_LIBRARIES),)
# If we are using static android libraries, every source file becomes an overlay.
# This is to emulate old AAPT behavior which simulated library support.
my_res_dir :=
my_overlay_res_dirs := $(my_resource_dirs)
else
# Without static libraries, the first directory is our directory, which can then be
# overlaid by the rest. (First directory in my_resource_dirs is last directory in
# $(LOCAL_RESOURCE_DIR) due to it being reversed.
my_res_dir := $(firstword $(my_resource_dirs))
my_overlay_res_dirs := $(wordlist 2,999,$(my_resource_dirs))
endif

my_overlay_resources := $(strip \
  $(foreach d,$(my_overlay_res_dirs),\
    $(addprefix $(d)/, \
        $(call find-subdir-assets,$(d)))))

my_res_resources := $(if $(my_res_dir),$(strip \
    $(addprefix $(my_res_dir)/, \
        $(call find-subdir-assets,$(my_res_dir)))))

all_resources := $(strip $(my_res_resources) $(my_overlay_resources))

# The linked resource package.
my_res_package := $(intermediates)/package-res.apk
LOCAL_INTERMEDIATE_TARGETS += $(my_res_package)

# Always run aapt2, because we need to at least compile the AndroidManifest.xml.
need_compile_res := true

else  # LOCAL_USE_AAPT2
all_resources := $(strip \
    $(foreach dir, $(LOCAL_RESOURCE_DIR), \
      $(addprefix $(dir)/, \
        $(patsubst res/%,%, \
          $(call find-subdir-assets,$(dir)) \
         ) \
       ) \
     ))

ifdef LOCAL_PACKAGE_SPLITS
LOCAL_AAPT_FLAGS += $(addprefix --split ,$(LOCAL_PACKAGE_SPLITS))
endif

endif  # LOCAL_USE_AAPT2

ifneq ($(all_resources),)
  need_compile_res := true
endif

all_res_assets := $(strip $(all_assets) $(all_resources))

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

ifdef LOCAL_COMPRESSED_MODULE
ifneq (true,$(LOCAL_COMPRESSED_MODULE))
$(call pretty-error, Unknown value for LOCAL_COMPRESSED_MODULE $(LOCAL_COMPRESSED_MODULE))
endif
endif

ifdef LOCAL_COMPRESSED_MODULE
PACKAGES.$(LOCAL_PACKAGE_NAME).COMPRESSED := gz
LOCAL_BUILT_MODULE_STEM := package.apk.gz
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk.gz
else  # !LOCAL_COMPRESSED_MODULE
LOCAL_BUILT_MODULE_STEM := package.apk
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk
endif

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
# No jacoco for test apks.
ifeq (,$(LOCAL_INSTRUMENTATION_FOR))
LOCAL_EMMA_INSTRUMENT := true
endif # No test apk
endif # LOCAL_EMMA_INSTRUMENT is not set
else
LOCAL_EMMA_INSTRUMENT := false
endif # EMMA_INSTRUMENT is true

ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
ifneq ($(LOCAL_SRC_FILES)$(LOCAL_SRCJARS)$(LOCAL_STATIC_JAVA_LIBRARIES)$(LOCAL_SOURCE_FILES_ALL_GENERATED),)
# Only add jacocoagent if the package contains some java code
LOCAL_STATIC_JAVA_LIBRARIES += jacocoagent
# Exclude jacoco classes from proguard
LOCAL_PROGUARD_FLAGS += -include $(BUILD_SYSTEM)/proguard.jacoco.flags
endif # Contains java code
else
ifdef LOCAL_SDK_VERSION
ifdef TARGET_BUILD_APPS
# In unbundled build, merge the coverage library into the apk.
ifneq ($(LOCAL_SRC_FILES)$(LOCAL_STATIC_JAVA_LIBRARIES)$(LOCAL_SOURCE_FILES_ALL_GENERATED),)
# Only add jacocoagent if the package contains some java code
LOCAL_STATIC_JAVA_LIBRARIES += jacocoagent
# Exclude jacoco classes from proguard
LOCAL_PROGUARD_FLAGS += -include $(BUILD_SYSTEM)/proguard.jacoco.flags
endif # Contains java code
endif # TARGET_BUILD_APPS
endif # LOCAL_SDK_VERSION
endif # EMMA_INSTRUMENT_STATIC
endif # LOCAL_EMMA_INSTRUMENT

rs_compatibility_jni_libs :=

ifeq ($(LOCAL_DATA_BINDING),true)
data_binding_intermediates := $(intermediates.COMMON)/data-binding

LOCAL_JAVACFLAGS += -processorpath $(DATA_BINDING_COMPILER) -s $(data_binding_intermediates)/anno-src

LOCAL_STATIC_JAVA_LIBRARIES += databinding-baselibrary
LOCAL_STATIC_JAVA_AAR_LIBRARIES += databinding-library databinding-adapters

data_binding_res_in := $(LOCAL_RESOURCE_DIR)
data_binding_res_out := $(data_binding_intermediates)/res

# Replace with the processed merged res dir.
LOCAL_RESOURCE_DIR := $(data_binding_res_out)

LOCAL_AAPT_FLAGS += --auto-add-overlay --extra-packages com.android.databinding.library
endif  # LOCAL_DATA_BINDING

# Process Support Library dependencies.
include $(BUILD_SYSTEM)/support_libraries.mk

# If the module is a compressed module, we don't pre-opt it because its final
# installation location will be the data partition.
ifdef LOCAL_COMPRESSED_MODULE
LOCAL_DEX_PREOPT := false
endif

include $(BUILD_SYSTEM)/android_manifest.mk

resource_export_package :=

include $(BUILD_SYSTEM)/java_renderscript.mk

include $(BUILD_SYSTEM)/aapt_flags.mk

ifeq ($(need_compile_res),true)

###############################
## APK splits
built_apk_splits :=
installed_apk_splits :=
my_apk_split_configs :=

ifdef LOCAL_PACKAGE_SPLITS
ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE): LOCAL_COMPRESSED_MODULE is not currently supported for split installs)
endif  # LOCAL_COMPRESSED_MODULE

my_apk_split_configs := $(LOCAL_PACKAGE_SPLITS)
my_split_suffixes := $(subst $(comma),_,$(my_apk_split_configs))
built_apk_splits := $(foreach s,$(my_split_suffixes),$(intermediates)/package_$(s).apk)
endif

$(R_file_stamp) $(my_res_package): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS)
$(R_file_stamp) $(my_res_package): PRIVATE_TARGET_AAPT_CHARACTERISTICS := $(TARGET_AAPT_CHARACTERISTICS)
$(R_file_stamp) $(my_res_package): PRIVATE_MANIFEST_PACKAGE_NAME := $(LOCAL_MANIFEST_PACKAGE_NAME)
$(R_file_stamp) $(my_res_package): PRIVATE_MANIFEST_INSTRUMENTATION_FOR := $(LOCAL_MANIFEST_INSTRUMENTATION_FOR)

###############################
## AAPT/AAPT2

ifdef LOCAL_USE_AAPT2
  my_compiled_res_base_dir := $(intermediates.COMMON)/flat-res
  ifneq (,$(renderscript_target_api))
    ifneq ($(call math_gt_or_eq,$(renderscript_target_api),21),true)
      my_generated_res_zips := $(rs_generated_res_zip)
    endif  # renderscript_target_api < 21
  endif  # renderscript_target_api is set
  my_asset_dirs := $(LOCAL_ASSET_DIR)
  my_full_asset_paths := $(all_assets)

  # Add AAPT2 link specific flags.
  $(my_res_package): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS)
  ifndef LOCAL_AAPT_NAMESPACES
    $(my_res_package): PRIVATE_AAPT_FLAGS += --no-static-lib-packages
  endif

  include $(BUILD_SYSTEM)/aapt2.mk
else  # LOCAL_USE_AAPT2

  my_srcjar := $(intermediates.COMMON)/aapt.srcjar
  LOCAL_SRCJARS += $(my_srcjar)
  $(R_file_stamp): PRIVATE_SRCJAR := $(my_srcjar)
  $(R_file_stamp): PRIVATE_JAVA_GEN_DIR := $(intermediates.COMMON)/aapt
  $(R_file_stamp): .KATI_IMPLICIT_OUTPUTS := $(my_srcjar)
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
  $(R_file_stamp): PRIVATE_RESOURCE_LIST := $(all_res_assets)
  $(R_file_stamp): $(all_res_assets) $(full_android_manifest) $(rs_generated_res_zip) $(AAPT) $(SOONG_ZIP) | $(ACP)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	@rm -rf $@ && mkdir -p $(dir $@)
	$(create-resource-java-files)
	$(call find-generated-R.java,$(PRIVATE_JAVA_GEN_DIR),$@)

  $(proguard_options_file): $(R_file_stamp)

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
    $(resource_export_package): PRIVATE_RESOURCE_LIST := $(all_res_assets)
    $(resource_export_package): $(all_res_assets) $(full_android_manifest) $(rs_generated_res_zip) $(AAPT)
	@echo "target Export Resources: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-assets-to-package)
  endif

endif  # LOCAL_USE_AAPT2

endif  # need_compile_res

called_from_package_internal := true
#################################
include $(BUILD_SYSTEM)/java.mk
#################################
called_from_package_internal :=

ifeq ($(need_compile_res),true)

# Other modules should depend on the BUILT module if
# they want to use this module's R.java file.
$(LOCAL_BUILT_MODULE): $(R_file_stamp)

# The R.java file must exist by the time the java source
# list is generated
$(java_source_list_file): $(R_file_stamp)

endif # need_compile_res

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)

ifeq ($(LOCAL_DATA_BINDING),true)
data_binding_stamp := $(data_binding_intermediates)/data-binding.stamp
$(data_binding_stamp): PRIVATE_INTERMEDIATES := $(data_binding_intermediates)
$(data_binding_stamp): PRIVATE_MANIFEST := $(full_android_manifest)
# Generate code into $(LOCAL_INTERMEDIATE_SOURCE_DIR) so that the generated .java files
# will be automatically picked up by function compile-java.
$(data_binding_stamp): PRIVATE_SRC_OUT := $(LOCAL_INTERMEDIATE_SOURCE_DIR)/data-binding
$(data_binding_stamp): PRIVATE_XML_OUT := $(data_binding_intermediates)/xml
$(data_binding_stamp): PRIVATE_RES_OUT := $(data_binding_res_out)
$(data_binding_stamp): PRIVATE_RES_IN := $(data_binding_res_in)
$(data_binding_stamp): PRIVATE_ANNO_SRC_DIR := $(data_binding_intermediates)/anno-src

$(data_binding_stamp) : $(all_res_assets) $(full_android_manifest) \
    $(DATA_BINDING_COMPILER)
	@echo "Data-binding process: $@"
	@rm -rf $(PRIVATE_INTERMEDIATES) $(PRIVATE_SRC_OUT) && \
	  mkdir -p $(PRIVATE_INTERMEDIATES) $(PRIVATE_SRC_OUT) \
	      $(PRIVATE_XML_OUT) $(PRIVATE_RES_OUT) $(PRIVATE_ANNO_SRC_DIR)
	$(hide) $(JAVA) -classpath $(DATA_BINDING_COMPILER) android.databinding.tool.MakeCopy \
	  $(PRIVATE_MANIFEST) $(PRIVATE_SRC_OUT) $(PRIVATE_XML_OUT) $(PRIVATE_RES_OUT) $(PRIVATE_RES_IN)
	$(hide) touch $@

# Make sure the data-binding process happens before javac and generation of R.java.
$(R_file_stamp): $(data_binding_stamp)
$(java_source_list_file): $(data_binding_stamp)
$(full_classes_compiled_jar): $(data_binding_stamp)
endif  # LOCAL_DATA_BINDING

framework_res_package_export :=

ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
# Most packages should link against the resources defined by framework-res.
# Even if they don't have their own resources, they may use framework
# resources.
ifeq ($(LOCAL_SDK_RES_VERSION),core_current)
# core_current doesn't contain any framework resources.
else ifneq ($(filter-out current system_current test_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current test_current,$(LOCAL_SDK_RES_VERSION))),)
# for released sdk versions, the platform resources were built into android.jar.
framework_res_package_export := \
    $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_RES_VERSION)/android.jar
else # LOCAL_SDK_RES_VERSION
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
endif # LOCAL_SDK_RES_VERSION
endif # LOCAL_NO_STANDARD_LIBRARIES

all_library_res_package_exports := \
    $(framework_res_package_export) \
    $(foreach lib,$(LOCAL_RES_LIBRARIES),\
        $(call intermediates-dir-for,APPS,$(lib),,COMMON)/package-export.apk)

all_library_res_package_export_deps := \
    $(framework_res_package_export) \
    $(foreach lib,$(LOCAL_RES_LIBRARIES),\
        $(call intermediates-dir-for,APPS,$(lib),,COMMON)/src/R.stamp)
$(resource_export_package) $(R_file_stamp) $(LOCAL_BUILT_MODULE): $(all_library_res_package_export_deps)
$(LOCAL_INTERMEDIATE_TARGETS): \
    PRIVATE_AAPT_INCLUDES := $(all_library_res_package_exports)

ifdef LOCAL_USE_AAPT2
$(my_res_package) : $(all_library_res_package_export_deps)
endif

# These four are set above for $(R_stamp_file) and $(my_res_package), but
# $(LOCAL_BUILT_MODULE) is not set before java.mk, so they have to be set again
# here.
$(LOCAL_BUILT_MODULE): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_AAPT_CHARACTERISTICS := $(TARGET_AAPT_CHARACTERISTICS)
$(LOCAL_BUILT_MODULE): PRIVATE_MANIFEST_PACKAGE_NAME := $(LOCAL_MANIFEST_PACKAGE_NAME)
$(LOCAL_BUILT_MODULE): PRIVATE_MANIFEST_INSTRUMENTATION_FOR := $(LOCAL_MANIFEST_INSTRUMENTATION_FOR)

ifneq ($(full_classes_jar),)
$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
# Use the jarjar processed arhive as the initial package file.
$(LOCAL_BUILT_MODULE): PRIVATE_SOURCE_ARCHIVE := $(full_classes_pre_proguard_jar)
$(LOCAL_BUILT_MODULE): $(built_dex)
else
$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE :=
$(LOCAL_BUILT_MODULE): PRIVATE_SOURCE_ARCHIVE :=
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
additional_certificates := $(foreach c,$(LOCAL_ADDITIONAL_CERTIFICATES), $(c).x509.pem $(c).pk8)

$(LOCAL_BUILT_MODULE): $(private_key) $(certificate) $(SIGNAPK_JAR)
$(LOCAL_BUILT_MODULE): PRIVATE_PRIVATE_KEY := $(private_key)
$(LOCAL_BUILT_MODULE): PRIVATE_CERTIFICATE := $(certificate)

PACKAGES.$(LOCAL_PACKAGE_NAME).PRIVATE_KEY := $(private_key)
PACKAGES.$(LOCAL_PACKAGE_NAME).CERTIFICATE := $(certificate)

$(LOCAL_BUILT_MODULE): $(additional_certificates)
$(LOCAL_BUILT_MODULE): PRIVATE_ADDITIONAL_CERTIFICATES := $(additional_certificates)

# Define the rule to build the actual package.
# PRIVATE_JNI_SHARED_LIBRARIES is a list of <abi>:<path_of_built_lib>.
$(LOCAL_BUILT_MODULE): PRIVATE_JNI_SHARED_LIBRARIES := $(jni_shared_libraries_with_abis)
# PRIVATE_JNI_SHARED_LIBRARIES_ABI is a list of ABI names.
$(LOCAL_BUILT_MODULE): PRIVATE_JNI_SHARED_LIBRARIES_ABI := $(jni_shared_libraries_abis)
ifneq ($(TARGET_BUILD_APPS),)
    # Include all resources for unbundled apps.
    LOCAL_AAPT_INCLUDE_ALL_RESOURCES := true
endif
ifeq ($(LOCAL_AAPT_INCLUDE_ALL_RESOURCES),true)
    $(my_res_package) $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_CONFIG :=
    $(my_res_package) $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
else
    $(my_res_package) $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_CONFIG := $(PRODUCT_AAPT_CONFIG)
ifdef LOCAL_PACKAGE_SPLITS
    $(my_res_package) $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
else
    $(my_res_package) $(LOCAL_BUILT_MODULE): PRIVATE_PRODUCT_AAPT_PREF_CONFIG := $(PRODUCT_AAPT_PREF_CONFIG)
endif
endif

$(LOCAL_BUILT_MODULE): PRIVATE_DONT_DELETE_JAR_DIRS := $(LOCAL_DONT_DELETE_JAR_DIRS)
$(LOCAL_BUILT_MODULE): PRIVATE_RESOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/resources
$(LOCAL_BUILT_MODULE): PRIVATE_FULL_CLASSES_JAR := $(full_classes_jar)
$(LOCAL_BUILT_MODULE) : $(jni_shared_libraries)
$(LOCAL_BUILT_MODULE) : $(JAR_ARGS)
ifdef LOCAL_USE_AAPT2
$(LOCAL_BUILT_MODULE): PRIVATE_RES_PACKAGE := $(my_res_package)
$(LOCAL_BUILT_MODULE) : $(my_res_package) $(AAPT2) | $(ACP)
else
$(LOCAL_BUILT_MODULE): PRIVATE_RESOURCE_LIST := $(all_res_assets)
$(LOCAL_BUILT_MODULE) : $(all_res_assets) $(full_android_manifest) $(AAPT) $(ZIPALIGN)
endif  # LOCAL_USE_AAPT2
ifdef LOCAL_COMPRESSED_MODULE
$(LOCAL_BUILT_MODULE) : $(MINIGZIP)
endif
	@echo "target Package: $(PRIVATE_MODULE) ($@)"
ifdef LOCAL_USE_AAPT2
	$(call copy-file-to-new-target)
else  # ! LOCAL_USE_AAPT2
	$(if $(PRIVATE_SOURCE_ARCHIVE),\
	  $(call initialize-package-file,$(PRIVATE_SOURCE_ARCHIVE),$@),\
	  $(create-empty-package))
	$(add-assets-to-package)
endif  # LOCAL_USE_AAPT2
ifneq ($(jni_shared_libraries),)
	$(add-jni-shared-libs-to-package)
endif
ifeq ($(full_classes_jar),)
# We don't build jar, need to add the Java resources here.
	$(if $(PRIVATE_EXTRA_JAR_ARGS),$(call add-java-resources-to,$@))
else  # full_classes_jar
	$(add-dex-to-package)
ifdef LOCAL_USE_AAPT2
	$(call add-jar-resources-to-package,$@,$(PRIVATE_FULL_CLASSES_JAR),$(PRIVATE_RESOURCE_INTERMEDIATES_DIR))
endif
endif  # full_classes_jar
ifeq (true, $(LOCAL_UNCOMPRESS_DEX))
	@# No need to align, sign-package below will do it.
	$(uncompress-dexs)
endif
ifdef LOCAL_DEX_PREOPT
ifneq ($(BUILD_PLATFORM_ZIP),)
	@# Keep a copy of apk with classes.dex unstripped
	$(hide) cp -f $@ $(dir $@)package.dex.apk
endif  # BUILD_PLATFORM_ZIP
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif
endif  # LOCAL_DEX_PREOPT
	$(sign-package)
ifdef LOCAL_COMPRESSED_MODULE
	$(compress-package)
endif  # LOCAL_COMPRESSED_MODULE

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
ifeq (true, $(LOCAL_UNCOMPRESS_DEX))
	$(uncompress-dexs)
	$(align-package)
endif
	$(hide) mv $@ $@.input
	$(call dexpreopt-one-file,$@.input,$@)
	$(hide) rm $@.input
endif

###############################
## APK splits
ifdef LOCAL_PACKAGE_SPLITS
# The splits should have been built in the same command building the base apk.
# This rule just runs signing.
# Note that we explicily check the existence of the split apk and remove the
# built base apk if the split apk isn't there.
# That way the build system will rerun the aapt after the user changes the splitting parameters.
$(built_apk_splits): PRIVATE_PRIVATE_KEY := $(private_key)
$(built_apk_splits): PRIVATE_CERTIFICATE := $(certificate)
$(built_apk_splits) : $(intermediates)/%.apk : $(LOCAL_BUILT_MODULE)
	$(hide) if [ ! -f $@ ]; then \
	  echo 'No $@ generated, check your apk splitting parameters.' 1>&2; \
	  rm $<; exit 1; \
	fi
	$(sign-package)

# Rules to install the splits
installed_apk_splits := $(foreach s,$(my_split_suffixes),$(my_module_path)/$(LOCAL_MODULE)_$(s).apk)
$(installed_apk_splits) : $(my_module_path)/$(LOCAL_MODULE)_%.apk : $(intermediates)/package_%.apk
	@echo "Install: $@"
	$(copy-file-to-new-target)

# Register the additional built and installed files.
ALL_MODULES.$(my_register_name).INSTALLED += $(installed_apk_splits)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += \
  $(foreach s,$(my_split_suffixes),$(intermediates)/package_$(s).apk:$(my_module_path)/$(LOCAL_MODULE)_$(s).apk)

# Make sure to install the splits when you run "make <module_name>".
$(my_all_targets): $(installed_apk_splits)

ifdef LOCAL_COMPATIBILITY_SUITE

$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) := $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
    $(foreach s,$(my_split_suffixes),\
      $(intermediates)/package_$(s).apk:$(dir)/$(LOCAL_MODULE)_$(s).apk))))

$(call create-suite-dependencies)

endif # LOCAL_COMPATIBILITY_SUITE
endif # LOCAL_PACKAGE_SPLITS

# Save information about this package
PACKAGES.$(LOCAL_PACKAGE_NAME).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))
PACKAGES.$(LOCAL_PACKAGE_NAME).RESOURCE_FILES := $(all_resources)

PACKAGES := $(PACKAGES) $(LOCAL_PACKAGE_NAME)

endif # skip_definition

# Reset internal variables.
all_res_assets :=

ifdef enforce_rro_enabled
  ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
    enforce_rro_use_res_lib := true
  else
    enforce_rro_use_res_lib := false
  endif

  ifdef LOCAL_MANIFEST_PACKAGE_NAME
    enforce_rro_is_manifest_package_name := true
    enforce_rro_manifest_package_info := $(LOCAL_MANIFEST_PACKAGE_NAME)
  else
    enforce_rro_is_manifest_package_name := false
    enforce_rro_manifest_package_info := $(full_android_manifest)
  endif

$(call append_enforce_rro_sources, \
    $(my_register_name), \
    $(enforce_rro_is_manifest_package_name), \
    $(enforce_rro_manifest_package_info), \
    $(enforce_rro_use_res_lib), \
    $(package_resource_overlays) \
    )
endif  # enforce_rro_enabled
