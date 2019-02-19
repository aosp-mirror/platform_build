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

# For java libraries, other modules should depend on
# out/target/common/obj/JAVA_LIBRARIES/.../classes.jar.
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
# Exclude jacoco classes from proguard
LOCAL_PROGUARD_FLAGS += -include $(BUILD_SYSTEM)/proguard.jacoco.flags
endif # LOCAL_EMMA_INSTRUMENT
endif # EMMA_INSTRUMENT_STATIC
else
LOCAL_EMMA_INSTRUMENT := false
endif # EMMA_INSTRUMENT

my_dex_jar := $(common_javalib.jar)

#################################
include $(BUILD_SYSTEM)/java.mk
#################################

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# There are some dependencies outside the build system that assume classes.jar
# is available as javalib.jar so copy it there too.
$(eval $(call copy-one-file,$(full_classes_pre_proguard_jar),$(common_javalib.jar)))

$(eval $(call copy-one-file,$(full_classes_pre_proguard_jar),$(LOCAL_BUILT_MODULE)))

else # !LOCAL_IS_STATIC_JAVA_LIBRARY

$(common_javalib.jar): PRIVATE_DEX_FILE := $(built_dex)
$(common_javalib.jar): PRIVATE_SOURCE_ARCHIVE := $(full_classes_pre_proguard_jar)
$(common_javalib.jar): $(MERGE_ZIPS) $(SOONG_ZIP) $(ZIP2ZIP)
$(common_javalib.jar) : $(built_dex) $(java_resource_sources) | $(ZIPTIME) $(ZIPALIGN)
	@echo "target Jar: $(PRIVATE_MODULE) ($@)"
	rm -rf $@.parts && mkdir -p $@.parts
	$(call create-dex-jar,$@.parts/dex.zip,$(PRIVATE_DEX_FILE))
	$(call extract-resources-jar,$@.parts/res.zip,$(PRIVATE_SOURCE_ARCHIVE))
	$(MERGE_ZIPS) -j $@.tmp $@.parts/dex.zip $@.parts/res.zip
	rm -rf $@.parts
	$(hide) $(ZIPTIME) $@.tmp
	$(call commit-change-for-toc,$@)
ifeq (true, $(LOCAL_UNCOMPRESS_DEX))
	$(uncompress-dexs)
	$(align-package)
endif  # LOCAL_UNCOMPRESS_DEX

.KATI_RESTAT: $(common_javalib.jar)

ifdef LOCAL_DEX_PREOPT

$(LOCAL_BUILT_MODULE): PRIVATE_STRIP_SCRIPT := $(intermediates)/strip.sh
$(LOCAL_BUILT_MODULE): $(intermediates)/strip.sh
$(LOCAL_BUILT_MODULE): | $(DEXPREOPT_STRIP_DEPS)
$(LOCAL_BUILT_MODULE): .KATI_DEPFILE := $(LOCAL_BUILT_MODULE).d
$(LOCAL_BUILT_MODULE): $(common_javalib.jar)
	$(PRIVATE_STRIP_SCRIPT) $< $@

else # LOCAL_DEX_PREOPT
$(eval $(call copy-one-file,$(common_javalib.jar),$(LOCAL_BUILT_MODULE)))

endif # LOCAL_DEX_PREOPT
endif # !LOCAL_IS_STATIC_JAVA_LIBRARY
