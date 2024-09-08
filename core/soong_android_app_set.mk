# App prebuilt coming from Soong.
# Extra inputs:
# LOCAL_APK_SET_INSTALL_FILE

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_apk_set.mk may only be used from Soong)
endif

LOCAL_BUILT_MODULE_STEM := package.apk
LOCAL_INSTALLED_MODULE_STEM := $(notdir $(LOCAL_PREBUILT_MODULE_FILE))

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

$(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(LOCAL_BUILT_MODULE)))

PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
# We can't know exactly what apk files would be outputted yet.
# Let extract_apks generate apkcerts.txt and merge it later.
PACKAGES.$(LOCAL_MODULE).APKCERTS_FILE := $(LOCAL_APKCERTS_FILE)

SOONG_ALREADY_CONV += $(LOCAL_MODULE)
