#
# Copyright (C) 2020 The Android Open Source Project
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

# sysprop.mk defines rules for generating <partition>/[etc/]build.prop files

# -----------------------------------------------------------------
# property_overrides_split_enabled
property_overrides_split_enabled :=
ifeq ($(BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED), true)
  property_overrides_split_enabled := true
endif

POST_PROCESS_PROPS := $(HOST_OUT_EXECUTABLES)/post_process_props$(HOST_EXECUTABLE_SUFFIX)

# Emits a set of sysprops common to all partitions to a file.
# $(1): Partition name
# $(2): Output file name
define generate-common-build-props
    echo "####################################" >> $(2);\
    echo "# from generate-common-build-props" >> $(2);\
    echo "# These properties identify this partition image." >> $(2);\
    echo "####################################" >> $(2);\
    echo "ro.product.$(1).brand=$(PRODUCT_BRAND)" >> $(2);\
    echo "ro.product.$(1).device=$(TARGET_DEVICE)" >> $(2);\
    echo "ro.product.$(1).manufacturer=$(PRODUCT_MANUFACTURER)" >> $(2);\
    echo "ro.product.$(1).model=$(PRODUCT_MODEL)" >> $(2);\
    echo "ro.product.$(1).name=$(TARGET_PRODUCT)" >> $(2);\
    if [ -n "$(strip $(PRODUCT_MODEL_FOR_ATTESTATION))" ]; then \
        echo "ro.product.model_for_attestation=$(PRODUCT_MODEL_FOR_ATTESTATION)" >> $(2);\
    fi; \
    if [ -n "$(strip $(PRODUCT_BRAND_FOR_ATTESTATION))" ]; then \
        echo "ro.product.brand_for_attestation=$(PRODUCT_BRAND_FOR_ATTESTATION)" >> $(2);\
    fi; \
    if [ -n "$(strip $(PRODUCT_NAME_FOR_ATTESTATION))" ]; then \
        echo "ro.product.name_for_attestation=$(PRODUCT_NAME_FOR_ATTESTATION)" >> $(2);\
    fi; \
    if [ -n "$(strip $(PRODUCT_DEVICE_FOR_ATTESTATION))" ]; then \
        echo "ro.product.device_for_attestation=$(PRODUCT_DEVICE_FOR_ATTESTATION)" >> $(2);\
    fi; \
    if [ -n "$(strip $(PRODUCT_MANUFACTURER_FOR_ATTESTATION))" ]; then \
        echo "ro.product.manufacturer_for_attestation=$(PRODUCT_MANUFACTURER_FOR_ATTESTATION)" >> $(2);\
    fi; \
    $(if $(filter true,$(ZYGOTE_FORCE_64)),\
        $(if $(filter vendor,$(1)),\
            echo "ro.$(1).product.cpu.abilist=$(TARGET_CPU_ABI_LIST_64_BIT)" >> $(2);\
            echo "ro.$(1).product.cpu.abilist32=" >> $(2);\
            echo "ro.$(1).product.cpu.abilist64=$(TARGET_CPU_ABI_LIST_64_BIT)" >> $(2);\
        )\
    ,\
        $(if $(filter system vendor odm,$(1)),\
            echo "ro.$(1).product.cpu.abilist=$(TARGET_CPU_ABI_LIST)" >> $(2);\
            echo "ro.$(1).product.cpu.abilist32=$(TARGET_CPU_ABI_LIST_32_BIT)" >> $(2);\
            echo "ro.$(1).product.cpu.abilist64=$(TARGET_CPU_ABI_LIST_64_BIT)" >> $(2);\
        )\
    )\
    echo "ro.$(1).build.date=`$(DATE_FROM_FILE)`" >> $(2);\
    echo "ro.$(1).build.date.utc=`$(DATE_FROM_FILE) +%s`" >> $(2);\
    # Allow optional assignments for ARC forward-declarations (b/249168657)
    # TODO: Remove any tag-related inconsistencies once the goals from
    # go/arc-android-sigprop-changes have been achieved.
    echo "ro.$(1).build.fingerprint?=$(BUILD_FINGERPRINT_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.id?=$(BUILD_ID)" >> $(2);\
    echo "ro.$(1).build.tags?=$(BUILD_VERSION_TAGS)" >> $(2);\
    echo "ro.$(1).build.type=$(TARGET_BUILD_VARIANT)" >> $(2);\
    echo "ro.$(1).build.version.incremental=$(BUILD_NUMBER_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.version.release=$(PLATFORM_VERSION_LAST_STABLE)" >> $(2);\
    echo "ro.$(1).build.version.release_or_codename=$(PLATFORM_VERSION)" >> $(2);\
    echo "ro.$(1).build.version.sdk=$(PLATFORM_SDK_VERSION)" >> $(2);\
    echo "ro.$(1).build.version.sdk_minor=$(PLATFORM_SDK_MINOR_VERSION)" >> $(2);\

