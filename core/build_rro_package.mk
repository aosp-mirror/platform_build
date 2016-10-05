#########################################################################
## Standard rules for installing runtime resouce overlay APKs.
##
## Set LOCAL_RRO_SKU to the SKU name if the package should apply only to
## a particular SKU as set by ro.boot.vendor.overlay.sku system property.
##
#########################################################################

LOCAL_IS_RUNTIME_RESOURCE_OVERLAY := true

ifneq ($(LOCAL_SRC_FILES),)
  $(error runtime resource overlay package should not contain sources)
endif

ifeq (S(LOCAL_RRO_SKU),)
  LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay
else
  LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/overlay/$(LOCAL_RRO_SKU)
endif

include $(BUILD_SYSTEM)/package.mk

