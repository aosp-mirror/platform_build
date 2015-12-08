# Set up rules to build dpi-specific apk, with whatever else from the base apk.
# Input variable: my_dpi, and all other variables set up in package_internal.mk.
#

dpi_apk_name := $(LOCAL_MODULE)_$(my_dpi)
dpi_intermediate := $(call intermediates-dir-for,APPS,$(dpi_apk_name))
built_dpi_apk := $(dpi_intermediate)/package.apk

# Set up all the target-specific variables.
$(built_dpi_apk): PRIVATE_MODULE := $(dpi_apk_name)
$(built_dpi_apk): PRIVATE_AAPT_FLAGS := $(LOCAL_AAPT_FLAGS) $(PRODUCT_AAPT_FLAGS) $($(LOCAL_PACKAGE_NAME)_aapt_flags_$(my_dpi))
# Clear PRIVATE_PRODUCT_AAPT_CONFIG to include everything by default.
$(built_dpi_apk): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(built_dpi_apk): PRIVATE_PRODUCT_AAPT_PREF_CONFIG := $(my_dpi)
$(built_dpi_apk): PRIVATE_ANDROID_MANIFEST := $(full_android_manifest)
$(built_dpi_apk): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(built_dpi_apk): PRIVATE_ASSET_DIR := $(LOCAL_ASSET_DIR)
$(built_dpi_apk): PRIVATE_AAPT_INCLUDES := $(all_library_res_package_exports)
ifneq (,$(filter-out current system_current test_current, $(LOCAL_SDK_VERSION)))
$(built_dpi_apk): PRIVATE_DEFAULT_APP_TARGET_SDK := $(LOCAL_SDK_VERSION)
else
$(built_dpi_apk): PRIVATE_DEFAULT_APP_TARGET_SDK := $(DEFAULT_APP_TARGET_SDK)
endif
$(built_dpi_apk): PRIVATE_MANIFEST_PACKAGE_NAME := $(LOCAL_MANIFEST_PACKAGE_NAME)
$(built_dpi_apk): PRIVATE_MANIFEST_INSTRUMENTATION_FOR := $(LOCAL_INSTRUMENTATION_FOR)
$(built_dpi_apk): PRIVATE_JNI_SHARED_LIBRARIES := $(jni_shared_libraries_with_abis)
$(built_dpi_apk): PRIVATE_JNI_SHARED_LIBRARIES_ABI := $(jni_shared_libraries_abis)
$(built_dpi_apk): PRIVATE_PRIVATE_KEY := $(private_key)
$(built_dpi_apk): PRIVATE_CERTIFICATE := $(certificate)
$(built_dpi_apk): PRIVATE_ADDITIONAL_CERTIFICATES := $(foreach c,\
    $(LOCAL_ADDITIONAL_CERTIFICATES), $(c).x509.pem $(c).pk8)

$(built_dpi_apk): PRIVATE_SOURCE_ARCHIVE :=
ifneq ($(full_classes_jar),)
$(built_dpi_apk): PRIVATE_DEX_FILE := $(built_dex)
ifndef LOCAL_JACK_ENABLED
# Use the jarjar processed arhive as the initial package file.
$(built_dpi_apk): PRIVATE_SOURCE_ARCHIVE := $(full_classes_jarjar_jar)
else
$(built_dpi_apk): PRIVATE_JACK_INTERMEDIATES_DIR := $(intermediates.COMMON)/jack-rsc
endif # LOCAL_JACK_ENABLED
$(built_dpi_apk): $(built_dex)
else
$(built_dpi_apk): PRIVATE_DEX_FILE :=
endif # full_classes_jar

# Set up dependenncies and the build recipe.
$(built_dpi_apk) : $(R_file_stamp)
$(built_dpi_apk) : $(all_library_res_package_export_deps)
$(built_dpi_apk) : $(private_key) $(certificate) $(SIGNAPK_JAR)
$(built_dpi_apk) : $(AAPT)
$(built_dpi_apk) : $(all_res_assets) $(jni_shared_libraries) $(full_android_manifest)
	@echo "target Package: $(PRIVATE_MODULE) ($@)"
	$(if $(PRIVATE_SOURCE_ARCHIVE),\
	  $(call initialize-package-file,$(PRIVATE_SOURCE_ARCHIVE),$@),\
	  $(create-empty-package))
	$(add-assets-to-package)
ifneq ($(jni_shared_libraries),)
	$(add-jni-shared-libs-to-package)
endif
ifeq ($(full_classes_jar),)
# We don't build jar, need to add the Java resources here.
	$(if $(PRIVATE_EXTRA_JAR_ARGS),$(call add-java-resources-to,$@))
else
	$(add-dex-to-package)
ifdef LOCAL_JACK_ENABLED
	$(add-carried-jack-resources)
endif
endif
	$(sign-package)

# Set up global variables to register this apk to the higher-level dependency graph.
ALL_MODULES += $(dpi_apk_name)
ALL_MODULES.$(dpi_apk_name).CLASS := APPS
ALL_MODULES.$(dpi_apk_name).BUILT := $(built_dpi_apk)
PACKAGES := $(PACKAGES) $(dpi_apk_name)
PACKAGES.$(dpi_apk_name).PRIVATE_KEY := $(private_key)
PACKAGES.$(dpi_apk_name).CERTIFICATE := $(certificate)

# Phony targets used by "apps_only".
.PHONY: $(dpi_apk_name)
$(dpi_apk_name) : $(built_dpi_apk)
