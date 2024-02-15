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

my_kernel_module_copy_files :=
my_custom_image_modules_var := BOARD_$(strip $(call to-upper,$(my_custom_image_name)))_KERNEL_MODULES
ifdef $(my_custom_image_modules_var)
$(foreach kmod,\
  $(call build-image-kernel-modules,$($(my_custom_image_modules_var)),$(my_staging_dir),$(CUSTOM_IMAGE_MOUNT_POINT),$(call intermediates-dir-for,PACKAGING,depmod_$(my_custom_image_name)),$($(my_custom_image_modules_var)),modules.load,,$(call intermediates-dir-for,PACKAGING,depmod_$(my_custom_image_name)_stripped)),\
  $(eval pair := $(subst :,$(space),$(kmod)))\
  $(eval my_kernel_module_copy_files += $(word 1,$(pair)):$(subst $(my_staging_dir)/,,$(word 2,$(pair)))))
endif

# Collect CUSTOM_IMAGE_COPY_FILES.
my_image_copy_files :=
$(foreach f,$(CUSTOM_IMAGE_COPY_FILES) $(my_kernel_module_copy_files),\
  $(eval pair := $(subst :,$(space),$(f)))\
  $(eval src := $(word 1,$(pair)))\
  $(eval my_image_copy_files += $(src))\
  $(eval my_copy_pairs += $(src):$(my_staging_dir)/$(word 2,$(pair))))

ifdef CUSTOM_IMAGE_AVB_KEY_PATH
ifndef CUSTOM_IMAGE_AVB_ALGORITHM
  $(error CUSTOM_IMAGE_AVB_ALGORITHM is not defined)
endif
ifndef CUSTOM_IMAGE_AVB_ROLLBACK_INDEX
  $(error CUSTOM_IMAGE_AVB_ROLLBACK_INDEX is not defined)
endif
# set rollback_index via footer args
CUSTOM_IMAGE_AVB_ADD_HASH_FOOTER_ARGS += --rollback_index $(CUSTOM_IMAGE_AVB_ROLLBACK_INDEX)
CUSTOM_IMAGE_AVB_ADD_HASHTREE_FOOTER_ARGS += --rollback_index $(CUSTOM_IMAGE_AVB_ROLLBACK_INDEX)
endif

$(my_built_custom_image): PRIVATE_INTERMEDIATES := $(intermediates)
$(my_built_custom_image): PRIVATE_MOUNT_POINT := $(CUSTOM_IMAGE_MOUNT_POINT)
$(my_built_custom_image): PRIVATE_PARTITION_SIZE := $(CUSTOM_IMAGE_PARTITION_SIZE)
$(my_built_custom_image): PRIVATE_FILE_SYSTEM_TYPE := $(CUSTOM_IMAGE_FILE_SYSTEM_TYPE)
$(my_built_custom_image): PRIVATE_STAGING_DIR := $(my_staging_dir)
$(my_built_custom_image): PRIVATE_COPY_PAIRS := $(my_copy_pairs)
$(my_built_custom_image): PRIVATE_PICKUP_FILES := $(my_pickup_files)
$(my_built_custom_image): PRIVATE_SELINUX := $(CUSTOM_IMAGE_SELINUX)
$(my_built_custom_image): PRIVATE_VERITY_BLOCK_DEVICE := $(CUSTOM_IMAGE_VERITY_BLOCK_DEVICE)
$(my_built_custom_image): PRIVATE_DICT_FILE := $(CUSTOM_IMAGE_DICT_FILE)
$(my_built_custom_image): PRIVATE_AVB_AVBTOOL := $(AVBTOOL)
$(my_built_custom_image): PRIVATE_AVB_KEY_PATH := $(CUSTOM_IMAGE_AVB_KEY_PATH)
$(my_built_custom_image): PRIVATE_AVB_ALGORITHM:= $(CUSTOM_IMAGE_AVB_ALGORITHM)
$(my_built_custom_image): PRIVATE_AVB_HASH_ENABLE := $(CUSTOM_IMAGE_AVB_HASH_ENABLE)
$(my_built_custom_image): PRIVATE_AVB_ADD_HASH_FOOTER_ARGS := $(CUSTOM_IMAGE_AVB_ADD_HASH_FOOTER_ARGS)
$(my_built_custom_image): PRIVATE_AVB_HASHTREE_ENABLE := $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)
$(my_built_custom_image): PRIVATE_AVB_ADD_HASHTREE_FOOTER_ARGS := $(CUSTOM_IMAGE_AVB_ADD_HASHTREE_FOOTER_ARGS)
ifeq (true,$(filter true, $(CUSTOM_IMAGE_AVB_HASH_ENABLE) $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)))
  $(my_built_custom_image): $(AVBTOOL)
else ifneq (,$(filter true, $(CUSTOM_IMAGE_AVB_HASH_ENABLE) $(CUSTOM_IMAGE_AVB_HASHTREE_ENABLE)))
  $(error Cannot set both CUSTOM_IMAGE_AVB_HASH_ENABLE and CUSTOM_IMAGE_AVB_HASHTREE_ENABLE to true)
endif
ifeq ($(strip $(HAS_BUILD_NUMBER)),true)
$(my_built_custom_image): $(BUILD_NUMBER_FILE)
endif
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
	$(if $($(PRIVATE_PICKUP_FILES)),$(hide) cp -Rf $(PRIVATE_PICKUP_FILES) $(PRIVATE_STAGING_DIR))
	# Generate the dict.
	$(hide) echo "# For all accepted properties, see BuildImage() in tools/releasetools/build_image.py" > $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "mount_point=$(PRIVATE_MOUNT_POINT)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "partition_name=$(PRIVATE_MOUNT_POINT)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "fs_type=$(PRIVATE_FILE_SYSTEM_TYPE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "partition_size=$(PRIVATE_PARTITION_SIZE)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(hide) echo "ext_mkuserimg=$(notdir $(MKEXTUSERIMG))" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(if $(PRIVATE_SELINUX),$(hide) echo "selinux_fc=$(SELINUX_FC)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(if $(filter eng, $(TARGET_BUILD_VARIANT)),$(hide) echo "verity_disable=true" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
	$(hide) echo "avb_avbtool=$(PRIVATE_AVB_AVBTOOL)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt
	$(if $(PRIVATE_AVB_KEY_PATH),\
	  $(hide) echo "avb_key_path=$(PRIVATE_AVB_KEY_PATH)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt;\
	    echo "avb_algorithm=$(PRIVATE_AVB_ALGORITHM)" >> $(PRIVATE_INTERMEDIATES)/image_info.txt)
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
	  $(hide) echo "oem.buildnumber=$(BUILD_NUMBER_FROM_FILE)" >> $(PRIVATE_STAGING_DIR)/oem.prop)
	$(hide) PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
	    $(BUILD_IMAGE) \
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