endef

# Rule for generating <partition>/[etc/]build.prop file
#
# $(1): partition name
# $(2): path to the output
# $(3): path to the input *.prop files. The contents of the files are directly
#       emitted to the output
# $(4): list of variable names each of which contains name=value pairs
# $(5): optional list of prop names to force remove from the output. Properties from both
#       $(3) and (4) are affected
# $(6): optional list of files to append at the end. The content of each file is emitted
#       to the output
# $(7): optional flag to skip common properties generation
define build-properties
ALL_DEFAULT_INSTALLED_MODULES += $(2)

$(eval # Properties can be assigned using `prop ?= value` or `prop = value` syntax.)
$(eval # Eliminate spaces around the ?= and = separators.)
$(foreach name,$(strip $(4)),\
    $(eval _temp := $$(call collapse-pairs,$$($(name)),?=))\
    $(eval _resolved_$(name) := $$(call collapse-pairs,$$(_temp),=))\
)

$(eval # Implement the legacy behavior when BUILD_BROKEN_DUP_SYSPROP is on.)
$(eval # Optional assignments are all converted to normal assignments and)
$(eval # when their duplicates the first one wins)
$(if $(filter true,$(BUILD_BROKEN_DUP_SYSPROP)),\
    $(foreach name,$(strip $(4)),\
        $(eval _temp := $$(subst ?=,=,$$(_resolved_$(name))))\
        $(eval _resolved_$(name) := $$(call uniq-pairs-by-first-component,$$(_resolved_$(name)),=))\
    )\
    $(eval _option := --allow-dup)\
)

$(2): $(POST_PROCESS_PROPS) $(INTERNAL_BUILD_ID_MAKEFILE) $(3) $(6) $(BUILT_KERNEL_VERSION_FILE_FOR_UFFD_GC)
	$(hide) echo Building $$@
	$(hide) mkdir -p $$(dir $$@)
	$(hide) rm -f $$@ && touch $$@
ifneq ($(strip $(7)), true)
	$(hide) $$(call generate-common-build-props,$(call to-lower,$(strip $(1))),$$@)
endif
        # Make and Soong use different intermediate files to build vendor/build.prop.
        # Although the sysprop contents are same, the absolute paths of android_info.prop are different.
        # Print the filename for the intermediate files (files in OUT_DIR).
        # This helps with validating mk->soong migration of android partitions.
	$(hide) $(foreach file,$(strip $(3)),\
	    if [ -f "$(file)" ]; then\
	        echo "" >> $$@;\
	        echo "####################################" >> $$@;\
	        $(if $(filter $(OUT_DIR)/%,$(file)), \
		echo "# from $(notdir $(file))" >> $$@;\
		,\
		echo "# from $(file)" >> $$@;\
		)\
	        echo "####################################" >> $$@;\
	        cat $(file) >> $$@;\
	    fi;)
	$(hide) $(foreach name,$(strip $(4)),\
	    echo "" >> $$@;\
	    echo "####################################" >> $$@;\
	    echo "# from variable $(name)" >> $$@;\
	    echo "####################################" >> $$@;\
	    $$(foreach line,$$(_resolved_$(name)),\
	        echo "$$(line)" >> $$@;\
	    )\
	)
	$(hide) $(POST_PROCESS_PROPS) $$(_option) \
	  --sdk-version $(PLATFORM_SDK_VERSION) \
	  --kernel-version-file-for-uffd-gc "$(BUILT_KERNEL_VERSION_FILE_FOR_UFFD_GC)" \
	  $$@ $(5)
	$(hide) $(foreach file,$(strip $(6)),\
	    if [ -f "$(file)" ]; then\
	        cat $(file) >> $$@;\
	    fi;)
	$(hide) echo "# end of file" >> $$@

$(call declare-1p-target,$(2))
endef

# -----------------------------------------------------------------
# Define fingerprint, thumbprint, and version tags for the current build
#
# BUILD_VERSION_TAGS is a comma-separated list of tags chosen by the device
# implementer that further distinguishes the build. It's basically defined
# by the device implementer. Here, we are adding a mandatory tag that
# identifies the signing config of the build.
BUILD_VERSION_TAGS := $(BUILD_VERSION_TAGS)
ifeq ($(TARGET_BUILD_TYPE),debug)
  BUILD_VERSION_TAGS += debug
endif
# The "test-keys" tag marks builds signed with the old test keys,
# which are available in the SDK.  "dev-keys" marks builds signed with
# non-default dev keys (usually private keys from a vendor directory).
# Both of these tags will be removed and replaced with "release-keys"
# when the target-files is signed in a post-build step.
ifeq ($(DEFAULT_SYSTEM_DEV_CERTIFICATE),build/make/target/product/security/testkey)
BUILD_KEYS := test-keys
else
BUILD_KEYS := dev-keys
endif
BUILD_VERSION_TAGS += $(BUILD_KEYS)
BUILD_VERSION_TAGS := $(subst $(space),$(comma),$(sort $(BUILD_VERSION_TAGS)))

# BUILD_FINGERPRINT is used used to uniquely identify the combined build and
# product; used by the OTA server.
ifeq (,$(strip $(BUILD_FINGERPRINT)))
  BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(TARGET_PRODUCT)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER_FROM_FILE):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif

BUILD_FINGERPRINT_FILE := $(PRODUCT_OUT)/build_fingerprint.txt
ifneq (,$(shell mkdir -p $(PRODUCT_OUT) && echo $(BUILD_FINGERPRINT) >$(BUILD_FINGERPRINT_FILE).tmp && (if ! cmp -s $(BUILD_FINGERPRINT_FILE).tmp $(BUILD_FINGERPRINT_FILE); then mv $(BUILD_FINGERPRINT_FILE).tmp $(BUILD_FINGERPRINT_FILE); else rm $(BUILD_FINGERPRINT_FILE).tmp; fi) && grep " " $(BUILD_FINGERPRINT_FILE)))
  $(error BUILD_FINGERPRINT cannot contain spaces: "$(file <$(BUILD_FINGERPRINT_FILE))")
endif
BUILD_FINGERPRINT_FROM_FILE := $$(cat $(BUILD_FINGERPRINT_FILE))
# unset it for safety.
BUILD_FINGERPRINT :=

# BUILD_THUMBPRINT is used to uniquely identify the system build; used by the
# OTA server. This purposefully excludes any product-specific variables.
ifeq (,$(strip $(BUILD_THUMBPRINT)))
  BUILD_THUMBPRINT := $(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER_FROM_FILE):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif

BUILD_THUMBPRINT_FILE := $(PRODUCT_OUT)/build_thumbprint.txt
ifeq ($(strip $(HAS_BUILD_NUMBER)),true)
$(BUILD_THUMBPRINT_FILE): $(BUILD_NUMBER_FILE)
endif
ifneq (,$(shell mkdir -p $(PRODUCT_OUT) && echo $(BUILD_THUMBPRINT) >$(BUILD_THUMBPRINT_FILE) && grep " " $(BUILD_THUMBPRINT_FILE)))
  $(error BUILD_THUMBPRINT cannot contain spaces: "$(file <$(BUILD_THUMBPRINT_FILE))")
endif
# unset it for safety.
BUILD_THUMBPRINT_FILE :=
BUILD_THUMBPRINT :=

KNOWN_OEM_THUMBPRINT_PROPERTIES := \
    ro.product.brand \
    ro.product.name \
    ro.product.device
OEM_THUMBPRINT_PROPERTIES := $(filter $(KNOWN_OEM_THUMBPRINT_PROPERTIES),\
    $(PRODUCT_OEM_PROPERTIES))
KNOWN_OEM_THUMBPRINT_PROPERTIES:=

# -----------------------------------------------------------------
# system/build.prop
#
# system/build.prop is built by Soong. See system-build.prop module in
# build/soong/Android.bp.

INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop

# -----------------------------------------------------------------
# vendor/build.prop
#
_prop_files_ := $(if $(TARGET_VENDOR_PROP),\
    $(TARGET_VENDOR_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/vendor.prop))

android_info_prop := $(call intermediates-dir-for,ETC,android_info_prop)/android_info.prop
$(android_info_prop): $(INSTALLED_ANDROID_INFO_TXT_TARGET)
	cat $< | grep 'require version-' | sed -e 's/require version-/ro.build.expect./g' > $@

_prop_files_ += $(android_info_prop)

ifdef property_overrides_split_enabled
# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_VENDOR_PROPERTIES \
    PRODUCT_VENDOR_PROPERTIES

# TODO(b/117892318): deprecate this
_prop_vars_ += \
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES \
    PRODUCT_PROPERTY_OVERRIDES
else
_prop_vars_ :=
endif

INSTALLED_VENDOR_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR)/build.prop
$(eval $(call build-properties,\
    vendor,\
    $(INSTALLED_VENDOR_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(PRODUCT_VENDOR_PROPERTY_BLACKLIST),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_VENDOR_BUILD_PROP_TARGET)))

# -----------------------------------------------------------------
# product/etc/build.prop
#
# product/etc/build.prop is built by Soong. See product-build.prop module in
# build/soong/Android.bp.

INSTALLED_PRODUCT_BUILD_PROP_TARGET := $(TARGET_OUT_PRODUCT)/etc/build.prop

# ----------------------------------------------------------------
# odm/etc/build.prop
#
# odm/etc/build.prop is built by Soong. See odm-build.prop module in
# build/soong/Android.bp.

INSTALLED_ODM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM)/etc/build.prop

# ----------------------------------------------------------------
# vendor_dlkm/etc/build.prop
# odm_dlkm/etc/build.prop
# system_dlkm/build.prop
# These are built by Soong. See build/soong/Android.bp

INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR_DLKM)/etc/build.prop
INSTALLED_ODM_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM_DLKM)/etc/build.prop
INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_DLKM)/etc/build.prop
ALL_DEFAULT_INSTALLED_MODULES += \
  $(INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET) \
  $(INSTALLED_ODM_DLKM_BUILD_PROP_TARGET) \
  $(INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET) \

