# Target Java.
# Requires:
# LOCAL_MODULE_SUFFIX
# LOCAL_MODULE_CLASS
# all_res_assets

LOCAL_NO_STANDARD_LIBRARIES:=$(strip $(LOCAL_NO_STANDARD_LIBRARIES))
LOCAL_SDK_VERSION:=$(strip $(LOCAL_SDK_VERSION))

proto_sources := $(filter %.proto,$(LOCAL_SRC_FILES))
ifneq ($(proto_sources),)
ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),micro)
    LOCAL_STATIC_JAVA_LIBRARIES += libprotobuf-java-micro
else
  ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
    LOCAL_STATIC_JAVA_LIBRARIES += libprotobuf-java-nano
  else
    ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),stream)
      # No library for stream protobufs
    else
      LOCAL_STATIC_JAVA_LIBRARIES += libprotobuf-java-lite
    endif
  endif
endif
endif

# LOCAL_STATIC_JAVA_AAR_LIBRARIES and LOCAL_STATIC_ANDROID_LIBRARIES are also LOCAL_STATIC_JAVA_LIBRARIES.
LOCAL_STATIC_JAVA_LIBRARIES := $(strip $(LOCAL_STATIC_JAVA_LIBRARIES) \
    $(LOCAL_STATIC_JAVA_AAR_LIBRARIES) \
    $(LOCAL_STATIC_ANDROID_LIBRARIES))
# LOCAL_SHARED_ANDROID_LIBRARIES are also LOCAL_JAVA_LIBRARIES.
LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES) $(LOCAL_SHARED_ANDROID_LIBRARIES))

LOCAL_BUILT_MODULE_STEM := $(strip $(LOCAL_BUILT_MODULE_STEM))
ifeq ($(LOCAL_BUILT_MODULE_STEM),)
$(error $(LOCAL_PATH): Target java template must define LOCAL_BUILT_MODULE_STEM)
endif
ifneq ($(filter classes-compiled.jar classes.jar,$(LOCAL_BUILT_MODULE_STEM)),)
$(error LOCAL_BUILT_MODULE_STEM may not be "$(LOCAL_BUILT_MODULE_STEM)")
endif


##############################################################################
# Define the intermediate targets before including base_rules so they get
# the correct environment.
##############################################################################

intermediates := $(call local-intermediates-dir)
intermediates.COMMON := $(call local-intermediates-dir,COMMON)

ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
LOCAL_PROGUARD_ENABLED :=
endif

full_classes_turbine_jar := $(intermediates.COMMON)/classes-turbine.jar
full_classes_header_jarjar := $(intermediates.COMMON)/classes-header-jarjar.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar
full_classes_compiled_jar := $(intermediates.COMMON)/classes-full-debug.jar
full_classes_processed_jar := $(intermediates.COMMON)/classes-processed.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_combined_jar := $(intermediates.COMMON)/classes-combined.jar
built_dex_intermediate := $(intermediates.COMMON)/dex/classes.dex
full_classes_stubs_jar := $(intermediates.COMMON)/stubs.jar
java_source_list_file := $(intermediates.COMMON)/java-source-list

ifeq ($(LOCAL_MODULE_CLASS)$(LOCAL_SRC_FILES)$(LOCAL_STATIC_JAVA_LIBRARIES)$(LOCAL_SOURCE_FILES_ALL_GENERATED),APPS)
# If this is an apk without any Java code (e.g. framework-res), we should skip compiling Java.
full_classes_jar :=
built_dex :=
else
full_classes_jar := $(intermediates.COMMON)/classes.jar
built_dex := $(intermediates.COMMON)/classes.dex
endif

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_turbine_jar) \
    $(full_classes_compiled_jar) \
    $(full_classes_jarjar_jar) \
    $(full_classes_jar) \
    $(full_classes_combined_jar) \
    $(built_dex_intermediate) \
    $(built_dex) \
    $(full_classes_stubs_jar) \
    $(java_source_list_file)

