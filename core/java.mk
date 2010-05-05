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
      ifeq ($(LOCAL_SDK_VERSION),current)
        LOCAL_JAVA_LIBRARIES := android_stubs_$(LOCAL_SDK_VERSION) $(LOCAL_JAVA_LIBRARIES)
      else
        LOCAL_JAVA_LIBRARIES := sdk_v$(LOCAL_SDK_VERSION) $(LOCAL_JAVA_LIBRARIES)
      endif
    endif
  endif
else
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    LOCAL_JAVA_LIBRARIES := core core-junit ext framework $(LOCAL_JAVA_LIBRARIES)
  endif
endif
LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES))

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

# This is cleared below, and re-set if we really need it.
full_classes_jar := $(intermediates.COMMON)/classes.jar

# Emma source code coverage
ifneq ($(EMMA_INSTRUMENT),true)
LOCAL_NO_EMMA_INSTRUMENT := true
LOCAL_NO_EMMA_COMPILE := true
endif

# Choose leaf name for the compiled jar file.
ifneq ($(LOCAL_NO_EMMA_COMPILE),true)
full_classes_compiled_jar_leaf := classes-no-debug-var.jar
built_dex_leaf := classes-no-local.dex
else
full_classes_compiled_jar_leaf := classes-full-debug.jar
built_dex_leaf := classes-with-local.dex
endif
full_classes_compiled_jar := $(intermediates.COMMON)/$(full_classes_compiled_jar_leaf)
built_dex_intermediate := $(intermediates.COMMON)/$(built_dex_leaf)

emma_intermediates_dir := $(intermediates.COMMON)/emma_out
# the 'lib/$(full_classes_compiled_jar_leaf)' portion of this path is fixed in
# the emma tool
full_classes_emma_jar := $(emma_intermediates_dir)/lib/$(full_classes_compiled_jar_leaf)
full_classes_stubs_jar := $(intermediates.COMMON)/stubs.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_full_names_jar := $(intermediates.COMMON)/classes-full-names.jar
full_classes_proguard_jar := $(full_classes_jar)
built_dex := $(intermediates.COMMON)/classes.dex

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_jar) \
    $(full_classes_compiled_jar) \
    $(full_classes_emma_jar) \
    $(full_classes_full_names_jar) \
    $(full_classes_stubs_jar) \
    $(full_classes_jarjar_jar) \
    $(built_dex) \
    $(built_dex_intermediate)


# TODO: It looks like the only thing we need from base_rules is
# all_java_sources.  See if we can get that by adding a
# common_java.mk, and moving the include of base_rules.mk to
# after all the declarations.

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
built_dex := $(intermediates.COMMON)/classes.dex

# Droiddoc isn't currently able to generate stubs for modules, so we're just
# allowing it to use the classes.jar as the "stubs" that would be use to link
# against, for the cases where someone needs the jar to link against.
# - Use the classes.jar instead of the handful of other intermediates that
#   we have, because it's the most processed, but still hasn't had dex run on
#   it, so it's closest to what's on the device.
# - This extra copy, with the dependency on LOCAL_BUILT_MODULE allows the
#   PRIVATE_ vars to be preserved.
$(full_classes_stubs_jar): PRIVATE_SOURCE_FILE := $(full_classes_jar)
$(full_classes_stubs_jar) : $(LOCAL_BUILT_MODULE) | $(ACP)
	@echo Copying $(PRIVATE_SOURCE_FILE)
	$(hide) $(ACP) -fp $(PRIVATE_SOURCE_FILE) $@
ALL_MODULES.$(LOCAL_MODULE).STUBS := $(full_classes_stubs_jar)

# Compile the java files to a .jar file.
# This intentionally depends on java_sources, not all_java_sources.
# Deps for generated source files must be handled separately,
# via deps on the target that generates the sources.
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS)
$(full_classes_compiled_jar): $(java_sources) $(full_java_lib_deps)
	$(transform-java-to-classes.jar)

# All of the rules after full_classes_compiled_jar are very unlikely
# to fail except for bugs in their respective tools.  If you would
# like to run these rules, add the "all" modifier goal to the make
# command line.
# This overwrites the value defined in base_rules.mk.  That's a little
# dirty.  It's preferable to set LOCAL_CHECKED_MODULE, but this has to
# be done after the inclusion of base_rules.mk.
ALL_MODULES.$(LOCAL_MODULE).CHECKED := $(full_classes_compiled_jar)

$(full_classes_compiled_jar): PRIVATE_JAVAC_DEBUG_FLAGS := -g

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# Skip adding emma instrumentation to class files if this is a static library,
# since it will be instrumented by the package that includes it
LOCAL_NO_EMMA_INSTRUMENT:= true
endif

ifneq ($(LOCAL_NO_EMMA_INSTRUMENT),true)
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILE := $(intermediates.COMMON)/coverage.em
$(full_classes_emma_jar): PRIVATE_EMMA_INTERMEDIATES_DIR := $(emma_intermediates_dir)
# module level coverage filter can be defined using LOCAL_EMMA_COVERAGE_FILTER
# in Android.mk
ifdef LOCAL_EMMA_COVERAGE_FILTER
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILTER := $(LOCAL_EMMA_COVERAGE_FILTER)
else
# by default, avoid applying emma instrumentation onto emma classes itself,
# otherwise there will be exceptions thrown
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILTER := *,-emma,-emmarun,-com.vladium.*
endif
# this rule will generate both $(PRIVATE_EMMA_COVERAGE_FILE) and
# $(full_classes_emma_jar)
$(full_classes_emma_jar): $(full_classes_compiled_jar) | $(EMMA_JAR)
	$(transform-classes.jar-to-emma)
