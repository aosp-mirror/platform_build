# This is a generic product that isn't specialized for a specific device.
# It includes the base Android platform. If you need Google-specific features,
# you should derive from generic_with_google.mk

PRODUCT_PACKAGES := \
    AlarmClock \
    AlarmProvider \
    Calendar \
    Camera \
    DrmProvider \
    LatinIME \
    Mms \
    Music \
    Settings \
    Sync \
    Updater \
    CalendarProvider \
    SubscribedFeedsProvider \
    SyncProvider

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic_x86
PRODUCT_DEVICE := generic_x86
PRODUCT_NAME := generic_x86
PRODUCT_POLICY := android.policy_phone
