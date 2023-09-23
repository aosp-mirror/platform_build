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

BUILDINFO_SH := build/make/tools/buildinfo.sh
POST_PROCESS_PROPS := $(HOST_OUT_EXECUTABLES)/post_process_props$(HOST_EXECUTABLE_SUFFIX)

# Emits a set of sysprops common to all partitions to a file.
# $(1): Partition name
# $(2): Output file name
define generate-common-build-props
    echo "####################################" >> $(2);\
    echo "# from generate-common-build-props" >> $(2);\
    echo "# These properties identify this partition image." >> $(2);\
    echo "####################################" >> $(2);\
    $(if $(filter system,$(1)),\
        echo "ro.product.$(1).brand=$(PRODUCT_SYSTEM_BRAND)" >> $(2);\
        echo "ro.product.$(1).device=$(PRODUCT_SYSTEM_DEVICE)" >> $(2);\
        echo "ro.product.$(1).manufacturer=$(PRODUCT_SYSTEM_MANUFACTURER)" >> $(2);\
        echo "ro.product.$(1).model=$(PRODUCT_SYSTEM_MODEL)" >> $(2);\
        echo "ro.product.$(1).name=$(PRODUCT_SYSTEM_NAME)" >> $(2);\
      ,\
        echo "ro.product.$(1).brand=$(PRODUCT_BRAND)" >> $(2);\
        echo "ro.product.$(1).device=$(TARGET_DEVICE)" >> $(2);\
        echo "ro.product.$(1).manufacturer=$(PRODUCT_MANUFACTURER)" >> $(2);\
        echo "ro.product.$(1).model=$(PRODUCT_MODEL)" >> $(2);\
        echo "ro.product.$(1).name=$(TARGET_PRODUCT)" >> $(2);\
        # Attestation specific properties for AOSP/GSI build running on device.
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
    )\
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
    echo "ro.$(1).build.fingerprint=$(BUILD_FINGERPRINT_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.id=$(BUILD_ID)" >> $(2);\
    echo "ro.$(1).build.tags=$(BUILD_VERSION_TAGS)" >> $(2);\
    echo "ro.$(1).build.type=$(TARGET_BUILD_VARIANT)" >> $(2);\
    echo "ro.$(1).build.version.incremental=$(BUILD_NUMBER_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.version.release=$(PLATFORM_VERSION_LAST_STABLE)" >> $(2);\
    echo "ro.$(1).build.version.release_or_codename=$(PLATFORM_VERSION)" >> $(2);\
    echo "ro.$(1).build.version.sdk=$(PLATFORM_SDK_VERSION)" >> $(2);\

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

$(2): $(POST_PROCESS_PROPS) $(INTERNAL_BUILD_ID_MAKEFILE) $(3) $(6)
	$(hide) echo Building $$@
	$(hide) mkdir -p $$(dir $$@)
	$(hide) rm -f $$@ && touch $$@
ifneq ($(strip $(7)), true)
	$(hide) $$(call generate-common-build-props,$(call to-lower,$(strip $(1))),$$@)
