###########################################################
## Standard rules for building a java library.
##
###########################################################
$(call record-module-type,JAVA_LIBRARY)

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

#################################
include $(BUILD_SYSTEM)/configure_local_jack.mk
#################################

ifdef LOCAL_JACK_ENABLED
ifdef LOCAL_IS_STATIC_JAVA_LIBRARY
LOCAL_BUILT_MODULE_STEM := classes.jack
endif
endif

# For non-static java libraries, other modules should depend on
# out/target/common/obj/JAVA_LIBRARIES/.../javalib.jar (for jack)
# or out/target/common/obj/JAVA_LIBRARIES/.../classes.jar (for javac).
# For static java libraries, other modules should depend on
# out/target/common/obj/JAVA_LIBRARIES/.../classes.jar
# There are some dependencies outside the build system that assume static
# java libraries produce javalib.jar, so we will copy classes.jar there too.
intermediates.COMMON := $(call local-intermediates-dir,COMMON)
common_javalib.jar := $(intermediates.COMMON)/javalib.jar
dex_preopt_profile_src_file := $(common_javalib.jar)
LOCAL_INTERMEDIATE_TARGETS += $(common_javalib.jar)

ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
  LOCAL_PROGUARD_ENABLED :=
endif

ifeq (true,$(EMMA_INSTRUMENT))
ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
LOCAL_STATIC_JAVA_LIBRARIES += jacocoagent
endif # LOCAL_EMMA_INSTRUMENT
endif # EMMA_INSTRUMENT_STATIC
else
LOCAL_EMMA_INSTRUMENT := false
endif # EMMA_INSTRUMENT

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# There are some dependencies outside the build system that assume classes.jar
# is available as javalib.jar so copy it there too.
$(eval $(call copy-one-file,$(full_classes_jar),$(common_javalib.jar)))

ifdef LOCAL_JACK_ENABLED
$(eval $(call copy-one-file,$(full_classes_jack),$(LOCAL_BUILT_MODULE)))
else
$(eval $(call copy-one-file,$(full_classes_jar),$(LOCAL_BUILT_MODULE)))
endif

else # !LOCAL_IS_STATIC_JAVA_LIBRARY

$(common_javalib.jar): PRIVATE_DEX_FILE := $(built_dex)
$(common_javalib.jar): PRIVATE_SOURCE_ARCHIVE := $(full_classes_pre_proguard_jar)
$(common_javalib.jar): PRIVATE_DONT_DELETE_JAR_DIRS := $(LOCAL_DONT_DELETE_JAR_DIRS)
$(common_javalib.jar) : $(built_dex) $(java_resource_sources) | $(ZIPTIME)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
ifdef LOCAL_JACK_ENABLED
	$(create-empty-package)
else
	$(call initialize-package-file,$(PRIVATE_SOURCE_ARCHIVE),$@)
endif
	$(add-dex-to-package)
ifdef LOCAL_JACK_ENABLED
	$(add-carried-jack-resources)
endif
	$(remove-timestamps-from-package)

ifdef LOCAL_DEX_PREOPT
ifneq ($(dexpreopt_boot_jar_module),) # boot jar
# boot jar's rules are defined in dex_preopt.mk
dexpreopted_boot_jar := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(dexpreopt_boot_jar_module)_nodex.jar
$(eval $(call copy-one-file,$(dexpreopted_boot_jar),$(LOCAL_BUILT_MODULE)))

# For libart boot jars, we don't have .odex files.
else # ! boot jar
$(built_odex): PRIVATE_MODULE := $(LOCAL_MODULE)
# Use pattern rule - we may have multiple built odex files.
$(built_odex) : $(dir $(LOCAL_BUILT_MODULE))% : $(common_javalib.jar)
	@echo "Dexpreopt Jar: $(PRIVATE_MODULE) ($@)"
	$(call dexpreopt-one-file,$<,$@)

$(eval $(call copy-one-file,$(common_javalib.jar),$(LOCAL_BUILT_MODULE)))
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif

endif # ! boot jar

else # LOCAL_DEX_PREOPT
$(eval $(call copy-one-file,$(common_javalib.jar),$(LOCAL_BUILT_MODULE)))

endif # LOCAL_DEX_PREOPT
endif # !LOCAL_IS_STATIC_JAVA_LIBRARY
