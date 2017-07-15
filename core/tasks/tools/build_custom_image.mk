#
# Copyright (C) 2015 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Define rule to build one custom image.
# Input variables: my_custom_imag_makefile

$(call clear-var-list, $(custom_image_parameter_variables))

include $(my_custom_imag_makefile)

my_custom_image_name := $(basename $(notdir $(my_custom_imag_makefile)))

intermediates := $(call intermediates-dir-for,PACKAGING,$(my_custom_image_name))
my_built_custom_image := $(intermediates)/$(my_custom_image_name).img
my_staging_dir := $(intermediates)/$(CUSTOM_IMAGE_MOUNT_POINT)

# Collect CUSTOM_IMAGE_MODULES's installd files and their PICKUP_FILES.
my_built_modules :=
my_copy_pairs :=
my_pickup_files :=

$(foreach m,$(CUSTOM_IMAGE_MODULES),\
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
      $(eval my_copy_dest := $(patsubst $(PRODUCT_OUT)/%,%,$(ins)))\
      $(eval my_copy_dest := $(subst /,$(space),$(my_copy_dest)))\
      $(eval my_copy_dest := $(wordlist 2,999,$(my_copy_dest)))\
      $(eval my_copy_dest := $(subst $(space),/,$(my_copy_dest)))\
      $(eval my_copy_pairs += $(bui):$(my_staging_dir)/$(my_copy_dest)))\
  ))

# Collect CUSTOM_IMAGE_COPY_FILES.
my_image_copy_files :=
$(foreach f,$(CUSTOM_IMAGE_COPY_FILES),\
  $(eval pair := $(subst :,$(space),$(f)))\
  $(eval src := $(word 1,$(pair)))\
  $(eval my_image_copy_files += $(src))\
  $(eval my_copy_pairs += $(src):$(my_staging_dir)/$(word 2,$(pair))))

ifndef CUSTOM_IMAGE_AVB_KEY_PATH
# If key path isn't specified, use the default signing args.
my_avb_signing_args := $(INTERNAL_AVB_SIGNING_ARGS)
else
my_avb_signing_args := \
  --algorithm $(CUSTOM_IMAGE_AVB_ALGORITHM) --key $(CUSTOM_IMAGE_AVB_KEY_PATH)
endif

$(my_built_custom_image): PRIVATE_INTERMEDIATES := $(intermediates)
$(my_built_custom_image): PRIVATE_MOUNT_POINT := $(CUSTOM_IMAGE_MOUNT_POINT)
$(my_built_custom_image): PRIVATE_PARTITION_SIZE := $(CUSTOM_IMAGE_PARTITION_SIZE)
$(my_built_custom_image): PRIVATE_FILE_SYSTEM_TYPE := $(CUSTOM_IMAGE_FILE_SYSTEM_TYPE)
$(my_built_custom_image): PRIVATE_STAGING_DIR := $(my_staging_dir)
$(my_built_custom_image): PRIVATE_COPY_PAIRS := $(my_copy_pairs)
$(my_built_custom_image): PRIVATE_PICKUP_FILES := $(my_pickup_files)
$(my_built_custom_image): PRIVATE_SELINUX := $(CUSTOM_IMAGE_SELINUX)
$(my_built_custom_image): PRIVATE_SUPPORT_VERITY := $(CUSTOM_IMAGE_SUPPORT_VERITY)
$(my_built_custom_image): PRIVATE_SUPPORT_VERITY_FEC := $(CUSTOM_IMAGE_SUPPORT_VERITY_FEC)
$(my_built_custom_image): PRIVATE_VERITY_KEY := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY)
$(my_built_custom_image): PRIVATE_VERITY_BLOCK_DEVICE := $(CUSTOM_IMAGE_VERITY_BLOCK_DEVICE)
$(my_built_custom_image): PRIVATE_DICT_FILE := $(CUSTOM_IMAGE_DICT_FILE)
$(my_built_custom_image): PRIVATE_AVB_AVBTOOL := $(AVBTOOL)
$(my_built_custom_image): PRIVATE_AVB_SIGNING_ARGS := $(my_avb_signing_args)
$(my_built_custom_image): PRIVATE_AVB_HASH_ENABLE := $(CUSTOM_IMAGE_AVB_HASH_ENABLE)
$(my_built_custom_image): PRIVATE_AVB_ADD_HASH_FOOTER_ARGS := $(CUSTOM_IMAGE_AVB_ADD_HASH_FOOTER_ARGS)
$(my_built_custom_image): PRIVATE_AVB_HASHTREE_ENABLE := $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)
$(my_built_custom_image): PRIVATE_AVB_ADD_HASHTREE_FOOTER_ARGS := $(CUSTOM_IMAGE_AVB_ADD_HASHTREE_FOOTER_ARGS)
ifeq (true,$(filter true, $(CUSTOM_IMAGE_AVB_HASH_ENABLE) $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)))
  $(my_built_custom_image): $(AVBTOOL)
else ifneq (,$(filter true, $(CUSTOM_IMAGE_AVB_HASH_ENABLE) $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)))
  $(error Cannot set both CUSTOM_IMAGE_AVB_HASH_ENABLE and CUSTOM_IMAGE_AVB_HASHTREE_ENABLE to true)
