# Java prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_HEADER_JAR
# LOCAL_SOONG_DEX_JAR
# LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_java_prebuilt.mk may only be used from Soong)
endif

LOCAL_MODULE_SUFFIX := .jar
LOCAL_BUILT_MODULE_STEM := javalib.jar

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

full_classes_jar := $(intermediates.COMMON)/classes.jar
full_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar
common_javalib.jar := $(intermediates.COMMON)/javalib.jar
greylist_txt := $(intermediates.COMMON)/greylist.txt

$(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(full_classes_jar)))
$(eval $(call copy-one-file,$(LOCAL_PREBUILT_MODULE_FILE),$(full_classes_pre_proguard_jar)))

ifdef LOCAL_DROIDDOC_STUBS_SRCJAR
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_STUBS_SRCJAR),$(OUT_DOCS)/$(LOCAL_MODULE)-stubs.srcjar))
ALL_DOCS += $(OUT_DOCS)/$(LOCAL_MODULE)-stubs.srcjar
endif

ifdef LOCAL_DROIDDOC_DOC_ZIP
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_DOC_ZIP),$(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip))
$(call dist-for-goals,docs,$(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip)
endif

ifdef LOCAL_DROIDDOC_ANNOTATIONS_ZIP
$(eval $(call copy-one-file,$(LOCAL_DROIDDOC_ANNOTATIONS_ZIP),$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)_annotations.zip))
endif

ifdef LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR
  $(eval $(call copy-one-file,$(LOCAL_SOONG_JACOCO_REPORT_CLASSES_JAR),\
    $(intermediates.COMMON)/jacoco-report-classes.jar))
  $(call add-dependency,$(common_javalib.jar),\
    $(intermediates.COMMON)/jacoco-report-classes.jar)
endif

ifdef LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE
  my_res_package := $(intermediates.COMMON)/package-res.apk

  $(my_res_package): $(LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE)
	@echo "Copy: $@"
	$(copy-file-to-target)

  $(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_res_package))

  my_proguard_flags := $(intermediates.COMMON)/export_proguard_flags
  $(my_proguard_flags): $(LOCAL_SOONG_EXPORT_PROGUARD_FLAGS)
	@echo "Export proguard flags: $@"
	rm -f $@
	touch $@
	for f in $+; do \
		echo -e "\n# including $$f" >>$@; \
		cat $$f >>$@; \
	done

  $(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_proguard_flags))

  my_static_library_extra_packages := $(intermediates.COMMON)/extra_packages
  $(eval $(call copy-one-file,$(LOCAL_SOONG_STATIC_LIBRARY_EXTRA_PACKAGES),$(my_static_library_extra_packages)))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_static_library_extra_packages))

  my_static_library_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml
  $(eval $(call copy-one-file,$(LOCAL_FULL_MANIFEST_FILE),$(my_static_library_android_manifest)))
  $(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_static_library_android_manifest))
endif # LOCAL_SOONG_RESOURCE_EXPORT_PACKAGE

ifneq ($(TURBINE_ENABLED),false)
ifdef LOCAL_SOONG_HEADER_JAR
$(eval $(call copy-one-file,$(LOCAL_SOONG_HEADER_JAR),$(full_classes_header_jar)))
else
$(eval $(call copy-one-file,$(full_classes_jar),$(full_classes_header_jar)))
endif
endif # TURBINE_ENABLED != false

ifdef LOCAL_SOONG_DEX_JAR
  ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
    ifndef LOCAL_IS_HOST_MODULE
      ifneq ($(filter $(LOCAL_MODULE),$(PRODUCT_BOOT_JARS)),)  # is_boot_jar
        # Derive greylist from classes.jar.
        # We use full_classes_jar here, which is the post-proguard jar (on the basis that we also
        # have a full_classes_pre_proguard_jar). This is consistent with the equivalent code in
        # java.mk.
        $(eval $(call hiddenapi-generate-greylist-txt,$(full_classes_jar),$(greylist_txt)))
        $(eval $(call hiddenapi-copy-soong-jar,$(LOCAL_SOONG_DEX_JAR),$(common_javalib.jar)))
      else # !is_boot_jar
        $(eval $(call copy-one-file,$(LOCAL_SOONG_DEX_JAR),$(common_javalib.jar)))
      endif # is_boot_jar
      $(eval $(call add-dependency,$(common_javalib.jar),$(full_classes_jar) $(full_classes_header_jar)))

      dex_preopt_profile_src_file := $(common_javalib.jar)

      # defines built_odex along with rule to install odex
      include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk

      dex_preopt_profile_src_file :=

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

         $(eval $(call dexpreopt-copy-jar,$(common_javalib.jar),$(LOCAL_BUILT_MODULE),$(LOCAL_DEX_PREOPT)))
        endif # ! boot jar
      else # LOCAL_DEX_PREOPT
        $(eval $(call copy-one-file,$(common_javalib.jar),$(LOCAL_BUILT_MODULE)))
      endif # LOCAL_DEX_PREOPT
    else # LOCAL_IS_HOST_MODULE
      $(eval $(call copy-one-file,$(LOCAL_SOONG_DEX_JAR),$(LOCAL_BUILT_MODULE)))
      $(eval $(call add-dependency,$(LOCAL_BUILT_MODULE),$(full_classes_jar) $(full_classes_header_jar)))
    endif

    java-dex : $(LOCAL_BUILT_MODULE)
  else  # LOCAL_UNINSTALLABLE_MODULE
    $(eval $(call copy-one-file,$(full_classes_jar),$(LOCAL_BUILT_MODULE)))
    $(eval $(call copy-one-file,$(LOCAL_SOONG_DEX_JAR),$(common_javalib.jar)))
    java-dex : $(common_javalib.jar)
  endif  # LOCAL_UNINSTALLABLE_MODULE
else  # LOCAL_SOONG_DEX_JAR
  $(eval $(call copy-one-file,$(full_classes_jar),$(LOCAL_BUILT_MODULE)))
endif  # LOCAL_SOONG_DEX_JAR

javac-check : $(full_classes_jar)
javac-check-$(LOCAL_MODULE) : $(full_classes_jar)
.PHONY: javac-check-$(LOCAL_MODULE)

ifndef LOCAL_IS_HOST_MODULE
ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
else ifneq (,$(call has-system-sdk-version,$(LOCAL_SDK_VERSION)))
my_link_type := java:system
else ifeq ($(LOCAL_SDK_VERSION),core_current)
my_link_type := java:core
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
else
my_link_type := java:platform
endif
# warn/allowed types are both empty because Soong modules can't depend on
# make-defined modules.
my_warn_types :=
my_allowed_types :=

my_link_deps :=
my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk
endif # !LOCAL_IS_HOST_MODULE

# LOCAL_EXPORT_SDK_LIBRARIES set by soong is written to exported-sdk-libs file
my_exported_sdk_libs_file := $(intermediates.COMMON)/exported-sdk-libs
$(my_exported_sdk_libs_file): PRIVATE_EXPORTED_SDK_LIBS := $(LOCAL_EXPORT_SDK_LIBRARIES)
$(my_exported_sdk_libs_file):
	@echo "Export SDK libs $@"
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(if $(PRIVATE_EXPORTED_SDK_LIBS),\
		$(hide) echo $(PRIVATE_EXPORTED_SDK_LIBS) | tr ' ' '\n' > $@,\
		$(hide) touch $@)
