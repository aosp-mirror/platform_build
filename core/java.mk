# Requires:
# LOCAL_MODULE_SUFFIX
# LOCAL_MODULE_CLASS
# all_res_assets

# Make sure there's something to build.
# It's possible to build a package that doesn't contain any classes.
ifeq (,$(strip $(LOCAL_SRC_FILES)$(all_res_assets)))
$(error $(LOCAL_PATH): Target java module does not define any source or resource files)
endif

LOCAL_NO_STANDARD_LIBRARIES:=$(strip $(LOCAL_NO_STANDARD_LIBRARIES))
LOCAL_SDK_VERSION:=$(strip $(LOCAL_SDK_VERSION))

ifneq ($(LOCAL_SDK_VERSION),)
  ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    $(error $(LOCAL_PATH): Must not define both LOCAL_NO_STANDARD_LIBRARIES and LOCAL_SDK_VERSION)
  else
    ifeq ($(strip $(filter $(LOCAL_SDK_VERSION),$(TARGET_AVAILABLE_SDK_VERSIONS))),)
      $(error $(LOCAL_PATH): Invalid LOCAL_SDK_VERSION '$(LOCAL_SDK_VERSION)' \
             Choices are: $(TARGET_AVAILABLE_SDK_VERSIONS))
    else
      LOCAL_JAVA_LIBRARIES := android_stubs_$(LOCAL_SDK_VERSION) $(LOCAL_JAVA_LIBRARIES) 
    endif
  endif
else
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    LOCAL_JAVA_LIBRARIES := core ext framework $(LOCAL_JAVA_LIBRARIES)
  endif
endif

LOCAL_BUILT_MODULE_STEM := $(strip $(LOCAL_BUILT_MODULE_STEM))
ifeq ($(LOCAL_BUILT_MODULE_STEM),)
$(error $(LOCAL_PATH): Target java template must define LOCAL_BUILT_MODULE_STEM)
endif
ifneq ($(filter classes-compiled.jar classes.jar,$(LOCAL_BUILT_MODULE_STEM)),)
$(error LOCAL_BUILT_MODULE_STEM may not be "$(LOCAL_BUILT_MODULE_STEM)")
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

# We use intermediates.COMMON because the classes.jar/.dex files will be
# common even if LOCAL_BUILT_MODULE isn't.
#
# Override some target variables that base_rules set up for us.
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_CLASS_INTERMEDIATES_DIR := $(intermediates.COMMON)/classes
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src

# Since we're using intermediates.COMMON, make sure that it gets cleaned
# properly.
$(cleantarget): PRIVATE_CLEAN_FILES += $(intermediates.COMMON)

# If the module includes java code (i.e., it's not framework-res), compile it.
full_classes_jar :=
built_dex :=
ifneq (,$(strip $(all_java_sources)))

# If LOCAL_BUILT_MODULE_STEM wasn't overridden by our caller,
# full_classes_jar will be the same module as LOCAL_BUILT_MODULE.
# Otherwise, the caller will define it as a prerequisite of
# LOCAL_BUILT_MODULE, so it will inherit the necessary PRIVATE_*
# variable definitions.
full_classes_jar := $(intermediates.COMMON)/classes.jar

# Compile the java files to a .jar file.
# This intentionally depends on java_sources, not all_java_sources.
# Deps for generated source files must be handled separately,
# via deps on the target that generates the sources.
full_classes_compiled_jar := $(intermediates.COMMON)/classes-compiled.jar
$(full_classes_compiled_jar): $(java_sources) $(full_java_lib_deps)
	$(transform-java-to-classes.jar)

# Run jarjar if necessary, otherwise just copy the file.  This is the last
# part of this step, so the output of this command is full_classes_jar.
full_classes_jarjar_jar := $(full_classes_jar)
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_compiled_jar) | jarjar
	@echo JarJar: $@
	$(hide) $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
$(full_classes_jarjar_jar): $(full_classes_compiled_jar) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) $< $@
endif


built_dex := $(intermediates.COMMON)/classes.dex

# Override PRIVATE_INTERMEDIATES_DIR so that install-dex-debug
# will work even when intermediates != intermediates.COMMON.
$(built_dex): PRIVATE_INTERMEDIATES_DIR := $(intermediates.COMMON)
$(built_dex): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(built_dex): $(full_classes_jar) $(DX)
	$(transform-classes.jar-to-dex)
ifneq ($(GENERATE_DEX_DEBUG),)
	$(install-dex-debug)
endif

findbugs_xml := $(intermediates.COMMON)/findbugs.xml
$(findbugs_xml) : PRIVATE_JAR_FILE := $(full_classes_jar)
$(findbugs_xml) : PRIVATE_AUXCLASSPATH := $(addprefix -auxclasspath ,$(strip \
								$(call normalize-path-list,$(filter %.jar,\
										$(full_java_libs)))))
# We can't depend directly on full_classes_jar because the PRIVATE_
# vars won't be set up correctly.
$(findbugs_xml) : $(LOCAL_BUILT_MODULE)
	@echo Findbugs: $@
	$(hide) $(FINDBUGS) -textui -effort:min -xml:withMessages \
		$(PRIVATE_AUXCLASSPATH) \
		$(PRIVATE_JAR_FILE) \
		> $@

ALL_FINDBUGS_FILES += $(findbugs_xml)

findbugs_html := $(PRODUCT_OUT)/findbugs/$(LOCAL_MODULE).html
$(findbugs_html) : PRIVATE_XML_FILE := $(findbugs_xml)
$(LOCAL_MODULE)-findbugs : $(findbugs_html)
$(findbugs_html) : $(findbugs_xml)
	@mkdir -p $(dir $@)
	@echo UnionBugs: $@
	$(hide) prebuilt/common/findbugs/bin/unionBugs $(PRIVATE_XML_FILE) \
	| prebuilt/common/findbugs/bin/convertXmlToText -html:fancy.xsl \
	> $@

$(LOCAL_MODULE)-findbugs : $(findbugs_html)

endif
