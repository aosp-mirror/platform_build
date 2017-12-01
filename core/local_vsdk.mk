
ifdef BOARD_VSDK_VERSION
# Set LOCAL_SDK_VERSION to system_current, If LOCAL_SDK_VERSION is not defined and LOCAL_VENDOR_MODULE is true
  _is_vendor_app :=
  ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_OEM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
    _is_vendor_app := true
  else
    ifneq (,$(filter $(TARGET_OUT_VENDOR)%,$(LOCAL_MODULE_PATH) $(LOCAL_MODULE_PATH_32) $(LOCAL_MODULE_PATH_64)))
      _is_vendor_app := true
    endif
  endif
  ifneq (,$(filter JAVA_LIBRARIES APPS,$(LOCAL_MODULE_CLASS)))
    ifndef LOCAL_SDK_VERSION
      ifeq ($(_is_vendor_app),true)
        LOCAL_SDK_VERSION := system_current
      endif
    endif
  endif
endif
