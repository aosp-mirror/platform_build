# Common to host and target Java modules.

my_soong_problems :=

ifneq ($(filter ../%,$(LOCAL_SRC_FILES)),)
my_soong_problems += dotdot_srcs
endif

###########################################################
## Java version
###########################################################
# Use the LOCAL_JAVA_LANGUAGE_VERSION if it is set, otherwise
# use one based on the LOCAL_SDK_VERSION. If it is < 24
# pass "1.7" to the tools, if it is unset, >= 24 or "current"
# pass "1.8".
#
# The LOCAL_SDK_VERSION behavior is to ensure that, by default,
# code that is expected to run on older releases of Android
# does not use any 1.8 language features that are not supported
# on earlier runtimes (like default / static interface methods).
# Modules can override this logic by specifying
# LOCAL_JAVA_LANGUAGE_VERSION explicitly.
ifeq (,$(LOCAL_JAVA_LANGUAGE_VERSION))
  ifdef LOCAL_IS_HOST_MODULE
    # Host modules always default to 1.9
    LOCAL_JAVA_LANGUAGE_VERSION := 1.9
  else
    ifneq (,$(filter $(LOCAL_SDK_VERSION), $(TARGET_SDK_VERSIONS_WITHOUT_JAVA_1_8_SUPPORT)))
      LOCAL_JAVA_LANGUAGE_VERSION := 1.7
    else ifneq (,$(filter $(LOCAL_SDK_VERSION), $(TARGET_SDK_VERSIONS_WITHOUT_JAVA_1_9_SUPPORT)))
      LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    else ifneq (,$(filter $(LOCAL_SDK_VERSION), $(TARGET_SDK_VERSIONS_WITHOUT_JAVA_11_SUPPORT)))
      LOCAL_JAVA_LANGUAGE_VERSION := 1.9
    else ifneq (,$(filter $(LOCAL_SDK_VERSION), $(TARGET_SDK_VERSIONS_WITHOUT_JAVA_17_SUPPORT)))
      LOCAL_JAVA_LANGUAGE_VERSION := 11
    else ifneq (,$(LOCAL_SDK_VERSION)$(TARGET_BUILD_USE_PREBUILT_SDKS))
      # TODO(ccross): allow 1.9 for current and unbundled once we have SDK system modules
      LOCAL_JAVA_LANGUAGE_VERSION := 1.8
    else
      LOCAL_JAVA_LANGUAGE_VERSION := 17
    endif
  endif
endif
LOCAL_JAVACFLAGS += -source $(LOCAL_JAVA_LANGUAGE_VERSION) -target $(LOCAL_JAVA_LANGUAGE_VERSION)

###########################################################

# OpenJDK versions up to 8 shipped with bootstrap and tools jars
# (rt.jar, jce.jar, tools.jar etc.). These are no longer part of
# OpenJDK 9, but we still make them available for host tools that
# are targeting older versions.
USE_HOST_BOOTSTRAP_JARS := true
ifeq (,$(filter $(LOCAL_JAVA_LANGUAGE_VERSION), 1.6 1.7 1.8))
USE_HOST_BOOTSTRAP_JARS := false
endif

###########################################################

# Drop HOST_JDK_TOOLS_JAR from classpath when targeting versions > 9 (which don't have it).
# TODO: Remove HOST_JDK_TOOLS_JAR and all references to it once host
# bootstrap jars are no longer supported (ie. when USE_HOST_BOOTSTRAP_JARS
# is always false). http://b/38418220
ifneq ($(USE_HOST_BOOTSTRAP_JARS),true)
LOCAL_CLASSPATH := $(filter-out $(HOST_JDK_TOOLS_JAR),$(LOCAL_CLASSPATH))
endif

###########################################################
## .proto files: Compile proto files to .java
###########################################################
ifeq ($(strip $(LOCAL_PROTOC_OPTIMIZE_TYPE)),)
  LOCAL_PROTOC_OPTIMIZE_TYPE := lite
