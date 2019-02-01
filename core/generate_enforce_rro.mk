include $(CLEAR_VARS)

LOCAL_PACKAGE_NAME := $(enforce_rro_module)

intermediates := $(call intermediates-dir-for,APPS,$(LOCAL_PACKAGE_NAME),,COMMON)
rro_android_manifest_file := $(intermediates)/AndroidManifest.xml

ifeq (true,$(enforce_rro_source_is_manifest_package_name))
$(rro_android_manifest_file): PRIVATE_PACKAGE_NAME := $(enforce_rro_source_manifest_package_info)
$(rro_android_manifest_file): build/make/tools/generate-enforce-rro-android-manifest.py
	$(hide) build/make/tools/generate-enforce-rro-android-manifest.py -u -p $(PRIVATE_PACKAGE_NAME) -o $@
else
$(rro_android_manifest_file): PRIVATE_SOURCE_MANIFEST_FILE := $(enforce_rro_source_manifest_package_info)
$(rro_android_manifest_file): $(enforce_rro_source_manifest_package_info) build/make/tools/generate-enforce-rro-android-manifest.py
	$(hide) build/make/tools/generate-enforce-rro-android-manifest.py -p $(PRIVATE_SOURCE_MANIFEST_FILE) -o $@
endif

LOCAL_PATH:= $(intermediates)

ifeq ($(enforce_rro_use_res_lib),true)
LOCAL_RES_LIBRARIES := $(enforce_rro_source_module)
endif

LOCAL_FULL_MANIFEST_FILE := $(rro_android_manifest_file)
LOCAL_CERTIFICATE := platform

LOCAL_AAPT_FLAGS += --auto-add-overlay
LOCAL_RESOURCE_DIR := $(enforce_rro_source_overlays)

ifneq (,$(LOCAL_RES_LIBRARIES))
  # Technically we are linking against the app (if only to grab its resources),
  # and because it's potentially not building against the SDK, we can't either.
  LOCAL_PRIVATE_PLATFORM_APIS := true
else ifeq (framework-res__auto_generated_rro,$(enforce_rro_module))
  LOCAL_PRIVATE_PLATFORM_APIS := true
else
  LOCAL_SDK_VERSION := current
endif

include $(BUILD_RRO_PACKAGE)