# -----------------------------------------------------------------
# system_ext/etc/build.prop
#
# system_ext/etc/build.prop is built by Soong. See system-build.prop module in
# build/soong/Android.bp.

INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_EXT)/etc/build.prop

RAMDISK_BUILD_PROP_REL_PATH := system/etc/ramdisk/build.prop
ifeq (true,$(BOARD_USES_RECOVERY_AS_BOOT))
INSTALLED_RAMDISK_BUILD_PROP_TARGET := $(TARGET_RECOVERY_ROOT_OUT)/first_stage_ramdisk/$(RAMDISK_BUILD_PROP_REL_PATH)
else
INSTALLED_RAMDISK_BUILD_PROP_TARGET := $(TARGET_RAMDISK_OUT)/$(RAMDISK_BUILD_PROP_REL_PATH)
endif

ALL_INSTALLED_BUILD_PROP_FILES := \
  $(INSTALLED_BUILD_PROP_TARGET) \
  $(INSTALLED_VENDOR_BUILD_PROP_TARGET) \
  $(INSTALLED_PRODUCT_BUILD_PROP_TARGET) \
  $(INSTALLED_ODM_BUILD_PROP_TARGET) \
  $(INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET) \
  $(INSTALLED_ODM_DLKM_BUILD_PROP_TARGET) \
  $(INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET) \
  $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET) \
  $(INSTALLED_RAMDISK_BUILD_PROP_TARGET)

# $1 installed file path, e.g. out/target/product/vsoc_x86_64/system/build.prop
define is-build-prop
$(if $(findstring $1,$(ALL_INSTALLED_BUILD_PROP_FILES)),Y)
endef