endif
ifeq (true,$(CUSTOM_IMAGE_SUPPORT_VERITY_FEC))
  $(my_built_custom_image): $(FEC)
endif
my_custom_image_modules_var:=BOARD_$(strip $(call to-upper,$(my_custom_image_name)))_KERNEL_MODULES
my_custom_image_modules:=$($(my_custom_image_modules_var))
my_custom_image_modules_dep:=$(if $(my_custom_image_modules),$(my_custom_image_modules) $(DEPMOD),)
$(my_built_custom_image): PRIVATE_KERNEL_MODULES := $(my_custom_image_modules)
$(my_built_custom_image): PRIVATE_IMAGE_NAME := $(my_custom_image_name)
$(my_built_custom_image): $(INTERNAL_USERIMAGES_DEPS) $(my_built_modules) $(my_image_copy_files) $(my_custom_image_modules_dep) \
  $(CUSTOM_IMAGE_DICT_FILE)
	@echo "Build image $@"
	$(hide) rm -rf $(PRIVATE_INTERMEDIATES) && mkdir -p $(PRIVATE_INTERMEDIATES)
	$(hide) rm -rf $(PRIVATE_STAGING_DIR) && mkdir -p $(PRIVATE_STAGING_DIR)
	# Copy all the files.
	$(hide) $(foreach p,$(PRIVATE_COPY_PAIRS),\
	          $(eval pair := $(subst :,$(space),$(p)))\
	          mkdir -p $(dir $(word 2,$(pair)));\
	          cp -Rf $(word 1,$(pair)) $(word 2,$(pair));)
	$(if $(PRIVATE_KERNEL_MODULES), \
		$(call build-image-kernel-modules,$(PRIVATE_KERNEL_MODULES),$(PRIVATE_STAGING_DIR),$(PRIVATE_IMAGE_NAME)/,$(call intermediates-dir-for,PACKAGING,depmod_$(PRIVATE_IMAGE_NAME))))
	$(if $($(PRIVATE_PICKUP_FILES)),$(hide) cp -Rf $(PRIVATE_PICKUP_FILES) $(PRIVATE_STAGING_DIR))
	# Generate the dict.
	$(hide) echo "# For all accepted properties, see BuildImage() in tools/releasetools/build_image.py" > $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "mount_point=$(PRIVATE_MOUNT_POINT)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "partition_name=$(PRIVATE_MOUNT_POINT)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "fs_type=$(PRIVATE_FILE_SYSTEM_TYPE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "partition_size=$(PRIVATE_PARTITION_SIZE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "ext_mkuserimg=$(notdir $(MKEXTUSERIMG))" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(if $(PRIVATE_SELINUX),$(hide) echo "selinux_fc=$(SELINUX_FC)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(if $(PRIVATE_SUPPORT_VERITY),\
	  $(hide) echo "verity=$(PRIVATE_SUPPORT_VERITY)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "verity_key=$(PRIVATE_VERITY_KEY)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "verity_signer_cmd=$(VERITY_SIGNER)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "verity_block_device=$(PRIVATE_VERITY_BLOCK_DEVICE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(if $(PRIVATE_SUPPORT_VERITY_FEC),\
	  $(hide) echo "verity_fec=$(PRIVATE_SUPPORT_VERITY_FEC)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(hide) echo "avb_avbtool=$(PRIVATE_AVB_AVBTOOL)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "avb_signing_args=$(PRIVATE_AVB_SIGNING_ARGS)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(if $(PRIVATE_AVB_HASH_ENABLE),\
	  $(hide) echo "avb_hash_enable=$(PRIVATE_AVB_HASH_ENABLE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "avb_add_hash_footer_args=$(PRIVATE_AVB_ADD_HASH_FOOTER_ARGS)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(if $(PRIVATE_AVB_HASHTREE_ENABLE),\
	  $(hide) echo "avb_hashtree_enable=$(PRIVATE_AVB_HASHTREE_ENABLE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "avb_add_hashtree_footer_args=$(PRIVATE_AVB_ADD_HASHTREE_FOOTER_ARGS)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(if $(PRIVATE_DICT_FILE),\
	  $(hide) echo "# Properties from $(PRIVATE_DICT_FILE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    cat $(PRIVATE_DICT_FILE) >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	# Generate the image.
	$(if $(filter oem,$(PRIVATE_MOUNT_POINT)), \
	  $(hide) echo "oem.buildnumber=$(BUILD_NUMBER)" >> $(PRIVATE_STAGING_DIR)/oem.prop)
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
	  ./build/tools/releasetools/build_image.py \
	  $(PRIVATE_STAGING_DIR) $(PRIVATE_INTERMEDIATES)/image_info.txt $@ $(TARGET_OUT)

my_installed_custom_image := $(PRODUCT_OUT)/$(notdir $(my_built_custom_image))
$(my_installed_custom_image) : $(my_built_custom_image)
	$(call copy-file-to-new-target-with-cp)

.PHONY: $(my_custom_image_name)
custom_images $(my_custom_image_name) : $(my_installed_custom_image)

# Archive the built image.
$(call dist-for-goals, $(my_custom_image_name) custom_images,$(my_installed_custom_image))

my_staging_dir :=
my_built_modules :=
my_copy_dest :=
my_copy_pairs :=
my_pickup_files :=
