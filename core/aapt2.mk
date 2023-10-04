######################################
# Compile resource with AAPT2
# Input variables:
# - full_android_manifest
# - my_res_resources
# - my_overlay_resources
# - my_compiled_res_base_dir
# - my_asset_dirs
# - my_full_asset_paths
# - my_res_package
# - R_file_stamp
# - proguard_options_file
# - my_generated_res_dirs: Resources generated during the build process and we have to compile them in a single run of aapt2.
# - my_generated_res_dirs_deps: the dependency to use for my_generated_res_dirs.
# - my_generated_res_zips: Zip files containing resources
# - my_apk_split_configs: The configurations for which to generate splits.
# - built_apk_splits: The paths where AAPT should generate the splits.
#
# Output variables:
# - my_res_resources_flat
# - my_overlay_resources_flat
# - my_generated_resources_flata
#
######################################

# Compile all the resource files.
my_res_resources_flat := \
  $(foreach r, $(my_res_resources),\
    $(eval o := $(call aapt2-compiled-resource-out-file,$(r),$(my_compiled_res_base_dir)))\
    $(eval $(call aapt2-compile-one-resource-file-rule,$(r),$(o)))\
    $(o))

my_overlay_resources_flat := \
  $(foreach r, $(my_overlay_resources),\
    $(eval o := $(call aapt2-compiled-resource-out-file,$(r),$(my_compiled_res_base_dir)))\
    $(eval $(call aapt2-compile-one-resource-file-rule,$(r),$(o)))\
    $(o))

my_resources_flata :=
# Compile generated resources
ifneq ($(my_generated_res_dirs),)
my_generated_resources_flata := $(my_compiled_res_base_dir)/gen_res.flata
$(my_generated_resources_flata): PRIVATE_SOURCE_RES_DIRS := $(my_generated_res_dirs)
$(my_generated_resources_flata) : $(my_generated_res_dirs_deps) $(AAPT2)
	@echo "AAPT2 compile $@ <- $(PRIVATE_SOURCE_RES_DIRS)"
	$(call aapt2-compile-resource-dirs)

my_resources_flata += $(my_generated_resources_flata)
endif

# Compile zipped resources
ifneq ($(my_generated_res_zips),)
my_zipped_resources_flata := $(my_compiled_res_base_dir)/zip_res.flata
$(my_zipped_resources_flata): PRIVATE_SOURCE_RES_ZIPS := $(my_generated_res_zips)
$(my_zipped_resources_flata) : $(my_generated_res_zips) $(AAPT2) $(ZIPSYNC)
	@echo "AAPT2 compile $@ <- $(PRIVATE_SOURCE_RES_ZIPS)"
	$(call aapt2-compile-resource-zips)

my_resources_flata += $(my_zipped_resources_flata)
endif

# Always set --pseudo-localize, it will be stripped out later for release
# builds that don't want it.
$(my_res_resources_flat) $(my_overlay_resources_flat) $(my_resources_flata) $(my_generated_resources_flata) $(my_zippped_resources_flata): \
  PRIVATE_AAPT2_CFLAGS := --pseudo-localize $(filter --legacy,$(LOCAL_AAPT_FLAGS))

