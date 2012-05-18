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

ifeq (,$(ONE_SHOT_MAKEFILE))

# PRODUCT_FACTORY_RAMDISK_MODULES consists of "<module_name>:<install_path>[:<install_path>...]" tuples.
# <install_path> is relative to the staging directory for the bundle.
# 
# Only host modules can be installed here. 
# (It's possible to relax this, but it's not needed and kind of tricky.  We'll need to add
# a better way of specifying the class. Really the answer is to stop having modules with
# duplicate names)
#
# You can also add files with PRODUCT_COPY_FILES if necessary.
#
# For example:
# PRODUCT_FACTORY_BUNDLE_MODULES := \
#     adb:adb fastboot:fastboot
requested_modules := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_FACTORY_BUNDLE_MODULES))

root_dir := $(PRODUCT_OUT)/factory_bundle
leaf := $(strip $(TARGET_PRODUCT))-factory_bundle-$(FILE_NAME_TAG)
named_dir := $(PRODUCT_OUT)/$(leaf)
tarball := $(PRODUCT_OUT)/$(leaf).tgz

copied_files := \
  $(foreach _fb_m, $(requested_modules), $(strip \
    $(eval _fb_m_tuple := $(subst :, ,$(_fb_m))) \
    $(eval _fb_m_name := $(word 1,$(_fb_m_tuple))) \
    $(eval _fb_dests := $(wordlist 2,999,$(_fb_m_tuple))) \
    $(eval _fb_m_built := $(filter $(HOST_OUT)/%, $(ALL_MODULES.$(_fb_m_name).BUILT))) \
    $(if $(_fb_m_built),,$(error no built file in requested_modules for '$(_fb_m_built)'))\
    $(foreach _fb_f,$(_fb_dests),$(eval $(call copy-one-file,$(_fb_m_built),$(root_dir)/$(_fb_f))))\
    $(addprefix $(root_dir)/,$(_fb_dests)) \
    )) \
  $(filter $(root_dir)/%, $(ALL_DEFAULT_INSTALLED_MODULES))

ifneq (,$(strip $(copied_files)))

#
# These files are made by magic so we need to explicitly include them
#
$(eval $(call copy-one-file,$(TARGET_OUT)/build.prop,$(root_dir)/build.prop))
copied_files += $(root_dir)/build.prop

$(eval $(call copy-one-file,$(PRODUCT_OUT)/factory_ramdisk.img,$(root_dir)/factory_ramdisk.img))
copied_files += $(root_dir)/factory_ramdisk.img
#
# End magic
#

$(tarball): PRIVATE_ROOT_DIR := $(root_dir)
$(tarball): PRIVATE_NAMED_DIR := $(named_dir)

$(tarball): $(copied_files)
	@echo "Tarball: $@"
	$(hide) rm -rf $(PRIVATE_NAMED_DIR)
	$(hide) ( cp -r $(PRIVATE_ROOT_DIR) $(PRIVATE_NAMED_DIR) \
			&& tar cfz $@ -C $(dir $(PRIVATE_NAMED_DIR)) $(notdir $(PRIVATE_NAMED_DIR)) \
			) && rm -rf $(PRIVATE_NAMED_DIR)

INSTALLED_FACTORY_BUNDLE_TARGET := $(tarball)

endif

endif # ONE_SHOT_MAKEFILE

