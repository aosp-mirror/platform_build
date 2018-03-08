
# Enforcement checks that LOCAL_SDK_VERSION and LOCAL_PRIVATE_PLATFORM_APIS are
# set correctly.
# Should be included by java targets that allow specifying LOCAL_SDK_VERSION.

ifeq ($(LOCAL_SDK_VERSION)$(LOCAL_PRIVATE_PLATFORM_APIS),)
ifneq ($(JAVA_SDK_ENFORCEMENT_WARNING),)
$(warning Java modules must specify LOCAL_SDK_VERSION or LOCAL_PRIVATE_PLATFORM_APIS, but $(LOCAL_MODULE) specifies neither.)
endif
else ifneq ($(LOCAL_SDK_VERSION),)
ifneq ($(LOCAL_PRIVATE_PLATFORM_APIS),)
$(error $(LOCAL_MODULE) specifies both LOCAL_SDK_VERSION ($(LOCAL_SDK_VERSION)) and LOCAL_PRIVATE_PLATFORM_APIS ($(LOCAL_PRIVATE_PLATFORM_APIS)), but should specify only one.)
endif
endif
