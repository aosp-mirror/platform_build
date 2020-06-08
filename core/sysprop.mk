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

# sysprop.mk defines rules for generating <partition>/build.prop files

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
    )\
    echo "ro.$(1).build.date=`$(DATE_FROM_FILE)`" >> $(2);\
    echo "ro.$(1).build.date.utc=`$(DATE_FROM_FILE) +%s`" >> $(2);\
    echo "ro.$(1).build.fingerprint=$(BUILD_FINGERPRINT_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.id=$(BUILD_ID)" >> $(2);\
    echo "ro.$(1).build.tags=$(BUILD_VERSION_TAGS)" >> $(2);\
    echo "ro.$(1).build.type=$(TARGET_BUILD_VARIANT)" >> $(2);\
    echo "ro.$(1).build.version.incremental=$(BUILD_NUMBER_FROM_FILE)" >> $(2);\
    echo "ro.$(1).build.version.release=$(PLATFORM_VERSION)" >> $(2);\
    echo "ro.$(1).build.version.sdk=$(PLATFORM_SDK_VERSION)" >> $(2);\

endef

# Rule for generating <partition>/build.prop file
#
# $(1): partition name
# $(2): path to the output
# $(3): path to the input *.prop files. The contents of the files are directly
#       emitted to the output
# $(4): list of variable names each of which contains name=value pairs
# $(5): optional list of prop names to force remove from the output. Properties from both
#       $(3) and (4) are affected.
define build-properties
ALL_DEFAULT_INSTALLED_MODULES += $(2)

# TODO(b/117892318): eliminate the call to uniq-pairs-by-first-component when
# it is guaranteed that there is no dup.
$(foreach name,$(strip $(4)),\
    $(eval _resolved_$(name) := $$(call collapse-pairs, $$(call uniq-pairs-by-first-component,$$($(name)),=)))\
)

$(2): $(POST_PROCESS_PROPS) $(INTERNAL_BUILD_ID_MAKEFILE) $(API_FINGERPRINT) $(3)
	$(hide) echo Building $$@
	$(hide) mkdir -p $$(dir $$@)
	$(hide) rm -f $$@ && touch $$@
	$(hide) $$(call generate-common-build-props,$(call to-lower,$(strip $(1))),$$@)
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
	$(hide) $(POST_PROCESS_PROPS) $$@ $(5)
	$(hide) echo "# end of file" >> $$@
endef


# -----------------------------------------------------------------
# system/build.prop
#
intermediate_system_build_prop := $(call intermediates-dir-for,ETC,system_build_prop)/build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)

# TODO(b/117892318) merge DEFAULT into BUILD
FINAL_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
FINAL_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_DEFAULT_PROPERTIES),=)

FINAL_BUILD_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_SYSTEM_PROPERTIES))

# For non-Treble devices, consider vendor properties as system properties
ifndef property_overrides_split_enabled
FINAL_BUILD_PROPERTIES += \
    $(call collapse-pairs, $(ADDITIONAL_VENDOR_PROPERTIES))
endif

FINAL_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_BUILD_PROPERTIES),=)

# A list of arbitrary tags describing the build configuration.
# Force ":=" so we can use +=
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

# A human-readable string that descibes this build in detail.
build_desc := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER_FROM_FILE) $(BUILD_VERSION_TAGS)
$(intermediate_system_build_prop): PRIVATE_BUILD_DESC := $(build_desc)

# The string used to uniquely identify the combined build and product; used by the OTA server.
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

# The string used to uniquely identify the system build; used by the OTA server.
# This purposefully excludes any product-specific variables.
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

KNOWN_OEM_THUMBPRINT_PROPERTIES := \
    ro.product.brand \
    ro.product.name \
    ro.product.device
OEM_THUMBPRINT_PROPERTIES := $(filter $(KNOWN_OEM_THUMBPRINT_PROPERTIES),\
    $(PRODUCT_OEM_PROPERTIES))

