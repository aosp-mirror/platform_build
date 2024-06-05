ifneq (,$(strip $(LOCAL_COPY_HEADERS)))
###########################################################
## Copy headers to the install tree
###########################################################
$(call record-module-type,COPY_HEADERS)
ifneq ($(strip $(LOCAL_IS_HOST_MODULE)),)
  $(call pretty-error,LOCAL_COPY_HEADERS may not be used with host modules)
endif

# Modules linking against the SDK do not have the include path to use
# COPY_HEADERS, so prevent them from exporting any either.
ifdef LOCAL_SDK_VERSION
  $(call pretty-error,Modules using LOCAL_SDK_VERSION may not use LOCAL_COPY_HEADERS)
endif

include $(BUILD_SYSTEM)/local_vendor_product.mk

# Modules in vendor or product may use LOCAL_COPY_HEADERS.
# Platform libraries will not have the include path present.
ifeq ($(call module-in-vendor-or-product),)
  $(call pretty-error,Only modules in vendor or product may use LOCAL_COPY_HEADERS)
endif

# Clean up LOCAL_COPY_HEADERS_TO, since soong_ui will be comparing cleaned
# paths to figure out which headers are obsolete and should be removed.
LOCAL_COPY_HEADERS_TO := $(call clean-path,$(LOCAL_COPY_HEADERS_TO))
ifneq ($(filter /% .. ../%,$(LOCAL_COPY_HEADERS_TO)),)
  $(call pretty-error,LOCAL_COPY_HEADERS_TO may not start with / or ../ : $(LOCAL_COPY_HEADERS_TO))
endif
ifeq ($(LOCAL_COPY_HEADERS_TO),.)
  LOCAL_COPY_HEADERS_TO :=
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
