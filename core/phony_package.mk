ifneq ($(strip $(LOCAL_SRC_FILES)),)
$(error LOCAL_SRC_FILES are not allowed for phony packages)
endif

ifeq ($(strip $(LOCAL_REQUIRED_MODULES)),)
$(error LOCAL_REQUIRED_MODULES is required for phony packages)
endif

LOCAL_MODULE_CLASS := FAKE
LOCAL_MODULE_SUFFIX := -timestamp

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE):
	$(hide) echo "Fake: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@
