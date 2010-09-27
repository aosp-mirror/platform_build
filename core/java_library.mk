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

intermediates := $(call local-intermediates-dir)
intermediates.COMMON := $(call local-intermediates-dir,COMMON)

ifndef LOCAL_IS_HOST_MODULE
ifeq (true,$(WITH_DEXPREOPT))
ifndef LOCAL_DEX_PREOPT
LOCAL_DEX_PREOPT := true

jar_with_dex := $(intermediates.COMMON)/javalib.dex.jar
LOCAL_INTERMEDIATE_TARGETS += $(jar_with_dex)
endif
endif
endif

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# No dex or resources; all we want are the .class files.
$(LOCAL_BUILT_MODULE): $(full_classes_jar)
	@echo "target Static Jar: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

else # !LOCAL_IS_STATIC_JAVA_LIBRARY

ifeq ($(LOCAL_DEX_PREOPT),true)
$(jar_with_dex): PRIVATE_DEX_FILE := $(built_dex)
$(jar_with_dex) : $(built_dex) $(java_resource_sources) | $(AAPT)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif

dexpreopt_boot_jar_module := $(filter $(LOCAL_MODULE),$(DEXPREOPT_BOOT_JARS_MODULES))
ifneq ($(dexpreopt_boot_jar_module),)
# boot jar's rules are defined in dex_preopt.mk
dexpreopted_boot_jar := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(dexpreopt_boot_jar_module)_nodex.jar
$(LOCAL_BUILT_MODULE) : $(dexpreopted_boot_jar) | $(ACP)
	$(call copy-file-to-target)

dexpreopted_boot_odex := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(dexpreopt_boot_jar_module).odex
built_odex := $(basename $(LOCAL_BUILT_MODULE)).odex
$(built_odex) : $(dexpreopted_boot_odex) | $(ACP)
	$(call copy-file-to-target)

else # dexpreopt_boot_jar_module
built_odex := $(basename $(LOCAL_BUILT_MODULE)).odex
$(built_odex): PRIVATE_MODULE := $(LOCAL_MODULE)
# Make sure the boot jars get dex-preopt-ed first
$(built_odex) : $(DEXPREOPT_BOOT_ODEXS)
$(built_odex) : $(jar_with_dex) | $(DEXPREOPT) $(DEXOPT)
	@echo "Dexpreopt Jar: $(PRIVATE_MODULE) ($@)"
	$(hide) rm -f $@
	$(call dexpreopt-one-file,$<,$@)

$(LOCAL_BUILT_MODULE) : $(jar_with_dex) | $(ACP) $(AAPT)
	$(call copy-file-to-target)
	$(call dexpreopt-remove-classes.dex,$@)

endif # dexpreopt_boot_jar_module

else # LOCAL_DEX_PREOPT
$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE) : $(built_dex) $(java_resource_sources) | $(AAPT)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif
endif # LOCAL_DEX_PREOPT

endif # !LOCAL_IS_STATIC_JAVA_LIBRARY
