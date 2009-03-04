###########################################################
## Standard rules for building a java library.
##
###########################################################

ifdef LOCAL_IS_HOST_MODULE
$(error $(LOCAL_PATH): Host java libraries must use BUILD_HOST_JAVA_LIBRARY)
endif

LOCAL_MODULE_SUFFIX := $(COMMON_JAVA_PACKAGE_SUFFIX)
LOCAL_MODULE_CLASS := JAVA_LIBRARIES

ifneq (,$(LOCAL_ASSET_DIR))
$(error $(LOCAL_PATH): Target java libraries may not set LOCAL_ASSET_DIR)
endif

ifneq (,$(LOCAL_RESOURCE_DIR))
$(error $(LOCAL_PATH): Target java libraries may not set LOCAL_RESOURCE_DIR)
endif

#xxx base_rules.mk looks at this
all_res_assets :=

LOCAL_BUILT_MODULE_STEM := javalib.jar

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# No dex or resources; all we want are the .class files.
$(LOCAL_BUILT_MODULE): $(full_classes_jar)
	@echo "target Static Jar: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

else # !LOCAL_IS_STATIC_JAVA_LIBRARY

$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): $(built_dex) $(java_resource_sources) | $(AAPT)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif

endif # !LOCAL_IS_STATIC_JAVA_LIBRARY
