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
      $($(my_prefix)OUT_HEADERS)/$(LOCAL_COPY_HEADERS_TO)/$(notdir $(header))) \
  $(eval $(call copy-one-header,$(_chFrom),$(_chTo))) \
  $(eval all_copied_headers: $(_chTo)) \
 )
_chFrom :=
_chTo :=
