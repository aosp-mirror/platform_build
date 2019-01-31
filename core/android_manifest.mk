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

  my_full_libs_manifest_files += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES) $(LOCAL_STATIC_ANDROID_LIBRARIES),\
    $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/manifest/AndroidManifest.xml)
endif

# With aapt2, we'll link in the built resource from the AAR.
ifneq ($(LOCAL_USE_AAPT2),true)
  LOCAL_RESOURCE_DIR += $(foreach lib, $(LOCAL_STATIC_JAVA_AAR_LIBRARIES),\
    $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/aar/res)
endif

full_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml

ifneq (,$(strip $(my_full_libs_manifest_files)))
  # Set up rules to merge library manifest files
  fixed_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml.fixed

  $(full_android_manifest): PRIVATE_LIBS_MANIFESTS := $(my_full_libs_manifest_files)
  $(full_android_manifest): $(ANDROID_MANIFEST_MERGER_DEPS)
  $(full_android_manifest) : $(fixed_android_manifest) $(my_full_libs_manifest_files)
	@echo "Merge android manifest files: $@ <-- $< $(PRIVATE_LIBS_MANIFESTS)"
	@mkdir -p $(dir $@)
	$(hide) $(ANDROID_MANIFEST_MERGER) --main $< \
	    --libs $(call normalize-path-list,$(PRIVATE_LIBS_MANIFESTS)) \
	    --out $@
else
  fixed_android_manifest := $(full_android_manifest)
endif

ifdef LOCAL_MIN_SDK_VERSION
  $(fixed_android_manifest): PRIVATE_MIN_SDK_VERSION := $(LOCAL_MIN_SDK_VERSION)
else ifneq (,$(filter-out current system_current test_current core_current, $(LOCAL_SDK_VERSION)))
  $(fixed_android_manifest): PRIVATE_MIN_SDK_VERSION := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
else
  $(fixed_android_manifest): PRIVATE_MIN_SDK_VERSION := $(DEFAULT_APP_TARGET_SDK)
endif

ifneq (,$(filter-out current system_current test_current core_current, $(LOCAL_SDK_VERSION)))
  $(fixed_android_manifest): PRIVATE_TARGET_SDK_VERSION := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
else
  $(fixed_android_manifest): PRIVATE_TARGET_SDK_VERSION := $(DEFAULT_APP_TARGET_SDK)
endif

my_exported_sdk_libs_file := $(call local-intermediates-dir,COMMON)/exported-sdk-libs
$(fixed_android_manifest): PRIVATE_EXPORTED_SDK_LIBS_FILE := $(my_exported_sdk_libs_file)
$(fixed_android_manifest): $(my_exported_sdk_libs_file)

my_manifest_fixer_flags :=
ifneq ($(LOCAL_MODULE_CLASS),APPS)
    my_manifest_fixer_flags += --library
endif
ifeq ($(LOCAL_PRIVATE_PLATFORM_APIS),true)
    my_manifest_fixer_flags += --uses-non-sdk-api
endif

ifeq (true,$(LOCAL_USE_EMBEDDED_DEX))
    my_manifest_fixer_flags += --use-embedded-dex
endif

$(fixed_android_manifest): PRIVATE_MANIFEST_FIXER_FLAGS := $(my_manifest_fixer_flags)
# These two libs are added as optional dependencies (<uses-library> with
# android:required set to false). This is because they haven't existed in pre-P
# devices, but classes in them were in bootclasspath jars, etc. So making them
# hard dependencies (andriod:required=true) would prevent apps from being
# installed to such legacy devices.
$(fixed_android_manifest): PRIVATE_OPTIONAL_SDK_LIB_NAMES := android.test.base android.test.mock
$(fixed_android_manifest): $(MANIFEST_FIXER)
$(fixed_android_manifest): $(main_android_manifest)
	echo $(PRIVATE_OPTIONAL_SDK_LIB_NAMES) | tr ' ' '\n' > $(PRIVATE_EXPORTED_SDK_LIBS_FILE).optional
	@echo "Fix manifest: $@"
	$(MANIFEST_FIXER) \
	  --minSdkVersion $(PRIVATE_MIN_SDK_VERSION) \
          --targetSdkVersion $(PRIVATE_TARGET_SDK_VERSION) \
          --raise-min-sdk-version \
	  $(PRIVATE_MANIFEST_FIXER_FLAGS) \
	  $(if (PRIVATE_EXPORTED_SDK_LIBS_FILE),\
	    $$(cat $(PRIVATE_EXPORTED_SDK_LIBS_FILE) | grep -v -f $(PRIVATE_EXPORTED_SDK_LIBS_FILE).optional | sort -u | sed -e 's/^/\ --uses-library\ /' | tr '\n' ' ') \
	    $$(cat $(PRIVATE_EXPORTED_SDK_LIBS_FILE) | grep -f $(PRIVATE_EXPORTED_SDK_LIBS_FILE).optional | sort -u | sed -e 's/^/\ --optional-uses-library\ /' | tr '\n' ' ') \
	   ) \
	  $< $@
	rm $(PRIVATE_EXPORTED_SDK_LIBS_FILE).optional