endif
	$(hide) $(foreach file,$(strip $(3)),\
	    if [ -f "$(file)" ]; then\
	        echo "" >> $$@;\
	        echo "####################################" >> $$@;\
	        echo "# from $(file)" >> $$@;\
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
	$(hide) $(POST_PROCESS_PROPS) $$(_option) --sdk-version $(PLATFORM_SDK_VERSION) $$@ $(5)
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
  ifeq ($(strip $(HAS_BUILD_NUMBER)),false)
    BF_BUILD_NUMBER := $(BUILD_USERNAME)$$($(DATE_FROM_FILE) +%m%d%H%M)
  else
    BF_BUILD_NUMBER := $(file <$(BUILD_NUMBER_FILE))
  endif
  BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(TARGET_PRODUCT)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BF_BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif
# unset it for safety.
BF_BUILD_NUMBER :=

BUILD_FINGERPRINT_FILE := $(PRODUCT_OUT)/build_fingerprint.txt
ifneq (,$(shell mkdir -p $(PRODUCT_OUT) && echo $(BUILD_FINGERPRINT) >$(BUILD_FINGERPRINT_FILE) && grep " " $(BUILD_FINGERPRINT_FILE)))
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
ifneq (,$(shell mkdir -p $(PRODUCT_OUT) && echo $(BUILD_THUMBPRINT) >$(BUILD_THUMBPRINT_FILE) && grep " " $(BUILD_THUMBPRINT_FILE)))
  $(error BUILD_THUMBPRINT cannot contain spaces: "$(file <$(BUILD_THUMBPRINT_FILE))")
endif
BUILD_THUMBPRINT_FROM_FILE := $$(cat $(BUILD_THUMBPRINT_FILE))
# unset it for safety.
BUILD_THUMBPRINT :=

# -----------------------------------------------------------------
# Define human readable strings that describe this build
#

# BUILD_ID: detail info; has the same info as the build fingerprint
BUILD_DESC := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER_FROM_FILE) $(BUILD_VERSION_TAGS)

# BUILD_DISPLAY_ID is shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
  # User builds should show:
  # release build number or branch.buld_number non-release builds

  # Dev. branches should have DISPLAY_BUILD_NUMBER set
  ifeq (true,$(DISPLAY_BUILD_NUMBER))
    BUILD_DISPLAY_ID := $(BUILD_ID).$(BUILD_NUMBER_FROM_FILE) $(BUILD_KEYS)
  else
    BUILD_DISPLAY_ID := $(BUILD_ID) $(BUILD_KEYS)
  endif
else
  # Non-user builds should show detailed build information
  BUILD_DISPLAY_ID := $(BUILD_DESC)
endif

# TARGET_BUILD_FLAVOR and ro.build.flavor are used only by the test
# harness to distinguish builds. Only add _asan for a sanitized build
# if it isn't already a part of the flavor (via a dedicated lunch
# config for example).
TARGET_BUILD_FLAVOR := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)
ifneq (, $(filter address, $(SANITIZE_TARGET)))
ifeq (,$(findstring _asan,$(TARGET_BUILD_FLAVOR)))
TARGET_BUILD_FLAVOR := $(TARGET_BUILD_FLAVOR)_asan
endif
endif

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
# Note: parts of this file that can't be generated by the build-properties
# macro are manually created as separate files and then fed into the macro

# Accepts a whitespace separated list of product locales such as
# (en_US en_AU en_GB...) and returns the first locale in the list with
# underscores replaced with hyphens. In the example above, this will
# return "en-US".
define get-default-product-locale
$(strip $(subst _,-, $(firstword $(1))))
endef

