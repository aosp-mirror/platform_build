$(call record-module-type,PHONY_PACKAGE)
ifneq ($(strip $(LOCAL_SRC_FILES)),)
$(error LOCAL_SRC_FILES are not allowed for phony packages)
endif

LOCAL_MODULE_CLASS := FAKE
LOCAL_MODULE_SUFFIX := -timestamp

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(hide) echo "Fake: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=PHONY_PACKAGE))