###########################################################
## AIDL: Compile .aidl files to .java
###########################################################
aidl_sources := $(filter %.aidl,$(LOCAL_SRC_FILES))
aidl_java_sources :=

ifneq ($(strip $(aidl_sources)),)

aidl_preprocess_import :=
ifdef LOCAL_SDK_VERSION
ifneq ($(filter current system_current test_current core_current, $(LOCAL_SDK_VERSION)$(TARGET_BUILD_USE_PREBUILT_SDKS)),)
  # LOCAL_SDK_VERSION is current and no TARGET_BUILD_USE_PREBUILT_SDKS
  aidl_preprocess_import := $(FRAMEWORK_AIDL)
else
  aidl_preprocess_import := $(call resolve-prebuilt-sdk-aidl-path,$(LOCAL_SDK_VERSION))
endif # not current or system_current
else
# build against the platform.
LOCAL_AIDL_INCLUDES += $(FRAMEWORKS_BASE_JAVA_SRC_DIRS)
endif # LOCAL_SDK_VERSION

$(foreach s,$(aidl_sources),\
    $(eval $(call define-aidl-java-rule,$(s),$(intermediates.COMMON)/aidl,aidl_java_sources)))
$(foreach java,$(aidl_java_sources), \
    $(call include-depfile,$(java:%.java=%.P),$(java)))

$(aidl_java_sources) : $(LOCAL_ADDITIONAL_DEPENDENCIES) $(aidl_preprocess_import)

$(aidl_java_sources): PRIVATE_AIDL_FLAGS := $(addprefix -p,$(aidl_preprocess_import)) -I$(LOCAL_PATH) -I$(LOCAL_PATH)/src $(addprefix -I,$(LOCAL_AIDL_INCLUDES))
$(aidl_java_sources): PRIVATE_MODULE := $(LOCAL_MODULE)

endif

##########################################

# All of the rules after full_classes_compiled_jar are very unlikely
# to fail except for bugs in their respective tools.  If you would
# like to run these rules, add the "all" modifier goal to the make
# command line.
ifndef LOCAL_CHECKED_MODULE
ifdef full_classes_jar
LOCAL_CHECKED_MODULE := $(full_classes_compiled_jar)
endif
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

###########################################################
## logtags: emit java source
###########################################################
ifneq ($(strip $(logtags_sources)),)

logtags_java_sources := $(patsubst %.logtags,%.java,$(addprefix $(intermediates.COMMON)/logtags/, $(logtags_sources)))
logtags_sources := $(addprefix $(LOCAL_PATH)/, $(logtags_sources))

$(logtags_java_sources): PRIVATE_MERGED_TAG := $(TARGET_OUT_COMMON_INTERMEDIATES)/all-event-log-tags.txt
$(logtags_java_sources): $(intermediates.COMMON)/logtags/%.java: $(LOCAL_PATH)/%.logtags $(TARGET_OUT_COMMON_INTERMEDIATES)/all-event-log-tags.txt $(JAVATAGS) build/make/tools/event_log_tags.py
	$(transform-logtags-to-java)

else
logtags_java_sources :=
endif

