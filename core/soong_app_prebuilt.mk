# App prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_app_prebuilt.mk may only be used from Soong)
endif

LOCAL_MODULE_SUFFIX := .apk
LOCAL_BUILT_MODULE_STEM := package.apk

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifdef LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
  $(eval $(call copy-one-file,$(LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR),\
    $(intermediates.COMMON)/jacoco-report-classes.jar))
endif

$(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(LOCAL_BUILT_MODULE)))

ifdef LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE
resource_export_package := $(intermediates.COMMON)/package-export.apk
resource_export_stamp := $(intermediates.COMMON)/src/R.stamp

$(resource_export_package): PRIVATE_STAMP := $(resource_export_stamp)
$(resource_export_package): .KATI_IMPLICIT_OUTPUTS := $(resource_export_stamp)
$(resource_export_package): $(LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE)
	@echo "Copy: $$@"
	$(copy-file-to-target)
	touch $(PRIVATE_STAMP)

endif # LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE

java-dex: $(LOCAL_SOONG_DEX_JAR)

ifdef LOCAL_DEX_PREOPT
# defines built_odex along with rule to install odex
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk

$(built_odex): $(LOCAL_SOONG_DEX_JAR)
	$(call dexpreopt-one-file,$<,$@)
endif

ifndef LOCAL_IS_HOST_MODULE
ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
my_warn_types := java:platform
my_allowed_types := java:sdk java:system
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
my_warn_types := java:system java:platform
my_allowed_types := java:sdk
else
my_link_type := java:platform
my_warn_types :=
my_allowed_types := java:sdk java:system java:platform
endif

my_link_deps :=
my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk
endif # !LOCAL_IS_HOST_MODULE

# Built in equivalent to include $(CLEAR_VARS)
LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE :=
