
#Set LOCAL_USE_VNDK for modules going into product, vendor or odm partition, except for host modules
#If LOCAL_SDK_VERSION is set, thats a more restrictive set, so they dont need LOCAL_USE_VNDK
ifndef LOCAL_IS_HOST_MODULE
ifndef LOCAL_SDK_VERSION
  ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_OEM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
    LOCAL_USE_VNDK:=true
    LOCAL_USE_VNDK_VENDOR:=true
    # Note: no need to check LOCAL_MODULE_PATH* since LOCAL_[VENDOR|ODM|OEM]_MODULE is already
    # set correctly before this is included.
  endif
  ifdef PRODUCT_PRODUCT_VNDK_VERSION
    # Product modules also use VNDK when PRODUCT_PRODUCT_VNDK_VERSION is defined.
    ifeq (true,$(LOCAL_PRODUCT_MODULE))
      LOCAL_USE_VNDK:=true
      LOCAL_USE_VNDK_PRODUCT:=true
    endif
  endif
endif
endif

# Verify LOCAL_USE_VNDK usage, and set LOCAL_SDK_VERSION if necessary

ifdef LOCAL_IS_HOST_MODULE
  ifdef LOCAL_USE_VNDK
    $(shell echo $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Do not use LOCAL_USE_VNDK with host modules >&2)
    $(error done)
  endif
endif
ifdef LOCAL_USE_VNDK
  ifneq ($(LOCAL_USE_VNDK),true)
    $(shell echo '$(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): LOCAL_USE_VNDK must be "true" or empty, not "$(LOCAL_USE_VNDK)"' >&2)
    $(error done)
  endif

  ifdef LOCAL_SDK_VERSION
    $(shell echo $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): LOCAL_USE_VNDK must not be used with LOCAL_SDK_VERSION >&2)
    $(error done)
  endif
endif