endif
proto_sources := $(filter %.proto,$(LOCAL_SRC_FILES))
ifneq ($(proto_sources),)
proto_sources_fullpath := $(addprefix $(LOCAL_PATH)/, $(proto_sources))

proto_java_intemediate_dir := $(intermediates.COMMON)/proto
proto_java_sources_dir := $(proto_java_intemediate_dir)/src
proto_java_srcjar := $(intermediates.COMMON)/proto.srcjar

LOCAL_SRCJARS += $(proto_java_srcjar)

$(proto_java_srcjar): PRIVATE_PROTO_INCLUDES := $(TOP)
$(proto_java_srcjar): PRIVATE_PROTO_SRC_FILES := $(proto_sources_fullpath)
$(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_DIR := $(proto_java_sources_dir)
$(proto_java_srcjar): PRIVATE_PROTOC_FLAGS := $(LOCAL_PROTOC_FLAGS)
ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),micro)
  $(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javamicro_out
  $(proto_java_srcjar): PRIVATE_PROTOC_FLAGS += --plugin=$(HOST_OUT_EXECUTABLES)/protoc-gen-javamicro
  $(proto_java_srcjar): $(HOST_OUT_EXECUTABLES)/protoc-gen-javamicro
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
  $(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javanano_out
  $(proto_java_srcjar): PRIVATE_PROTOC_FLAGS += --plugin=$(HOST_OUT_EXECUTABLES)/protoc-gen-javanano
  $(proto_java_srcjar): $(HOST_OUT_EXECUTABLES)/protoc-gen-javanano
else ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),stream)
  $(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javastream_out
  $(proto_java_srcjar): PRIVATE_PROTOC_FLAGS += --plugin=$(HOST_OUT_EXECUTABLES)/protoc-gen-javastream
  $(proto_java_srcjar): $(HOST_OUT_EXECUTABLES)/protoc-gen-javastream
else
  $(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --java_out
endif
$(proto_java_srcjar): PRIVATE_PROTO_JAVA_OUTPUT_PARAMS := $(if $(filter lite,$(LOCAL_PROTOC_OPTIMIZE_TYPE)),lite$(if $(LOCAL_PROTO_JAVA_OUTPUT_PARAMS),:,),)$(LOCAL_PROTO_JAVA_OUTPUT_PARAMS)
$(proto_java_srcjar) : $(proto_sources_fullpath) $(PROTOC) $(SOONG_ZIP)
	$(call transform-proto-to-java)

#TODO: protoc should output the dependencies introduced by imports.

ALL_MODULES.$(my_register_name).PROTO_FILES := $(proto_sources_fullpath)
endif # proto_sources

#########################################
## Java resources

# Look for resource files in any specified directories.
# Non-java and non-doc files will be picked up as resources
# and included in the output jar file.
java_resource_file_groups :=

LOCAL_JAVA_RESOURCE_DIRS := $(strip $(LOCAL_JAVA_RESOURCE_DIRS))
ifneq ($(LOCAL_JAVA_RESOURCE_DIRS),)
  # This makes a list of words like
  #     <dir1>::<file1>:<file2> <dir2>::<file1> <dir3>:
  # where each of the files is relative to the directory it's grouped with.
  # Directories that don't contain any resource files will result in groups
  # that end with a colon, and they are stripped out in the next step.
  java_resource_file_groups += \
    $(foreach dir,$(LOCAL_JAVA_RESOURCE_DIRS), \
	$(subst $(space),:,$(strip \
		$(LOCAL_PATH)/$(dir): \
	    $(patsubst ./%,%,$(sort $(shell cd $(LOCAL_PATH)/$(dir) && \
		find . \
		    -type d -a -name ".svn" -prune -o \
		    -type f \
			-a \! -name "*.java" \
			-a \! -name "package.html" \
			-a \! -name "overview.html" \
			-a \! -name ".*.swp" \
			-a \! -name ".DS_Store" \
			-a \! -name "*~" \
			-print \
		    ))) \
	)) \
    )
  java_resource_file_groups := $(filter-out %:,$(java_resource_file_groups))
endif # LOCAL_JAVA_RESOURCE_DIRS

ifneq ($(LOCAL_JAVA_RESOURCE_FILES),)
  # Converts LOCAL_JAVA_RESOURCE_FILES := <file> to $(dir $(file))::$(notdir $(file))
  # and LOCAL_JAVA_RESOURCE_FILES := <dir>:<file> to <dir>::<file>
  java_resource_file_groups += $(strip $(foreach res,$(LOCAL_JAVA_RESOURCE_FILES), \
    $(eval _file := $(call word-colon,2,$(res))) \
    $(if $(_file), \
      $(eval _base := $(call word-colon,1,$(res))), \
      $(eval _base := $(dir $(res))) \
        $(eval _file := $(notdir $(res)))) \
    $(if $(filter /%, \
      $(filter-out $(OUT_DIR)/%,$(_base) $(_file))), \
        $(call pretty-error,LOCAL_JAVA_RESOURCE_FILES may not include absolute paths: $(_base) $(_file))) \
    $(patsubst %/,%,$(_base))::$(_file)))

endif # LOCAL_JAVA_RESOURCE_FILES

ifdef java_resource_file_groups
  # The full paths to all resources, used for dependencies.
  java_resource_sources := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix $(word 1,$(subst :,$(space),$(group)))/, \
	    $(wordlist 2,9999,$(subst :,$(space),$(group))) \
	) \
    )
  # The arguments to jar that will include these files in a jar file.
  # Quote the file name to handle special characters (such as #) correctly.
  extra_jar_args := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix -C "$(word 1,$(subst :,$(space),$(group)))" , \
	    $(foreach w, $(wordlist 2,9999,$(subst :,$(space),$(group))), "$(w)" ) \
	) \
    )
  java_resource_file_groups :=
