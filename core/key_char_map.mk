###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := KEYCHARS
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := .bin
endif

LOCAL_MODULE := $(LOCAL_SRC_FILES)

include $(BUILD_SYSTEM)/base_rules.mk

full_src_files := $(addprefix $(LOCAL_PATH)/,$(LOCAL_SRC_FILES))

$(LOCAL_BUILT_MODULE) : PRIVATE_SRC_FILES := $(full_src_files)

ifeq ($(BUILD_TINY_ANDROID),true)
$(LOCAL_BUILT_MODULE) : $(full_src_files)
	@echo KeyCharMap: $@
	@mkdir -p $(dir $@)
	$(hide) touch $@
else
$(LOCAL_BUILT_MODULE) : $(full_src_files) $(KCM)
	@echo KeyCharMap: $@
	@mkdir -p $(dir $@)
	$(hide) $(KCM) $(PRIVATE_SRC_FILES) $@
endif