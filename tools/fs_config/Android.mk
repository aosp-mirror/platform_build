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

include $(CLEAR_VARS)

LOCAL_SRC_FILES := fs_config.c
LOCAL_MODULE := fs_config
LOCAL_SHARED_LIBRARIES := libcutils libselinux
LOCAL_CFLAGS := -Werror

include $(BUILD_HOST_EXECUTABLE)

# To Build the custom target binary for the host to generate the fs_config
# override files. The executable is hard coded to include the
# $(TARGET_ANDROID_FILESYSTEM_CONFIG_H) file if it exists.
# Expectations:
#    device/<vendor>/<device>/android_filesystem_config.h
#        fills in struct fs_path_config android_device_dirs[] and
#                 struct fs_path_config android_device_files[]
#    device/<vendor>/<device>/device.mk
#        PRODUCT_PACKAGES += fs_config_dirs fs_config_files

# If not specified, check if default one to be found
ANDROID_FS_CONFIG_H := android_filesystem_config.h

ifneq ($(TARGET_ANDROID_FILESYSTEM_CONFIG_H),)
ifeq ($(filter %/$(ANDROID_FS_CONFIG_H),$(TARGET_ANDROID_FILESYSTEM_CONFIG_H)),)
$(error TARGET_ANDROID_FILESYSTEM_CONFIG_H file name must be $(ANDROID_FS_CONFIG_H), \
 see "$(notdir $(TARGET_ANDROID_FILESYSTEM_CONFIG_H))".)
endif

my_fs_config_h := $(TARGET_ANDROID_FILESYSTEM_CONFIG_H)
else ifneq ($(wildcard $(TARGET_DEVICE_DIR)/$(ANDROID_FS_CONFIG_H)),)
my_fs_config_h := $(TARGET_DEVICE_DIR)/$(ANDROID_FS_CONFIG_H)
else
my_fs_config_h := $(LOCAL_PATH)/default/$(ANDROID_FS_CONFIG_H)
endif

include $(CLEAR_VARS)
LOCAL_SRC_FILES := fs_config_generate.c
LOCAL_MODULE := fs_config_generate_$(TARGET_DEVICE)
LOCAL_SHARED_LIBRARIES := libcutils
LOCAL_CFLAGS := -Werror -Wno-error=\#warnings
LOCAL_C_INCLUDES := $(dir $(my_fs_config_h))
include $(BUILD_HOST_EXECUTABLE)
fs_config_generate_bin := $(LOCAL_INSTALLED_MODULE)

# Generate the system/etc/fs_config_dirs binary file for the target
# Add fs_config_dirs to PRODUCT_PACKAGES in the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_dirs
LOCAL_MODULE_CLASS := ETC
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -D -o $@

# Generate the system/etc/fs_config_files binary file for the target
# Add fs_config_files to PRODUCT_PACKAGES in the device make file to enable
include $(CLEAR_VARS)

LOCAL_MODULE := fs_config_files
LOCAL_MODULE_CLASS := ETC
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): $(fs_config_generate_bin)
	@mkdir -p $(dir $@)
	$< -F -o $@

ANDROID_FS_CONFIG_H :=
my_fs_config_h :=
fs_config_generate_bin :=