# Display parameters shown under Settings -> About Phone
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
  BUILD_DISPLAY_ID := $(build_desc)
endif

# Accepts a whitespace separated list of product locales such as
# (en_US en_AU en_GB...) and returns the first locale in the list with
# underscores replaced with hyphens. In the example above, this will
# return "en-US".
define get-default-product-locale
$(strip $(subst _,-, $(firstword $(1))))
endef

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

ifdef TARGET_SYSTEM_PROP
system_prop_file := $(TARGET_SYSTEM_PROP)
else
system_prop_file := $(wildcard $(TARGET_DEVICE_DIR)/system.prop)
endif
$(intermediate_system_build_prop): $(BUILDINFO_SH) $(INTERNAL_BUILD_ID_MAKEFILE) $(BUILD_SYSTEM)/version_defaults.mk $(system_prop_file) $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(API_FINGERPRINT) $(POST_PROCESS_PROPS)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
	$(hide) $(foreach line,$(FINAL_DEFAULT_PROPERTIES), \
	    echo "$(line)" >> $@;)
ifneq ($(PRODUCT_OEM_PROPERTIES),)
	$(hide) echo "#" >> $@; \
	        echo "# PRODUCT_OEM_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach prop,$(PRODUCT_OEM_PROPERTIES), \
	    echo "import /oem/oem.prop $(prop)" >> $@;)
endif
	$(hide) $(call generate-common-build-props,system,$@)
	$(hide) TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
	        TARGET_BUILD_FLAVOR="$(TARGET_BUILD_FLAVOR)" \
	        TARGET_DEVICE="$(TARGET_DEVICE)" \
	        PRODUCT_DEFAULT_LOCALE="$(call get-default-product-locale,$(PRODUCT_LOCALES))" \
	        PRODUCT_DEFAULT_WIFI_CHANNELS="$(PRODUCT_DEFAULT_WIFI_CHANNELS)" \
	        PRIVATE_BUILD_DESC="$(PRIVATE_BUILD_DESC)" \
	        BUILD_ID="$(BUILD_ID)" \
	        BUILD_DISPLAY_ID="$(BUILD_DISPLAY_ID)" \
	        DATE="$(DATE_FROM_FILE)" \
	        BUILD_USERNAME="$(BUILD_USERNAME)" \
	        BUILD_HOSTNAME="$(BUILD_HOSTNAME)" \
	        BUILD_NUMBER="$(BUILD_NUMBER_FROM_FILE)" \
	        BOARD_BUILD_SYSTEM_ROOT_IMAGE="$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)" \
	        PLATFORM_VERSION="$(PLATFORM_VERSION)" \
	        PLATFORM_VERSION_LAST_STABLE="$(PLATFORM_VERSION_LAST_STABLE)" \
	        PLATFORM_SECURITY_PATCH="$(PLATFORM_SECURITY_PATCH)" \
	        PLATFORM_BASE_OS="$(PLATFORM_BASE_OS)" \
	        PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" \
	        PLATFORM_PREVIEW_SDK_VERSION="$(PLATFORM_PREVIEW_SDK_VERSION)" \
	        PLATFORM_PREVIEW_SDK_FINGERPRINT="$$(cat $(API_FINGERPRINT))" \
	        PLATFORM_VERSION_CODENAME="$(PLATFORM_VERSION_CODENAME)" \
	        PLATFORM_VERSION_ALL_CODENAMES="$(PLATFORM_VERSION_ALL_CODENAMES)" \
	        PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION="$(PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION)" \
	        BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
	        $(if $(OEM_THUMBPRINT_PROPERTIES),BUILD_THUMBPRINT="$(BUILD_THUMBPRINT_FROM_FILE)") \
	        TARGET_CPU_ABI_LIST="$(TARGET_CPU_ABI_LIST)" \
	        TARGET_CPU_ABI_LIST_32_BIT="$(TARGET_CPU_ABI_LIST_32_BIT)" \
	        TARGET_CPU_ABI_LIST_64_BIT="$(TARGET_CPU_ABI_LIST_64_BIT)" \
	        TARGET_CPU_ABI="$(TARGET_CPU_ABI)" \
	        TARGET_CPU_ABI2="$(TARGET_CPU_ABI2)" \
	        bash $(BUILDINFO_SH) >> $@
	$(hide) $(foreach file,$(system_prop_file), \
	    if [ -f "$(file)" ]; then \
	        echo Target buildinfo from: "$(file)"; \
	        echo "" >> $@; \
	        echo "#" >> $@; \
	        echo "# from $(file)" >> $@; \
	        echo "#" >> $@; \
	        cat $(file) >> $@; \
	        echo "# end of $(file)" >> $@; \
	    fi;)
	$(if $(FINAL_BUILD_PROPERTIES), \
	    $(hide) echo >> $@; \
	            echo "#" >> $@; \
	            echo "# ADDITIONAL_SYSTEM_PROPERTIES" >> $@; \
	            echo "#" >> $@; )
	$(hide) $(foreach line,$(FINAL_BUILD_PROPERTIES), \
	    echo "$(line)" >> $@;)
	$(hide) $(POST_PROCESS_PROPS) $@ $(PRODUCT_SYSTEM_PROPERTY_BLACKLIST)

