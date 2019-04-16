# App prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_BUILT_INSTALLED
# LOCAL_SOONG_BUNDLE
# LOCAL_SOONG_CLASSES_JAR
# LOCAL_SOONG_DEX_JAR
# LOCAL_SOONG_HEADER_JAR
# LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
# LOCAL_SOONG_PROGUARD_DICT
# LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE
# LOCAL_SOONG_RRO_DIRS
# LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH)
# LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH)

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_app_prebuilt.mk may only be used from Soong)
endif

LOCAL_MODULE_SUFFIX := .apk
LOCAL_BUILT_MODULE_STEM := package.apk

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

full_classes_jar := $(intermediates.COMMON)/classes.jar
full_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar

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
endif

# Run veridex on product, product_services and vendor modules.
# We skip it for unbundled app builds where we cannot build veridex.
module_run_appcompat :=
ifeq (true,$(non_system_module))
ifeq (,$(TARGET_BUILD_APPS)$(filter true,$(TARGET_BUILD_PDK)))  # ! unbundled app build
ifneq ($(UNSAFE_DISABLE_HIDDENAPI_FLAGS),true)
  module_run_appcompat := true
endif
endif
endif

ifeq ($(module_run_appcompat),true)
  $(LOCAL_BUILT_MODULE): $(appcompat-files)
  $(LOCAL_BUILT_MODULE): PRIVATE_INSTALLED_MODULE := $(LOCAL_INSTALLED_MODULE)
  $(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)
	@echo "Copy: $@"
	$(copy-file-to-target)
	$(call appcompat-header, aapt2)
	$(run-appcompat)
else
  $(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(LOCAL_BUILT_MODULE)))
endif

ifdef LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
  $(eval $(call copy-one-file,$(LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR),\
    $(intermediates.COMMON)/jacoco-report-classes.jar))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),\
    $(intermediates.COMMON)/jacoco-report-classes.jar)
endif

ifdef LOCAL_SOONG_PROGUARD_DICT
  $(eval $(call copy-one-file,$(LOCAL_SOONG_PROGUARD_DICT),\
    $(intermediates.COMMON)/proguard_dictionary))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),\
    $(intermediates.COMMON)/proguard_dictionary)
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


ifneq ($(BUILD_PLATFORM_ZIP),)
  $(eval $(call copy-one-file,$(LOCAL_SOONG_DEX_JAR),$(dir $(LOCAL_BUILT_MODULE))package.dex.apk))
endif

my_built_installed := $(foreach f,$(LOCAL_SOONG_BUILT_INSTALLED),\
  $(call word-colon,1,$(f)):$(PRODUCT_OUT)$(call word-colon,2,$(f)))
my_installed := $(call copy-many-files, $(my_built_installed))
ALL_MODULES.$(my_register_name).INSTALLED += $(my_installed)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(my_built_installed)
$(my_all_targets): $(my_installed)

# embedded JNI will already have been handled by soong
my_embed_jni :=
my_prebuilt_jni_libs :=
ifdef LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH)
  my_2nd_arch_prefix :=
  LOCAL_JNI_SHARED_LIBRARIES := $(LOCAL_SOONG_JNI_LIBS_$(TARGET_ARCH))
  include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
endif
ifdef TARGET_2ND_ARCH
  ifdef LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH)
    my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
    LOCAL_JNI_SHARED_LIBRARIES := $(LOCAL_SOONG_JNI_LIBS_$(TARGET_2ND_ARCH))
    include $(BUILD_SYSTEM)/install_jni_libs_internal.mk
  endif
endif
LOCAL_SHARED_JNI_LIBRARIES :=
my_embed_jni :=
my_prebuilt_jni_libs :=
my_2nd_arch_prefix :=

PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
ifdef LOCAL_CERTIFICATE
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE)
  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(patsubst %.x509.pem,%.pk8,$(LOCAL_CERTIFICATE))
endif
include $(BUILD_SYSTEM)/app_certificate_validate.mk
PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

ifdef LOCAL_SOONG_BUNDLE
  ALL_MODULES.$(LOCAL_MODULE).BUNDLE := $(LOCAL_SOONG_BUNDLE)
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

SOONG_ALREADY_CONV := $(SOONG_ALREADY_CONV) $(LOCAL_MODULE)
