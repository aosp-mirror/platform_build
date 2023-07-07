LOCAL_PATH:= $(call my-dir)

#######################################
# adb key, if configured via PRODUCT_ADB_KEYS
ifdef PRODUCT_ADB_KEYS
  ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
    include $(CLEAR_VARS)
    LOCAL_MODULE := adb_keys
    LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
    LOCAL_LICENSE_CONDITIONS := notice
    LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
    LOCAL_PREBUILT_MODULE_FILE := $(PRODUCT_ADB_KEYS)
    include $(BUILD_PREBUILT)
  endif
endif


#######################################
# otacerts: A keystore with the authorized keys in it, which is used to verify the authenticity of
# downloaded OTA packages.
include $(CLEAR_VARS)

LOCAL_MODULE := otacerts
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_STEM := otacerts.zip
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/security
include $(BUILD_SYSTEM)/base_rules.mk

extra_ota_keys := $(addsuffix .x509.pem,$(PRODUCT_EXTRA_OTA_KEYS))

$(LOCAL_BUILT_MODULE): PRIVATE_CERT := $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem
$(LOCAL_BUILT_MODULE): PRIVATE_EXTRA_OTA_KEYS := $(extra_ota_keys)
$(LOCAL_BUILT_MODULE): \
	    $(SOONG_ZIP) \
	    $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem \
	    $(extra_ota_keys)
	$(SOONG_ZIP) -o $@ -j -symlinks=false \
	    $(addprefix -f ,$(PRIVATE_CERT) $(PRIVATE_EXTRA_OTA_KEYS))


#######################################
# otacerts for recovery image.
include $(CLEAR_VARS)

LOCAL_MODULE := otacerts.recovery
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_STEM := otacerts.zip
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/system/etc/security
include $(BUILD_SYSTEM)/base_rules.mk

extra_recovery_keys := $(addsuffix .x509.pem,$(PRODUCT_EXTRA_RECOVERY_KEYS))

$(LOCAL_BUILT_MODULE): PRIVATE_CERT := $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem
$(LOCAL_BUILT_MODULE): PRIVATE_EXTRA_RECOVERY_KEYS := $(extra_recovery_keys)
$(LOCAL_BUILT_MODULE): \
	    $(SOONG_ZIP) \
	    $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem \
	    $(extra_recovery_keys)
	$(SOONG_ZIP) -o $@ -j -symlinks=false \
	    $(addprefix -f ,$(PRIVATE_CERT) $(PRIVATE_EXTRA_RECOVERY_KEYS))
