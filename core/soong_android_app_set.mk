# App prebuilt coming from Soong.
# Extra inputs:
# LOCAL_APK_SET_MASTER_FILE

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_apk_set.mk may only be used from Soong)
endif

LOCAL_BUILT_MODULE_STEM := $(LOCAL_APK_SET_MASTER_FILE)
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_APK_SET_MASTER_FILE)

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

## Extract master APK from APK set into given directory
# $(1) APK set
# $(2) master APK entry (e.g., splits/base-master.apk

define extract-master-from-apk-set
$(LOCAL_BUILT_MODULE): $(1)
	@echo "Extracting $$@"
	unzip -pq $$< $(2) >$$@
endef

$(eval $(call extract-master-from-apk-set,$(LOCAL_PREBUILT_MODULE_FILE),$(LOCAL_APK_SET_MASTER_FILE)))
# unzip returns 11 it there was nothing to extract, which is expected,
# $(LOCAL_APK_SET_MASTER_FILE) has is already there.
LOCAL_POST_INSTALL_CMD := unzip -qo -j -d $(dir $(LOCAL_INSTALLED_MODULE)) \
	$(LOCAL_PREBUILT_MODULE_FILE) -x $(LOCAL_APK_SET_MASTER_FILE) || [[ $$? -eq 11 ]]
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

# android_app_set modules are always presigned
PACKAGES.$(LOCAL_MODULE).CERTIFICATE := PRESIGNED
PACKAGES := $(PACKAGES) $(LOCAL_MODULE)

ifneq ($(LOCAL_MODULE_STEM),)
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE_STEM)
else
  PACKAGES.$(LOCAL_MODULE).STEM := $(LOCAL_MODULE)
endif

# Set a actual_partition_tag (calculated in base_rules.mk) for the package.
PACKAGES.$(LOCAL_MODULE).PARTITION := $(actual_partition_tag)

SOONG_ALREADY_CONV += $(LOCAL_MODULE)
