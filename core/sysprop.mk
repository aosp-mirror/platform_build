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

# -----------------------------------------------------------------
# FINAL_VENDOR_DEFAULT_PROPERTIES will be installed in vendor/build.prop if
# property_overrides_split_enabled is true. Otherwise it will be installed in
# /system/build.prop
ifdef BOARD_VNDK_VERSION
  ifeq ($(BOARD_VNDK_VERSION),current)
    FINAL_VENDOR_DEFAULT_PROPERTIES := ro.vndk.version=$(PLATFORM_VNDK_VERSION)
  else
    FINAL_VENDOR_DEFAULT_PROPERTIES := ro.vndk.version=$(BOARD_VNDK_VERSION)
  endif
  ifdef BOARD_VNDK_RUNTIME_DISABLE
    FINAL_VENDOR_DEFAULT_PROPERTIES += ro.vndk.lite=true
  endif
else
  FINAL_VENDOR_DEFAULT_PROPERTIES := ro.vndk.version=$(PLATFORM_VNDK_VERSION)
  FINAL_VENDOR_DEFAULT_PROPERTIES += ro.vndk.lite=true
endif
FINAL_VENDOR_DEFAULT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))

# Add cpu properties for bionic and ART.
FINAL_VENDOR_DEFAULT_PROPERTIES += ro.bionic.arch=$(TARGET_ARCH)
FINAL_VENDOR_DEFAULT_PROPERTIES += ro.bionic.cpu_variant=$(TARGET_CPU_VARIANT_RUNTIME)
FINAL_VENDOR_DEFAULT_PROPERTIES += ro.bionic.2nd_arch=$(TARGET_2ND_ARCH)
FINAL_VENDOR_DEFAULT_PROPERTIES += ro.bionic.2nd_cpu_variant=$(TARGET_2ND_CPU_VARIANT_RUNTIME)

FINAL_VENDOR_DEFAULT_PROPERTIES += persist.sys.dalvik.vm.lib.2=libart.so
FINAL_VENDOR_DEFAULT_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).variant=$(DEX2OAT_TARGET_CPU_VARIANT_RUNTIME)
ifneq ($(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
  FINAL_VENDOR_DEFAULT_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).features=$(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
endif

ifdef TARGET_2ND_ARCH
  FINAL_VENDOR_DEFAULT_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).variant=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT_RUNTIME)
  ifneq ($($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
    FINAL_VENDOR_DEFAULT_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).features=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
  endif
endif

# Although these variables are prefixed with TARGET_RECOVERY_, they are also needed under charger
# mode (via libminui).
ifdef TARGET_RECOVERY_DEFAULT_ROTATION
FINAL_VENDOR_DEFAULT_PROPERTIES += \
    ro.minui.default_rotation=$(TARGET_RECOVERY_DEFAULT_ROTATION)
endif
ifdef TARGET_RECOVERY_OVERSCAN_PERCENT
FINAL_VENDOR_DEFAULT_PROPERTIES += \
    ro.minui.overscan_percent=$(TARGET_RECOVERY_OVERSCAN_PERCENT)
endif
ifdef TARGET_RECOVERY_PIXEL_FORMAT
FINAL_VENDOR_DEFAULT_PROPERTIES += \
    ro.minui.pixel_format=$(TARGET_RECOVERY_PIXEL_FORMAT)
endif
FINAL_VENDOR_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_VENDOR_DEFAULT_PROPERTIES),=)

BUILDINFO_SH := build/make/tools/buildinfo.sh
BUILDINFO_COMMON_SH := build/make/tools/buildinfo_common.sh
POST_PROCESS_PROPS :=$= build/make/tools/post_process_props.py

# Generates a set of sysprops common to all partitions to a file.
# $(1): Partition name
# $(2): Output file name
define generate-common-build-props
	PRODUCT_BRAND="$(PRODUCT_BRAND)" \
	PRODUCT_DEVICE="$(TARGET_DEVICE)" \
	PRODUCT_MANUFACTURER="$(PRODUCT_MANUFACTURER)" \
	PRODUCT_MODEL="$(PRODUCT_MODEL)" \
	PRODUCT_NAME="$(TARGET_PRODUCT)" \
	$(call generate-common-build-props-with-product-vars-set,$(1),$(2))
