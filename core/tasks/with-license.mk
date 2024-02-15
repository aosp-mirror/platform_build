# Copyright (C) 2019 The Android Open Source Project
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


.PHONY: with-license

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
	name := $(name)_debug
endif

dist_name := $(name)-flashable-FILE_NAME_TAG_PLACEHOLDER-with-license
name := $(name)-flashable-with-license

with_license_intermediates := \
	$(call intermediates-dir-for,PACKAGING,with_license)

# Create a with-license artifact target
license_image_input_zip := $(with_license_intermediates)/$(name).zip
$(license_image_input_zip) : $(BUILT_TARGET_FILES_PACKAGE) $(ZIP2ZIP)
# DO NOT PROCEED without a license file.
ifndef VENDOR_BLOBS_LICENSE
	@echo "with-license requires VENDOR_BLOBS_LICENSE to be set."
	exit 1
else
	$(ZIP2ZIP) -i $(BUILT_TARGET_FILES_PACKAGE) -o $@ \
		RADIO/bootloader.img:bootloader.img RADIO/radio.img:radio.img \
		IMAGES/*.img:. OTA/android-info.txt:android-info.txt
endif

$(call declare-1p-container,$(license_image_input_zip),build)
$(call declare-container-deps,$(license_image_input_zip),$(BUILT_TARGET_FILES_PACKAGE))

with_license_zip := $(PRODUCT_OUT)/$(name).sh
dist_name := $(dist_name).sh
$(with_license_zip): PRIVATE_NAME := $(name)
$(with_license_zip): PRIVATE_INPUT_ZIP := $(license_image_input_zip)
$(with_license_zip): PRIVATE_VENDOR_BLOBS_LICENSE := $(VENDOR_BLOBS_LICENSE)
$(with_license_zip): $(license_image_input_zip) $(VENDOR_BLOBS_LICENSE)
$(with_license_zip): $(HOST_OUT_EXECUTABLES)/generate-self-extracting-archive
	# Args: <output> <input archive> <comment> <license file>
	$(HOST_OUT_EXECUTABLES)/generate-self-extracting-archive $@ \
		$(PRIVATE_INPUT_ZIP) $(PRIVATE_NAME) $(PRIVATE_VENDOR_BLOBS_LICENSE)
with-license : $(with_license_zip)
$(call dist-for-goals, with-license, $(with_license_zip):$(dist_name))

$(call declare-1p-container,$(with_license_zip),)
$(call declare-container-license-deps,$(with_license_zip),$(license_image_input_zip),$(with_license_zip):)

