PRODUCT_PROPERTY_OVERRIDES :=

PRODUCT_PACKAGES := \
	ApiDemos \
	Development \
	Fallback \
	GPSEnable

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_NAME := sdk
PRODUCT_DEVICE := generic
