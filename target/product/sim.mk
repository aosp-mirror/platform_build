PRODUCT_PACKAGES := \
	IM

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_with_google.mk)

# Overrides
PRODUCT_NAME := sim
PRODUCT_DEVICE := sim
PRODUCT_LOCALES := en_US
