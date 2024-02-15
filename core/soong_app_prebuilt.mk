# App prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_BUILT_INSTALLED
# LOCAL_SOONG_BUNDLE
# LOCAL_SOONG_CLASSES_JAR
# LOCAL_SOONG_DEX_JAR
# LOCAL_SOONG_HEADER_JAR
# LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
# LOCAL_SOONG_PROGUARD_DICT
# LOCAL_SOONG_PROGUARD_USAGE_ZIP
# LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE
# LOCAL_SOONG_RRO_DIRS
# LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH)
# LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH)
# LOCAL_SOONG_JNI_LIBS_SYMBOLS
# LOCAL_SOONG_DEXPREOPT_CONFIG

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_app_prebuilt.mk may only be used from Soong)
endif

LOCAL_MODULE_SUFFIX := .apk
LOCAL_BUILT_MODULE_STEM := package.apk

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

full_classes_jar := $(intermediates.COMMON)/classes.jar
full_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar


# Use the Soong output as the checkbuild target instead of LOCAL_BUILT_MODULE
# to avoid checkbuilds making an extra copy of every module.
LOCAL_CHECKED_MODULE := $(LOCAL_PREBUILT_MODULE_FILE)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_SOONG_CLASSES_JAR)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_SOONG_HEADER_JAR)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_FULL_MANIFEST_FILE)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_SOONG_DEXPREOPT_CONFIG)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE)
LOCAL_ADDITIONAL_CHECKED_MODULE += $(LOCAL_SOONG_DEX_JAR)

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifdef LOCAL_SOONG_CLASSES_JAR
  $(eval $(call copy-one-file,$(LOCAL_SOONG_CLASSES_JAR),$(full_classes_jar)))
  $(eval $(call copy-one-file,$(LOCAL_SOONG_CLASSES_JAR),$(full_classes_pre_proguard_jar)))
  $(eval $(call add-dependency,$(LOCAL_BUILT_MODULE),$(full_classes_jar)))

  ifneq ($(TURBINE_ENABLED),false)
    ifdef LOCAL_SOONG_HEADER_JAR
      $(eval $(call copy-one-file,$(LOCAL_SOONG_HEADER_JAR),$(full_classes_header_jar)))
    else
      $(eval $(call copy-one-file,$(full_classes_jar),$(full_classes_header_jar)))
    endif
  endif # TURBINE_ENABLED != false

  javac-check : $(full_classes_jar)
  javac-check-$(LOCAL_MODULE) : $(full_classes_jar)
  .PHONY: javac-check-$(LOCAL_MODULE)
endif

ifdef LOCAL_SOONG_DEXPREOPT_CONFIG
  my_dexpreopt_config := $(PRODUCT_OUT)/dexpreopt_config/$(LOCAL_MODULE)_dexpreopt.config
  $(eval $(call copy-one-file,$(LOCAL_SOONG_DEXPREOPT_CONFIG), $(my_dexpreopt_config)))
  $(LOCAL_BUILT_MODULE): $(my_dexpreopt_config)
endif



# Run veridex on product, system_ext and vendor modules.
# We skip it for unbundled app builds where we cannot build veridex.
module_run_appcompat :=
ifeq (true,$(non_system_module))
ifeq (,$(TARGET_BUILD_APPS))  # not unbundled app build
ifeq (,$(filter sdk,$(MAKECMDGOALS))) # not sdk build (which is another form of unbundled build)
ifneq ($(UNSAFE_DISABLE_HIDDENAPI_FLAGS),true)
  module_run_appcompat := true
endif
endif
endif
endif

ifeq ($(module_run_appcompat),true)
  $(LOCAL_BUILT_MODULE): $(appcompat-files)
  $(LOCAL_BUILT_MODULE): PRIVATE_INSTALLED_MODULE := $(LOCAL_INSTALLED_MODULE)
  $(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)
	@echo "Copy: $@"
	$(copy-file-to-target)
	$(appcompat-header)
	$(run-appcompat)
else
  $(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(LOCAL_BUILT_MODULE)))
endif

ifdef LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
  $(eval $(call copy-one-file,$(LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR),\
    $(call local-packaging-dir,jacoco)/jacoco-report-classes.jar))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),\
    $(call local-packaging-dir,jacoco)/jacoco-report-classes.jar)
endif

ifdef LOCAL_SOONG_PROGUARD_DICT
  $(eval $(call copy-r8-dictionary-file-with-mapping,\
    $(LOCAL_SOONG_PROGUARD_DICT),\
    $(intermediates.COMMON)/proguard_dictionary,\
    $(intermediates.COMMON)/proguard_dictionary.textproto))

  ALL_MODULES.$(my_register_name).PROGUARD_DICTIONARY_FILES := \
    $(intermediates.COMMON)/proguard_dictionary \
    $(LOCAL_SOONG_CLASSES_JAR)
  ALL_MODULES.$(my_register_name).PROGUARD_DICTIONARY_SOONG_ZIP_ARGUMENTS := \
    -e out/target/common/obj/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates/proguard_dictionary \
    -f $(intermediates.COMMON)/proguard_dictionary \
    -e out/target/common/obj/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates/classes.jar \
    -f $(LOCAL_SOONG_CLASSES_JAR)
  ALL_MODULES.$(my_register_name).PROGUARD_DICTIONARY_MAPPING := $(intermediates.COMMON)/proguard_dictionary.textproto
endif

ifdef LOCAL_SOONG_PROGUARD_USAGE_ZIP
  ALL_MODULES.$(my_register_name).PROGUARD_USAGE_ZIP := $(LOCAL_SOONG_PROGUARD_USAGE_ZIP)
endif

ifdef LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE
resource_export_package := $(intermediates.COMMON)/package-export.apk
resource_export_stamp := $(intermediates.COMMON)/src/R.stamp