##########################################
java_sources := $(addprefix $(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) $(aidl_java_sources) $(logtags_java_sources) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
java_intermediate_sources := $(addprefix $(TARGET_OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))
all_java_sources := $(java_sources) $(java_intermediate_sources)
ALL_MODULES.$(my_register_name).SRCS := $(ALL_MODULES.$(my_register_name).SRCS) $(all_java_sources)

include $(BUILD_SYSTEM)/java_common.mk

include $(BUILD_SYSTEM)/sdk_check.mk

# Set the profile source so that the odex / profile code included from java.mk
# can find it.
#
# TODO: b/64896089, this is broken when called from package_internal.mk, since the file
# we preopt from is a temporary file. This will be addressed in a follow up, possibly
# by disabling stripping for profile guided preopt (which may be desirable for other
# reasons anyway).
#
# Note that we set this only when called from package_internal.mk and not in other cases.
ifneq (,$(called_from_package_internal)
dex_preopt_profile_src_file := $(LOCAL_BUILT_MODULE)
endif

#######################################
# defines built_odex along with rule to install odex
my_manifest_or_apk := $(full_android_manifest)
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
my_manifest_or_apk :=
#######################################

# Make sure there's something to build.
ifdef full_classes_jar
ifndef need_compile_java
$(call pretty-error,Target java module does not define any source or resource files)
endif
endif

# Since we're using intermediates.COMMON, make sure that it gets cleaned
# properly.
$(cleantarget): PRIVATE_CLEAN_FILES += $(intermediates.COMMON)

ifdef full_classes_jar

# Droiddoc isn't currently able to generate stubs for modules, so we're just
# allowing it to use the classes.jar as the "stubs" that would be use to link
# against, for the cases where someone needs the jar to link against.
$(eval $(call copy-one-file,$(full_classes_jar),$(full_classes_stubs_jar)))
ALL_MODULES.$(my_register_name).STUBS := $(full_classes_stubs_jar)

$(full_classes_compiled_jar): PRIVATE_WARNINGS_ENABLE := $(LOCAL_WARNINGS_ENABLE)

# Compile the java files to a .jar file.
# This intentionally depends on java_sources, not all_java_sources.
# Deps for generated source files must be handled separately,
# via deps on the target that generates the sources.

# For user / userdebug builds, strip the local variable table and the local variable
# type table. This has no bearing on stack traces, but will leave less information
# available via JDWP.
ifneq (,$(PRODUCT_MINIMIZE_JAVA_DEBUG_INFO))
ifneq (,$(filter userdebug user,$(TARGET_BUILD_VARIANT)))
LOCAL_JAVACFLAGS+= -g:source,lines
endif
endif

# List of dependencies for anything that needs all java sources in place
java_sources_deps := \
    $(java_sources) \
    $(java_resource_sources) \
    $(LOCAL_SRCJARS) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES)

$(java_source_list_file): $(java_sources_deps) $(NORMALIZE_PATH)
	$(write-java-source-list)

ALL_MODULES.$(my_register_name).SRCJARS := $(LOCAL_SRCJARS)

ifneq ($(TURBINE_ENABLED),false)

$(full_classes_turbine_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS) $(annotation_processor_flags)
$(full_classes_turbine_jar): PRIVATE_SRCJARS := $(LOCAL_SRCJARS)
$(full_classes_turbine_jar): \
    $(java_source_list_file) \
    $(java_sources_deps) \
    $(full_java_header_libs) \
    $(full_java_bootclasspath_libs) \
    $(full_java_system_modules_deps) \
    $(NORMALIZE_PATH) \
    $(JAR_ARGS) \
    $(ZIPTIME) \
    | $(TURBINE) \
    $(MERGE_ZIPS)
	$(transform-java-to-header.jar)

.KATI_RESTAT: $(full_classes_turbine_jar)

# Run jarjar before generate classes-header.jar if necessary.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_header_jarjar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_header_jarjar): $(full_classes_turbine_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	$(call transform-jarjar)
else
full_classes_header_jarjar := $(full_classes_turbine_jar)
endif

$(eval $(call copy-one-file,$(full_classes_header_jarjar),$(full_classes_header_jar)))

endif # TURBINE_ENABLED != false

# TODO(b/143658984): goma can't handle the --system argument to javac.
#$(full_classes_compiled_jar): .KATI_NINJA_POOL := $(GOMA_POOL)
$(full_classes_compiled_jar): .KATI_NINJA_POOL := $(JAVAC_NINJA_POOL)
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS) $(annotation_processor_flags)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_FILES := $(LOCAL_JAR_EXCLUDE_FILES)
$(full_classes_compiled_jar): PRIVATE_JAR_PACKAGES := $(LOCAL_JAR_PACKAGES)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_PACKAGES := $(LOCAL_JAR_EXCLUDE_PACKAGES)
$(full_classes_compiled_jar): PRIVATE_JAVA_SOURCE_LIST := $(java_source_list_file)
$(full_classes_compiled_jar): PRIVATE_ALL_JAVA_HEADER_LIBRARIES := $(full_java_header_libs)
$(full_classes_compiled_jar): PRIVATE_SRCJARS := $(LOCAL_SRCJARS)
$(full_classes_compiled_jar): PRIVATE_SRCJAR_LIST_FILE := $(intermediates.COMMON)/srcjar-list
$(full_classes_compiled_jar): PRIVATE_SRCJAR_INTERMEDIATES_DIR := $(intermediates.COMMON)/srcjars
$(full_classes_compiled_jar): \
    $(java_source_list_file) \
    $(full_java_header_libs) \
    $(java_sources_deps) \
    $(full_java_bootclasspath_libs) \
    $(full_java_system_modules_deps) \
    $(layers_file) \
    $(annotation_processor_deps) \
    $(NORMALIZE_PATH) \
    $(JAR_ARGS) \
    $(ZIPSYNC) \
    $(SOONG_ZIP) \
    | $(SOONG_JAVAC_WRAPPER)
	@echo "Target Java: $@
	$(call compile-java,$(TARGET_JAVAC),$(PRIVATE_ALL_JAVA_HEADER_LIBRARIES))

