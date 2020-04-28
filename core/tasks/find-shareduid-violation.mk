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

find_shareduid_script := $(BUILD_SYSTEM)/tasks/find-shareduid-violation.py

$(shareduid_violation_modules_filename): $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(INSTALLED_BOOTIMAGE_TARGET) \
    $(INSTALLED_USERDATAIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(INSTALLED_PRODUCT_SERVICESIMAGE_TARGET)

$(shareduid_violation_modules_filename): $(find_shareduid_script)
$(shareduid_violation_modules_filename): $(AAPT2)
	$(find_shareduid_script) $(PRODUCT_OUT) $(AAPT2) > $@
$(call dist-for-goals,droidcore,$(shareduid_violation_modules_filename))
