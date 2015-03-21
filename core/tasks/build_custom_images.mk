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

# Build additional images requested by the product makefile.
# This script gives the ability to build multiple additional images and you can
# configure what modules/files to include in each image.
# 1. Define PRODUCT_CUSTOM_IMAGE_MAKEFILES in your product makefile.
#    PRODUCT_CUSTOM_IMAGE_MAKEFILES is a list of makefiles.
#    Each makefile configures an image.
#    For image configuration makefile foo/bar/xyz.mk, the built image file name
#    will be xyz.img. So make sure they won't conflict.
# 2. In each image's configuration makefile, you can define variables:
#   - CUSTOM_IMAGE_MOUNT_POINT, the mount point, such as "oem", "odm" etc.
#   - CUSTOM_IMAGE_PARTITION_SIZE
#   - CUSTOM_IMAGE_FILE_SYSTEM_TYPE
#   - CUSTOM_IMAGE_DICT_FILE, a text file defines a dictionary accepted by
#     BuildImage() in tools/releasetools/build_image.py.
#   - CUSTOM_IMAGE_MODULES, a list of module names you want to include in
#     the image; Not only the module itself will be installed to proper path in
#     the image, you can also piggyback additional files/directories with the
#     module's LOCAL_PICKUP_FILES.
#   - CUSTOM_IMAGE_COPY_FILES, a list of "<src>:<dest>" to be copied to the
#     image. <dest> is relativ to the root of the image.
#   - CUSTOM_IMAGE_SELINUX, set to "true" if the image supports selinux.
#   - CUSTOM_IMAGE_SUPPORT_VERITY, set to "true" if the product supports verity.
#   - CUSTOM_IMAGE_VERITY_BLOCK_DEVICE
#
# To build all those images, run "make custom_images".

ifneq ($(filter $(MAKECMDGOALS),custom_images),)

.PHONY: custom_images

custom_image_parameter_variables := \
  CUSTOM_IMAGE_MOUNT_POINT \
  CUSTOM_IMAGE_PARTITION_SIZE \
  CUSTOM_IMAGE_FILE_SYSTEM_TYPE \
  CUSTOM_IMAGE_DICT_FILE \
  CUSTOM_IMAGE_MODULES \
  CUSTOM_IMAGE_COPY_FILES \
  CUSTOM_IMAGE_SELINUX \
  CUSTOM_IMAGE_SUPPORT_VERITY \
  CUSTOM_IMAGE_VERITY_BLOCK_DEVICE \

# We don't expect product makefile to inherit/override PRODUCT_CUSTOM_IMAGE_MAKEFILES,
# so we don't put it in the _product_var_list.
$(foreach mk, $(PRODUCT_CUSTOM_IMAGE_MAKEFILES),\
  $(eval my_custom_imag_makefile := $(mk))\
  $(eval include $(BUILD_SYSTEM)/tasks/tools/build_custom_image.mk))

endif
