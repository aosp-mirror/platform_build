###########################################################
## Copy headers to the install tree
###########################################################
ifneq ($(strip $(LOCAL_IS_HOST_MODULE)),)
  my_prefix := HOST_
else
  my_prefix := TARGET_
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
        $($(my_prefix)OUT_HEADERS)/$(LOCAL_COPY_HEADERS_TO)/$(notdir $(header)),\
        $($(my_prefix)OUT_HEADERS)/$(notdir $(header)))) \
  $(eval ALL_COPIED_HEADERS.$(_chTo).MAKEFILE += $(LOCAL_MODULE_MAKEFILE)) \
  $(eval ALL_COPIED_HEADERS.$(_chTo).SRC += $(_chFrom)) \
  $(if $(filter $(_chTo),$(ALL_COPIED_HEADERS)),, \
      $(eval ALL_COPIED_HEADERS += $(_chTo))) \
 )
_chFrom :=
_chTo :=
