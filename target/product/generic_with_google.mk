# This is a generic product that isn't specialized for a specific device.
# It includes the base Android platform including some Google-specific features.
# If you do not want to include Google specific features, you should derive 
# from generic.mk

PRODUCT_PACKAGES := \
    GoogleContactsProvider \
    GoogleSubscribedFeedsProvider

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic.mk)

# Overrides
PRODUCT_NAME := generic_with_google