endef

# Like the above macro, but requiring the relevant PRODUCT_ environment
# variables to be set when called.
define generate-common-build-props-with-product-vars-set
	BUILD_FINGERPRINT="$(BUILD_FINGERPRINT_FROM_FILE)" \
	BUILD_ID="$(BUILD_ID)" \
	BUILD_NUMBER="$(BUILD_NUMBER_FROM_FILE)" \
	BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
	DATE="$(DATE_FROM_FILE)" \
	PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" \
	PLATFORM_VERSION_LAST_STABLE="$(PLATFORM_VERSION_LAST_STABLE)" \
	PLATFORM_VERSION="$(PLATFORM_VERSION)" \
	TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
	bash $(BUILDINFO_COMMON_SH) "$(1)" >> $(2)
endef

# -----------------------------------------------------------------
# build.prop
intermediate_system_build_prop := $(call intermediates-dir-for,ETC,system_build_prop)/build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)

# TODO(b/117892318) merge DEFAULT into BUILD
FINAL_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
FINAL_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_DEFAULT_PROPERTIES),=)

FINAL_BUILD_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))
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
$(intermediate_system_build_prop): $(BUILDINFO_SH) $(BUILDINFO_COMMON_SH) $(INTERNAL_BUILD_ID_MAKEFILE) $(BUILD_SYSTEM)/version_defaults.mk $(system_prop_file) $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(API_FINGERPRINT) $(POST_PROCESS_PROPS)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
	$(hide) $(foreach line,$(FINAL_DEFAULT_PROPERTIES), \
	    echo "$(line)" >> $@;)
ifndef property_overrides_split_enabled
	$(hide) $(foreach line,$(FINAL_VENDOR_DEFAULT_PROPERTIES), \
	    echo "$(line)" >> $@;)
endif
ifneq ($(PRODUCT_OEM_PROPERTIES),)
	$(hide) echo "#" >> $@; \
	        echo "# PRODUCT_OEM_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach prop,$(PRODUCT_OEM_PROPERTIES), \
	    echo "import /oem/oem.prop $(prop)" >> $@;)
endif
	$(hide) PRODUCT_BRAND="$(PRODUCT_SYSTEM_BRAND)" \
	        PRODUCT_MANUFACTURER="$(PRODUCT_SYSTEM_MANUFACTURER)" \
	        PRODUCT_MODEL="$(PRODUCT_SYSTEM_MODEL)" \
	        PRODUCT_NAME="$(PRODUCT_SYSTEM_NAME)" \
	        PRODUCT_DEVICE="$(PRODUCT_SYSTEM_DEVICE)" \
	        $(call generate-common-build-props-with-product-vars-set,system,$@)
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
	            echo "# ADDITIONAL_BUILD_PROPERTIES" >> $@; \
	            echo "#" >> $@; )
	$(hide) $(foreach line,$(FINAL_BUILD_PROPERTIES), \
	    echo "$(line)" >> $@;)
	$(hide) $(POST_PROCESS_PROPS) $@ $(PRODUCT_SYSTEM_PROPERTY_BLACKLIST)

build_desc :=

$(INSTALLED_BUILD_PROP_TARGET): $(intermediate_system_build_prop)
	@echo "Target build info: $@"
	$(hide) grep -v 'ro.product.first_api_level' $(intermediate_system_build_prop) > $@

# -----------------------------------------------------------------
# vendor build.prop
#
# For verifying that the vendor build is what we think it is
INSTALLED_VENDOR_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_VENDOR_BUILD_PROP_TARGET)

ifdef TARGET_VENDOR_PROP
vendor_prop_files := $(TARGET_VENDOR_PROP)
else
vendor_prop_files := $(wildcard $(TARGET_DEVICE_DIR)/vendor.prop)
endif

ifdef property_overrides_split_enabled
FINAL_VENDOR_BUILD_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_PROPERTY_OVERRIDES))
FINAL_VENDOR_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_VENDOR_BUILD_PROPERTIES),=)
endif  # property_overrides_split_enabled

