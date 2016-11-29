ifneq (,$(strip $(LOCAL_COPY_HEADERS)))
###########################################################
## Copy headers to the install tree
###########################################################
$(call record-module-type,COPY_HEADERS)
ifneq ($(strip $(LOCAL_IS_HOST_MODULE)),)
  $(shell echo $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): LOCAL_COPY_HEADERS may not be used with host modules >&2)
  $(error done)
endif

# Modules linking against the SDK do not have the include path to use
# COPY_HEADERS, so prevent them from exporting any either.
ifdef LOCAL_SDK_VERSION
$(shell echo $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Modules using LOCAL_SDK_VERSION may not use LOCAL_COPY_HEADERS >&2)
$(error done)
endif

include $(BUILD_SYSTEM)/local_vndk.mk

# If we're using the VNDK, only vendor modules using the VNDK may use
# LOCAL_COPY_HEADERS. Platform libraries will not have the include path
# present.
ifdef BOARD_VNDK_VERSION
ifndef LOCAL_USE_VNDK
$(shell echo $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Only vendor modules using LOCAL_USE_VNDK may use LOCAL_COPY_HEADERS >&2)
$(error done)
endif
endif

# Create a rule to copy each header, and make the
# all_copied_headers phony target depend on each
# destination header.  copy-one-header defines the
# actual rule.
#
$(foreach header,$(LOCAL_COPY_HEADERS), \
  $(eval _chFrom := $(LOCAL_PATH)/$(header)) \
  $(eval _chTo := \
      $(if $(LOCAL_COPY_HEADERS_TO),\
        $(TARGET_OUT_HEADERS)/$(LOCAL_COPY_HEADERS_TO)/$(notdir $(header)),\
        $(TARGET_OUT_HEADERS)/$(notdir $(header)))) \
  $(eval ALL_COPIED_HEADERS.$(_chTo).MAKEFILE += $(LOCAL_MODULE_MAKEFILE)) \
  $(eval ALL_COPIED_HEADERS.$(_chTo).SRC += $(_chFrom)) \
  $(if $(filter $(_chTo),$(ALL_COPIED_HEADERS)),, \
      $(eval ALL_COPIED_HEADERS += $(_chTo))) \
 )
_chFrom :=
_chTo :=

endif # LOCAL_COPY_HEADERS
