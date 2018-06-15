# Handle AndroidManifest.xmls
# Input: LOCAL_MANIFEST_FILE, LOCAL_FULL_MANIFEST_FILE, LOCAL_FULL_LIBS_MANIFEST_FILES
# Output: full_android_manifest

ifeq ($(strip $(LOCAL_MANIFEST_FILE)),)
  LOCAL_MANIFEST_FILE := AndroidManifest.xml
endif
ifdef LOCAL_FULL_MANIFEST_FILE
  main_android_manifest := $(LOCAL_FULL_MANIFEST_FILE)
else
  main_android_manifest := $(LOCAL_PATH)/$(LOCAL_MANIFEST_FILE)
endif

LOCAL_STATIC_JAVA_AAR_LIBRARIES := $(strip $(LOCAL_STATIC_JAVA_AAR_LIBRARIES))

my_full_libs_manifest_files :=

ifndef LOCAL_DONT_MERGE_MANIFESTS
  my_full_libs_manifest_files += $(LOCAL_FULL_LIBS_MANIFEST_FILES)

  ifdef LOCAL_STATIC_JAVA_AAR_LIBRARIES
    my_full_libs_manifest_files += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/AndroidManifest.xml)
  endif
endif

ifdef LOCAL_STATIC_JAVA_AAR_LIBRARIES
  # With aapt2, we'll link in the built resource from the AAR.
  ifneq ($(LOCAL_USE_AAPT2),true)
    LOCAL_RESOURCE_DIR += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/res)
  endif
endif

full_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml

ifdef LOCAL_MIN_SDK_VERSION
  $(full_android_manifest): PRIVATE_MIN_SDK_VERSION := $(LOCAL_MIN_SDK_VERSION)
else ifneq (,$(filter-out current system_current test_current core_current, $(LOCAL_SDK_VERSION)))
  $(full_android_manifest): PRIVATE_MIN_SDK_VERSION := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
else
  $(full_android_manifest): PRIVATE_MIN_SDK_VERSION := $(DEFAULT_APP_TARGET_SDK)
endif

# Set up rules to merge library manifest files
ifneq (,$(strip $(my_full_libs_manifest_files)))

$(full_android_manifest): PRIVATE_LIBS_MANIFESTS := $(my_full_libs_manifest_files)
$(full_android_manifest): $(ANDROID_MANIFEST_MERGER_CLASSPATH)
$(full_android_manifest): $(MANIFEST_FIXER)
$(full_android_manifest) : $(main_android_manifest) $(my_full_libs_manifest_files)
	@echo "Merge android manifest files: $@ <-- $< $(PRIVATE_LIBS_MANIFESTS)"
	@mkdir -p $(dir $@)
	$(MANIFEST_FIXER) $< $@.tmp --minSdkVersion $(PRIVATE_MIN_SDK_VERSION)
	$(hide) $(ANDROID_MANIFEST_MERGER) --main $@.tmp \
	    --libs $(call normalize-path-list,$(PRIVATE_LIBS_MANIFESTS)) \
	    --out $@
	rm $@.tmp

else
$(full_android_manifest): $(MANIFEST_FIXER)
$(full_android_manifest): $(main_android_manifest)
	@echo "Fix manifest: $@"
	$(MANIFEST_FIXER) $< $@ --minSdkVersion $(PRIVATE_MIN_SDK_VERSION)

endif
