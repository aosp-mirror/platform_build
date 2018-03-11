
# Enforcement checks that LOCAL_SDK_VERSION and LOCAL_PRIVATE_PLATFORM_APIS are
# set correctly.
# Should be included by java targets that allow specifying LOCAL_SDK_VERSION.
# The JAVA_SDK_ENFORCEMENT_WARNING and JAVA_SDK_ENFORCEMENT_ERROR variables may
# be set to a particular module class to enable warnings and errors for that
# subtype.

whitelisted_modules := framework-res__auto_generated_rro


ifeq (,$(JAVA_SDK_ENFORCEMENT_ERROR))
  JAVA_SDK_ENFORCEMENT_ERROR := APPS
endif

ifeq ($(LOCAL_SDK_VERSION)$(LOCAL_PRIVATE_PLATFORM_APIS),)
  ifeq (,$(filter $(LOCAL_MODULE),$(whitelisted_modules)))
    ifneq ($(JAVA_SDK_ENFORCEMENT_WARNING)$(JAVA_SDK_ENFORCEMENT_ERROR),)
      my_message := Must specify LOCAL_SDK_VERSION or LOCAL_PRIVATE_PLATFORM_APIS,
      ifeq ($(LOCAL_MODULE_CLASS),$(JAVA_SDK_ENFORCEMENT_ERROR))
        $(call pretty-error,$(my_message))
      endif
      ifeq ($(LOCAL_MODULE_CLASS),$(JAVA_SDK_ENFORCEMENT_WARNING))
        $(call pretty-warning,$(my_message))
      endif
      my_message :=
    endif
  endif
else ifneq ($(LOCAL_SDK_VERSION),)
  ifneq ($(LOCAL_PRIVATE_PLATFORM_APIS),)
    my_message := Specifies both LOCAL_SDK_VERSION ($(LOCAL_SDK_VERSION)) and
    my_message += LOCAL_PRIVATE_PLATFORM_APIS ($(LOCAL_PRIVATE_PLATFORM_APIS))
    my_message += but should specify only one
    $(call pretty-error,$(my_message))
    my_message :=
  endif
endif
