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

my_generated_resources_flata :=
# Compile generated resources
ifneq ($(my_generated_res_dirs),)
my_generated_resources_flata := $(my_compiled_res_base_dir)/gen_res.flata
$(my_generated_resources_flata): PRIVATE_SOURCE_RES_DIRS := $(my_generated_res_dirs)
$(my_generated_resources_flata) : $(my_generated_res_dirs_deps) $(AAPT2)
	@echo "AAPT2 compile $@ <- $(PRIVATE_SOURCE_RES_DIRS)"
	$(call aapt2-compile-resource-dirs)

my_generated_resources_flata += $(my_generated_resources_flata)
endif

$(my_res_resources_flat) $(my_overlay_resources_flat) $(my_generated_resources_flata): \
  PRIVATE_AAPT2_CFLAGS := $(PRODUCT_AAPT2_CFLAGS)

my_static_library_resources := $(foreach l, $(call reverse-list,$(LOCAL_STATIC_ANDROID_LIBRARIES)),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/package-res.apk)
my_shared_library_resources := $(foreach l, $(LOCAL_SHARED_ANDROID_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/package-res.apk)

ifneq ($(my_static_library_resources),)
$(my_res_package): PRIVATE_AAPT_FLAGS += --auto-add-overlay
endif

ifneq ($(my_apk_split_configs),)
# Join the Split APK paths with their configuration, separated by a ':'.
$(my_res_package): PRIVATE_AAPT_FLAGS += $(addprefix --split ,$(join $(built_apk_splits),$(addprefix :,$(my_apk_split_configs))))
endif

$(my_res_package): PRIVATE_RES_FLAT := $(my_res_resources_flat)
$(my_res_package): PRIVATE_OVERLAY_FLAT := $(my_static_library_resources) $(my_generated_resources_flata) $(my_overlay_resources_flat)
$(my_res_package): PRIVATE_SHARED_ANDROID_LIBRARIES := $(my_shared_library_resources)
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(my_res_package): PRIVATE_ASSET_DIRS := $(my_asset_dirs)
$(my_res_package): $(full_android_manifest) $(my_static_library_resources) $(my_shared_library_resources)
$(my_res_package): $(my_full_asset_paths)
$(my_res_package): $(my_res_resources_flat) $(my_overlay_resources_flat) \
  $(my_generated_resources_flata) $(my_static_library_resources) \
  $(AAPT2)
	@echo "AAPT2 link $@"
	$(call aapt2-link)

ifdef R_file_stamp
$(R_file_stamp) : $(my_res_package) | $(ACP)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	@rm -rf $@ && mkdir -p $(dir $@)
	$(call find-generated-R.java)
endif

ifdef proguard_options_file
$(proguard_options_file) : $(my_res_package)
endif

resource_export_package :=
ifdef LOCAL_EXPORT_PACKAGE_RESOURCES
# Put this module's resources into a PRODUCT-agnositc package that
# other packages can use to build their own PRODUCT-agnostic R.java (etc.)
# files.
resource_export_package := $(intermediates.COMMON)/package-export.apk
$(R_file_stamp) : $(resource_export_package)

$(resource_export_package) : $(my_res_package) | $(ACP)
	@echo "target Export Resources: $(PRIVATE_MODULE) $(@)"
	$(copy-file-to-new-target)

endif
