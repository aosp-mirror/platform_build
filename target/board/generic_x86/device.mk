ifeq ($(TARGET_PREBUILT_KERNEL),)
LOCAL_KERNEL := prebuilt/android-x86/kernel/kernel
else
LOCAL_KERNEL := $(TARGET_PREBUILT_KERNEL)
endif

PRODUCT_COPY_FILES += \
    $(LOCAL_KERNEL):kernel \
    build/target/board/generic_x86/init.rc:root/init.rc