gen_from_buildinfo_sh := $(call intermediates-dir-for,PACKAGING,system_build_prop)/buildinfo.prop
$(gen_from_buildinfo_sh): $(INTERNAL_BUILD_ID_MAKEFILE) $(API_FINGERPRINT) | $(BUILD_DATETIME_FILE) $(BUILD_NUMBER_FILE)
	$(hide) TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
	        TARGET_BUILD_FLAVOR="$(TARGET_BUILD_FLAVOR)" \
	        TARGET_DEVICE="$(TARGET_DEVICE)" \
	        PRODUCT_DEFAULT_LOCALE="$(call get-default-product-locale,$(PRODUCT_LOCALES))" \
	        PRODUCT_DEFAULT_WIFI_CHANNELS="$(PRODUCT_DEFAULT_WIFI_CHANNELS)" \
	        PRIVATE_BUILD_DESC="$(BUILD_DESC)" \
	        BUILD_ID="$(BUILD_ID)" \
	        BUILD_DISPLAY_ID="$(BUILD_DISPLAY_ID)" \
	        DATE="$(DATE_FROM_FILE)" \
	        BUILD_USERNAME="$(BUILD_USERNAME)" \
	        BUILD_HOSTNAME="$(BUILD_HOSTNAME)" \
	        BUILD_NUMBER="$(BUILD_NUMBER_FROM_FILE)" \
	        BOARD_USE_VBMETA_DIGTEST_IN_FINGERPRINT="$(BOARD_USE_VBMETA_DIGTEST_IN_FINGERPRINT)" \
	        PLATFORM_VERSION="$(PLATFORM_VERSION)" \
	        PLATFORM_DISPLAY_VERSION="$(PLATFORM_DISPLAY_VERSION)" \
	        PLATFORM_VERSION_LAST_STABLE="$(PLATFORM_VERSION_LAST_STABLE)" \
	        PLATFORM_SECURITY_PATCH="$(PLATFORM_SECURITY_PATCH)" \
	        PLATFORM_BASE_OS="$(PLATFORM_BASE_OS)" \
	        PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" \
	        PLATFORM_PREVIEW_SDK_VERSION="$(PLATFORM_PREVIEW_SDK_VERSION)" \
	        PLATFORM_PREVIEW_SDK_FINGERPRINT="$$(cat $(API_FINGERPRINT))" \
	        PLATFORM_VERSION_CODENAME="$(PLATFORM_VERSION_CODENAME)" \
	        PLATFORM_VERSION_ALL_CODENAMES="$(PLATFORM_VERSION_ALL_CODENAMES)" \
	        PLATFORM_VERSION_KNOWN_CODENAMES="$(PLATFORM_VERSION_KNOWN_CODENAMES)" \
	        PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION="$(PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION)" \
	        BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
	        $(if $(OEM_THUMBPRINT_PROPERTIES),BUILD_THUMBPRINT="$(BUILD_THUMBPRINT_FROM_FILE)") \
	        TARGET_CPU_ABI_LIST="$(TARGET_CPU_ABI_LIST)" \
	        TARGET_CPU_ABI_LIST_32_BIT="$(TARGET_CPU_ABI_LIST_32_BIT)" \
	        TARGET_CPU_ABI_LIST_64_BIT="$(TARGET_CPU_ABI_LIST_64_BIT)" \
	        TARGET_CPU_ABI="$(TARGET_CPU_ABI)" \
	        TARGET_CPU_ABI2="$(TARGET_CPU_ABI2)" \
	        ZYGOTE_FORCE_64_BIT="$(ZYGOTE_FORCE_64_BIT)" \
	        bash $(BUILDINFO_SH) > $@

ifdef TARGET_SYSTEM_PROP
system_prop_file := $(TARGET_SYSTEM_PROP)
else
system_prop_file := $(wildcard $(TARGET_DEVICE_DIR)/system.prop)
endif

_prop_files_ := \
  $(gen_from_buildinfo_sh) \
  $(system_prop_file)

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_SYSTEM_PROPERTIES \
    PRODUCT_SYSTEM_PROPERTIES

# TODO(b/117892318): deprecate this
_prop_vars_ += \
    PRODUCT_SYSTEM_DEFAULT_PROPERTIES

ifndef property_overrides_split_enabled
_prop_vars_ += \
    ADDITIONAL_VENDOR_PROPERTIES \
    PRODUCT_VENDOR_PROPERTIES
endif

INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop

$(eval $(call build-properties,\
    system,\
    $(INSTALLED_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(PRODUCT_SYSTEM_PROPERTY_BLACKLIST),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_BUILD_PROP_TARGET)))

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

