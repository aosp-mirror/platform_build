#
# Copyright (C) 2014 The Android Open Source Project
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

# We build oem.img only if it's asked for.
ifneq ($(filter $(MAKECMDGOALS),oem_image),)
ifndef BOARD_OEMIMAGE_PARTITION_SIZE
$(error BOARD_OEMIMAGE_PARTITION_SIZE is not set.)
endif

INTERNAL_OEMIMAGE_FILES := \
    $(filter $(TARGET_OUT_OEM)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

oemimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,oem)
BUILT_OEMIMAGE_TARGET := $(PRODUCT_OUT)/oem.img
# We just build this directly to the install location.
INSTALLED_OEMIMAGE_TARGET := $(BUILT_OEMIMAGE_TARGET)

$(INSTALLED_OEMIMAGE_TARGET) : $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_OEMIMAGE_FILES)
	$(call pretty,"Target oem fs image: $@")
	@mkdir -p $(TARGET_OUT_OEM)
	@mkdir -p $(oemimage_intermediates) && rm -rf $(oemimage_intermediates)/oem_image_info.txt
	$(call generate-userimage-prop-dictionary, $(oemimage_intermediates)/oem_image_info.txt, skip_fsck=true)
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
	  ./build/tools/releasetools/build_image.py \
	  $(TARGET_OUT_OEM) $(oemimage_intermediates)/oem_image_info.txt $@ $(TARGET_OUT)
	$(hide) $(call assert-max-image-size,$@,$(BOARD_OEMIMAGE_PARTITION_SIZE))

.PHONY: oem_image
oem_image : $(INSTALLED_OEMIMAGE_TARGET)
$(call dist-for-goals, oem_image, $(INSTALLED_OEMIMAGE_TARGET))

endif  # oem_image in $(MAKECMDGOALS)
