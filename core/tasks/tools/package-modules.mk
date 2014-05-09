# Package up modules to a zip file.
# It preserves the install path of the modules' installed files.
#
# Input variables:
#   my_modules: a list of module names
#   my_package_name: the name of the output zip file.
# Output variables:
#   my_package_zip: the path to the output zip file.
#
#

my_staging_dir := $(call intermediates-dir-for,PACKAGING,$(my_package_name))
my_built_modules :=
my_copy_pairs :=
my_pickup_files :=

# Search for modules' built files and installed files;
# Calculate the dest files in the output zip file.
# If for 1 module name we found multiple installed files,
# we use suffix matching to find the corresponding built file.
$(foreach m,$(my_modules),\
  $(if $(ALL_MODULES.$(m).INSTALLED),,\
    $(warning Unknown installed file for module '$(m)'))\
  $(eval my_pickup_files += $(ALL_MODULES.$(m).PICKUP_FILES))\
  $(foreach i,$(filter $(TARGET_OUT_ROOT)/%,$(ALL_MODULES.$(m).INSTALLED)),\
    $(eval my_suffix := $(suffix $(i))) \
    $(if $(my_suffix),\
      $(eval my_patt := $(TARGET_OUT_ROOT)/%$(my_suffix)),\
      $(eval my_patt := $(TARGET_OUT_ROOT)/%$(notdir $(i))))\
    $(eval b := $(filter $(my_patt),$(ALL_MODULES.$(m).BUILT)))\
    $(if $(filter 1,$(words $(b))),\
      $(eval my_built_modules += $(b))\
      $(eval my_copy_dest := $(patsubst data/%,DATA/%,\
                               $(patsubst system/%,SYSTEM/%,\
                                 $(patsubst $(PRODUCT_OUT)/%,%,$(i)))))\
      $(eval my_copy_pairs += $(b):$(my_staging_dir)/$(my_copy_dest)),\
      $(warning Unexpected module built file '$(b)' for module '$(m)'))\
  ))

my_package_zip := $(my_staging_dir)/$(my_package_name).zip
$(my_package_zip): PRIVATE_COPY_PAIRS := $(my_copy_pairs)
$(my_package_zip): PRIVATE_PICKUP_FILES := $(my_pickup_files)
$(my_package_zip) : $(my_built_modules)
	@echo "Package $@"
	@rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) $(foreach p, $(PRIVATE_COPY_PAIRS), \
	  $(eval pair := $(subst :,$(space),$(p)))\
	  mkdir -p $(dir $(word 2,$(pair))); \
	  cp -rf $(word 1,$(pair)) $(word 2,$(pair));)
	$(hide) $(foreach f, $(PRIVATE_PICKUP_FILES), \
	  cp -rf $(f) $(dir $@);)
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) *