javac-check : $(full_classes_compiled_jar)
javac-check-$(LOCAL_MODULE) : $(full_classes_compiled_jar)
.PHONY: javac-check-$(LOCAL_MODULE)

$(full_classes_combined_jar): PRIVATE_DONT_DELETE_JAR_META_INF := $(LOCAL_DONT_DELETE_JAR_META_INF)
$(full_classes_combined_jar): $(full_classes_compiled_jar) \
                              $(jar_manifest_file) \
                              $(full_static_java_libs) | $(MERGE_ZIPS)
	$(MERGE_ZIPS) -j --ignore-duplicates $(if $(PRIVATE_JAR_MANIFEST),-m $(PRIVATE_JAR_MANIFEST)) \
            $(if $(PRIVATE_DONT_DELETE_JAR_META_INF),,-stripDir META-INF -zipToNotStrip $<) \
            $@ $< $(PRIVATE_STATIC_JAVA_LIBRARIES)

ifdef LOCAL_JAR_PROCESSOR
# LOCAL_JAR_PROCESSOR_ARGS must be evaluated here to set up the rule-local
# PRIVATE_JAR_PROCESSOR_ARGS variable, but $< and $@ are not available yet.
# Set ${in} and ${out} so they can be referenced by LOCAL_JAR_PROCESSOR_ARGS
# using deferred evaluation (LOCAL_JAR_PROCESSOR_ARGS = instead of :=).
in := $(full_classes_combined_jar)
out := $(full_classes_processed_jar).tmp
my_jar_processor := $(HOST_OUT_JAVA_LIBRARIES)/$(LOCAL_JAR_PROCESSOR).jar

$(full_classes_processed_jar): PRIVATE_JAR_PROCESSOR_ARGS := $(LOCAL_JAR_PROCESSOR_ARGS)
$(full_classes_processed_jar): PRIVATE_JAR_PROCESSOR := $(my_jar_processor)
$(full_classes_processed_jar): PRIVATE_TMP_OUT := $(out)
in :=
out :=

$(full_classes_processed_jar): $(full_classes_combined_jar) $(my_jar_processor)
	@echo Processing $@ with $(PRIVATE_JAR_PROCESSOR)
	$(hide) rm -f $@ $(PRIVATE_TMP_OUT)
	$(hide) $(JAVA) -jar $(PRIVATE_JAR_PROCESSOR) $(PRIVATE_JAR_PROCESSOR_ARGS)
	$(hide) mv $(PRIVATE_TMP_OUT) $@

my_jar_processor :=
else
full_classes_processed_jar := $(full_classes_combined_jar)
endif