else
  java_resource_sources :=
  extra_jar_args :=
endif # java_resource_file_groups

#####################################
## Warn if there is unrecognized file in LOCAL_SRC_FILES.
my_unknown_src_files := $(filter-out \
  %.java %.aidl %.proto %.logtags, \
  $(LOCAL_SRC_FILES) $(LOCAL_INTERMEDIATE_SOURCES) $(LOCAL_GENERATED_SOURCES))
ifneq ($(my_unknown_src_files),)
$(warning $(LOCAL_MODULE_MAKEFILE): $(LOCAL_MODULE): Unused source files: $(my_unknown_src_files))
endif

######################################
## PRIVATE java vars
# LOCAL_SOURCE_FILES_ALL_GENERATED is set only if the module does not have static source files,
# but generated source files.
# You have to set up the dependency in some other way.
need_compile_java := $(strip $(all_java_sources)$(LOCAL_SRCJARS)$(all_res_assets)$(java_resource_sources))$(LOCAL_STATIC_JAVA_LIBRARIES)$(filter true,$(LOCAL_SOURCE_FILES_ALL_GENERATED))
ifdef need_compile_java

annotation_processor_flags :=
annotation_processor_deps :=
annotation_processor_jars :=

# If error prone is enabled then add LOCAL_ERROR_PRONE_FLAGS to LOCAL_JAVACFLAGS
ifeq ($(RUN_ERROR_PRONE),true)
annotation_processor_jars += $(ERROR_PRONE_JARS)
LOCAL_JAVACFLAGS += $(ERROR_PRONE_FLAGS)
LOCAL_JAVACFLAGS += '-Xplugin:ErrorProne $(ERROR_PRONE_CHECKS) $(LOCAL_ERROR_PRONE_FLAGS)'
endif

