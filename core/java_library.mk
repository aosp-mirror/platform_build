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

ifneq (true,$(LOCAL_IS_STATIC_JAVA_LIBRARY))
ifneq (,$(LOCAL_RESOURCE_DIR))
$(error $(LOCAL_PATH): Target java libraries may not set LOCAL_RESOURCE_DIR)
endif
# base_rules.mk looks at this
all_res_assets :=
endif

LOCAL_BUILT_MODULE_STEM := javalib.jar

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

# This file will be the one that other modules should depend on.
common_javalib.jar := $(intermediates.COMMON)/$(LOCAL_BUILT_MODULE_STEM)
LOCAL_INTERMEDIATE_TARGETS += $(common_javalib.jar)

ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
  LOCAL_PROGUARD_ENABLED :=
endif

ifneq (true,$(WITH_DEXPREOPT))
LOCAL_DEX_PREOPT :=
else
ifeq (,$(TARGET_BUILD_APPS))
ifeq (,$(LOCAL_APK_LIBRARIES))
ifndef LOCAL_DEX_PREOPT
LOCAL_DEX_PREOPT := $(DEX_PREOPT_DEFAULT)
endif
endif
endif
endif
ifeq (false,$(LOCAL_DEX_PREOPT))
LOCAL_DEX_PREOPT :=
endif

ifeq (true,$(EMMA_INSTRUMENT))
ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
LOCAL_STATIC_JAVA_LIBRARIES += emma
endif # LOCAL_EMMA_INSTRUMENT
endif # EMMA_INSTRUMENT_STATIC
else
LOCAL_EMMA_INSTRUMENT := false
endif # EMMA_INSTRUMENT

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# No dex; all we want are the .class files with resources.
$(common_javalib.jar) : $(java_resource_sources)
ifdef LOCAL_PROGUARD_ENABLED
$(common_javalib.jar) : $(full_classes_proguard_jar)
else
$(common_javalib.jar) : $(full_classes_jar)
endif
	@echo "target Static Jar: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif

$(LOCAL_BUILT_MODULE): $(common_javalib.jar)
	$(copy-file-to-target)

else # !LOCAL_IS_STATIC_JAVA_LIBRARY

$(common_javalib.jar): PRIVATE_DEX_FILE := $(built_dex)
$(common_javalib.jar) : $(built_dex) $(java_resource_sources)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
	$(add-carried-java-resources)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif

ifdef LOCAL_DEX_PREOPT
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
$(built_odex) : $(common_javalib.jar) | $(DEXPREOPT) $(DEXOPT)
	@echo "Dexpreopt Jar: $(PRIVATE_MODULE) ($@)"
	$(hide) rm -f $@
	@mkdir -p $(dir $@)
	$(call dexpreopt-one-file,$<,$@)

$(LOCAL_BUILT_MODULE) : $(common_javalib.jar) | $(ACP)
	$(call copy-file-to-target)
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif

endif # dexpreopt_boot_jar_module

else # LOCAL_DEX_PREOPT
$(LOCAL_BUILT_MODULE) : $(common_javalib.jar) | $(ACP)
	$(call copy-file-to-target)

endif # LOCAL_DEX_PREOPT
endif # !LOCAL_IS_STATIC_JAVA_LIBRARY
