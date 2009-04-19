# This is a generic product that isn't specialized for a specific device.
# It includes the base Android platform including some Google-specific features.
# If you do not want to include Google specific features, you should derive 
# from generic.mk

PRODUCT_PACKAGES := \
    GoogleContactsProvider \
    GoogleSubscribedFeedsProvider \
    com.google.android.gtalkservice \
    com.google.android.maps

PRODUCT_COPY_FILES := \
    vendor/google/frameworks/maps/com.google.android.maps.xml:system/etc/permissions/com.google.android.maps.xml \
    vendor/google/apps/GTalkService/com.google.android.gtalkservice.xml:system/etc/permissions/com.google.android.gtalkservice.xml


$(call inherit-product, $(SRC_TARGET_DIR)/product/generic.mk)

# Overrides
PRODUCT_NAME := generic_with_google
