LOCAL_MODULE_CLASS := _FAKE_

ifneq ($(strip $(LOCAL_SRC_FILES)),)
$(error LOCAL_SRC_FILES are not allowed for phony packages)
endif

ifeq ($(strip $(LOCAL_REQUIRED_MODULES)),)
$(error LOCAL_REQUIRED_MODULES is required for phony packages)
endif

.PHONY: $(LOCAL_MODULE)

$(LOCAL_MODULE): $(LOCAL_REQUIRED_MODULES)

ALL_MODULES += $(LOCAL_MODULE)
ALL_MODULES.$(LOCAL_MODULE).CLASS := _FAKE_

PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