$(INSTALLED_VENDOR_BUILD_PROP_TARGET): $(BUILDINFO_COMMON_SH) $(POST_PROCESS_PROPS) $(intermediate_system_build_prop) $(vendor_prop_files)
	@echo Target vendor buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
ifdef property_overrides_split_enabled
	$(hide) $(foreach line,$(FINAL_VENDOR_DEFAULT_PROPERTIES), \
	  echo "$(line)" >> $@;)
endif
ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
	$(hide) echo ro.boot.dynamic_partitions=true >> $@
endif
ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)
	$(hide) echo ro.boot.dynamic_partitions_retrofit=true >> $@
endif
	$(hide) grep 'ro.product.first_api_level' $(intermediate_system_build_prop) >> $@ || true
	$(hide) echo ro.vendor.build.security_patch="$(VENDOR_SECURITY_PATCH)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist="$(TARGET_CPU_ABI_LIST)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist32="$(TARGET_CPU_ABI_LIST_32_BIT)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist64="$(TARGET_CPU_ABI_LIST_64_BIT)">>$@
	$(hide) echo ro.product.board="$(TARGET_BOOTLOADER_BOARD_NAME)">>$@
	$(hide) echo ro.board.platform="$(TARGET_BOARD_PLATFORM)">>$@
	$(hide) echo ro.hwui.use_vulkan="$(TARGET_USES_VULKAN)">>$@
ifdef TARGET_SCREEN_DENSITY
	$(hide) echo ro.sf.lcd_density="$(TARGET_SCREEN_DENSITY)">>$@
endif
ifeq ($(AB_OTA_UPDATER),true)
	$(hide) echo ro.build.ab_update=true >> $@
endif
	$(hide) $(call generate-common-build-props,vendor,$@)
	$(hide) echo "#" >> $@; \
	        echo "# BOOTIMAGE_BUILD_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) echo ro.bootimage.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.bootimage.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.bootimage.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL VENDOR BUILD PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) cat $(INSTALLED_ANDROID_INFO_TXT_TARGET) | grep 'require version-' | sed -e 's/require version-/ro.build.expect./g' >> $@
ifdef property_overrides_split_enabled
	$(hide) $(foreach file,$(vendor_prop_files), \
	    if [ -f "$(file)" ]; then \
	        echo Target vendor properties from: "$(file)"; \
	        echo "" >> $@; \
	        echo "#" >> $@; \
	        echo "# from $(file)" >> $@; \
	        echo "#" >> $@; \
	        cat $(file) >> $@; \
	        echo "# end of $(file)" >> $@; \
	    fi;)
	$(hide) $(foreach line,$(FINAL_VENDOR_BUILD_PROPERTIES), \
	    echo "$(line)" >> $@;)
endif  # property_overrides_split_enabled
	$(hide) $(POST_PROCESS_PROPS) $@ $(PRODUCT_VENDOR_PROPERTY_BLACKLIST)


# -----------------------------------------------------------------
# product build.prop
INSTALLED_PRODUCT_BUILD_PROP_TARGET := $(TARGET_OUT_PRODUCT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_PRODUCT_BUILD_PROP_TARGET)

ifdef TARGET_PRODUCT_PROP
product_prop_files := $(TARGET_PRODUCT_PROP)
else
product_prop_files := $(wildcard $(TARGET_DEVICE_DIR)/product.prop)
endif

FINAL_PRODUCT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_PRODUCT_PROPERTIES) $(ADDITIONAL_PRODUCT_PROPERTIES))
FINAL_PRODUCT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_PRODUCT_PROPERTIES),=)

$(INSTALLED_PRODUCT_BUILD_PROP_TARGET): $(BUILDINFO_COMMON_SH) $(POST_PROCESS_PROPS) $(product_prop_files)
	@echo Target product buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
ifdef BOARD_USES_PRODUCTIMAGE
	$(hide) $(call generate-common-build-props,product,$@)
