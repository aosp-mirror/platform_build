# Handle AndroidManifest.xmls
# Input: LOCAL_MANIFEST_FILE, LOCAL_FULL_MANIFEST_FILE, LOCAL_FULL_LIBS_MANIFEST_FILES,
#        LOCAL_USE_EMBEDDED_NATIVE_LIBS
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

full_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml

ifneq (,$(strip $(my_full_libs_manifest_files)))
  # Set up rules to merge library manifest files
  fixed_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml.fixed

  $(full_android_manifest): PRIVATE_LIBS_MANIFESTS := $(my_full_libs_manifest_files)
  $(full_android_manifest): $(ANDROID_MANIFEST_MERGER)
  $(full_android_manifest) : $(fixed_android_manifest) $(my_full_libs_manifest_files)
	@echo "Merge android manifest files: $@ <-- $< $(PRIVATE_LIBS_MANIFESTS)"
	@mkdir -p $(dir $@)
	$(hide) $(ANDROID_MANIFEST_MERGER) --main $< \
	    --libs $(call normalize-path-list,$(PRIVATE_LIBS_MANIFESTS)) \
	    --out $@
else
  fixed_android_manifest := $(full_android_manifest)
endif

my_target_sdk_version := $(call module-target-sdk-version)
my_min_sdk_version := $(call module-min-sdk-version)

ifdef TARGET_BUILD_APPS
  ifndef TARGET_BUILD_USE_PREBUILT_SDKS
    ifeq ($(my_target_sdk_version),$(PLATFORM_VERSION_CODENAME))
      ifdef UNBUNDLED_BUILD_TARGET_SDK_WITH_API_FINGERPRINT
        my_target_sdk_version := $(my_target_sdk_version).$$(cat $(API_FINGERPRINT))
        my_min_sdk_version := $(my_min_sdk_version).$$(cat $(API_FINGERPRINT))
        $(fixed_android_manifest): $(API_FINGERPRINT)
      else ifdef UNBUNDLED_BUILD_TARGET_SDK_WITH_DESSERT_SHA
        my_target_sdk_version := $(UNBUNDLED_BUILD_TARGET_SDK_WITH_DESSERT_SHA)
        my_min_sdk_version := $(UNBUNDLED_BUILD_TARGET_SDK_WITH_DESSERT_SHA)
      endif
    endif
  endif
endif

$(fixed_android_manifest): PRIVATE_MIN_SDK_VERSION := $(my_min_sdk_version)
$(fixed_android_manifest): PRIVATE_TARGET_SDK_VERSION := $(my_target_sdk_version)

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

ifeq ($(LOCAL_MODULE_CLASS),APPS)
  ifeq (true,$(call math_gt_or_eq,$(patsubst $(PLATFORM_VERSION_CODENAME),100,$(call module-min-sdk-version)),23))
    ifeq (true,$(LOCAL_USE_EMBEDDED_NATIVE_LIBS))
      my_manifest_fixer_flags += --extract-native-libs=false
    else
      my_manifest_fixer_flags += --extract-native-libs=true
    endif
  else ifeq (true,$(LOCAL_USE_EMBEDDED_NATIVE_LIBS))
    $(call pretty-error,LOCAL_USE_EMBEDDED_NATIVE_LIBS is set but minSdkVersion $(call module-min-sdk-version) does not support it)
  endif
endif

# TODO: Replace this hardcoded list of optional uses-libraries with build logic
# that propagates optionality via the generated exported-sdk-libs files.
# Hardcodng doesn't scale and enforces a single choice on each library, while in
# reality this is a choice of the library users (which may differ).
my_optional_sdk_lib_names := \
    android.test.base \
    android.test.mock \
    androidx.window.extensions \
    androidx.window.sidecar

$(fixed_android_manifest): PRIVATE_MANIFEST_FIXER_FLAGS := $(my_manifest_fixer_flags)
# These two libs are added as optional dependencies (<uses-library> with
# android:required set to false). This is because they haven't existed in pre-P
# devices, but classes in them were in bootclasspath jars, etc. So making them
# hard dependencies (andriod:required=true) would prevent apps from being
# installed to such legacy devices.
$(fixed_android_manifest): PRIVATE_OPTIONAL_SDK_LIB_NAMES := $(my_optional_sdk_lib_names)
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

my_optional_sdk_lib_names :=
