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

# Iterate over modules' built files and installed files;
# Calculate the dest files in the output zip file.

$(foreach m,$(my_modules),\
  $(eval _pickup_files := $(strip $(ALL_MODULES.$(m).PICKUP_FILES)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).PICKUP_FILES)))\
  $(eval _built_files := $(strip $(ALL_MODULES.$(m).BUILT_INSTALLED)\
    $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).BUILT_INSTALLED)))\
  $(if $(_pickup_files)$(_built_files),,\
    $(warning Unknown installed file for module '$(m)'))\
  $(eval my_pickup_files += $(_pickup_files))\
  $(foreach i, $(_built_files),\
    $(eval bui_ins := $(subst :,$(space),$(i)))\
    $(eval ins := $(word 2,$(bui_ins)))\
    $(if $(filter $(TARGET_OUT_ROOT)/%,$(ins)),\
      $(eval bui := $(word 1,$(bui_ins)))\
      $(eval my_built_modules += $(bui))\
      $(eval my_copy_dest := $(patsubst data/%,DATA/%,\
                               $(patsubst system/%,DATA/%,\
                                 $(patsubst $(PRODUCT_OUT)/%,%,$(ins)))))\
      $(eval my_copy_pairs += $(bui):$(my_staging_dir)/$(my_copy_dest)))\
  ))

define copy-tests-in-batch
$(hide) $(foreach p, $(1),\
  $(eval pair := $(subst :,$(space),$(p)))\
  mkdir -p $(dir $(word 2,$(pair)));\
  cp -rf $(word 1,$(pair)) $(word 2,$(pair));)
endef

my_package_zip := $(my_staging_dir)/$(my_package_name).zip
$(my_package_zip): PRIVATE_COPY_PAIRS := $(my_copy_pairs)
$(my_package_zip): PRIVATE_PICKUP_FILES := $(my_pickup_files)
$(my_package_zip) : $(my_built_modules)
	@echo "Package $@"
	@rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(call copy-tests-in-batch,$(wordlist 1,200,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 201,400,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 401,600,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 601,800,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 801,1000,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 1001,1200,$(PRIVATE_COPY_PAIRS)))
	$(call copy-tests-in-batch,$(wordlist 1201,9999,$(PRIVATE_COPY_PAIRS)))
	$(hide) $(foreach f, $(PRIVATE_PICKUP_FILES),\
	  cp -rf $(f) $(dir $@);)
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) *
