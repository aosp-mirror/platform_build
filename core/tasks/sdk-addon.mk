# Copyright (C) 2009 The Android Open Source Project
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


# If they didn't define PRODUCT_SDK_ADDON_NAME, then we won't define
# any of these rules.
addon_name := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ADDON_NAME))
ifneq ($(addon_name),)

addon_dir_leaf := $(addon_name)-$(FILE_NAME_TAG)-$(INTERNAL_SDK_HOST_OS_NAME)

intermediates := $(HOST_OUT_INTERMEDIATES)/SDK_ADDON/$(addon_name)_intermediates
full_target := $(HOST_OUT_SDK_ADDON)/$(addon_dir_leaf).zip
staging := $(intermediates)/$(addon_dir_leaf)

sdk_addon_deps :=
files_to_copy :=

define stub-addon-jar-file
$(subst .jar,_stub-addon.jar,$(1))
endef

define stub-addon-jar
$(call stub-addon-jar-file,$(1)): $(1) | mkstubs
	$(info Stubbing addon jar using $(PRODUCT_SDK_ADDON_STUB_DEFS))
	$(hide) java -jar $(call module-installed-files,mkstubs) $(if $(hide),,--v) \
		"$$<" "$$@" @$(PRODUCT_SDK_ADDON_STUB_DEFS)
endef

# Files that are built and then copied into the sdk-addon
ifneq ($(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ADDON_COPY_MODULES)),)
$(foreach cf,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ADDON_COPY_MODULES), \
  $(eval _src := $(call module-stubs-files,$(call word-colon,1,$(cf)))) \
  $(eval $(call stub-addon-jar,$(_src))) \
  $(eval _src := $(call stub-addon-jar-file,$(_src))) \
  $(if $(_src),,$(eval $(error Unknown or unlinkable module: $(call word-colon,1,$(cf)). Requested by $(INTERNAL_PRODUCT)))) \
  $(eval _dest := $(call word-colon,2,$(cf))) \
  $(eval files_to_copy += $(_src):$(_dest)) \
 )
endif

# Files that are copied directly into the sdk-addon
files_to_copy += $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ADDON_COPY_FILES)

# All SDK add-ons have these files
files_to_copy += \
        $(BUILT_SYSTEMIMAGE):images/system.img \
        $(BUILT_USERDATAIMAGE_TARGET):images/userdata.img \
        $(BUILT_RAMDISK_TARGET):images/ramdisk.img \
        $(target_notice_file_txt):images/NOTICE.txt

# Generate rules to copy the requested files
$(foreach cf,$(files_to_copy), \
  $(eval _src := $(call word-colon,1,$(cf))) \
  $(eval _dest := $(call append-path,$(staging),$(call word-colon,2,$(cf)))) \
  $(eval $(call copy-one-file,$(_src),$(_dest))) \
  $(eval sdk_addon_deps += $(_dest)) \
 )

# We don't know about all of the docs files, so depend on the timestamp for
# that, and record the directory, and the packaging rule will just copy the
# whole thing.
doc_module := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ADDON_DOC_MODULE))
ifneq ($(doc_module),)
  doc_timestamp := $(call doc-timestamp-for, $(doc_module))
  sdk_addon_deps += $(doc_timestamp)
  $(full_target): PRIVATE_DOCS_DIR := $(OUT_DOCS)/$(doc_module)
else
  $(full_target): PRIVATE_DOCS_DIR :=
endif

$(full_target): PRIVATE_STAGING_DIR := $(staging)

$(full_target): $(sdk_addon_deps) | $(ACP)
	@echo Packaging SDK Addon: $@
	$(hide) mkdir -p $(PRIVATE_STAGING_DIR)/docs/reference
	$(hide) if [ -n "$(PRIVATE_DOCS_DIR)" ] ; then \
	    $(ACP) -r $(PRIVATE_DOCS_DIR)/* $(PRIVATE_STAGING_DIR)/docs/reference ;\
	  fi
	$(hide) mkdir -p $(dir $@)
	$(hide) ( F=$$(pwd)/$@ ; cd $(PRIVATE_STAGING_DIR)/.. && zip -rq $$F * )

.PHONY: sdk_addon
sdk_addon: $(full_target)

$(call dist-for-goals, sdk_addon, $(full_target))

else # addon_name
ifneq ($(filter sdk_addon,$(MAKECMDGOALS)),)
$(error Trying to build sdk_addon, but product '$(INTERNAL_PRODUCT)' does not define one)
endif
endif # addon_name

