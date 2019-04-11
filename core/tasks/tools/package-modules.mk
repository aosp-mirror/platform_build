# Package up modules to a zip file.
# It preserves the install path of the modules' installed files.
#
# Input variables:
#   my_modules: a list of module names
#   my_package_name: the name of the output zip file.
#   my_copy_pairs: a list of extra files to install (in src:dest format)
# Output variables:
#   my_package_zip: the path to the output zip file.
#
#

my_makefile := $(lastword $(filter-out $(lastword $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
my_staging_dir := $(call intermediates-dir-for,PACKAGING,$(my_package_name))
my_built_modules := $(foreach p,$(my_copy_pairs),$(call word-colon,1,$(p)))
my_copy_pairs := $(foreach p,$(my_copy_pairs),$(call word-colon,1,$(p)):$(my_staging_dir)/$(call word-colon,2,$(p)))
my_pickup_files :=

# Iterate over the modules and include their direct dependencies stated in the
# LOCAL_REQUIRED_MODULES.
my_modules_and_deps := $(my_modules)
$(foreach m,$(my_modules),\
  $(eval _explicitly_required := \
    $(strip $(ALL_MODULES.$(m).EXPLICITLY_REQUIRED_FROM_TARGET)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).EXPLICITLY_REQUIRED_FROM_TARGET)))\
  $(eval my_modules_and_deps += $(_explicitly_required))\
)

# Ignore unknown installed files on partial builds
my_missing_files :=
ifneq ($(ALLOW_MISSING_DEPENDENCIES),true)
my_missing_files = $(shell $(call echo-warning,$(my_makefile),$(my_package_name): Unknown installed file for module '$(1)'))
endif

# Iterate over modules' built files and installed files;
# Calculate the dest files in the output zip file.

$(foreach m,$(my_modules_and_deps),\
  $(eval _pickup_files := $(strip $(ALL_MODULES.$(m).PICKUP_FILES)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).PICKUP_FILES)))\
  $(eval _built_files := $(strip $(ALL_MODULES.$(m).BUILT_INSTALLED)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).BUILT_INSTALLED)))\
  $(eval _module_class_folder := $($(strip MODULE_CLASS_$(word 1, $(strip $(ALL_MODULES.$(m).CLASS)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).CLASS))))))\
  $(if $(_pickup_files)$(_built_files),,\
    $(call my_missing_files,$(m)))\
  $(eval my_pickup_files += $(_pickup_files))\
  $(foreach i, $(_built_files),\
    $(eval bui_ins := $(subst :,$(space),$(i)))\
    $(eval ins := $(word 2,$(bui_ins)))\
    $(if $(filter $(TARGET_OUT_ROOT)/%,$(ins)),\
      $(eval bui := $(word 1,$(bui_ins)))\
      $(eval my_built_modules += $(bui))\
      $(if $(filter $(_module_class_folder), nativetest benchmarktest),\
        $(eval module_class_folder_stem := $(_module_class_folder)$(findstring 64, $(patsubst $(PRODUCT_OUT)/%,%,$(ins)))),\
        $(eval module_class_folder_stem := $(_module_class_folder)))\
      $(eval my_copy_dest := $(patsubst data/%,DATA/%,\
                               $(patsubst testcases/%,DATA/$(module_class_folder_stem)/%,\
                                 $(patsubst testcases/$(m)/$(TARGET_ARCH)/%,DATA/$(module_class_folder_stem)/$(m)/%,\
                                   $(patsubst testcases/$(m)/$(TARGET_2ND_ARCH)/%,DATA/$(module_class_folder_stem)/$(m)/%,\
                                     $(patsubst system/%,DATA/%,\
                                       $(patsubst $(PRODUCT_OUT)/%,%,$(ins))))))))\
      $(eval my_copy_pairs += $(bui):$(my_staging_dir)/$(my_copy_dest)))\
  ))

my_package_zip := $(my_staging_dir)/$(my_package_name).zip
$(my_package_zip): PRIVATE_COPY_PAIRS := $(my_copy_pairs)
$(my_package_zip): PRIVATE_PICKUP_FILES := $(my_pickup_files)
$(my_package_zip) : $(my_built_modules)
	@echo "Package $@"
	@rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(foreach p, $(PRIVATE_COPY_PAIRS),\
	  $(eval pair := $(subst :,$(space),$(p)))\
	  mkdir -p $(dir $(word 2,$(pair))) && \
	  cp -Rf $(word 1,$(pair)) $(word 2,$(pair)) && ) true
	$(hide) $(foreach f, $(PRIVATE_PICKUP_FILES),\
	  cp -RfL $(f) $(dir $@) && ) true
	$(hide) cd $(dir $@) && zip -rqX $(notdir $@) *

my_makefile :=
my_staging_dir :=
my_built_modules :=
my_copy_dest :=
my_copy_pairs :=
my_pickup_files :=
my_missing_files :=
my_modules_and_deps :=
