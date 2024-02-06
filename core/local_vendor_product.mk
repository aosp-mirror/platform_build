# LOCAL_USE_VNDK is not the variable which set by module directly, but there are some modules do so.
# Set those as LOCAL_IN_VENDOR to make those modules work as expected.
ifeq (true,$(LOCAL_USE_VNDK))
  $(warning LOCAL_USE_VNDK must not be used. Please use LOCAL_VENDOR_MODULE or LOCAL_PRODUCT_MODULE instead.)
  LOCAL_IN_VENDOR:=true
endif

# Set LOCAL_IN_VENDOR for modules going into vendor or odm partition and LOCAL_IN_PRODUCT for product
# except for host modules. If LOCAL_SDK_VERSION is set, thats a more restrictive set, so they don't need
# LOCAL_IN_VENDOR or LOCAL_IN_PRODUCT
ifndef LOCAL_IS_HOST_MODULE
ifndef LOCAL_SDK_VERSION
  ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_OEM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
    LOCAL_IN_VENDOR:=true
    # Note: no need to check LOCAL_MODULE_PATH* since LOCAL_[VENDOR|ODM|OEM]_MODULE is already
    # set correctly before this is included.
  endif
  ifeq (true,$(LOCAL_PRODUCT_MODULE))
    LOCAL_IN_PRODUCT:=true
  endif
endif
endif