endif  # BOARD_USES_PRODUCTIMAGE
	$(hide) $(foreach file,$(product_prop_files), \
	    if [ -f "$(file)" ]; then \
	        echo Target product properties from: "$(file)"; \
	        echo "" >> $@; \
	        echo "#" >> $@; \
	        echo "# from $(file)" >> $@; \
	        echo "#" >> $@; \
	        cat $(file) >> $@; \
	        echo "# end of $(file)" >> $@; \
	    fi;)
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL PRODUCT PROPERTIES" >> $@; \
	        echo "#" >> $@; \
	        echo "ro.build.characteristics=$(TARGET_AAPT_CHARACTERISTICS)" >> $@;
	$(hide) $(foreach line,$(FINAL_PRODUCT_PROPERTIES), \
	    echo "$(line)" >> $@;)
	$(hide) $(POST_PROCESS_PROPS) $@

# ----------------------------------------------------------------
# odm build.prop
INSTALLED_ODM_BUILD_PROP_TARGET := $(TARGET_OUT_ODM)/etc/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_ODM_BUILD_PROP_TARGET)

ifdef TARGET_ODM_PROP
odm_prop_files := $(TARGET_ODM_PROP)
else
odm_prop_files := $(wildcard $(TARGET_DEVICE_DIR)/odm.prop)
endif

FINAL_ODM_BUILD_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_ODM_PROPERTIES))
FINAL_ODM_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_ODM_BUILD_PROPERTIES),=)

$(INSTALLED_ODM_BUILD_PROP_TARGET): $(BUILDINFO_COMMON_SH) $(POST_PROCESS_PROPS) $(odm_prop_files)
	@echo Target odm buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
	$(hide) echo ro.odm.product.cpu.abilist="$(TARGET_CPU_ABI_LIST)">>$@
	$(hide) echo ro.odm.product.cpu.abilist32="$(TARGET_CPU_ABI_LIST_32_BIT)">>$@
	$(hide) echo ro.odm.product.cpu.abilist64="$(TARGET_CPU_ABI_LIST_64_BIT)">>$@
	$(hide) $(call generate-common-build-props,odm,$@)
	$(hide) $(foreach file,$(odm_prop_files), \
	    if [ -f "$(file)" ]; then \
	        echo Target odm properties from: "$(file)"; \
	        echo "" >> $@; \
	        echo "#" >> $@; \
	        echo "# from $(file)" >> $@; \
	        echo "#" >> $@; \
	        cat $(file) >> $@; \
	        echo "# end of $(file)" >> $@; \
	    fi;)
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL ODM BUILD PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_ODM_BUILD_PROPERTIES), \
	    echo "$(line)" >> $@;)
	$(hide) $(POST_PROCESS_PROPS) $@

# -----------------------------------------------------------------
# system_ext build.prop
INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET := $(TARGET_OUT_SYSTEM_EXT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET)

ifdef TARGET_SYSTEM_EXT_PROP
system_ext_prop_files := $(TARGET_SYSTEM_EXT_PROP)
else
system_ext_prop_files := $(wildcard $(TARGET_DEVICE_DIR)/system_ext.prop)
endif

FINAL_SYSTEM_EXT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_SYSTEM_EXT_PROPERTIES))
FINAL_SYSTEM_EXT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_SYSTEM_EXT_PROPERTIES),=)

$(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET): $(BUILDINFO_COMMON_SH) $(POST_PROCESS_PROPS) $(system_ext_prop_files)
	@echo Target system_ext buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@ && touch $@
	$(hide) $(call generate-common-build-props,system_ext,$@)
	$(hide) $(foreach file,$(system_ext_prop_files), \
	    if [ -f "$(file)" ]; then \
	        echo Target system_ext properties from: "$(file)"; \
	        echo "" >> $@; \
	        echo "#" >> $@; \
	        echo "# from $(file)" >> $@; \
	        echo "#" >> $@; \
	        cat $(file) >> $@; \
	        echo "# end of $(file)" >> $@; \
	    fi;)
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL SYSTEM_EXT BUILD PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_SYSTEM_EXT_PROPERTIES), \
	    echo "$(line)" >> $@;)
	$(hide) $(POST_PROCESS_PROPS) $@