# Run jarjar if necessary
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_processed_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	$(call transform-jarjar)
else
full_classes_jarjar_jar := $(full_classes_processed_jar)
endif

$(eval $(call copy-one-file,$(full_classes_jarjar_jar),$(full_classes_jar)))

#######################################
LOCAL_FULL_CLASSES_PRE_JACOCO_JAR := $(full_classes_jar)

include $(BUILD_SYSTEM)/jacoco.mk
#######################################

# Temporarily enable --multi-dex until proguard supports v53 class files
# ( http://b/67673860 ) or we move away from proguard altogether.
LOCAL_DX_FLAGS := $(filter-out --multi-dex,$(LOCAL_DX_FLAGS)) --multi-dex

full_classes_pre_proguard_jar := $(LOCAL_FULL_CLASSES_JACOCO_JAR)

# Keep a copy of the jar just before proguard processing.
$(eval $(call copy-one-file,$(full_classes_pre_proguard_jar),$(intermediates.COMMON)/classes-pre-proguard.jar))

# Run proguard if necessary
ifdef LOCAL_PROGUARD_ENABLED
ifneq ($(filter-out full custom obfuscation optimization,$(LOCAL_PROGUARD_ENABLED)),)
    $(warning while processing: $(LOCAL_MODULE))
    $(error invalid value for LOCAL_PROGUARD_ENABLED: $(LOCAL_PROGUARD_ENABLED))
endif
proguard_dictionary := $(intermediates.COMMON)/proguard_dictionary
proguard_configuration := $(intermediates.COMMON)/proguard_configuration

# When an app contains references to APIs that are not in the SDK specified by
# its LOCAL_SDK_VERSION for example added by support library or by runtime
# classes added by desugar, we artifically raise the "SDK version" "linked" by
# ProGuard, to
# - suppress ProGuard warnings of referencing symbols unknown to the lower SDK version.
# - prevent ProGuard stripping subclass in the support library that extends class added in the higher SDK version.
# See b/20667396
my_proguard_sdk_raise :=
ifdef LOCAL_SDK_VERSION
ifdef TARGET_BUILD_APPS
ifeq (,$(filter current system_current test_current core_current, $(LOCAL_SDK_VERSION)))
  my_proguard_sdk_raise := $(call java-lib-header-files, $(call resolve-prebuilt-sdk-module,current))
endif
else
  # For platform build, we can't just raise to the "current" SDK,
  # that would break apps that use APIs removed from the current SDK.
  my_proguard_sdk_raise := $(call java-lib-header-files,$(LEGACY_CORE_PLATFORM_BOOTCLASSPATH_LIBRARIES) $(FRAMEWORK_LIBRARIES))
endif
ifdef BOARD_SYSTEMSDK_VERSIONS
ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
  # But for vendor or odm apks, don't raise SDK as the apks are required to
  # use SDK APIs only
  my_proguard_sdk_raise :=
endif
endif
endif

legacy_proguard_flags := $(addprefix -libraryjars ,$(my_proguard_sdk_raise) \
  $(filter-out $(my_proguard_sdk_raise), \
    $(full_java_bootclasspath_libs) \
    $(full_shared_java_header_libs)))

legacy_proguard_lib_deps := $(my_proguard_sdk_raise) \
  $(filter-out $(my_proguard_sdk_raise),$(full_java_bootclasspath_libs) $(full_shared_java_header_libs))

legacy_proguard_flags += -printmapping $(proguard_dictionary)
legacy_proguard_flags += -printconfiguration $(proguard_configuration)

common_proguard_flags :=
common_proguard_flag_files := $(BUILD_SYSTEM)/proguard.flags
ifneq ($(LOCAL_INSTRUMENTATION_FOR)$(filter tests,$(LOCAL_MODULE_TAGS)),)
common_proguard_flags += -dontshrink # don't shrink tests by default
endif # test package
ifneq ($(LOCAL_PROGUARD_ENABLED),custom)
  common_proguard_flag_files += $(foreach l,$(LOCAL_STATIC_ANDROID_LIBRARIES),\
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/export_proguard_flags)
endif
ifneq ($(common_proguard_flag_files),)
common_proguard_flags += $(addprefix -include , $(common_proguard_flag_files))
# This is included from $(BUILD_SYSTEM)/proguard.flags
common_proguard_flag_files += $(BUILD_SYSTEM)/proguard_basic_keeps.flags
endif

