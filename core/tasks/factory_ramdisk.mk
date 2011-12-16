#
# Copyright (C) 2011 The Android Open Source Project
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

# PRODUCT_FACTORY_RAMDISK_MODULES consists of "<module_name>:<install_path>" pairs.
# <install_path> is relative to TARGET_FACTORY_RAMDISK_OUT.
# For example:
# PRODUCT_FACTORY_RAMDISK_MODULES := \
#     toolbox:bin/toolbox adbd:sbin/adbd adb:bin/adb
factory_ramdisk_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_RAMDISK_MODULES))
ifneq (,$(factory_ramdisk_modules))
INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES :=
$(foreach m, $(factory_ramdisk_modules), \
    $(eval _fr_m_name := $(call word-colon,1,$(m))) \
    $(eval _fr_dest := $(call word-colon,2,$(m))) \
    $(eval _fr_m_built := $(filter $(PRODUCT_OUT)/%, $(ALL_MODULES.$(_fr_m_name).BUILT))) \
    $(if $(_fr_m_built), \
        $(eval _fulldest := $(TARGET_FACTORY_RAMDISK_OUT)/$(_fr_dest)) \
        $(eval $(call copy-one-file,$(_fr_m_built),$(_fulldest))) \
        $(eval INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES += $(_fulldest)), \
        $(error Error: module "$(m)" in PRODUCT_FACTORY_RAMDISK_MODULES is not a target module!) \
    ))
endif

# Files may also be installed via PRODUCT_COPY_FILES, PRODUCT_PACKAGES etc.
INTERNAL_FACTORY_RAMDISK_FILES := $(filter $(TARGET_FACTORY_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

ifneq (,$(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES)$(INTERNAL_FACTORY_RAMDISK_FILES))

BUILT_FACTORY_RAMDISK_TARGET := $(PRODUCT_OUT)/factory_ramdisk.img

INSTALLED_FACTORY_RAMDISK_TARGET := $(BUILT_FACTORY_RAMDISK_TARGET)
$(INSTALLED_FACTORY_RAMDISK_TARGET) : $(MKBOOTFS) \
    $(INTERNAL_FACTORY_RAMDISK_EXTRA_MODULES_FILES) $(INTERNAL_FACTORY_RAMDISK_FILES) | $(MINIGZIP)
	$(call pretty,"Target factory ram disk: $@")
	$(hide) $(MKBOOTFS) $(TARGET_FACTORY_RAMDISK_OUT) | $(MINIGZIP) > $@

endif