$(PRIVATE_EMMA_COVERAGE_FILE): $(full_classes_emma_jar)

# tell proguard to load emma jar
LOCAL_PROGUARD_FLAGS := $(LOCAL_PROGUARD_FLAGS) $(addprefix -libraryjars ,$(EMMA_JAR))
else
$(full_classes_emma_jar): $(full_classes_compiled_jar) | $(ACP)
	@echo Copying: $<
	$(copy-file-to-target)
endif

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_emma_jar) | $(JARJAR)
	@echo JarJar: $@
	$(hide) java -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
$(full_classes_jarjar_jar): $(full_classes_emma_jar) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) $< $@
endif

# Keep a copy of the jar just before proguard processing.
$(full_classes_full_names_jar): $(full_classes_jarjar_jar) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) $< $@

# Run proguard if necessary, otherwise just copy the file.  This is the last
# part of this step, so the output of this command is full_classes_jar.
proguard_dictionary := $(intermediates.COMMON)/proguard_dictionary
# Proguard doesn't like a class in both library and the jar to be processed.
proguard_full_java_libs := $(filter-out $(full_static_java_libs),$(full_java_libs))
proguard_flags := $(addprefix -libraryjars ,$(proguard_full_java_libs)) \
                  -include $(BUILD_SYSTEM)/proguard.flags \
                  -forceprocessing \
                  -printmapping $(proguard_dictionary)
# If this is a test package, add proguard keep flags for tests.
ifneq ($(strip $(LOCAL_INSTRUMENTATION_FOR)$(filter tests,$(LOCAL_MODULE_TAGS))$(filter android.test.runner,$(LOCAL_JAVA_LIBRARIES))),)
proguard_flags := $(proguard_flags) -include $(BUILD_SYSTEM)/proguard_tests.flags
endif # test package

LOCAL_PROGUARD_ENABLED:=$(strip $(LOCAL_PROGUARD_ENABLED))
ifeq ($(LOCAL_PROGUARD_ENABLED),disabled)
    LOCAL_PROGUARD_ENABLED :=
endif
ifneq ($(LOCAL_PROGUARD_ENABLED),)
ifeq ($(LOCAL_PROGUARD_ENABLED),full)
    # full
else
ifeq ($(LOCAL_PROGUARD_ENABLED),optonly)
    # optonly
    proguard_flags += -dontobfuscate
else
ifeq ($(LOCAL_PROGUARD_ENABLED),custom)
    # custom
else
    $(warning while processing: $(LOCAL_MODULE))
    $(error invalid value for LOCAL_PROGUARD_ENABLED: $(LOCAL_PROGUARD_ENABLED))
endif # custom
endif # optonly
endif # full
endif # LOCAL_PROGUARD_ENABLED

$(full_classes_proguard_jar): PRIVATE_PROGUARD_ENABLED:=$(LOCAL_PROGUARD_ENABLED)
$(full_classes_proguard_jar): PRIVATE_PROGUARD_FLAGS := $(proguard_flags) $(LOCAL_PROGUARD_FLAGS)
$(full_classes_proguard_jar): PRIVATE_INSTRUMENTATION_FOR:=$(strip $(LOCAL_INSTRUMENTATION_FOR))

$(full_classes_proguard_jar): $(full_classes_full_names_jar) | $(ACP) $(PROGUARD)
	$(call transform-jar-to-proguard)

ALL_MODULES.$(LOCAL_MODULE).PROGUARD_ENABLED:=$(LOCAL_PROGUARD_ENABLED)

# If you instrument class files that have local variable debug information in
# them emma does not correctly maintain the local variable table.
# This will cause an error when you try to convert the class files for Android.
# The workaround here is to build different dex file here based on emma switch
# then later copy into classes.dex. When emma is on, dx is run with --no-locals
# option to remove local variable information

# Override PRIVATE_INTERMEDIATES_DIR so that install-dex-debug
# will work even when intermediates != intermediates.COMMON.
$(built_dex_intermediate): PRIVATE_INTERMEDIATES_DIR := $(intermediates.COMMON)
$(built_dex_intermediate): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
ifneq ($(LOCAL_NO_EMMA_COMPILE),true)
$(built_dex_intermediate): PRIVATE_DX_FLAGS += --no-locals
endif
$(built_dex_intermediate): $(full_classes_jar) $(DX)
	$(transform-classes.jar-to-dex)
$(built_dex): $(built_dex_intermediate) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) $< $@
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
	@echo ConvertXmlToText: $@
	$(hide) prebuilt/common/findbugs/bin/convertXmlToText -html:fancy.xsl $(PRIVATE_XML_FILE) \
	> $@

$(LOCAL_MODULE)-findbugs : $(findbugs_html)

endif
