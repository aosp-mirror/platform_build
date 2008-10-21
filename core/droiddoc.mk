###########################################################
## Standard rules for building documentation
###########################################################

LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))
ifdef LOCAL_IS_HOST_MODULE
my_prefix:=HOST_
else
my_prefix:=TARGET_
endif

LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifndef LOCAL_MODULE_CLASS
$(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined)
endif

full_src_files := $(patsubst %,$(LOCAL_PATH)/%,$(LOCAL_SRC_FILES))
out_dir := $(OUT_DOCS)/$(LOCAL_MODULE)
full_target := $(OUT_DOCS)/$(LOCAL_MODULE)-timestamp

ifeq ($(LOCAL_DROIDDOC_SOURCE_PATH),)
LOCAL_DROIDDOC_SOURCE_PATH := $(LOCAL_PATH)
endif

ifeq ($(LOCAL_DROIDDOC_TEMPLATE_DIR),)
LOCAL_DROIDDOC_TEMPLATE_DIR := $(SRC_DROIDDOC_DIR)/templates
endif
ifeq ($(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR),)
LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR := $(SRC_DROIDDOC_DIR)/templates
endif

ifeq ($(LOCAL_DROIDDOC_ASSET_DIR),)
LOCAL_DROIDDOC_ASSET_DIR := assets
endif
ifeq ($(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR),)
LOCAL_DROIDDOC_CUSTOM_ASSET_DIR := assets
endif

droiddoc_templates := \
    $(shell find $(LOCAL_DROIDDOC_TEMPLATE_DIR) -type f) \
    $(shell find $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR) -type f)

droiddoc := \
	$(HOST_JDK_TOOLS_JAR) \
	$(HOST_OUT_JAVA_LIBRARIES)/droiddoc$(COMMON_JAVA_PACKAGE_SUFFIX) \
	$(HOST_OUT_JAVA_LIBRARIES)/clearsilver$(COMMON_JAVA_PACKAGE_SUFFIX) \
	$(HOST_OUT_SHARED_LIBRARIES)/libclearsilver-jni$(HOST_JNILIB_SUFFIX)

intermediates := $(call local-intermediates-dir)

$(full_target): PRIVATE_CLASSPATH:=$(LOCAL_CLASSPATH)
full_java_lib_deps :=

ifndef LOCAL_IS_HOST_MODULE

ifeq ($(LOCAL_JAVA_LIBRARIES),)
LOCAL_JAVA_LIBRARIES := core ext framework
endif
full_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
full_java_lib_deps := $(call java-lib-deps,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))

# we're not going to generate docs from any of these classes, but we need them
# to build properly.
ifneq ($(strip $(LOCAL_STATIC_JAVA_LIBRARIES)),)
full_java_libs += $(addprefix $(LOCAL_PATH)/,$(LOCAL_STATIC_JAVA_LIBRARIES)) $(LOCAL_CLASSPATH)
full_java_lib_deps += $(addprefix $(LOCAL_PATH)/,$(LOCAL_STATIC_JAVA_LIBRARIES)) $(LOCAL_CLASSPATH)
endif

empty :=
space := $(empty) $(empty)
$(full_target): PRIVATE_CLASSPATH := $(subst $(space),:,$(full_java_libs))

endif # !LOCAL_IS_HOST_MODULE

$(full_target): PRIVATE_DOCLETPATH := $(HOST_OUT_JAVA_LIBRARIES)/clearsilver$(COMMON_JAVA_PACKAGE_SUFFIX):$(HOST_OUT_JAVA_LIBRARIES)/droiddoc$(COMMON_JAVA_PACKAGE_SUFFIX)
$(full_target): PRIVATE_JAVA_FILES := $(filter %.java,$(full_src_files))
$(full_target): PRIVATE_JAVA_FILES += $(addprefix $($(my_prefix)OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))
$(full_target): PRIVATE_CURRENT_BUILD := -hdf page.build $(BUILD_ID)-$(BUILD_NUMBER)
$(full_target): PRIVATE_CURRENT_TIME :=  -hdf page.now "$(shell date "+%d %b %Y %k:%M")"
$(full_target): PRIVATE_OUT_DIR := $(out_dir)
$(full_target): PRIVATE_DROIDDOC_OPTIONS := $(LOCAL_DROIDDOC_OPTIONS)
$(full_target): PRIVATE_TEMPLATE_DIR := $(LOCAL_DROIDDOC_TEMPLATE_DIR)
$(full_target): PRIVATE_CUSTOM_TEMPLATE_DIR := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)
$(full_target): PRIVATE_IN_ASSET_DIR := $(LOCAL_DROIDDOC_TEMPLATE_DIR)/$(LOCAL_DROIDDOC_ASSET_DIR)
$(full_target): PRIVATE_IN_CUSTOM_ASSET_DIR := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)/$(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR)
$(full_target): PRIVATE_OUT_ASSET_DIR := $(out_dir)/$(LOCAL_DROIDDOC_ASSET_DIR)
$(full_target): PRIVATE_OUT_CUSTOM_ASSET_DIR := $(out_dir)/$(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR)
ifneq ($(strip $(LOCAL_DROIDDOC_HTML_DIR)),)
$(full_target): PRIVATE_DROIDDOC_HTML_DIR := -htmldir $(LOCAL_PATH)/$(LOCAL_DROIDDOC_HTML_DIR)
else
$(full_target): PRIVATE_DROIDDOC_HTML_DIR := 
endif
$(full_target): PRIVATE_LOCAL_PATH := $(LOCAL_PATH)
$(full_target): PRIVATE_SOURCE_PATH := $(call normalize-path-list,$(LOCAL_DROIDDOC_SOURCE_PATH))
$(full_target): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates)/src
$(full_target): PRIVATE_SRC_LIST_FILE := $(intermediates)/droiddoc-src-list