# TODO(b/78447299): Forbid LOCAL_STATIC_JAVA_AAR_LIBRARIES in aapt2 and remove
# support for it.
my_static_library_resources := $(foreach l, $(call reverse-list,$(LOCAL_STATIC_ANDROID_LIBRARIES) $(LOCAL_STATIC_JAVA_AAR_LIBRARIES)),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/package-res.apk)
my_static_library_transitive_resource_packages_lists := $(foreach l, $(call reverse-list,$(LOCAL_STATIC_ANDROID_LIBRARIES) $(LOCAL_STATIC_JAVA_AAR_LIBRARIES)),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/transitive-res-packages)
my_static_library_extra_packages := $(foreach l, $(call reverse-list,$(LOCAL_STATIC_ANDROID_LIBRARIES) $(LOCAL_STATIC_JAVA_AAR_LIBRARIES)),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/extra_packages)
my_shared_library_resources := $(foreach l, $(LOCAL_SHARED_ANDROID_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/package-res.apk)

ifneq ($(my_static_library_resources),)
$(my_res_package): PRIVATE_AAPT_FLAGS += --auto-add-overlay
endif

ifneq ($(my_apk_split_configs),)
# Join the Split APK paths with their configuration, separated by a ':'.
$(my_res_package): PRIVATE_AAPT_FLAGS += $(addprefix --split ,$(join $(built_apk_splits),$(addprefix :,$(my_apk_split_configs))))
endif

my_srcjar := $(intermediates.COMMON)/aapt2.srcjar
LOCAL_SRCJARS += $(my_srcjar)

aapt_extra_packages := $(intermediates.COMMON)/extra_packages

$(my_res_package): PRIVATE_RES_FLAT := $(my_res_resources_flat)
$(my_res_package): PRIVATE_OVERLAY_FLAT := $(my_static_library_resources) $(my_resources_flata) $(my_overlay_resources_flat)
$(my_res_package): PRIVATE_SHARED_ANDROID_LIBRARIES := $(my_shared_library_resources)
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(my_res_package): PRIVATE_ASSET_DIRS := $(my_asset_dirs)
$(my_res_package): PRIVATE_JAVA_GEN_DIR := $(intermediates.COMMON)/aapt2
$(my_res_package): PRIVATE_SRCJAR := $(my_srcjar)
$(my_res_package): PRIVATE_STATIC_LIBRARY_EXTRA_PACKAGES := $(my_static_library_extra_packages)
$(my_res_package): PRIVATE_STATIC_LIBRARY_TRANSITIVE_RES_PACKAGES_LISTS := $(my_static_library_transitive_resource_packages_lists)
$(my_res_package): PRIVATE_AAPT_EXTRA_PACKAGES := $(aapt_extra_packages)
$(my_res_package): .KATI_IMPLICIT_OUTPUTS := $(my_srcjar) $(aapt_extra_packages)

ifdef R_file_stamp
$(my_res_package): PRIVATE_R_FILE_STAMP := $(R_file_stamp)
$(my_res_package): .KATI_IMPLICIT_OUTPUTS += $(R_file_stamp)
endif

resource_export_package :=
ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
# Put this module's resources into a PRODUCT-agnositc package that
# other packages can use to build their own PRODUCT-agnostic R.java (etc.)
# files.
resource_export_package := $(intermediates.COMMON)/package-export.apk
$(my_res_package): PRIVATE_RESOURCE_EXPORT_PACKAGE := $(resource_export_package)
$(my_res_package): .KATI_IMPLICIT_OUTPUTS += $(resource_export_package)
endif

ifdef proguard_options_file
$(my_res_package): .KATI_IMPLICIT_OUTPUTS += $(proguard_options_file)
endif

$(my_res_package): $(full_android_manifest) $(my_static_library_resources) $(my_static_library_transitive_resource_packages_lists) $(my_shared_library_resources)
$(my_res_package): $(my_full_asset_paths)
$(my_res_package): $(my_res_resources_flat) $(my_overlay_resources_flat) \
  $(my_resources_flata) $(my_static_library_resources) $(my_static_library_extra_packages) \
  $(AAPT2) $(SOONG_ZIP) $(EXTRACT_JAR_PACKAGES)
	@echo "AAPT2 link $@"
	$(call aapt2-link)
ifdef R_file_stamp
	@rm -f $(PRIVATE_R_FILE_STAMP)
	$(call find-generated-R.java,$(PRIVATE_JAVA_GEN_DIR),$(PRIVATE_R_FILE_STAMP))
endif
ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
	@rm -f $(PRIVATE_RESOURCE_EXPORT_PACKAGE)

	cp $@ $(PRIVATE_RESOURCE_EXPORT_PACKAGE)
endif

# Clear inputs only used in this file, so that they're not re-used during the next build
my_res_resources :=
my_overlay_resources :=
my_compiled_res_base_dir :=
my_asset_dirs :=
my_full_asset_paths :=
my_apk_split_configs :=
my_generated_res_dirs :=
my_generated_res_dirs_deps :=
my_generated_res_zips :=
