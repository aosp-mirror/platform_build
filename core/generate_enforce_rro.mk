include $(CLEAR_VARS)

enforce_rro_module := $(enforce_rro_source_module)__auto_generated_rro
LOCAL_PACKAGE_NAME := $(enforce_rro_module)

intermediates := $(call intermediates-dir-for,APPS,$(LOCAL_PACKAGE_NAME),,COMMON)
rro_android_manifest_file := $(intermediates)/AndroidManifest.xml

ifeq (true,$(enforce_rro_source_is_manifest_package_name))
  use_package_name_arg := --use-package-name
else
  use_package_name_arg :=
$(rro_android_manifest_file): $(enforce_rro_source_manifest_package_info)
endif

$(rro_android_manifest_file): PRIVATE_PACKAGE_INFO := $(enforce_rro_source_manifest_package_info)
$(rro_android_manifest_file): build/make/tools/generate-enforce-rro-android-manifest.py
	$(hide) build/make/tools/generate-enforce-rro-android-manifest.py \
	    --package-info $(PRIVATE_PACKAGE_INFO) \
	    $(use_package_name_arg) \
	    -o $@

LOCAL_PATH:= $(intermediates)

ifeq ($(enforce_rro_use_res_lib),true)
  LOCAL_RES_LIBRARIES := $(enforce_rro_source_module)
endif

LOCAL_FULL_MANIFEST_FILE := $(rro_android_manifest_file)
LOCAL_CERTIFICATE := platform

LOCAL_AAPT_FLAGS += --auto-add-overlay
LOCAL_RESOURCE_DIR := $(enforce_rro_source_overlays)
LOCAL_PRODUCT_MODULE := true

ifneq (,$(LOCAL_RES_LIBRARIES))
  # Technically we are linking against the app (if only to grab its resources),
  # and because it's potentially not building against the SDK, we can't either.
  LOCAL_PRIVATE_PLATFORM_APIS := true
else ifeq (framework-res,$(enforce_rro_source_module))
  LOCAL_PRIVATE_PLATFORM_APIS := true
else
  LOCAL_SDK_VERSION := current
endif

include $(BUILD_RRO_PACKAGE)
