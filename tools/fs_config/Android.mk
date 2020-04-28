# Copyright (C) 2008 The Android Open Source Project
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

LOCAL_PATH := $(call my-dir)

# One can override the default android_filesystem_config.h file by using TARGET_FS_CONFIG_GEN.
#   Set TARGET_FS_CONFIG_GEN to contain a list of intermediate format files
#   for generating the android_filesystem_config.h file.
#
# More information can be found in the README

ifneq ($(wildcard $(TARGET_DEVICE_DIR)/android_filesystem_config.h),)
$(error Using $(TARGET_DEVICE_DIR)/android_filesystem_config.h is deprecated, please use TARGET_FS_CONFIG_GEN instead)
endif

system_android_filesystem_config := system/core/include/private/android_filesystem_config.h
system_capability_header := bionic/libc/kernel/uapi/linux/capability.h

# List of supported vendor, oem, odm, product and product_services Partitions
fs_config_generate_extra_partition_list := $(strip \
  $(if $(BOARD_USES_VENDORIMAGE)$(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE),vendor) \
  $(if $(BOARD_USES_OEMIMAGE)$(BOARD_OEMIMAGE_FILE_SYSTEM_TYPE),oem) \
  $(if $(BOARD_USES_ODMIMAGE)$(BOARD_ODMIMAGE_FILE_SYSTEM_TYPE),odm) \
  $(if $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE),product) \
  $(if $(BOARD_PRODUCT_SERVICESIMAGE_FILE_SYSTEM_TYPE),product_services) \
)

##################################
# Generate the <p>/etc/fs_config_dirs binary files for each partition.
# Add fs_config_dirs to PRODUCT_PACKAGES in the device make file to enable.
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs
LOCAL_REQUIRED_MODULES := \
	fs_config_dirs_system \
	$(foreach t,$(fs_config_generate_extra_partition_list),$(LOCAL_MODULE)_$(t))
include $(BUILD_PHONY_PACKAGE)


##################################
# Generate the <p>/etc/fs_config_files binary files for each partition.
# Add fs_config_files to PRODUCT_PACKAGES in the device make file to enable.
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files
LOCAL_REQUIRED_MODULES := \
  fs_config_files_system \
  $(foreach t,$(fs_config_generate_extra_partition_list),$(LOCAL_MODULE)_$(t))
include $(BUILD_PHONY_PACKAGE)

##################################
# Generate the <p>/etc/fs_config_dirs binary files for all enabled partitions
# excluding /system. Add fs_config_dirs_nonsystem to PRODUCT_PACKAGES in the
# device make file to enable.
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_nonsystem
LOCAL_REQUIRED_MODULES := $(foreach t,$(fs_config_generate_extra_partition_list),fs_config_dirs_$(t))
include $(BUILD_PHONY_PACKAGE)

##################################
# Generate the <p>/etc/fs_config_files binary files for all enabled partitions
# excluding /system. Add fs_config_files_nonsystem to PRODUCT_PACKAGES in the
# device make file to enable.
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_nonsystem
LOCAL_REQUIRED_MODULES := $(foreach t,$(fs_config_generate_extra_partition_list),fs_config_files_$(t))
include $(BUILD_PHONY_PACKAGE)

##################################
# Generate the system/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_system to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_system
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_PARTITION_LIST := $(fs_config_generate_extra_partition_list)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition system \
	   --all-partitions "$(subst $(space),$(comma),$(PRIVATE_PARTITION_LIST))" \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the system/etc/fs_config_files binary file for the target
# Add fs_config_files or fs_config_files_system to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_system
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_PARTITION_LIST := $(fs_config_generate_extra_partition_list)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition system \
	   --all-partitions "$(subst $(space),$(comma),$(PRIVATE_PARTITION_LIST))" \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

ifneq ($(filter vendor,$(fs_config_generate_extra_partition_list)),)
##################################
# Generate the vendor/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_vendor to PRODUCT_PACKAGES in
# the device make file to enable.
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_vendor
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition vendor \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the vendor/etc/fs_config_files binary file for the target
# Add fs_config_files or fs_config_files_vendor to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_vendor
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition vendor \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

endif

ifneq ($(filter oem,$(fs_config_generate_extra_partition_list)),)
##################################
# Generate the oem/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_oem to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_oem
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
LOCAL_MODULE_PATH := $(TARGET_OUT_OEM)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition oem \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the oem/etc/fs_config_files binary file for the target
# Add fs_config_files or fs_config_files_oem to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_oem
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
LOCAL_MODULE_PATH := $(TARGET_OUT_OEM)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition oem \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

endif

ifneq ($(filter odm,$(fs_config_generate_extra_partition_list)),)
##################################
# Generate the odm/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_odm to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_odm
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
LOCAL_MODULE_PATH := $(TARGET_OUT_ODM)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition odm \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the odm/etc/fs_config_files binary file for the target
# Add fs_config_files of fs_config_files_odm to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_odm
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
LOCAL_MODULE_PATH := $(TARGET_OUT_ODM)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition odm \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

endif

ifneq ($(filter product,$(fs_config_generate_extra_partition_list)),)
##################################
# Generate the product/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_product to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_product
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition product \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the product/etc/fs_config_files binary file for the target
# Add fs_config_files of fs_config_files_product to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_product
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition product \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)
endif

ifneq ($(filter product_services,$(fs_config_generate_extra_partition_list)),)
##################################
# Generate the product_services/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs or fs_config_dirs_product_services to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs_product_services
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_dirs
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_SERVICES)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition product_services \
	   --dirs \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)

##################################
# Generate the product_services/etc/fs_config_files binary file for the target
# Add fs_config_files of fs_config_files_product_services to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_product_services
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_SERVICES)/etc
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_CAP_HDR := $(system_capability_header)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(system_capability_header)
	@mkdir -p $(dir $@)
	$< fsconfig \
	   --aid-header $(PRIVATE_ANDROID_FS_HDR) \
	   --capability-header $(PRIVATE_ANDROID_CAP_HDR) \
	   --partition product_services \
	   --files \
	   --out_file $@ \
	   $(or $(PRIVATE_TARGET_FS_CONFIG_GEN),/dev/null)
endif

system_android_filesystem_config :=
system_capability_header :=
fs_config_generate_extra_partition_list :=