build_desc :=

$(INSTALLED_BUILD_PROP_TARGET): $(intermediate_system_build_prop)
	@echo "Target build info: $@"
	$(hide) grep -v 'ro.product.first_api_level' $(intermediate_system_build_prop) > $@

# -----------------------------------------------------------------
# vendor/build.prop
#
_prop_files_ := $(if $(TARGET_VENDOR_PROP),\
    $(TARGET_VENDOR_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/vendor.prop))

android_info_prop := $(call intermediates-dir-for,ETC,android_info_prop)/android_info.prop
$(android_info_prop): $(INSTALLED_ANDROID_INFO_TXT_TARGET)
	cat $< | grep 'require version-' | sed -e 's/require version-/ro.build.expect./g' > $@

_prop_files_ += $(android_info_pro)

ifdef property_overrides_split_enabled
# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_VENDOR_PROPERTIES \
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
    $(PRODUCT_VENDOR_PROPERTY_BLACKLIST)))

# -----------------------------------------------------------------
# product/build.prop
#

_prop_files_ := $(if $(TARGET_PRODUCT_PROP),\
    $(TARGET_PRODUCT_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/product.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_PRODUCT_PROPERTIES \
    PRODUCT_PRODUCT_PROPERTIES

INSTALLED_PRODUCT_BUILD_PROP_TARGET := $(TARGET_OUT_PRODUCT)/build.prop
$(eval $(call build-properties,\
    product,\
    $(INSTALLED_PRODUCT_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(empty)))

# ----------------------------------------------------------------
# odm/build.prop
#
_prop_files_ := $(if $(TARGET_ODM_PROP),\
    $(TARGET_ODM_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/odm.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := \
    ADDITIONAL_ODM_PROPERTIES \
    PRODUCT_ODM_PROPERTIES

INSTALLED_ODM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM)/build.prop
$(eval $(call build-properties,\
    odm,\
    $(INSTALLED_ODM_BUILD_PROP_TARGET),\
    $(_prop_files),\
    $(_prop_vars_),\
    $(empty)))

# -----------------------------------------------------------------
# system_ext/build.prop
#
_prop_files_ := $(if $(TARGET_SYSTEM_EXT_PROP),\
    $(TARGET_SYSTEM_EXT_PROP),\
    $(wildcard $(TARGET_DEVICE_DIR)/system_ext.prop))

# Order matters here. When there are duplicates, the last one wins.
# TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
_prop_vars_ := PRODUCT_SYSTEM_EXT_PROPERTIES

INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_EXT)/build.prop
$(eval $(call build-properties,\
    system_ext,\
    $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET),\
    $(_prop_files_),\
    $(_prop_vars_),\
    $(empty)))