ifeq ($(filter obfuscation,$(LOCAL_PROGUARD_ENABLED)),)
# By default no obfuscation
common_proguard_flags += -dontobfuscate
endif  # No obfuscation
ifeq ($(filter optimization,$(LOCAL_PROGUARD_ENABLED)),)
# By default no optimization
common_proguard_flags += -dontoptimize
endif  # No optimization

ifdef LOCAL_INSTRUMENTATION_FOR
ifeq ($(filter obfuscation,$(LOCAL_PROGUARD_ENABLED)),)
# If no obfuscation, link in the instrmented package's classes.jar as a library.
# link_instr_classes_jar is defined in base_rule.mk
legacy_proguard_flags += -libraryjars $(link_instr_classes_jar)
legacy_proguard_lib_deps += $(link_instr_classes_jar)
else # obfuscation
# If obfuscation is enabled, the main app must be obfuscated too.
# We need to run obfuscation using the main app's dictionary,
# and treat the main app's class.jar as injars instead of libraryjars.
legacy_proguard_flags := -injars  $(link_instr_classes_jar) \
    -outjars $(intermediates.COMMON)/proguard.$(LOCAL_INSTRUMENTATION_FOR).jar \
    -include $(link_instr_intermediates_dir.COMMON)/proguard_options \
    -applymapping $(link_instr_intermediates_dir.COMMON)/proguard_dictionary \
    -verbose \
    $(legacy_proguard_flags)
legacy_proguard_lib_deps += \
  $(link_instr_classes_jar) \
  $(link_instr_intermediates_dir.COMMON)/proguard_options \
  $(link_instr_intermediates_dir.COMMON)/proguard_dictionary \

# Sometimes (test + main app) uses different keep rules from the main app -
# apply the main app's dictionary anyway.
legacy_proguard_flags += -ignorewarnings

endif # no obfuscation
endif # LOCAL_INSTRUMENTATION_FOR

proguard_flag_files := $(addprefix $(LOCAL_PATH)/, $(LOCAL_PROGUARD_FLAG_FILES))
proguard_flag_files += $(addprefix $(LOCAL_PATH)/, $(LOCAL_R8_FLAG_FILES))
LOCAL_PROGUARD_FLAGS += $(addprefix -include , $(proguard_flag_files))
LOCAL_PROGUARD_FLAGS_DEPS += $(proguard_flag_files)
proguard_flag_files :=

ifdef LOCAL_TEST_MODULE_TO_PROGUARD_WITH
extra_input_jar := $(call intermediates-dir-for,APPS,$(LOCAL_TEST_MODULE_TO_PROGUARD_WITH),,COMMON)/classes.jar
else
extra_input_jar :=
endif

ifneq ($(filter obfuscation,$(LOCAL_PROGUARD_ENABLED)),)
  $(built_dex_intermediate): .KATI_IMPLICIT_OUTPUTS := $(proguard_dictionary) $(proguard_configuration)

  # Make a rule to copy the proguard_dictionary to a packaging directory.
  $(eval $(call copy-one-file,$(proguard_dictionary),\
    $(call local-packaging-dir,proguard_dictionary)/proguard_dictionary))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),\
    $(call local-packaging-dir,proguard_dictionary)/proguard_dictionary)

  $(eval $(call copy-one-file,$(full_classes_pre_proguard_jar),\
    $(call local-packaging-dir,proguard_dictionary)/classes.jar))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),\
    $(call local-packaging-dir,proguard_dictionary)/classes.jar)
endif

endif # LOCAL_PROGUARD_ENABLED defined

ifneq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
$(built_dex_intermediate): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)