$(resource_export_package): PRIVATE_STAMP := $(resource_export_stamp)
$(resource_export_package): .KATI_IMPLICIT_OUTPUTS := $(resource_export_stamp)
$(resource_export_package): $(LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE)
	@echo "Copy: $@"
	$(copy-file-to-target)
	touch $(PRIVATE_STAMP)
$(call add-dependency,$(LOCAL_BUILT_MODULE),$(resource_export_package))

endif # LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE

java-dex: $(LOCAL_SOONG_DEX_JAR)


# Copy test suite files.
ifdef LOCAL_COMPATIBILITY_SUITE
my_apks_to_install := $(foreach f,$(filter %.apk %.idsig,$(LOCAL_SOONG_BUILT_INSTALLED)),$(call word-colon,1,$(f)))
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) := $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
    $(foreach a,$(my_apks_to_install),\
      $(call compat-copy-pair,$(a),$(dir)/$(notdir $(a)))))))
$(call create-suite-dependencies)
endif

# install symbol files of JNI libraries
my_jni_lib_symbols_copy_files := $(foreach f,$(LOCAL_SOONG_JNI_LIBS_SYMBOLS),\
  $(call word-colon,1,$(f)):$(patsubst $(PRODUCT_OUT)/%,$(TARGET_OUT_UNSTRIPPED)/%,$(call word-colon,2,$(f))))
$(LOCAL_BUILT_MODULE): | $(call copy-many-files, $(my_jni_lib_symbols_copy_files))

# embedded JNI will already have been handled by soong
my_embed_jni :=
my_prebuilt_jni_libs :=
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  ifdef LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH)
    my_2nd_arch_prefix :=
    LOCAL_JNI_SHARED_LIBRARIES := $(LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH))
    partition_lib_pairs :=  $(LOCAL_SOONG_JNI_LIBS_PARTITION_$(TARGET_ARCH))
    include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
  endif
  ifdef TARGET_2ND_ARCH
    ifdef LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH)
      my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
      LOCAL_JNI_SHARED_LIBRARIES := $(LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH))
      partition_lib_pairs :=  $(LOCAL_SOONG_JNI_LIBS_PARTITION_$(TARGET_2ND_ARCH))
      include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
    endif
  endif
endif
LOCAL_SHARED_JNI_LIBRARIES :=
my_embed_jni :=
my_prebuilt_jni_libs :=
my_2nd_arch_prefix :=
partition_lib_pairs :=

PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
ifndef LOCAL_CERTIFICATE
  $(call pretty-error,LOCAL_CERTIFICATE must be set for soong_app_prebuilt.mk)
endif
ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
  # The magic string "PRESIGNED" means this package is already checked
  # signed with its release key.
  #
  # By setting .CERTIFICATE but not .PRIVATE_KEY, this package will be
  # mentioned in apkcerts.txt (with certificate set to "PRESIGNED")
  # but the dexpreopt process will not try to re-sign the app.
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := PRESIGNED
else ifneq ($(LOCAL_CERTIFICATE),)
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE)
  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(patsubst %.x509.pem,%.pk8,$(LOCAL_CERTIFICATE))
endif
include $(BUILD_SYSTEM)/app_certificate_validate.mk
PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

ifneq ($(LOCAL_MODULE_STEM),)
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE_STEM)
else
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE)
endif

# Set a actual_partition_tag (calculated in base_rules.mk) for the package.
PACKAGES.$(LOCAL_MODULE).PARTITION := $(actual_partition_tag)

ifdef LOCAL_SOONG_BUNDLE
  ALL_MODULES.$(my_register_name).BUNDLE := $(LOCAL_SOONG_BUNDLE)
endif

ifdef LOCAL_SOONG_LINT_REPORTS
  ALL_MODULES.$(my_register_name).LINT_REPORTS := $(LOCAL_SOONG_LINT_REPORTS)
endif

ifndef LOCAL_IS_HOST_MODULE
ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
else
my_link_type := java:platform
endif
# warn/allowed types are both empty because Soong modules can't depend on
# make-defined modules.
my_warn_types :=
my_allowed_types :=

my_link_deps :=
my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk
endif # !LOCAL_IS_HOST_MODULE

ifeq (,$(filter tests,$(LOCAL_MODULE_TAGS)))
  ifdef LOCAL_SOONG_DEVICE_RRO_DIRS
    $(call append_enforce_rro_sources, \
        $(my_register_name), \
        false, \
        $(LOCAL_FULL_MANIFEST_FILE), \
        $(if $(LOCAL_EXPORT_PACKAGE_RESOURCES),true,false), \
        $(LOCAL_SOONG_DEVICE_RRO_DIRS), \
        vendor \
    )
  endif

  ifdef LOCAL_SOONG_PRODUCT_RRO_DIRS
    $(call append_enforce_rro_sources, \
        $(my_register_name), \
        false, \
        $(LOCAL_FULL_MANIFEST_FILE), \
        $(if $(LOCAL_EXPORT_PACKAGE_RESOURCES),true,false), \
        $(LOCAL_SOONG_PRODUCT_RRO_DIRS), \
        product \
    )
  endif
endif

ifdef LOCAL_PREBUILT_COVERAGE_ARCHIVE
  my_coverage_dir := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
  my_coverage_copy_pairs := $(foreach f,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(f):$(my_coverage_dir)/$(notdir  $(f)))
  my_coverage_files := $(call copy-many-files,$(my_coverage_copy_pairs))
  $(LOCAL_INSTALLED_MODULE): $(my_coverage_files)
endif

SOONG_ALREADY_CONV += $(LOCAL_MODULE)

###########################################################
## SBOM generation
###########################################################
include $(BUILD_SBOM_GEN)