_prop_files_ := $(if $(TARGET_PRODUCT_PROP),\
    $(TARGET_PRODUCT_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/product.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_PRODUCT_PROPERTIES \
    PRODUCT_PRODUCT_PROPERTIES

INSTALLED_PRODUCT_BUILD_PROP_TARGET := $(TARGET_OUT_PRODUCT)/etc/build.prop

ifdef PRODUCT_OEM_PROPERTIES
import_oem_prop := $(call intermediates-dir-for,ETC,import_oem_prop)/oem.prop

$(import_oem_prop):
	$(hide) echo "####################################" >> $@; \
	        echo "# PRODUCT_OEM_PROPERTIES" >> $@; \
	        echo "####################################" >> $@;
	$(hide) $(foreach prop,$(PRODUCT_OEM_PROPERTIES), \
	    echo "import /oem/oem.prop $(prop)" >> $@;)

_footers_ := $(import_oem_prop)
else
_footers_ :=
endif

# Skip common /product properties generation if device released before R and
# has no product partition. This is the first part of the check.
ifeq ($(call math_lt,$(if $(PRODUCT_SHIPPING_API_LEVEL),$(PRODUCT_SHIPPING_API_LEVEL),30),30), true)
  _skip_common_properties := true
endif

# The second part of the check - always generate common properties for the
# devices with product partition regardless of shipping level.
ifneq ($(BOARD_USES_PRODUCTIMAGE),)
  _skip_common_properties :=
endif

$(eval $(call build-properties,\
    product,\
    $(INSTALLED_PRODUCT_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(empty),\
    $(_footers_),\
    $(_skip_common_properties)))

$(eval $(call declare-1p-target,$(INSTALLED_PRODUCT_BUILD_PROP_TARGET)))

_skip_common_properties :=

# ----------------------------------------------------------------
# odm/etc/build.prop
#
_prop_files_ := $(if $(TARGET_ODM_PROP),\
    $(TARGET_ODM_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/odm.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_ODM_PROPERTIES \
    PRODUCT_ODM_PROPERTIES

INSTALLED_ODM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM)/etc/build.prop
$(eval $(call build-properties,\
    odm,\
    $(INSTALLED_ODM_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_ODM_BUILD_PROP_TARGET)))

# ----------------------------------------------------------------
# vendor_dlkm/etc/build.prop
#

INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR_DLKM)/etc/build.prop
$(eval $(call build-properties,\
    vendor_dlkm,\
    $(INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_VENDOR_DLKM_BUILD_PROP_TARGET)))

# ----------------------------------------------------------------
# odm_dlkm/etc/build.prop
#

INSTALLED_ODM_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM_DLKM)/etc/build.prop
$(eval $(call build-properties,\
    odm_dlkm,\
    $(INSTALLED_ODM_DLKM_BUILD_PROP_TARGET),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_ODM_DLKM_BUILD_PROP_TARGET)))

# ----------------------------------------------------------------
# system_dlkm/build.prop
#

INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_DLKM)/etc/build.prop
$(eval $(call build-properties,\
    system_dlkm,\
    $(INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_SYSTEM_DLKM_BUILD_PROP_TARGET)))

# -----------------------------------------------------------------
# system_ext/etc/build.prop
#
_prop_files_ := $(if $(TARGET_SYSTEM_EXT_PROP),\
    $(TARGET_SYSTEM_EXT_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/system_ext.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := PRODUCT_SYSTEM_EXT_PROPERTIES

INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_EXT)/etc/build.prop
$(eval $(call build-properties,\
    system_ext,\
    $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET)))

# ----------------------------------------------------------------
# ramdisk/boot/etc/build.prop
#

RAMDISK_BUILD_PROP_REL_PATH := system/etc/ramdisk/build.prop
INSTALLED_RAMDISK_BUILD_PROP_TARGET := $(TARGET_RAMDISK_OUT)/$(RAMDISK_BUILD_PROP_REL_PATH)
$(eval $(call build-properties,\
    bootimage,\
    $(INSTALLED_RAMDISK_BUILD_PROP_TARGET),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty),\
    $(empty)))

$(eval $(call declare-1p-target,$(INSTALLED_RAMDISK_BUILD_PROP_TARGET)))

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