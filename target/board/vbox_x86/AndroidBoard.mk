LOCAL_PATH := $(call my-dir)

LOCAL_KERNEL := prebuilt/android-x86/kernel/kernel-vbox

PRODUCT_COPY_FILES += \
    $(LOCAL_KERNEL):kernel \
    $(LOCAL_PATH)/init.rc:root/init.rc