ifdef LOCAL_PROGUARD_ENABLED
  $(built_dex_intermediate): .KATI_NINJA_POOL := $(R8_NINJA_POOL)
  $(built_dex_intermediate): PRIVATE_EXTRA_INPUT_JAR := $(extra_input_jar)
  $(built_dex_intermediate): PRIVATE_PROGUARD_FLAGS := $(legacy_proguard_flags) $(common_proguard_flags) $(LOCAL_PROGUARD_FLAGS)
  $(built_dex_intermediate): PRIVATE_PROGUARD_DICTIONARY := $(proguard_dictionary)
  $(built_dex_intermediate) : $(full_classes_pre_proguard_jar) $(extra_input_jar) $(my_proguard_sdk_raise) $(common_proguard_flag_files) $(legacy_proguard_lib_deps) $(R8) $(LOCAL_PROGUARD_FLAGS_DEPS)
	$(transform-jar-to-dex-r8)
else # !LOCAL_PROGUARD_ENABLED
  $(built_dex_intermediate): .KATI_NINJA_POOL := $(D8_NINJA_POOL)
  $(built_dex_intermediate): PRIVATE_D8_LIBS := $(full_java_bootclasspath_libs) $(full_shared_java_header_libs)
  $(built_dex_intermediate): $(full_java_bootclasspath_libs) $(full_shared_java_header_libs)
  $(built_dex_intermediate): $(full_classes_pre_proguard_jar) $(D8) $(ZIP2ZIP)
	$(transform-classes.jar-to-dex)
endif

$(foreach pair,$(PRODUCT_BOOT_JARS), \
  $(if $(filter $(LOCAL_MODULE),$(call word-colon,2,$(pair))), \
    $(call pretty-error,Modules in PRODUCT_BOOT_JARS must be defined in Android.bp files)))

$(built_dex): $(built_dex_intermediate)
	@echo Copying: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $(dir $@)/classes*.dex
	$(hide) cp -fp $(dir $<)/classes*.dex $(dir $@)

java-dex: $(built_dex)

endif # !LOCAL_IS_STATIC_JAVA_LIBRARY

findbugs_xml := $(intermediates.COMMON)/findbugs.xml
$(findbugs_xml): PRIVATE_AUXCLASSPATH := $(addprefix -auxclasspath ,$(strip \
    $(call normalize-path-list,$(filter %.jar,$(full_java_libs)))))
$(findbugs_xml): PRIVATE_FINDBUGS_FLAGS := $(LOCAL_FINDBUGS_FLAGS)
$(findbugs_xml) : $(full_classes_pre_proguard_jar) $(filter %.xml, $(LOCAL_FINDBUGS_FLAGS))
	@echo Findbugs: $@
	$(hide) $(FINDBUGS) -textui -effort:min -xml:withMessages \
		$(PRIVATE_AUXCLASSPATH) $(PRIVATE_FINDBUGS_FLAGS) \
		$< \
		> $@

ALL_FINDBUGS_FILES += $(findbugs_xml)

findbugs_html := $(PRODUCT_OUT)/findbugs/$(LOCAL_MODULE).html
$(findbugs_html) : PRIVATE_XML_FILE := $(findbugs_xml)
$(LOCAL_MODULE)-findbugs : $(findbugs_html)
.PHONY: $(LOCAL_MODULE)-findbugs
$(findbugs_html) : $(findbugs_xml)
	@mkdir -p $(dir $@)
	@echo ConvertXmlToText: $@
	$(hide) $(FINDBUGS_DIR)/convertXmlToText -html:fancy.xsl $(PRIVATE_XML_FILE) \
	> $@

$(LOCAL_MODULE)-findbugs : $(findbugs_html)

endif  # full_classes_jar is defined

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEFAULT_APP_TARGET_SDK := $(call module-target-sdk-version)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SDK_VERSION := $(call module-sdk-version)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MIN_SDK_VERSION := $(call codename-or-sdk-to-sdk,$(call module-min-sdk-version))
