
ifeq (true,$(filter true, \
   $(LOCAL_PRODUCT_MODULE) $(LOCAL_PRODUCT_SERVICES_MODULE) \
   $(LOCAL_VENDOR_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
  ifneq (,$(filter $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))%,$(LOCAL_CERTIFICATE)))
    CERTIFICATE_VIOLATION_MODULES += $(LOCAL_MODULE)
    ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT))
      $(if $(filter $(LOCAL_MODULE),$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_WHITELIST)),,\
        $(call pretty-error,The module in product partition cannot be signed with certificate in system.))
    endif
  endif
endif