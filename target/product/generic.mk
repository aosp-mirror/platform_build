# This is a generic product that isn't specialized for a specific device.
# It includes the base Android platform. If you need Google-specific features,
# you should derive from generic_with_google.mk

PRODUCT_PACKAGES := \
    AccountAndSyncSettings \
    AlarmClock \
    AlarmProvider \
    Bluetooth \
    Calculator \
    Calendar \
    Camera \
    CertInstaller \
    DrmProvider \
    Email \
    Gallery \
    LatinIME \
    Mms \
    Music \
    Provision \
    Settings \
    Sync \
    Updater \
    CalendarProvider \
    SyncProvider

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := generic