ifneq ($(strip $(LOCAL_ADDITIONAL_JAVA_DIR)),)
$(full_target): PRIVATE_ADDITIONAL_JAVA_DIR := $(LOCAL_ADDITIONAL_JAVA_DIR)
endif

html_dir_files := $(shell find $(LOCAL_PATH)/$(LOCAL_DROIDDOC_HTML_DIR) -type f)

ifeq (a,b)
$(full_target): PRIVATE_PROFILING_OPTIONS := \
    -J-agentlib:jprofilerti=port=8849 -J-Xbootclasspath/a:/Applications/jprofiler5/bin/agent.jar
endif

$(full_target): $(full_src_files) $(droiddoc_templates) $(droiddoc) $(html_dir_files) $(full_java_lib_deps)
	@echo Docs droiddoc: $(PRIVATE_OUT_DIR)
	@mkdir -p $(dir $(full_target))
	@mkdir -p $(dir $(PRIVATE_SRC_LIST_FILE))
	$(call dump-words-to-file, $(PRIVATE_JAVA_FILES), $(PRIVATE_SRC_LIST_FILE))
	$(hide) find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' >> $(PRIVATE_SRC_LIST_FILE) 2> /dev/null || true
	$(hide) if [ "$(PRIVATE_ADDITIONAL_JAVA_DIR)" != "" ] ; then ( find $(PRIVATE_ADDITIONAL_JAVA_DIR) -name '*.java' >> $(PRIVATE_SRC_LIST_FILE) 2> /dev/null || true ) fi
	$(hide) ( \
        \
            LD_LIBRARY_PATH=$(HOST_OUT_SHARED_LIBRARIES) \
            javadoc \
                \@$(PRIVATE_SRC_LIST_FILE) \
                -J-Xmx768m \
                -J-Djava.library.path=$(HOST_OUT_SHARED_LIBRARIES) \
                $(PRIVATE_PROFILING_OPTIONS) \
                -quiet \
                -doclet DroidDoc \
                -docletpath $(PRIVATE_DOCLETPATH) \
                -templatedir $(PRIVATE_CUSTOM_TEMPLATE_DIR) \
                -templatedir $(PRIVATE_TEMPLATE_DIR) \
                $(PRIVATE_DROIDDOC_HTML_DIR) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                -sourcepath $(PRIVATE_SOURCE_PATH)$(addprefix :,$(PRIVATE_CLASSPATH)) \
                -d $(PRIVATE_OUT_DIR) \
                $(PRIVATE_CURRENT_BUILD) $(PRIVATE_CURRENT_TIME) \
                $(PRIVATE_DROIDDOC_OPTIONS) \
        && rm -rf $(PRIVATE_OUT_ASSET_DIR) \
        && rm -rf $(PRIVATE_OUT_CUSTOM_ASSET_DIR) \
        && mkdir -p $(PRIVATE_OUT_ASSET_DIR) \
        && mkdir -p $(PRIVATE_OUT_CUSTOM_ASSET_DIR) \
        && cp -fr $(PRIVATE_IN_ASSET_DIR)/* $(PRIVATE_OUT_ASSET_DIR)/ \
        && cp -fr $(PRIVATE_IN_CUSTOM_ASSET_DIR)/* $(PRIVATE_OUT_CUSTOM_ASSET_DIR)/ \
        && touch -f $@ \
    ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)

ALL_DOCS += $(full_target)

.PHONY: $(LOCAL_MODULE)-docs
$(LOCAL_MODULE)-docs : $(full_target)

# Define a rule to create a zip of these docs.
out_zip := $(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip
$(out_zip): PRIVATE_DOCS_DIR := $(out_dir)
$(out_zip): $(full_target)
	@echo Package docs: $@
	@rm -f $@
	@mkdir -p $(dir $@)
	$(hide) ( F=$$(pwd)/$@ ; cd $(PRIVATE_DOCS_DIR) && zip -rq $$F * )

$(call dist-for-goals,docs,$(out_zip))
