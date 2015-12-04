######################################
# Compile resource with AAPT2
# Input variables:
# full_android_manifest,
# my_res_resources, my_overlay_resources, my_aapt_characteristics,
# my_compiled_res_base_dir, rs_generated_res_dir, my_res_package,
# R_file_stamp, proguard_options_file
# Output variables:
# my_res_resources_flat, my_overlay_resources_flat,
# my_generated_resources_flata
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
ifneq ($(rs_generated_res_dir),)
rs_gen_resource_flata := $(my_compiled_res_base_dir)/renderscript_gen_res.flata
$(rs_gen_resource_flata): PRIVATE_SOURCE_RES_DIR := $(rs_generated_res_dir)
$(rs_gen_resource_flata) : $(RenderScript_file_stamp)
	@echo "AAPT2 compile $@ <- $(PRIVATE_SOURCE_RES_DIR)"
	$(call aapt2-compile-one-resource-dir)

my_generated_resources_flata += $(rs_gen_resource_flata)
endif

$(my_res_resources_flat) $(my_overlay_resources_flat) $(my_generated_resources_flata): \
  PRIVATE_AAPT2_CFLAGS := $(addprefix --product ,$(my_aapt_characteristics))

# Link the static library resource packages.
my_static_library_resources := $(foreach l, $(LOCAL_STATIC_JAVA_LIBRARIES),\
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(l),,COMMON)/library-res.flata)

$(my_res_package): PRIVATE_RES_FLAT := $(my_res_resources_flat)
$(my_res_package): PRIVATE_OVERLAY_FLAT := $(my_overlay_resources_flat) $(my_generated_resources_flata) $(my_static_library_resources)
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE := $(proguard_options_file)
$(my_res_package) : $(full_android_manifest)
$(my_res_package) : $(my_res_resources_flat) $(my_overlay_resources_flat) \
  $(my_generated_resources_flata) $(my_static_library_resources) \
  $(AAPT2)
	@echo "AAPT2 link $@"
	$(call aapt2-link)

$(R_file_stamp) : $(my_res_package) | $(ACP)
	@echo "target R.java/Manifest.java: $(PRIVATE_MODULE) ($@)"
	@rm -rf $@ && mkdir -p $(dir $@)
	$(call find-generated-R.java)

$(proguard_options_file) : $(my_res_package)

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
