# Droiddoc prebuilt coming from Soong.

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_droiddoc_prebuilt.mk may only be used from Soong)
endif

ifdef LOCAL_DROIDDOC_STUBS_SRCJAR
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_STUBS_SRCJAR),$(OUT_DOCS)/$(LOCAL_MODULE)-stubs.srcjar))
ALL_DOCS += $(OUT_DOCS)/$(LOCAL_MODULE)-stubs.srcjar

.PHONY: $(LOCAL_MODULE)
$(LOCAL_MODULE) : $(OUT_DOCS)/$(LOCAL_MODULE)-stubs.srcjar
endif

ifdef LOCAL_DROIDDOC_DOC_ZIP
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_DOC_ZIP),$(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip))
$(call dist-for-goals,docs,$(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip)

.PHONY: $(LOCAL_MODULE) $(LOCAL_MODULE)-docs.zip
$(LOCAL_MODULE) $(LOCAL_MODULE)-docs.zip : $(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip
ALL_DOCS += $(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip
endif

ifdef LOCAL_DROIDDOC_ANNOTATIONS_ZIP
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_ANNOTATIONS_ZIP),$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)_annotations.zip))
endif

ifdef LOCAL_DROIDDOC_API_VERSIONS_XML
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_API_VERSIONS_XML),$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)_generated-api-versions.xml))
endif

ifdef LOCAL_DROIDDOC_METADATA_ZIP
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_METADATA_ZIP),$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)-metadata.zip))
endif
