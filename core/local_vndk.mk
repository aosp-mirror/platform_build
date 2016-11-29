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

  # If we're not using the VNDK, drop all restrictions
  ifndef BOARD_VNDK_VERSION
    LOCAL_USE_VNDK:=
  endif
endif