ifdef LOCAL_ANNOTATION_PROCESSORS
  annotation_processor_jars += $(call java-lib-files,$(LOCAL_ANNOTATION_PROCESSORS),true)

  # b/25860419: annotation processors must be explicitly specified for grok
  annotation_processor_flags += $(foreach class,$(LOCAL_ANNOTATION_PROCESSOR_CLASSES),-processor $(class))
endif

ifneq (,$(strip $(annotation_processor_jars)))
annotation_processor_flags += -processorpath $(call normalize-path-list,$(annotation_processor_jars))
annotation_processor_deps += $(annotation_processor_jars)
endif

full_static_java_libs := $(call java-lib-files,$(LOCAL_STATIC_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
full_static_java_header_libs := $(call java-lib-header-files,$(LOCAL_STATIC_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JAVA_LIBRARIES := $(full_static_java_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JAVA_HEADER_LIBRARIES := $(full_static_java_header_libs)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASSET_DIR := $(LOCAL_ASSET_DIR)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CLASS_INTERMEDIATES_DIR := $(intermediates.COMMON)/classes
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ANNO_INTERMEDIATES_DIR := $(intermediates.COMMON)/anno
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_HAS_RS_SOURCES :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_SOURCES := $(all_java_sources)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_SOURCE_LIST := $(java_source_list_file)

# Quickly check class path vars.
disallowed_deps := $(foreach sdk,$(TARGET_AVAILABLE_SDK_VERSIONS),$(call resolve-prebuilt-sdk-module,$(sdk)))
disallowed_deps += $(foreach sdk,$(TARGET_AVAILABLE_SDK_VERSIONS),\
  $(foreach sdk_lib,$(JAVA_SDK_LIBRARIES),$(call resolve-prebuilt-sdk-module,$(sdk),$(sdk_lib))))
bad_deps := $(filter $(disallowed_deps),$(LOCAL_JAVA_LIBRARIES) $(LOCAL_STATIC_JAVA_LIBRARIES))
ifneq (,$(bad_deps))
  $(call pretty-error,SDK modules should not be depended on directly. Please use LOCAL_SDK_VERSION for $(bad_deps))
endif

full_java_bootclasspath_libs :=
empty_bootclasspath :=
my_system_modules :=
exported_sdk_libs_files :=
my_exported_sdk_libs_file :=

ifndef LOCAL_IS_HOST_MODULE
  sdk_libs :=

  # When an sdk lib name is listed in LOCAL_JAVA_LIBRARIES, move it to LOCAL_SDK_LIBRARIES, so that
  # it is correctly redirected to the stubs library.
  LOCAL_SDK_LIBRARIES += $(filter $(JAVA_SDK_LIBRARIES),$(LOCAL_JAVA_LIBRARIES))
  LOCAL_JAVA_LIBRARIES := $(filter-out $(JAVA_SDK_LIBRARIES),$(LOCAL_JAVA_LIBRARIES))

  ifeq ($(LOCAL_SDK_VERSION),)
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      # No bootclasspath. But we still need "" to prevent javac from using default host bootclasspath.
      empty_bootclasspath := ""
      # Most users of LOCAL_NO_STANDARD_LIBRARIES really mean no framework libs,
      # and manually add back the core libs.  The ones that don't are in soong
      # now, so just always assume that they want the default system modules
      my_system_modules := $(LEGACY_CORE_PLATFORM_SYSTEM_MODULES)
    else  # LOCAL_NO_STANDARD_LIBRARIES
      full_java_bootclasspath_libs := $(call java-lib-header-files,$(LEGACY_CORE_PLATFORM_BOOTCLASSPATH_LIBRARIES) $(FRAMEWORK_LIBRARIES))
      LOCAL_JAVA_LIBRARIES := $(filter-out $(LEGACY_CORE_PLATFORM_BOOTCLASSPATH_LIBRARIES) $(FRAMEWORK_LIBRARIES),$(LOCAL_JAVA_LIBRARIES))
      my_system_modules := $(LEGACY_CORE_PLATFORM_SYSTEM_MODULES)
    endif  # LOCAL_NO_STANDARD_LIBRARIES

    ifneq (,$(TARGET_BUILD_USE_PREBUILT_SDKS))
      sdk_libs := $(foreach lib_name,$(LOCAL_SDK_LIBRARIES),$(call resolve-prebuilt-sdk-module,system_current,$(lib_name)))
    else
      # When SDK libraries are referenced from modules built without SDK, provide the all APIs to them
      sdk_libs := $(foreach lib_name,$(LOCAL_SDK_LIBRARIES),$(lib_name))
    endif
  else
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      $(call pretty-error,Must not define both LOCAL_NO_STANDARD_LIBRARIES and LOCAL_SDK_VERSION)
    endif
    ifeq ($(strip $(filter $(LOCAL_SDK_VERSION),$(TARGET_AVAILABLE_SDK_VERSIONS))),)
      $(call pretty-error,Invalid LOCAL_SDK_VERSION '$(LOCAL_SDK_VERSION)' \
             Choices are: $(TARGET_AVAILABLE_SDK_VERSIONS))
    endif

    ifneq (,$(TARGET_BUILD_USE_PREBUILT_SDKS)$(filter-out %current,$(LOCAL_SDK_VERSION)))
      # TARGET_BUILD_USE_PREBUILT_SDKS mode or numbered SDK. Use prebuilt modules.
      sdk_module := $(call resolve-prebuilt-sdk-module,$(LOCAL_SDK_VERSION))
      sdk_libs := $(foreach lib_name,$(LOCAL_SDK_LIBRARIES),$(call resolve-prebuilt-sdk-module,$(LOCAL_SDK_VERSION),$(lib_name)))
    else
      # Note: the lib naming scheme must be kept in sync with build/soong/java/sdk_library.go.
      sdk_lib_suffix = $(call pretty-error,sdk_lib_suffix was not set correctly)
      ifeq (current,$(LOCAL_SDK_VERSION))
        sdk_module := $(ANDROID_PUBLIC_STUBS)
        sdk_lib_suffix := .stubs
      else ifeq (system_current,$(LOCAL_SDK_VERSION))
        sdk_module := $(ANDROID_SYSTEM_STUBS)
        sdk_lib_suffix := .stubs.system
      else ifeq (test_current,$(LOCAL_SDK_VERSION))
        sdk_module := $(ANDROID_TEST_STUBS)
        sdk_lib_suffix := .stubs.test
      else ifeq (core_current,$(LOCAL_SDK_VERSION))
        sdk_module := $(ANDROID_CORE_STUBS)
        sdk_lib_suffix = $(call pretty-error,LOCAL_SDK_LIBRARIES not supported for LOCAL_SDK_VERSION = core_current)
      endif
      sdk_libs := $(foreach lib_name,$(LOCAL_SDK_LIBRARIES),$(lib_name)$(sdk_lib_suffix))
    endif
    full_java_bootclasspath_libs := $(call java-lib-header-files,$(sdk_module))
  endif # LOCAL_SDK_VERSION

  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    ifneq ($(LOCAL_MODULE),jacocoagent)
      ifeq ($(EMMA_INSTRUMENT),true)
        ifneq ($(EMMA_INSTRUMENT_STATIC),true)
          # For instrumented build, if Jacoco is not being included statically
          # in instrumented packages then include Jacoco classes into the
          # bootclasspath.
          full_java_bootclasspath_libs += $(call java-lib-header-files,jacocoagent)
        endif # EMMA_INSTRUMENT_STATIC
      endif # EMMA_INSTRUMENT
    endif # LOCAL_MODULE == jacocoagent
  endif # LOCAL_NO_STANDARD_LIBRARIES

  # In order to compile lambda code javac requires various invokedynamic-
  # related classes to be present. This change adds stubs needed for
  # javac to compile lambdas.
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    ifdef TARGET_BUILD_USE_PREBUILT_SDKS
      full_java_bootclasspath_libs += $(call java-lib-header-files,sdk-core-lambda-stubs)
    else
      full_java_bootclasspath_libs += $(call java-lib-header-files,core-lambda-stubs)
    endif
  endif
  full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES) $(sdk_libs),$(LOCAL_IS_HOST_MODULE))
  full_shared_java_header_libs := $(call java-lib-header-files,$(LOCAL_JAVA_LIBRARIES) $(sdk_libs),$(LOCAL_IS_HOST_MODULE))
  sdk_libs :=

  # Files that contains the names of SDK libraries exported from dependencies. These will be re-exported.
  # Note: No need to consider LOCAL_*_ANDROID_LIBRARIES and LOCAL_STATIC_JAVA_AAR_LIBRARIES. They are all appended to
  # LOCAL_*_JAVA_LIBRARIES in java.mk
  exported_sdk_libs_files := $(call exported-sdk-libs-files,$(LOCAL_JAVA_LIBRARIES) $(LOCAL_STATIC_JAVA_LIBRARIES))
  # The file that contains the names of all SDK libraries that this module exports and re-exports
  my_exported_sdk_libs_file := $(call local-intermediates-dir,COMMON)/exported-sdk-libs

else # LOCAL_IS_HOST_MODULE

  ifeq ($(USE_CORE_LIB_BOOTCLASSPATH),true)
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      empty_bootclasspath := ""
    else
      full_java_bootclasspath_libs := $(call java-lib-header-files,$(addsuffix -hostdex,$(LEGACY_CORE_PLATFORM_BOOTCLASSPATH_LIBRARIES)),true)
    endif

    my_system_modules := $(LEGACY_CORE_PLATFORM_SYSTEM_MODULES)
    full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),true)
    full_shared_java_header_libs := $(call java-lib-header-files,$(LOCAL_JAVA_LIBRARIES),true)
  else # !USE_CORE_LIB_BOOTCLASSPATH
    # Give host-side tools a version of OpenJDK's standard libraries
    # close to what they're targeting. As of Dec 2017, AOSP is only
    # bundling OpenJDK 8 and 9, so nothing < 8 is available.
    #
    # When building with OpenJDK 8, the following should have no
    # effect since those jars would be available by default.
    #
    # When building with OpenJDK 9 but targeting a version < 1.8,
    # putting them on the bootclasspath means that:
    # a) code can't (accidentally) refer to OpenJDK 9 specific APIs
    # b) references to existing APIs are not reinterpreted in an
    #    OpenJDK 9-specific way, eg. calls to subclasses of
    #    java.nio.Buffer as in http://b/70862583
    ifeq ($(USE_HOST_BOOTSTRAP_JARS),true)
      full_java_bootclasspath_libs += $(ANDROID_JAVA8_HOME)/jre/lib/jce.jar
      full_java_bootclasspath_libs += $(ANDROID_JAVA8_HOME)/jre/lib/rt.jar
    endif
    full_shared_java_libs := $(addprefix $(HOST_OUT_JAVA_LIBRARIES)/,\
      $(addsuffix $(COMMON_JAVA_PACKAGE_SUFFIX),$(LOCAL_JAVA_LIBRARIES)))
    full_shared_java_header_libs := $(full_shared_java_libs)
  endif # USE_CORE_LIB_BOOTCLASSPATH
endif # !LOCAL_IS_HOST_MODULE

# (b/204397180) Record ALL_DEPS by default.
ALL_MODULES.$(my_register_name).ALL_DEPS := $(ALL_MODULES.$(my_register_name).ALL_DEPS) $(full_java_bootclasspath_libs)

# Export the SDK libs. The sdk library names listed in LOCAL_SDK_LIBRARIES are first exported.
# Then sdk library names exported from dependencies are all re-exported.
$(my_exported_sdk_libs_file): PRIVATE_EXPORTED_SDK_LIBS_FILES := $(exported_sdk_libs_files)
$(my_exported_sdk_libs_file): PRIVATE_SDK_LIBS := $(sort $(LOCAL_SDK_LIBRARIES))
$(my_exported_sdk_libs_file): $(exported_sdk_libs_files)
	@echo "Export SDK libs $@"
	$(hide) mkdir -p $(dir $@) && rm -f $@ $@.temp
	$(if $(PRIVATE_SDK_LIBS),\
		echo $(PRIVATE_SDK_LIBS) | tr ' ' '\n' > $@.temp,\
		touch $@.temp)
	$(if $(PRIVATE_EXPORTED_SDK_LIBS_FILES),\
		cat $(PRIVATE_EXPORTED_SDK_LIBS_FILES) >> $@.temp)
	$(hide) cat $@.temp | sort -u > $@
	$(hide) rm -f $@.temp

ifdef empty_bootclasspath
  ifdef full_java_bootclasspath_libs
    $(call pretty-error,internal error: empty_bootclasspath and full_java_bootclasspath_libs should not both be set)
  endif
endif

full_java_system_modules_deps :=
my_system_modules_dir :=
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_USE_SYSTEM_MODULES :=
ifeq (,$(filter $(LOCAL_JAVA_LANGUAGE_VERSION),$(JAVA_LANGUAGE_VERSIONS_WITHOUT_SYSTEM_MODULES)))
  $(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_USE_SYSTEM_MODULES := true
  ifdef my_system_modules
    ifneq ($(my_system_modules),none)
      ifndef SOONG_SYSTEM_MODULES_$(my_system_modules)
        $(call pretty-error, Invalid system modules $(my_system_modules))
      endif
      full_java_system_modules_deps := $(SOONG_SYSTEM_MODULES_DEPS_$(my_system_modules))
      my_system_modules_dir := $(SOONG_SYSTEM_MODULES_$(my_system_modules))
    endif
  endif
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := $(full_java_bootclasspath_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_EMPTY_BOOTCLASSPATH := $(empty_bootclasspath)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SYSTEM_MODULES := $(my_system_modules)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SYSTEM_MODULES_DIR := $(my_system_modules_dir)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SYSTEM_MODULES_LIBS := $(call java-lib-files,$(SOONG_SYSTEM_MODULES_LIBS_$(my_system_modules)))
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_PATCH_MODULE := $(LOCAL_PATCH_MODULE)

ifndef LOCAL_IS_HOST_MODULE
# This is set by packages that are linking to other packages that export
# shared libraries, allowing them to make use of the code in the linked apk.
apk_libraries := $(sort $(LOCAL_APK_LIBRARIES) $(LOCAL_RES_LIBRARIES))
ifneq ($(apk_libraries),)
  link_apk_libraries := $(call app-lib-files,$(apk_libraries))
  link_apk_header_libs := $(call app-lib-header-files,$(apk_libraries))

  # link against the jar with full original names (before proguard processing).
  full_shared_java_libs += $(link_apk_libraries)
  full_shared_java_header_libs += $(link_apk_header_libs)
endif

# This is set by packages that contain instrumentation, allowing them to
# link against the package they are instrumenting.  Currently only one such
# package is allowed.
LOCAL_INSTRUMENTATION_FOR := $(strip $(LOCAL_INSTRUMENTATION_FOR))
ifdef LOCAL_INSTRUMENTATION_FOR
  ifneq ($(words $(LOCAL_INSTRUMENTATION_FOR)),1)
    $(error \
        $(LOCAL_PATH): Multiple LOCAL_INSTRUMENTATION_FOR members defined)
  endif

  link_instr_intermediates_dir.COMMON := $(call intermediates-dir-for, \
      APPS,$(LOCAL_INSTRUMENTATION_FOR),,COMMON)
  # link against the jar with full original names (before proguard processing).
  link_instr_classes_jar := $(link_instr_intermediates_dir.COMMON)/classes-pre-proguard.jar
  ifneq ($(TURBINE_ENABLED),false)
    link_instr_classes_header_jar := $(link_instr_intermediates_dir.COMMON)/classes-header.jar
  else
    link_instr_classes_header_jar := $(link_instr_intermediates_dir.COMMON)/classes.jar
  endif
  full_shared_java_libs += $(link_instr_classes_jar)
  full_shared_java_header_libs += $(link_instr_classes_header_jar)
endif  # LOCAL_INSTRUMENTATION_FOR
endif  # LOCAL_IS_HOST_MODULE

endif  # need_compile_java

# We may want to add jar manifest or jar resource files even if there is no java code at all.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_EXTRA_JAR_ARGS := $(extra_jar_args)
jar_manifest_file :=
ifneq ($(strip $(LOCAL_JAR_MANIFEST)),)
jar_manifest_file := $(LOCAL_PATH)/$(LOCAL_JAR_MANIFEST)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST := $(jar_manifest_file)
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST :=
endif

##########################################################

full_java_libs := $(full_shared_java_libs) $(full_static_java_libs) $(LOCAL_CLASSPATH)
full_java_header_libs := $(full_shared_java_header_libs) $(full_static_java_header_libs)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_JAVA_LIBRARIES := $(full_java_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ALL_JAVA_HEADER_LIBRARIES := $(full_java_header_libs)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SHARED_JAVA_HEADER_LIBRARIES := $(full_shared_java_header_libs)

###########################################################
# Verify that all libraries are safe to use
###########################################################
ifndef LOCAL_IS_HOST_MODULE
ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
my_warn_types :=
my_allowed_types := java:sdk java:system java:core
else ifneq (,$(call has-system-sdk-version,$(LOCAL_SDK_VERSION)))
my_link_type := java:system
my_warn_types :=
my_allowed_types := java:sdk java:system java:core
else ifeq ($(LOCAL_SDK_VERSION),core_current)
my_link_type := java:core
my_warn_types :=
my_allowed_types := java:core
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
my_warn_types :=
my_allowed_types := java:sdk java:core
else
my_link_type := java:platform
my_warn_types :=
my_allowed_types := java:sdk java:system java:platform java:core
endif

my_link_deps := $(addprefix JAVA_LIBRARIES:,$(LOCAL_STATIC_JAVA_LIBRARIES) $(LOCAL_JAVA_LIBRARIES))
my_link_deps += $(addprefix APPS:,$(apk_libraries))

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk
endif  # !LOCAL_IS_HOST_MODULE

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))

SOONG_CONV.$(LOCAL_MODULE).PROBLEMS := \
    $(SOONG_CONV.$(LOCAL_MODULE).PROBLEMS) $(my_soong_problems)
SOONG_CONV.$(LOCAL_MODULE).DEPS := \
    $(SOONG_CONV.$(LOCAL_MODULE).DEPS) \
    $(LOCAL_STATIC_JAVA_LIBRARIES) \
    $(LOCAL_JAVA_LIBRARIES) \
    $(LOCAL_JNI_SHARED_LIBRARIES)
SOONG_CONV.$(LOCAL_MODULE).TYPE := java
SOONG_CONV.$(LOCAL_MODULE).MAKEFILES := \
    $(SOONG_CONV.$(LOCAL_MODULE).MAKEFILES) $(LOCAL_MODULE_MAKEFILE)
SOONG_CONV.$(LOCAL_MODULE).INSTALLED := \
    $(SOONG_CONV.$(LOCAL_MODULE).INSTALLED) $(LOCAL_INSTALLED_MODULE)
SOONG_CONV := $(SOONG_CONV) $(LOCAL_MODULE)

endif
