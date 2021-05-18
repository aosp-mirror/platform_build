# Copyright (C) 2021 The Android Open Source Project
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

# Enable GKI 2.0 signing.
BOARD_GKI_SIGNING_KEY_PATH := build/make/target/product/gsi/testkey_rsa2048.pem
BOARD_GKI_SIGNING_ALGORITHM := SHA256_RSA2048

# The following is needed to allow release signing process appends more extra
# args, e.g., passing --signing_helper_with_files from mkbootimg to avbtool.
# See b/178559811 for more details.
BOARD_GKI_SIGNING_SIGNATURE_ARGS := --prop foo:bar

# Boot image with ramdisk and kernel
BOARD_RAMDISK_USE_LZ4 := true
BOARD_BOOT_HEADER_VERSION := 4
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_USES_RECOVERY_AS_BOOT :=
TARGET_NO_KERNEL := false
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_KERNEL_MODULE_INTERFACE_VERSIONS := \
    5.4-android12-unstable \
    5.10-android12-unstable \

# Copy boot image in $OUT to target files. This is defined for targets where
# the installed GKI APEXes are built from source.
BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES := true

# No vendor_boot
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT :=

# No recovery
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE :=
