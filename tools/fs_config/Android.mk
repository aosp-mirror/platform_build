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
ANDROID_FS_CONFIG_H := android_filesystem_config.h

my_fs_config_h := $(LOCAL_PATH)/default/$(ANDROID_FS_CONFIG_H)
system_android_filesystem_config := system/core/include/private/android_filesystem_config.h

##################################
include $(CLEAR_VARS)
LOCAL_SRC_FILES := fs_config_generate.c
LOCAL_MODULE := fs_config_generate_$(TARGET_DEVICE)
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_SHARED_LIBRARIES := libcutils
LOCAL_CFLAGS := -Werror -Wno-error=\#warnings

ifneq ($(TARGET_FS_CONFIG_GEN),)
# Generate the "generated_oem_aid.h" file
oem := $(local-generated-sources-dir)/generated_oem_aid.h
$(oem): PRIVATE_LOCAL_PATH := $(LOCAL_PATH)
$(oem): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(oem): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(oem): PRIVATE_CUSTOM_TOOL = $(PRIVATE_LOCAL_PATH)/fs_config_generator.py oemaid --aid-header=$(PRIVATE_ANDROID_FS_HDR) $(PRIVATE_TARGET_FS_CONFIG_GEN) > $@
$(oem): $(TARGET_FS_CONFIG_GEN) $(LOCAL_PATH)/fs_config_generator.py
	$(transform-generated-source)

# Generate the fs_config header
gen := $(local-generated-sources-dir)/$(ANDROID_FS_CONFIG_H)
$(gen): PRIVATE_LOCAL_PATH := $(LOCAL_PATH)
$(gen): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
$(gen): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(gen): PRIVATE_CUSTOM_TOOL = $(PRIVATE_LOCAL_PATH)/fs_config_generator.py fsconfig --aid-header=$(PRIVATE_ANDROID_FS_HDR) $(PRIVATE_TARGET_FS_CONFIG_GEN) > $@
$(gen): $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config) $(LOCAL_PATH)/fs_config_generator.py
	$(transform-generated-source)

LOCAL_GENERATED_SOURCES := $(oem) $(gen)

my_fs_config_h := $(gen)
my_gen_oem_aid := $(oem)
gen :=
oem :=
endif

LOCAL_C_INCLUDES := $(dir $(my_fs_config_h)) $(dir $(my_gen_oem_aid))

include $(BUILD_HOST_EXECUTABLE)
fs_config_generate_bin := $(LOCAL_INSTALLED_MODULE)
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
$(LOCAL_BUILT_MODULE): PRIVATE_PARTITION_LIST := $(fs_config_generate_extra_partition_list)
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D $(if $(PRIVATE_PARTITION_LIST), \
	   -P '$(subst $(space),$(comma),$(addprefix -,$(PRIVATE_PARTITION_LIST)))') \
	   -o $@

##################################
# Generate the system/etc/fs_config_files binary file for the target
# Add fs_config_files or fs_config_files_system to PRODUCT_PACKAGES in
# the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files_system
LOCAL_MODULE_CLASS := ETC
LOCAL_INSTALLED_MODULE_STEM := fs_config_files
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_PARTITION_LIST := $(fs_config_generate_extra_partition_list)
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F $(if $(PRIVATE_PARTITION_LIST), \
	   -P '$(subst $(space),$(comma),$(addprefix -,$(PRIVATE_PARTITION_LIST)))') \
	   -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -P vendor -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -P vendor -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -P oem -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -P oem -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -P odm -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -P odm -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -P product -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -P product -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -P product_services -o $@

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
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -P product_services -o $@

endif

##################################
# Build the oemaid header library when fs config files are present.
# Intentionally break build if you require generated AIDs
# header file, but are not using any fs config files.
ifneq ($(TARGET_FS_CONFIG_GEN),)
include $(CLEAR_VARS)
LOCAL_MODULE := oemaids_headers
LOCAL_EXPORT_C_INCLUDE_DIRS := $(dir $(my_gen_oem_aid))
LOCAL_EXPORT_C_INCLUDE_DEPS := $(my_gen_oem_aid)
include $(BUILD_HEADER_LIBRARY)
endif

##################################
# Generate the vendor/etc/passwd text file for the target
# This file may be empty if no AIDs are defined in
# TARGET_FS_CONFIG_GEN files.
include $(CLEAR_VARS)

LOCAL_MODULE := passwd
LOCAL_MODULE_CLASS := ETC
LOCAL_VENDOR_MODULE := true

include $(BUILD_SYSTEM)/base_rules.mk

ifneq ($(TARGET_FS_CONFIG_GEN),)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
else
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := /dev/null
endif
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config)
	@mkdir -p $(dir $@)
	$(hide) $< passwd --required-prefix=vendor_ --aid-header=$(PRIVATE_ANDROID_FS_HDR) $(PRIVATE_TARGET_FS_CONFIG_GEN) > $@

##################################
# Generate the vendor/etc/group text file for the target
# This file may be empty if no AIDs are defined in
# TARGET_FS_CONFIG_GEN files.
include $(CLEAR_VARS)

LOCAL_MODULE := group
LOCAL_MODULE_CLASS := ETC
LOCAL_VENDOR_MODULE := true

include $(BUILD_SYSTEM)/base_rules.mk

ifneq ($(TARGET_FS_CONFIG_GEN),)
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := $(TARGET_FS_CONFIG_GEN)
else
$(LOCAL_BUILT_MODULE): PRIVATE_TARGET_FS_CONFIG_GEN := /dev/null
endif
$(LOCAL_BUILT_MODULE): PRIVATE_ANDROID_FS_HDR := $(system_android_filesystem_config)
$(LOCAL_BUILT_MODULE): $(LOCAL_PATH)/fs_config_generator.py $(TARGET_FS_CONFIG_GEN) $(system_android_filesystem_config)
	@mkdir -p $(dir $@)
	$(hide) $< group --required-prefix=vendor_ --aid-header=$(PRIVATE_ANDROID_FS_HDR) $(PRIVATE_TARGET_FS_CONFIG_GEN) > $@

system_android_filesystem_config :=

ANDROID_FS_CONFIG_H :=
my_fs_config_h :=
fs_config_generate_bin :=
my_gen_oem_aid :=
fs_config_generate_extra_partition_list :=
