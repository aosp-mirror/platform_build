#
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
#

shareduid_violation_modules_filename := $(PRODUCT_OUT)/shareduid_violation_modules.json

$(shareduid_violation_modules_filename): $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(INSTALLED_BOOTIMAGE_TARGET) \
    $(INSTALLED_USERDATAIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)

$(shareduid_violation_modules_filename): $(HOST_OUT_EXECUTABLES)/find_shareduid_violation
$(shareduid_violation_modules_filename): $(AAPT2)
	$(HOST_OUT_EXECUTABLES)/find_shareduid_violation \
		--product_out $(PRODUCT_OUT) \
		--aapt $(AAPT2) \
		--copy_out_system $(TARGET_COPY_OUT_SYSTEM) \
		--copy_out_vendor $(TARGET_COPY_OUT_VENDOR) \
		--copy_out_product $(TARGET_COPY_OUT_PRODUCT) \
		--copy_out_system_ext $(TARGET_COPY_OUT_SYSTEM_EXT) \
		> $@

$(call dist-for-goals,droidcore,$(shareduid_violation_modules_filename))
