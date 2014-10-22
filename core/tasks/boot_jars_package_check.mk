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
# Rules to check if classes in the boot jars are from the whitelisted packages.
#

ifneq ($(SKIP_BOOT_JARS_CHECK),true)
ifneq ($(TARGET_BUILD_PDK),true)
ifdef PRODUCT_BOOT_JARS

intermediates := $(call intermediates-dir-for, PACKAGING, boot-jars-package-check,,COMMON)
stamp := $(intermediates)/stamp
built_boot_jars := $(foreach j, $(PRODUCT_BOOT_JARS), \
  $(call intermediates-dir-for, JAVA_LIBRARIES, $(j),,COMMON)/classes.jar)
script := build/core/tasks/check_boot_jars/check_boot_jars.py
whitelist_file := build/core/tasks/check_boot_jars/package_whitelist.txt

$(stamp): PRIVATE_BOOT_JARS := $(built_boot_jars)
$(stamp): PRIVATE_SCRIPT := $(script)
$(stamp): PRIVATE_WHITELIST := $(whitelist_file)
$(stamp) : $(built_boot_jars) $(script) $(whitelist_file)
	@echo "Check package name for $(PRIVATE_BOOT_JARS)"
	$(hide) $(PRIVATE_SCRIPT) $(PRIVATE_WHITELIST) $(PRIVATE_BOOT_JARS)
	$(hide) mkdir -p $(dir $@) && touch $@

.PHONY: check-boot-jars
check-boot-jars : $(stamp)

# Run check-boot-jars by default
droidcore : check-boot-jars

endif  # PRODUCT_BOOT_JARS
endif  # TARGET_BUILD_PDK not true
endif  # SKIP_BOOT_JARS_CHECK not true
