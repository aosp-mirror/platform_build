LOCAL_PATH:= $(call my-dir)

#######################################
# verity_key (installed to /, i.e. part of system.img)
include $(CLEAR_VARS)

LOCAL_MODULE := verity_key
LOCAL_SRC_FILES := $(LOCAL_MODULE)
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)

# For devices using a separate ramdisk, we need a copy there to establish the chain of trust.
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
LOCAL_REQUIRED_MODULES := verity_key_ramdisk
endif

include $(BUILD_PREBUILT)

#######################################
# verity_key (installed to ramdisk)
#
# Enabling the target when using system-as-root would cause build failure, as TARGET_RAMDISK_OUT
# points to the same location as TARGET_ROOT_OUT.
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
  include $(CLEAR_VARS)
  LOCAL_MODULE := verity_key_ramdisk
  LOCAL_MODULE_CLASS := ETC
  LOCAL_SRC_FILES := verity_key
  LOCAL_MODULE_STEM := verity_key
  LOCAL_MODULE_PATH := $(TARGET_RAMDISK_OUT)
  include $(BUILD_PREBUILT)
endif

#######################################
# adb key, if configured via PRODUCT_ADB_KEYS
ifdef PRODUCT_ADB_KEYS
  ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
    include $(CLEAR_VARS)
    LOCAL_MODULE := adb_keys
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
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_STEM := otacerts.zip
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/security
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_CERT := $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem
$(LOCAL_BUILT_MODULE): $(SOONG_ZIP) $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem
	$(SOONG_ZIP) -o $@ -j -f $(PRIVATE_CERT)


#######################################
# otacerts for recovery image.
include $(CLEAR_VARS)

LOCAL_MODULE := otacerts.recovery
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_STEM := otacerts.zip
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/system/etc/security
include $(BUILD_SYSTEM)/base_rules.mk

extra_recovery_keys := $(patsubst %,%.x509.pem,$(PRODUCT_EXTRA_RECOVERY_KEYS))

$(LOCAL_BUILT_MODULE): PRIVATE_CERT := $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem
$(LOCAL_BUILT_MODULE): PRIVATE_EXTRA_RECOVERY_KEYS := $(extra_recovery_keys)
$(LOCAL_BUILT_MODULE): \
	    $(SOONG_ZIP) \
	    $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem \
	    $(extra_recovery_keys)
	$(SOONG_ZIP) -o $@ -j \
	    $(foreach key_file, $(PRIVATE_CERT) $(PRIVATE_EXTRA_RECOVERY_KEYS), -f $(key_file))
