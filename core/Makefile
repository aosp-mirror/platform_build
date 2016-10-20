# Put some miscellaneous rules here

# HACK: clear LOCAL_PATH from including last build target before calling
# intermedites-dir-for
LOCAL_PATH := $(BUILD_SYSTEM)

# Pick a reasonable string to use to identify files.
ifneq "" "$(filter eng.%,$(BUILD_NUMBER))"
  # BUILD_NUMBER has a timestamp in it, which means that
  # it will change every time.  Pick a stable value.
  FILE_NAME_TAG := eng.$(USER)
else
  FILE_NAME_TAG := $(BUILD_NUMBER)
endif

# -----------------------------------------------------------------
# Define rules to copy PRODUCT_COPY_FILES defined by the product.
# PRODUCT_COPY_FILES contains words like <source file>:<dest file>[:<owner>].
# <dest file> is relative to $(PRODUCT_OUT), so it should look like,
# e.g., "system/etc/file.xml".
# The filter part means "only eval the copy-one-file rule if this
# src:dest pair is the first one to match the same dest"
#$(1): the src:dest pair
define check-product-copy-files
$(if $(filter %.apk, $(call word-colon, 2, $(1))),$(error \
    Prebuilt apk found in PRODUCT_COPY_FILES: $(1), use BUILD_PREBUILT instead!))
endef
# filter out the duplicate <source file>:<dest file> pairs.
unique_product_copy_files_pairs :=
$(foreach cf,$(PRODUCT_COPY_FILES), \
    $(if $(filter $(unique_product_copy_files_pairs),$(cf)),,\
        $(eval unique_product_copy_files_pairs += $(cf))))
unique_product_copy_files_destinations :=
$(foreach cf,$(unique_product_copy_files_pairs), \
    $(eval _src := $(call word-colon,1,$(cf))) \
    $(eval _dest := $(call word-colon,2,$(cf))) \
    $(call check-product-copy-files,$(cf)) \
    $(if $(filter $(unique_product_copy_files_destinations),$(_dest)), \
        $(info PRODUCT_COPY_FILES $(cf) ignored.), \
        $(eval _fulldest := $(call append-path,$(PRODUCT_OUT),$(_dest))) \
        $(if $(filter %.xml,$(_dest)),\
            $(eval $(call copy-xml-file-checked,$(_src),$(_fulldest))),\
            $(eval $(call copy-one-file,$(_src),$(_fulldest)))) \
        $(eval ALL_DEFAULT_INSTALLED_MODULES += $(_fulldest)) \
        $(eval unique_product_copy_files_destinations += $(_dest))))
unique_product_copy_files_pairs :=
unique_product_copy_files_destinations :=

# -----------------------------------------------------------------
# Define rules to copy headers defined in copy_headers.mk
# If more than one makefile declared a header, print a warning,
# then copy the last one defined. This matches the previous make
# behavior.
$(foreach dest,$(ALL_COPIED_HEADERS), \
    $(eval _srcs := $(ALL_COPIED_HEADERS.$(dest).SRC)) \
    $(eval _src := $(word $(words $(_srcs)),$(_srcs))) \
    $(if $(call streq,$(_src),$(_srcs)),, \
        $(warning Duplicate header copy: $(dest)) \
	$(warning Defined in: $(ALL_COPIED_HEADERS.$(dest).MAKEFILE))) \
    $(eval $(call copy-one-header,$(_src),$(dest))))
all_copied_headers: $(ALL_COPIED_HEADERS)

# -----------------------------------------------------------------
# docs/index.html
ifeq (,$(TARGET_BUILD_APPS))
gen := $(OUT_DOCS)/index.html
ALL_DOCS += $(gen)
$(gen): frameworks/base/docs/docs-redirect-index.html
	@mkdir -p $(dir $@)
	@cp -f $< $@
endif

# -----------------------------------------------------------------
# default.prop
INSTALLED_DEFAULT_PROP_TARGET := $(TARGET_ROOT_OUT)/default.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DEFAULT_PROP_TARGET)
ADDITIONAL_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES))
ADDITIONAL_DEFAULT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))
ADDITIONAL_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(ADDITIONAL_DEFAULT_PROPERTIES),=)

intermediate_system_build_prop := $(call intermediates-dir-for,ETC,system_build_prop)/build.prop

$(INSTALLED_DEFAULT_PROP_TARGET): $(intermediate_system_build_prop)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# ADDITIONAL_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(ADDITIONAL_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) echo "#" >> $@; \
	        echo "# BOOTIMAGE_BUILD_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) echo ro.bootimage.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.bootimage.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.bootimage.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
	$(hide) build/tools/post_process_props.py $@

# -----------------------------------------------------------------
# build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)
ADDITIONAL_BUILD_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))
ADDITIONAL_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(ADDITIONAL_BUILD_PROPERTIES),=)

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
ifeq ($(DEFAULT_SYSTEM_DEV_CERTIFICATE),build/target/product/security/testkey)
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
  ifneq ($(filter eng.%,$(BUILD_NUMBER)),)
    # Trim down BUILD_FINGERPRINT: the default BUILD_NUMBER makes it easily exceed
    # the Android system property length limit (PROPERTY_VALUE_MAX=92).
    BF_BUILD_NUMBER := $(shell echo $${USER:0:6})$(shell $(DATE) +%m%d%H%M)
  else
    BF_BUILD_NUMBER := $(BUILD_NUMBER)
  endif
  BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(TARGET_PRODUCT)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BF_BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif
ifneq ($(words $(BUILD_FINGERPRINT)),1)
  $(error BUILD_FINGERPRINT cannot contain spaces: "$(BUILD_FINGERPRINT)")
endif

$(shell mkdir -p $(PRODUCT_OUT) && echo $(BUILD_FINGERPRINT) > $(PRODUCT_OUT)/build_fingerprint.txt)
BUILD_FINGERPRINT_FROM_FILE := $$(cat $(PRODUCT_OUT)/build_fingerprint.txt)

# The string used to uniquely identify the system build; used by the OTA server.
# This purposefully excludes any product-specific variables.
ifeq (,$(strip $(BUILD_THUMBPRINT)))
  BUILD_THUMBPRINT := $(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif
ifneq ($(words $(BUILD_THUMBPRINT)),1)
  $(error BUILD_THUMBPRINT cannot contain spaces: "$(BUILD_THUMBPRINT)")
endif

KNOWN_OEM_THUMBPRINT_PROPERTIES := \
    ro.product.brand \
    ro.product.name \
    ro.product.device
OEM_THUMBPRINT_PROPERTIES := $(filter $(KNOWN_OEM_THUMBPRINT_PROPERTIES),\
    $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OEM_PROPERTIES))

# Display parameters shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
  # User builds should show:
  # release build number or branch.buld_number non-release builds

  # Dev. branches should have DISPLAY_BUILD_NUMBER set
  ifeq "true" "$(DISPLAY_BUILD_NUMBER)"
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

BUILDINFO_SH := build/tools/buildinfo.sh

# TARGET_BUILD_FLAVOR and ro.build.flavor are used only by the test harness to distinguish builds.
TARGET_BUILD_FLAVOR := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)
ifdef SANITIZE_TARGET
TARGET_BUILD_FLAVOR := $(TARGET_BUILD_FLAVOR)_asan
endif

ifdef TARGET_SYSTEM_PROP
system_prop_file := $(TARGET_SYSTEM_PROP)
else
system_prop_file := $(wildcard $(TARGET_DEVICE_DIR)/system.prop)
endif
$(intermediate_system_build_prop): $(BUILDINFO_SH) $(INTERNAL_BUILD_ID_MAKEFILE) $(BUILD_SYSTEM)/version_defaults.mk $(system_prop_file) $(INSTALLED_ANDROID_INFO_TXT_TARGET)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo > $@
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OEM_PROPERTIES),)
	$(hide) echo "#" >> $@; \
	        echo "# PRODUCT_OEM_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach prop,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OEM_PROPERTIES), \
		echo "import /oem/oem.prop $(prop)" >> $@;)
endif
	$(hide) TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
			TARGET_BUILD_FLAVOR="$(TARGET_BUILD_FLAVOR)" \
			TARGET_DEVICE="$(TARGET_DEVICE)" \
			PRODUCT_NAME="$(TARGET_PRODUCT)" \
			PRODUCT_BRAND="$(PRODUCT_BRAND)" \
			PRODUCT_DEFAULT_LOCALE="$(call get-default-product-locale,$(PRODUCT_LOCALES))" \
			PRODUCT_DEFAULT_WIFI_CHANNELS="$(PRODUCT_DEFAULT_WIFI_CHANNELS)" \
			PRODUCT_MODEL="$(PRODUCT_MODEL)" \
			PRODUCT_MANUFACTURER="$(PRODUCT_MANUFACTURER)" \
			PRIVATE_BUILD_DESC="$(PRIVATE_BUILD_DESC)" \
			BUILD_ID="$(BUILD_ID)" \
			BUILD_DISPLAY_ID="$(BUILD_DISPLAY_ID)" \
			DATE="$(DATE_FROM_FILE)" \
			BUILD_NUMBER="$(BUILD_NUMBER_FROM_FILE)" \
			BOARD_BUILD_SYSTEM_ROOT_IMAGE="$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)" \
			AB_OTA_UPDATER="$(AB_OTA_UPDATER)" \
			PLATFORM_VERSION="$(PLATFORM_VERSION)" \
			PLATFORM_SECURITY_PATCH="$(PLATFORM_SECURITY_PATCH)" \
			PLATFORM_BASE_OS="$(PLATFORM_BASE_OS)" \
			PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" \
			PLATFORM_PREVIEW_SDK_VERSION="$(PLATFORM_PREVIEW_SDK_VERSION)" \
			PLATFORM_VERSION_CODENAME="$(PLATFORM_VERSION_CODENAME)" \
			PLATFORM_VERSION_ALL_CODENAMES="$(PLATFORM_VERSION_ALL_CODENAMES)" \
			BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
			TARGET_BOOTLOADER_BOARD_NAME="$(TARGET_BOOTLOADER_BOARD_NAME)" \
			BUILD_FINGERPRINT="$(BUILD_FINGERPRINT_FROM_FILE)" \
			$(if $(OEM_THUMBPRINT_PROPERTIES),BUILD_THUMBPRINT="$(BUILD_THUMBPRINT)") \
			TARGET_BOARD_PLATFORM="$(TARGET_BOARD_PLATFORM)" \
			TARGET_CPU_ABI_LIST="$(TARGET_CPU_ABI_LIST)" \
			TARGET_CPU_ABI_LIST_32_BIT="$(TARGET_CPU_ABI_LIST_32_BIT)" \
			TARGET_CPU_ABI_LIST_64_BIT="$(TARGET_CPU_ABI_LIST_64_BIT)" \
			TARGET_CPU_ABI="$(TARGET_CPU_ABI)" \
			TARGET_CPU_ABI2="$(TARGET_CPU_ABI2)" \
			TARGET_AAPT_CHARACTERISTICS="$(TARGET_AAPT_CHARACTERISTICS)" \
	        bash $(BUILDINFO_SH) >> $@
	$(hide) $(foreach file,$(system_prop_file), \
		if [ -f "$(file)" ]; then \
			echo "#" >> $@; \
			echo Target buildinfo from: "$(file)"; \
			echo "# from $(file)" >> $@; \
			echo "#" >> $@; \
			cat $(file) >> $@; \
		fi;)
	$(if $(ADDITIONAL_BUILD_PROPERTIES), \
		$(hide) echo >> $@; \
		        echo "#" >> $@; \
		        echo "# ADDITIONAL_BUILD_PROPERTIES" >> $@; \
		        echo "#" >> $@; )
	$(hide) $(foreach line,$(ADDITIONAL_BUILD_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) cat $(INSTALLED_ANDROID_INFO_TXT_TARGET) | grep 'require version-' | sed -e 's/require version-/ro.build.expect./g' >> $@
	$(hide) build/tools/post_process_props.py $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_PROPERTY_BLACKLIST)

build_desc :=

ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
else
INSTALLED_RECOVERYIMAGE_TARGET :=
endif

$(INSTALLED_BUILD_PROP_TARGET): $(intermediate_system_build_prop) $(INSTALLED_RECOVERYIMAGE_TARGET)
	@echo "Target build info: $@"
	$(hide) cat $(intermediate_system_build_prop) > $@
ifdef INSTALLED_RECOVERYIMAGE_TARGET
	$(hide) echo ro.expect.recovery_id=`cat $(RECOVERYIMAGE_ID_FILE)` >> $@
endif

# -----------------------------------------------------------------
# vendor build.prop
#
# For verifying that the vendor build is what we thing it is
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
INSTALLED_VENDOR_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_VENDOR_BUILD_PROP_TARGET)
$(INSTALLED_VENDOR_BUILD_PROP_TARGET): $(INSTALLED_BUILD_PROP_TARGET)
	@echo Target vendor buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo > $@
	$(hide) echo ro.vendor.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.vendor.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.vendor.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
endif

# ----------------------------------------------------------------

# -----------------------------------------------------------------
# sdk-build.prop
#
# There are certain things in build.prop that we don't want to
# ship with the sdk; remove them.

# This must be a list of entire property keys followed by
# "=" characters, without any internal spaces.
sdk_build_prop_remove := \
	ro.build.user= \
	ro.build.host= \
	ro.product.brand= \
	ro.product.manufacturer= \
	ro.product.device=
# TODO: Remove this soon-to-be obsolete property
sdk_build_prop_remove += ro.build.product=
INSTALLED_SDK_BUILD_PROP_TARGET := $(PRODUCT_OUT)/sdk/sdk-build.prop
$(INSTALLED_SDK_BUILD_PROP_TARGET): $(INSTALLED_BUILD_PROP_TARGET)
	@echo SDK buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) grep -v "$(subst $(space),\|,$(strip \
				$(sdk_build_prop_remove)))" $< > $@.tmp
	$(hide) for x in $(sdk_build_prop_remove); do \
				echo "$$x"generic >> $@.tmp; done
	$(hide) mv $@.tmp $@

# -----------------------------------------------------------------
# package stats
PACKAGE_STATS_FILE := $(PRODUCT_OUT)/package-stats.txt
PACKAGES_TO_STAT := \
    $(sort $(filter $(TARGET_OUT)/% $(TARGET_OUT_DATA)/%, \
	$(filter %.jar %.apk, $(ALL_DEFAULT_INSTALLED_MODULES))))
$(PACKAGE_STATS_FILE): $(PACKAGES_TO_STAT)
	@echo Package stats: $@
	@mkdir -p $(dir $@)
	$(hide) rm -f $@
ifeq ($(PACKAGES_TO_STAT),)
# Create empty package stats file if target builds no jar(s) or apk(s).
	$(hide) touch $@
else
	$(hide) build/tools/dump-package-stats $^ > $@
endif

.PHONY: package-stats
package-stats: $(PACKAGE_STATS_FILE)

# -----------------------------------------------------------------
# Cert-to-package mapping.  Used by the post-build signing tools.
# Use a macro to add newline to each echo command
define _apkcerts_echo_with_newline
$(hide) echo $(1)

endef

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-apkcerts-$(FILE_NAME_TAG)
intermediates := \
	$(call intermediates-dir-for,PACKAGING,apkcerts)
APKCERTS_FILE := $(intermediates)/$(name).txt
# We don't need to really build all the modules.
# TODO: rebuild APKCERTS_FILE if any app change its cert.
$(APKCERTS_FILE):
	@echo APK certs list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(foreach p,$(PACKAGES),\
	  $(if $(PACKAGES.$(p).EXTERNAL_KEY),\
	    $(call _apkcerts_echo_with_newline,\
	      'name="$(p).apk" certificate="EXTERNAL" \
	      private_key=""' >> $@),\
	    $(call _apkcerts_echo_with_newline,\
	      'name="$(p).apk" certificate="$(PACKAGES.$(p).CERTIFICATE)" \
	      private_key="$(PACKAGES.$(p).PRIVATE_KEY)"' >> $@)))
	# In case value of PACKAGES is empty.
	$(hide) touch $@

.PHONY: apkcerts-list
apkcerts-list: $(APKCERTS_FILE)

ifneq (,$(TARGET_BUILD_APPS))
  $(call dist-for-goals, apps_only, $(APKCERTS_FILE):apkcerts.txt)
endif

# -----------------------------------------------------------------

# The dev key is used to sign this package, and as the key required
# for future OTA packages installed by this system.  Actual product
# deliverables will be re-signed by hand.  We expect this file to
# exist with the suffixes ".x509.pem" and ".pk8".
DEFAULT_KEY_CERT_PAIR := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)


# Rules that need to be present for the all targets, even
# if they don't do anything.
.PHONY: systemimage
systemimage:

# -----------------------------------------------------------------

.PHONY: event-log-tags

# Produce an event logs tag file for everything we know about, in order
# to properly allocate numbers.  Then produce a file that's filtered
# for what's going to be installed.

all_event_log_tags_file := $(TARGET_OUT_COMMON_INTERMEDIATES)/all-event-log-tags.txt

event_log_tags_file := $(TARGET_OUT)/etc/event-log-tags

# Include tags from all packages that we know about
all_event_log_tags_src := \
    $(sort $(foreach m, $(ALL_MODULES), $(ALL_MODULES.$(m).EVENT_LOG_TAGS)))

# PDK builds will already have a full list of tags that needs to get merged
# in with the ones from source
pdk_fusion_log_tags_file := $(patsubst $(PRODUCT_OUT)/%,$(_pdk_fusion_intermediates)/%,$(filter $(event_log_tags_file),$(ALL_PDK_FUSION_FILES)))

$(all_event_log_tags_file): PRIVATE_SRC_FILES := $(all_event_log_tags_src) $(pdk_fusion_log_tags_file)
$(all_event_log_tags_file): $(all_event_log_tags_src) $(pdk_fusion_log_tags_file)
	$(hide) mkdir -p $(dir $@)
	$(hide) build/tools/merge-event-log-tags.py -o $@ $(PRIVATE_SRC_FILES)

# Include tags from all packages included in this product, plus all
# tags that are part of the system (ie, not in a vendor/ or device/
# directory).
event_log_tags_src := \
    $(sort $(foreach m,\
      $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES) \
      $(call module-names-for-tag-list,user), \
      $(ALL_MODULES.$(m).EVENT_LOG_TAGS)) \
      $(filter-out vendor/% device/% out/%,$(all_event_log_tags_src)))

$(event_log_tags_file): PRIVATE_SRC_FILES := $(event_log_tags_src) $(pdk_fusion_log_tags_file)
$(event_log_tags_file): PRIVATE_MERGED_FILE := $(all_event_log_tags_file)
$(event_log_tags_file): $(event_log_tags_src) $(all_event_log_tags_file) $(pdk_fusion_log_tags_file)
	$(hide) mkdir -p $(dir $@)
	$(hide) build/tools/merge-event-log-tags.py -o $@ -m $(PRIVATE_MERGED_FILE) $(PRIVATE_SRC_FILES)

event-log-tags: $(event_log_tags_file)

ALL_DEFAULT_INSTALLED_MODULES += $(event_log_tags_file)


# #################################################################
# Targets for boot/OS images
# #################################################################
ifneq ($(strip $(TARGET_NO_BOOTLOADER)),true)
  INSTALLED_BOOTLOADER_MODULE := $(PRODUCT_OUT)/bootloader
  ifeq ($(strip $(TARGET_BOOTLOADER_IS_2ND)),true)
    INSTALLED_2NDBOOTLOADER_TARGET := $(PRODUCT_OUT)/2ndbootloader
  else
    INSTALLED_2NDBOOTLOADER_TARGET :=
  endif
else
  INSTALLED_BOOTLOADER_MODULE :=
  INSTALLED_2NDBOOTLOADER_TARGET :=
endif # TARGET_NO_BOOTLOADER
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
  INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
else
  INSTALLED_KERNEL_TARGET :=
endif

# -----------------------------------------------------------------
# the ramdisk
INTERNAL_RAMDISK_FILES := $(filter $(TARGET_ROOT_OUT)/%, \
	$(ALL_PREBUILT) \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

BUILT_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img

# We just build this directly to the install location.
INSTALLED_RAMDISK_TARGET := $(BUILT_RAMDISK_TARGET)
$(INSTALLED_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_RAMDISK_FILES) | $(MINIGZIP)
	$(call pretty,"Target ram disk: $@")
	$(hide) $(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_ROOT_OUT) | $(MINIGZIP) > $@

.PHONY: ramdisk-nodeps
ramdisk-nodeps: $(MKBOOTFS) | $(MINIGZIP)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_ROOT_OUT) | $(MINIGZIP) > $(INSTALLED_RAMDISK_TARGET)

ifneq ($(strip $(TARGET_NO_KERNEL)),true)

# -----------------------------------------------------------------
# the boot image, which is a collection of other images.
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET)

ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
INTERNAL_BOOTIMAGE_ARGS += --ramdisk $(INSTALLED_RAMDISK_TARGET)
endif

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

BOARD_KERNEL_BASE := $(strip $(BOARD_KERNEL_BASE))
ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

BOARD_KERNEL_PAGESIZE := $(strip $(BOARD_KERNEL_PAGESIZE))
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

ifeq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),true)
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
VERITY_KEYID := veritykeyid=id:`openssl x509 -in $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem -text \
                | grep keyid | sed 's/://g' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/keyid//g'`
endif
endif

BOARD_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE) buildvariant=$(TARGET_BUILD_VARIANT) $(VERITY_KEYID))
ifdef BOARD_KERNEL_CMDLINE
INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(BOARD_KERNEL_CMDLINE)"
endif

INTERNAL_MKBOOTIMG_VERSION_ARGS := \
    --os_version $(PLATFORM_VERSION) \
    --os_patch_level $(PLATFORM_SECURITY_PATCH)

INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img

# BOARD_USES_RECOVERY_AS_BOOT = true must have BOARD_BUILD_SYSTEM_ROOT_IMAGE = true.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
  $(error BOARD_BUILD_SYSTEM_ROOT_IMAGE must be enabled for BOARD_USES_RECOVERY_AS_BOOT.)
endif
endif

# We build recovery as boot image if BOARD_USES_RECOVERY_AS_BOOT is true.
ifneq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifeq ($(TARGET_BOOTIMAGE_USE_EXT2),true)
$(error TARGET_BOOTIMAGE_USE_EXT2 is not supported anymore)
else ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)) # TARGET_BOOTIMAGE_USE_EXT2 != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(BOOT_SIGNER)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(BOOT_SIGNER) /boot $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(BOOT_SIGNER)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(INSTALLED_BOOTIMAGE_TARGET)
	$(BOOT_SIGNER) /boot $(INSTALLED_BOOTIMAGE_TARGET) $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $(INSTALLED_BOOTIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$(INSTALLED_BOOTIMAGE_TARGET),$(BOARD_BOOTIMAGE_PARTITION_SIZE))

else ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT)) # PRODUCT_SUPPORTS_BOOT_SIGNER != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(VBOOT_SIGNER)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@.unsigned
	$(VBOOT_SIGNER) $(FUTILITY) $@.unsigned $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $@.keyblock $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(VBOOT_SIGNER)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(INSTALLED_BOOTIMAGE_TARGET).unsigned
	$(VBOOT_SIGNER) $(FUTILITY) $(INSTALLED_BOOTIMAGE_TARGET).unsigned $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(INSTALLED_BOOTIMAGE_TARGET).keyblock $(INSTALLED_BOOTIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$(INSTALLED_BOOTIMAGE_TARGET),$(BOARD_BOOTIMAGE_PARTITION_SIZE))

else # PRODUCT_SUPPORTS_VBOOT != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(INSTALLED_BOOTIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$(INSTALLED_BOOTIMAGE_TARGET),$(BOARD_BOOTIMAGE_PARTITION_SIZE))

endif # TARGET_BOOTIMAGE_USE_EXT2
endif # BOARD_USES_RECOVERY_AS_BOOT

else	# TARGET_NO_KERNEL
# HACK: The top-level targets depend on the bootimage.  Not all targets
# can produce a bootimage, though, and emulator targets need the ramdisk
# instead.  Fake it out by calling the ramdisk the bootimage.
# TODO: make the emulator use bootimages, and make mkbootimg accept
#       kernel-less inputs.
INSTALLED_BOOTIMAGE_TARGET := $(INSTALLED_RAMDISK_TARGET)
endif

# -----------------------------------------------------------------
# NOTICE files
#
# We are required to publish the licenses for all code under BSD, GPL and
# Apache licenses (and possibly other more exotic ones as well). We err on the
# side of caution, so the licenses for other third-party code are included here
# too.
#
# This needs to be before the systemimage rules, because it adds to
# ALL_DEFAULT_INSTALLED_MODULES, which those use to pick which files
# go into the systemimage.

.PHONY: notice_files

# Create the rule to combine the files into text and html forms
# $(1) - Plain text output file
# $(2) - HTML output file
# $(3) - File title
# $(4) - Directory to use.  Notice files are all $(4)/src.  Other
#		 directories in there will be used for scratch
# $(5) - Dependencies for the output files
#
# The algorithm here is that we go collect a hash for each of the notice
# files and write the names of the files that match that hash.  Then
# to generate the real files, we go print out all of the files and their
# hashes.
#
# These rules are fairly complex, so they depend on this makefile so if
# it changes, they'll run again.
#
# TODO: We could clean this up so that we just record the locations of the
# original notice files instead of making rules to copy them somwehere.
# Then we could traverse that without quite as much bash drama.
define combine-notice-files
$(1) $(2): PRIVATE_MESSAGE := $(3)
$(1) $(2): PRIVATE_DIR := $(4)
$(1) : $(2)
$(2) : $(5) $(BUILD_SYSTEM)/Makefile build/tools/generate-notice-files.py
	build/tools/generate-notice-files.py $(1) $(2) $$(PRIVATE_MESSAGE) $$(PRIVATE_DIR)/src
notice_files: $(1) $(2)
endef

# TODO These intermediate NOTICE.txt/NOTICE.html files should go into
# TARGET_OUT_NOTICE_FILES now that the notice files are gathered from
# the src subdirectory.

target_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE.txt
target_notice_file_html := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html
target_notice_file_html_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html.gz
tools_notice_file_txt := $(HOST_OUT_INTERMEDIATES)/NOTICE.txt
tools_notice_file_html := $(HOST_OUT_INTERMEDIATES)/NOTICE.html

ifndef TARGET_BUILD_APPS
kernel_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/kernel.txt
pdk_fusion_notice_files := $(filter $(TARGET_OUT_NOTICE_FILES)/%, $(ALL_PDK_FUSION_FILES))

$(eval $(call combine-notice-files, \
			$(target_notice_file_txt), \
			$(target_notice_file_html), \
			"Notices for files contained in the filesystem images in this directory:", \
			$(TARGET_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file) $(pdk_fusion_notice_files)))

$(eval $(call combine-notice-files, \
			$(tools_notice_file_txt), \
			$(tools_notice_file_html), \
			"Notices for files contained in the tools directory:", \
			$(HOST_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES)))

# Install the html file at /system/etc/NOTICE.html.gz.
# This is not ideal, but this is very late in the game, after a lot of
# the module processing has already been done -- in fact, we used the
# fact that all that has been done to get the list of modules that we
# need notice files for.
$(target_notice_file_html_gz): $(target_notice_file_html) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
installed_notice_html_gz := $(TARGET_OUT)/etc/NOTICE.html.gz
$(installed_notice_html_gz): $(target_notice_file_html_gz) | $(ACP)
	$(copy-file-to-target)

# if we've been run my mm, mmm, etc, don't reinstall this every time
ifeq ($(ONE_SHOT_MAKEFILE),)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_notice_html_gz)
endif
endif  # TARGET_BUILD_APPS

# The kernel isn't really a module, so to get its module file in there, we
# make the target NOTICE files depend on this particular file too, which will
# then be in the right directory for the find in combine-notice-files to work.
$(kernel_notice_file): \
	    $(BUILD_SYSTEM)/LINUX_KERNEL_COPYING \
	    | $(ACP)
	@echo Copying: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) $(ACP) $< $@


# -----------------------------------------------------------------
# Build a keystore with the authorized keys in it, used to verify the
# authenticity of downloaded OTA packages.
#
# This rule adds to ALL_DEFAULT_INSTALLED_MODULES, so it needs to come
# before the rules that use that variable to build the image.
ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT_ETC)/security/otacerts.zip
$(TARGET_OUT_ETC)/security/otacerts.zip: KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(TARGET_OUT_ETC)/security/otacerts.zip: $(addsuffix .x509.pem,$(DEFAULT_KEY_CERT_PAIR)) | $(ZIPTIME)
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(hide) zip -qjX $@ $<
	$(remove-timestamps-from-package)

# Carry the public key for update_engine if it's a non-Brillo target that
# uses the AB updater. We use the same key as otacerts but in RSA public key
# format.
ifeq ($(AB_OTA_UPDATER),true)
ifeq ($(BRILLO),)
ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT_ETC)/update_engine/update-payload-key.pub.pem
$(TARGET_OUT_ETC)/update_engine/update-payload-key.pub.pem: $(addsuffix .x509.pem,$(DEFAULT_KEY_CERT_PAIR))
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(hide) openssl x509 -pubkey -noout -in $< > $@

ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_RECOVERY_ROOT_OUT)/etc/update_engine/update-payload-key.pub.pem
$(TARGET_RECOVERY_ROOT_OUT)/etc/update_engine/update-payload-key.pub.pem: $(TARGET_OUT_ETC)/update_engine/update-payload-key.pub.pem
	$(hide) cp -f $< $@
endif
endif

.PHONY: otacerts
otacerts: $(TARGET_OUT_ETC)/security/otacerts.zip


# #################################################################
# Targets for user images
# #################################################################

INTERNAL_USERIMAGES_EXT_VARIANT :=
ifeq ($(TARGET_USERIMAGES_USE_EXT2),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext2
else
ifeq ($(TARGET_USERIMAGES_USE_EXT3),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext3
else
ifeq ($(TARGET_USERIMAGES_USE_EXT4),true)
INTERNAL_USERIMAGES_USE_EXT := true
INTERNAL_USERIMAGES_EXT_VARIANT := ext4
endif
endif
endif

# These options tell the recovery updater/installer how to mount the partitions writebale.
# <fstype>=<fstype_opts>[|<fstype_opts>]...
# fstype_opts := <opt>[,<opt>]...
#         opt := <name>[=<value>]
# The following worked on Nexus devices with Kernel 3.1, 3.4, 3.10
DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS := ext4=max_batch_time=0,commit=1,data=ordered,barrier=1,errors=panic,nodelalloc

ifneq (true,$(TARGET_USERIMAGES_SPARSE_EXT_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_EXT_FLAG := -s
endif

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
INTERNAL_USERIMAGES_DEPS := $(SIMG2IMG)
INTERNAL_USERIMAGES_DEPS += $(MKEXTUSERIMG) $(MAKE_EXT4FS) $(E2FSCK)
ifeq ($(TARGET_USERIMAGES_USE_F2FS),true)
INTERNAL_USERIMAGES_DEPS += $(MKF2FSUSERIMG) $(MAKE_F2FS)
endif
endif

ifneq (true,$(TARGET_USERIMAGES_SPARSE_SQUASHFS_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG := -s
endif
ifneq ($(filter $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE) $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE),squashfs),)
INTERNAL_USERIMAGES_DEPS += $(MAKE_SQUASHFS) $(MKSQUASHFSUSERIMG) $(IMG2SIMG)
endif

INTERNAL_USERIMAGES_BINARY_PATHS := $(sort $(dir $(INTERNAL_USERIMAGES_DEPS)))

ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY))
INTERNAL_USERIMAGES_DEPS += $(BUILD_VERITY_TREE) $(APPEND2SIMG) $(VERITY_SIGNER)
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC))
INTERNAL_USERIMAGES_DEPS += $(FEC)
endif
endif

SELINUX_FC := $(TARGET_ROOT_OUT)/file_contexts.bin
INTERNAL_USERIMAGES_DEPS += $(SELINUX_FC)

INTERNAL_USERIMAGES_DEPS += $(BLK_ALLOC_TO_BASE_FS)

# $(1): the path of the output dictionary file
# $(2): additional "key=value" pairs to append to the dictionary file.
define generate-userimage-prop-dictionary
$(if $(INTERNAL_USERIMAGES_EXT_VARIANT),$(hide) echo "fs_type=$(INTERNAL_USERIMAGES_EXT_VARIANT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_PARTITION_SIZE),$(hide) echo "system_size=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "system_fs_type=$(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "system_extfs_inode_count=$(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_JOURNAL_SIZE),$(hide) echo "system_journal_size=$(BOARD_SYSTEMIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_HAS_EXT4_RESERVED_BLOCKS),$(hide) echo "has_ext4_reserved_blocks=$(BOARD_HAS_EXT4_RESERVED_BLOCKS)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "system_squashfs_compressor=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "system_squashfs_compressor_opt=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "system_squashfs_block_size=$(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "system_squashfs_disable_4k_align=$(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH),$(hide) echo "system_base_fs_file=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH)" >> $(1))
$(if $(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "userdata_fs_type=$(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(hide) echo "userdata_size=$(BOARD_USERDATAIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "cache_fs_type=$(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_CACHEIMAGE_PARTITION_SIZE),$(hide) echo "cache_size=$(BOARD_CACHEIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "vendor_fs_type=$(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT),$(hide) echo "vendor_extfs_inode_count=$(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_VENDORIMAGE_PARTITION_SIZE),$(hide) echo "vendor_size=$(BOARD_VENDORIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_JOURNAL_SIZE),$(hide) echo "vendor_journal_size=$(BOARD_VENDORIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "vendor_squashfs_compressor=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "vendor_squashfs_compressor_opt=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "vendor_squashfs_block_size=$(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "vendor_squashfs_disable_4k_align=$(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH),$(hide) echo "vendor_base_fs_file=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH)" >> $(1))
$(if $(BOARD_OEMIMAGE_PARTITION_SIZE),$(hide) echo "oem_size=$(BOARD_OEMIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_OEMIMAGE_JOURNAL_SIZE),$(hide) echo "oem_journal_size=$(BOARD_OEMIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_OEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "oem_extfs_inode_count=$(BOARD_OEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG),$(hide) echo "extfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG),$(hide) echo "squashfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG)" >> $(1))
$(hide) echo "selinux_fc=$(SELINUX_FC)" >> $(1)
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER),$(hide) echo "boot_signer=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_key=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_signer_cmd=$(notdir $(VERITY_SIGNER))" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC),$(hide) echo "verity_fec=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_VERITY_PARTITION),$(hide) echo "system_verity_block_device=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_VERITY_PARTITION),$(hide) echo "vendor_verity_block_device=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_key=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_subkey=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "futility=$(FUTILITY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_signer_cmd=$(VBOOT_SIGNER)" >> $(1))
$(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(hide) echo "recovery_as_boot=true" >> $(1))
$(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)),\
    $(hide) echo "system_root_image=true" >> $(1);\
    echo "ramdisk_dir=$(TARGET_ROOT_OUT)" >> $(1))
$(if $(2),$(hide) $(foreach kv,$(2),echo "$(kv)" >> $(1);))
endef

# -----------------------------------------------------------------
# Recovery image

# Recovery image exists if we are building recovery, or building recovery as boot.
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))

INTERNAL_RECOVERYIMAGE_FILES := $(filter $(TARGET_RECOVERY_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

recovery_initrc := $(call include-path-for, recovery)/etc/init.rc
recovery_sepolicy := $(call intermediates-dir-for,ETC,sepolicy.recovery)/sepolicy.recovery
recovery_kernel := $(INSTALLED_KERNEL_TARGET) # same as a non-recovery system
recovery_ramdisk := $(PRODUCT_OUT)/ramdisk-recovery.img
recovery_build_prop := $(intermediate_system_build_prop)
recovery_resources_common := $(call include-path-for, recovery)/res

# Set recovery_density to the density bucket of the device.
recovery_density := unknown
ifneq (,$(PRODUCT_AAPT_PREF_CONFIG))
# If PRODUCT_AAPT_PREF_CONFIG includes a dpi bucket, then use that value.
recovery_density := $(filter %dpi,$(PRODUCT_AAPT_PREF_CONFIG))
else
# Otherwise, use the default medium density.
recovery_densities := mdpi
endif

ifneq (,$(wildcard $(recovery_resources_common)-$(recovery_density)))
recovery_resources_common := $(recovery_resources_common)-$(recovery_density)
else
recovery_resources_common := $(recovery_resources_common)-xhdpi
endif

# Select the 18x32 font on high-density devices (xhdpi and up); and
# the 12x22 font on other devices.  Note that the font selected here
# can be overridden for a particular device by putting a font.png in
# its private recovery resources.

ifneq (,$(filter xxxhdpi 560dpi xxhdpi 400dpi xhdpi,$(recovery_density)))
recovery_font := $(call include-path-for, recovery)/fonts/18x32.png
else
recovery_font := $(call include-path-for, recovery)/fonts/12x22.png
endif

ifndef TARGET_PRIVATE_RES_DIRS
TARGET_PRIVATE_RES_DIRS := $(wildcard $(TARGET_DEVICE_DIR)/recovery/res)
endif
recovery_resource_deps := $(shell find $(recovery_resources_common) \
  $(TARGET_PRIVATE_RES_DIRS) -type f)
ifdef TARGET_RECOVERY_FSTAB
recovery_fstab := $(TARGET_RECOVERY_FSTAB)
else
recovery_fstab := $(strip $(wildcard $(TARGET_DEVICE_DIR)/recovery.fstab))
endif
ifdef TARGET_RECOVERY_WIPE
recovery_wipe := $(TARGET_RECOVERY_WIPE)
else
recovery_wipe :=
endif

# Prior to A/B update, we used to have:
#   boot.img + recovery-from-boot.p + recovery-resource.dat = recovery.img.
# recovery-resource.dat is needed only if we carry a patch of the boot and
# recovery images and invoke install-recovery.sh on the first boot post an
# OTA update.
#
# We no longer need that if one of the following conditions holds:
#   a) We carry a full copy of the recovery image
#      (BOARD_USES_FULL_RECOVERY_IMAGE = true);
#   b) We build a single image that contains boot and recovery both
#      (BOARD_USES_RECOVERY_AS_BOOT = true).

ifeq (,$(filter true, $(BOARD_USES_FULL_RECOVERY_IMAGE) $(BOARD_USES_RECOVERY_AS_BOOT)))
# Named '.dat' so we don't attempt to use imgdiff for patching it.
RECOVERY_RESOURCE_ZIP := $(TARGET_OUT)/etc/recovery-resource.dat
else
RECOVERY_RESOURCE_ZIP :=
endif

ifeq ($(TARGET_PRIVATE_RES_DIRS),)
  $(info No private recovery resources for TARGET_DEVICE $(TARGET_DEVICE))
endif

ifeq ($(recovery_fstab),)
  $(info No recovery.fstab for TARGET_DEVICE $(TARGET_DEVICE))
endif

INTERNAL_RECOVERYIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(recovery_kernel) \
	--ramdisk $(recovery_ramdisk)

# Assumes this has already been stripped
ifdef BOARD_KERNEL_CMDLINE
  INTERNAL_RECOVERYIMAGE_ARGS += --cmdline "$(BOARD_KERNEL_CMDLINE)"
endif
ifdef BOARD_KERNEL_BASE
  INTERNAL_RECOVERYIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif
BOARD_KERNEL_PAGESIZE := $(strip $(BOARD_KERNEL_PAGESIZE))
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_RECOVERYIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

# Keys authorized to sign OTA packages this build will accept.  The
# build always uses dev-keys for this; release packaging tools will
# substitute other keys for this one.
OTA_PUBLIC_KEYS := $(DEFAULT_SYSTEM_DEV_CERTIFICATE).x509.pem

# Generate a file containing the keys that will be read by the
# recovery binary.
RECOVERY_INSTALL_OTA_KEYS := \
	$(call intermediates-dir-for,PACKAGING,ota_keys)/keys
DUMPKEY_JAR := $(HOST_OUT_JAVA_LIBRARIES)/dumpkey.jar
$(RECOVERY_INSTALL_OTA_KEYS): PRIVATE_OTA_PUBLIC_KEYS := $(OTA_PUBLIC_KEYS)
$(RECOVERY_INSTALL_OTA_KEYS): extra_keys := $(patsubst %,%.x509.pem,$(PRODUCT_EXTRA_RECOVERY_KEYS))
$(RECOVERY_INSTALL_OTA_KEYS): $(OTA_PUBLIC_KEYS) $(DUMPKEY_JAR) $(extra_keys)
	@echo "DumpPublicKey: $@ <= $(PRIVATE_OTA_PUBLIC_KEYS) $(extra_keys)"
	@rm -rf $@
	@mkdir -p $(dir $@)
	java -jar $(DUMPKEY_JAR) $(PRIVATE_OTA_PUBLIC_KEYS) $(extra_keys) > $@

RECOVERYIMAGE_ID_FILE := $(PRODUCT_OUT)/recovery.id
# $(1): output file
define build-recoveryimage-target
  @echo ----- Making recovery image ------
  $(hide) mkdir -p $(TARGET_RECOVERY_OUT)
  $(hide) mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/etc $(TARGET_RECOVERY_ROOT_OUT)/sdcard $(TARGET_RECOVERY_ROOT_OUT)/tmp
  @echo Copying baseline ramdisk...
  $(hide) rsync -a --exclude=etc --exclude=sdcard $(IGNORE_CACHE_LINK) $(TARGET_ROOT_OUT) $(TARGET_RECOVERY_OUT) # "cp -Rf" fails to overwrite broken symlinks on Mac.
  @echo Modifying ramdisk contents...
  $(hide) rm -f $(TARGET_RECOVERY_ROOT_OUT)/init*.rc
  $(hide) cp -f $(recovery_initrc) $(TARGET_RECOVERY_ROOT_OUT)/
  $(hide) rm -f $(TARGET_RECOVERY_ROOT_OUT)/sepolicy
  $(hide) cp -f $(recovery_sepolicy) $(TARGET_RECOVERY_ROOT_OUT)/sepolicy
  $(hide) cp $(TARGET_ROOT_OUT)/init.recovery.*.rc $(TARGET_RECOVERY_ROOT_OUT)/ || true # Ignore error when the src file doesn't exist.
  $(hide) mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/res
  $(hide) rm -rf $(TARGET_RECOVERY_ROOT_OUT)/res/*
  $(hide) cp -rf $(recovery_resources_common)/* $(TARGET_RECOVERY_ROOT_OUT)/res
  $(hide) cp -f $(recovery_font) $(TARGET_RECOVERY_ROOT_OUT)/res/images/font.png
  $(hide) $(foreach item,$(TARGET_PRIVATE_RES_DIRS), \
    cp -rf $(item) $(TARGET_RECOVERY_ROOT_OUT)/$(newline))
  $(hide) $(foreach item,$(recovery_fstab), \
    cp -f $(item) $(TARGET_RECOVERY_ROOT_OUT)/etc/recovery.fstab)
  $(if $(strip $(recovery_wipe)), \
    $(hide) cp -f $(recovery_wipe) $(TARGET_RECOVERY_ROOT_OUT)/etc/recovery.wipe)
  $(hide) cp $(RECOVERY_INSTALL_OTA_KEYS) $(TARGET_RECOVERY_ROOT_OUT)/res/keys
  $(hide) cat $(INSTALLED_DEFAULT_PROP_TARGET) $(recovery_build_prop) \
          > $(TARGET_RECOVERY_ROOT_OUT)/default.prop
  $(BOARD_RECOVERY_IMAGE_PREPARE)
  $(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)), \
    $(hide) mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/system_root; \
            rm -rf $(TARGET_RECOVERY_ROOT_OUT)/system; \
            ln -sf /system_root/system $(TARGET_RECOVERY_ROOT_OUT)/system) # Mount the system_root_image to /system_root and symlink /system.
  $(hide) $(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_RECOVERY_ROOT_OUT) | $(MINIGZIP) > $(recovery_ramdisk)
  $(if $(filter true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT)), \
    $(hide) $(MKBOOTIMG) $(INTERNAL_RECOVERYIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1).unsigned, \
    $(hide) $(MKBOOTIMG) $(INTERNAL_RECOVERYIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1) --id > $(RECOVERYIMAGE_ID_FILE))
  $(if $(filter true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)),\
    $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
      $(BOOT_SIGNER) /boot $(1) $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $(1),\
      $(BOOT_SIGNER) /recovery $(1) $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem $(1)\
    )\
  )
  $(if $(filter true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT)), \
    $(VBOOT_SIGNER) $(FUTILITY) $(1).unsigned $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(1).keyblock $(1))
  $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
    $(hide) $(call assert-max-image-size,$(1),$(BOARD_BOOTIMAGE_PARTITION_SIZE)), \
    $(hide) $(call assert-max-image-size,$(1),$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)))
  @echo ----- Made recovery image: $(1) --------
endef

ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER))
$(INSTALLED_BOOTIMAGE_TARGET) : $(BOOT_SIGNER)
endif
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT))
$(INSTALLED_BOOTIMAGE_TARGET) : $(VBOOT_SIGNER)
endif
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTFS) $(MKBOOTIMG) $(MINIGZIP) \
		$(INSTALLED_RAMDISK_TARGET) \
		$(INTERNAL_RECOVERYIMAGE_FILES) \
		$(recovery_initrc) $(recovery_sepolicy) $(recovery_kernel) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(recovery_build_prop) $(recovery_resource_deps) \
		$(recovery_fstab) \
		$(RECOVERY_INSTALL_OTA_KEYS)
		$(call pretty,"Target boot image from recovery: $@")
		$(call build-recoveryimage-target, $@)
endif

$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTFS) $(MKBOOTIMG) $(MINIGZIP) \
		$(INSTALLED_RAMDISK_TARGET) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INTERNAL_RECOVERYIMAGE_FILES) \
		$(recovery_initrc) $(recovery_sepolicy) $(recovery_kernel) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(recovery_build_prop) $(recovery_resource_deps) \
		$(recovery_fstab) \
		$(RECOVERY_INSTALL_OTA_KEYS)
		$(call build-recoveryimage-target, $@)

ifdef RECOVERY_RESOURCE_ZIP
$(RECOVERY_RESOURCE_ZIP): $(INSTALLED_RECOVERYIMAGE_TARGET) | $(ZIPTIME)
	$(hide) mkdir -p $(dir $@)
	$(hide) find $(TARGET_RECOVERY_ROOT_OUT)/res -type f | sort | zip -0qrjX $@ -@
	$(remove-timestamps-from-package)
endif

.PHONY: recoveryimage-nodeps
recoveryimage-nodeps:
	@echo "make $@: ignoring dependencies"
	$(call build-recoveryimage-target, $(INSTALLED_RECOVERYIMAGE_TARGET))

else # INSTALLED_RECOVERYIMAGE_TARGET not defined
RECOVERY_RESOURCE_ZIP :=
endif

.PHONY: recoveryimage
recoveryimage: $(INSTALLED_RECOVERYIMAGE_TARGET) $(RECOVERY_RESOURCE_ZIP)

ifeq ($(BOARD_NAND_PAGE_SIZE),)
BOARD_NAND_PAGE_SIZE := 2048
endif

ifeq ($(BOARD_NAND_SPARE_SIZE),)
BOARD_NAND_SPARE_SIZE := 64
endif

# -----------------------------------------------------------------
# system image
#
# Remove overridden packages from $(ALL_PDK_FUSION_FILES)
PDK_FUSION_SYSIMG_FILES := \
    $(filter-out $(foreach p,$(overridden_packages),$(p) %/$(p).apk), \
        $(ALL_PDK_FUSION_FILES))

INTERNAL_SYSTEMIMAGE_FILES := $(filter $(TARGET_OUT)/%, \
    $(ALL_PREBUILT) \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(PDK_FUSION_SYSIMG_FILES) \
    $(RECOVERY_RESOURCE_ZIP))


FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)
# -----------------------------------------------------------------
# installed file list
# Depending on anything that $(BUILT_SYSTEMIMAGE) depends on.
# We put installed-files.txt ahead of image itself in the dependency graph
# so that we can get the size stat even if the build fails due to too large
# system image.
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
$(INSTALLED_FILES_FILE): $(FULL_SYSTEMIMAGE_DEPS)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) build/tools/fileslist.py $(TARGET_OUT) > $(@:.txt=.json)
	$(hide) build/tools/fileslist_util.py -c $(@:.txt=.json) > $@

.PHONY: installed-file-list
installed-file-list: $(INSTALLED_FILES_FILE)

$(call dist-for-goals, sdk win_sdk sdk_addon, $(INSTALLED_FILES_FILE))

systemimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE := $(systemimage_intermediates)/system.img

# Create symlink /system/vendor to /vendor if necessary.
ifdef BOARD_USES_VENDORIMAGE
define create-system-vendor-symlink
$(hide) if [ -d $(TARGET_OUT)/vendor ] && [ ! -h $(TARGET_OUT)/vendor ]; then \
  echo 'Non-symlink $(TARGET_OUT)/vendor detected!' 1>&2; \
  echo 'You cannot install files to $(TARGET_OUT)/vendor while building a separate vendor.img!' 1>&2; \
  exit 1; \
fi
$(hide) ln -sf /vendor $(TARGET_OUT)/vendor
endef
else
define create-system-vendor-symlink
endef
endif

# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  $(call create-system-vendor-symlink)
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-userimage-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt, \
      skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1) $(TARGET_OUT) \
      || ( echo "Out of space? the tree size of $(TARGET_OUT) is (MB): " 1>&2 ;\
           du -sm $(TARGET_OUT) 1>&2;\
           if [ "$(INTERNAL_USERIMAGES_EXT_VARIANT)" == "ext4" ]; then \
               maxsize=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE); \
               if [ "$(BOARD_HAS_EXT4_RESERVED_BLOCKS)" == "true" ]; then \
                   maxsize=$$((maxsize - 4096 * 4096)); \
               fi; \
               echo "The max is $$(( maxsize / 1048576 )) MB." 1>&2 ;\
           else \
               echo "The max is $$(( $(BOARD_SYSTEMIMAGE_PARTITION_SIZE) / 1048576 )) MB." 1>&2 ;\
           fi; \
           mkdir -p $(DIST_DIR); cp $(INSTALLED_FILES_FILE) $(DIST_DIR)/installed-files-rescued.txt; \
           exit 1 )
endef

$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE)
	$(call build-systemimage-target,$@)

INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img
SYSTEMIMAGE_SOURCE_DIR := $(TARGET_OUT)

# The system partition needs room for the recovery image as well.  We
# now store the recovery image as a binary patch using the boot image
# as the source (since they are very similar).  Generate the patch so
# we can see how big it's going to be, and include that in the system
# image size check calculation.
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
ifneq ($(BOARD_USES_FULL_RECOVERY_IMAGE),true)
intermediates := $(call intermediates-dir-for,PACKAGING,recovery_patch)
RECOVERY_FROM_BOOT_PATCH := $(intermediates)/recovery_from_boot.p
$(RECOVERY_FROM_BOOT_PATCH): $(INSTALLED_RECOVERYIMAGE_TARGET) \
                             $(INSTALLED_BOOTIMAGE_TARGET) \
			     $(HOST_OUT_EXECUTABLES)/imgdiff \
	                     $(HOST_OUT_EXECUTABLES)/bsdiff
	@echo "Construct recovery from boot"
	mkdir -p $(dir $@)
	PATH=$(HOST_OUT_EXECUTABLES):$$PATH $(HOST_OUT_EXECUTABLES)/imgdiff $(INSTALLED_BOOTIMAGE_TARGET) $(INSTALLED_RECOVERYIMAGE_TARGET) $@
else # $(BOARD_USES_FULL_RECOVERY_IMAGE) == true
RECOVERY_FROM_BOOT_PATCH := $(INSTALLED_RECOVERYIMAGE_TARGET)
endif
endif


$(INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE) $(RECOVERY_FROM_BOOT_PATCH) | $(ACP)
	@echo "Install system fs image: $@"
	$(copy-file-to-target)
	$(hide) $(call assert-max-image-size,$@ $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))

systemimage: $(INSTALLED_SYSTEMIMAGE)

.PHONY: systemimage-nodeps snod
systemimage-nodeps snod: $(filter-out systemimage-nodeps snod,$(MAKECMDGOALS)) \
	            | $(INTERNAL_USERIMAGES_DEPS)
	@echo "make $@: ignoring dependencies"
	$(call build-systemimage-target,$(INSTALLED_SYSTEMIMAGE))
	$(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMIMAGE),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))

ifneq (,$(filter systemimage-nodeps snod, $(MAKECMDGOALS)))
ifeq (true,$(WITH_DEXPREOPT))
$(warning Warning: with dexpreopt enabled, you may need a full rebuild.)
endif
endif

#######
## system tarball
define build-systemtarball-target
  $(call pretty,"Target system fs tarball: $(INSTALLED_SYSTEMTARBALL_TARGET)")
  $(call create-system-vendor-symlink)
  $(MKTARBALL) $(FS_GET_STATS) \
    $(PRODUCT_OUT) system $(PRIVATE_SYSTEM_TAR) \
    $(INSTALLED_SYSTEMTARBALL_TARGET) $(TARGET_OUT)
endef

ifndef SYSTEM_TARBALL_FORMAT
    SYSTEM_TARBALL_FORMAT := bz2
endif

system_tar := $(PRODUCT_OUT)/system.tar
INSTALLED_SYSTEMTARBALL_TARGET := $(system_tar).$(SYSTEM_TARBALL_FORMAT)
$(INSTALLED_SYSTEMTARBALL_TARGET): PRIVATE_SYSTEM_TAR := $(system_tar)
$(INSTALLED_SYSTEMTARBALL_TARGET): $(FS_GET_STATS) $(INTERNAL_SYSTEMIMAGE_FILES)
	$(build-systemtarball-target)

.PHONY: systemtarball-nodeps
systemtarball-nodeps: $(FS_GET_STATS) \
                      $(filter-out systemtarball-nodeps stnod,$(MAKECMDGOALS))
	$(build-systemtarball-target)

.PHONY: stnod
stnod: systemtarball-nodeps

# -----------------------------------------------------------------
## platform.zip: system, plus other files to be used in PDK fusion build,
## in a zip file
##
## PDK_PLATFORM_ZIP_PRODUCT_BINARIES is used to store specified files to platform.zip.
## The variable will be typically set from BoardConfig.mk.
## Files under out dir will be rejected to prevent possible conflicts with other rules.
pdk_odex_javalibs := $(strip $(foreach m,$(DEXPREOPT.MODULES.JAVA_LIBRARIES),\
  $(if $(filter $(DEXPREOPT.$(m).INSTALLED),$(ALL_DEFAULT_INSTALLED_MODULES)),$(m))))
pdk_odex_apps := $(strip $(foreach m,$(DEXPREOPT.MODULES.APPS),\
  $(if $(filter $(DEXPREOPT.$(m).INSTALLED),$(ALL_DEFAULT_INSTALLED_MODULES)),$(m))))
pdk_classes_dex := $(strip \
  $(foreach m,$(pdk_odex_javalibs),$(call intermediates-dir-for,JAVA_LIBRARIES,$(m),,COMMON)/javalib.jar) \
  $(foreach m,$(pdk_odex_apps),$(call intermediates-dir-for,APPS,$(m))/package.dex.apk))

pdk_odex_config_mk := $(PRODUCT_OUT)/pdk_dexpreopt_config.mk
$(pdk_odex_config_mk): PRIVATE_JAVA_LIBRARIES := $(pdk_odex_javalibs)
$(pdk_odex_config_mk): PRIVATE_APPS := $(pdk_odex_apps)
$(pdk_odex_config_mk) :
	@echo "PDK odex config makefile: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) echo "# Auto-generated. Do not modify." > $@
	$(hide) echo "PDK.DEXPREOPT.JAVA_LIBRARIES:=$(PRIVATE_JAVA_LIBRARIES)" >> $@
	$(hide) echo "PDK.DEXPREOPT.APPS:=$(PRIVATE_APPS)" >> $@
	$(foreach m,$(PRIVATE_JAVA_LIBRARIES),\
	  $(hide) echo "PDK.DEXPREOPT.$(m).SRC:=$(patsubst $(OUT_DIR)/%,%,$(call intermediates-dir-for,JAVA_LIBRARIES,$(m),,COMMON)/javalib.jar)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).DEX_PREOPT:=$(DEXPREOPT.$(m).DEX_PREOPT)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).MULTILIB:=$(DEXPREOPT.$(m).MULTILIB)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).DEX_PREOPT_FLAGS:=$(DEXPREOPT.$(m).DEX_PREOPT_FLAGS)" >> $@$(newline)\
	  )
	$(foreach m,$(PRIVATE_APPS),\
	  $(hide) echo "PDK.DEXPREOPT.$(m).SRC:=$(patsubst $(OUT_DIR)/%,%,$(call intermediates-dir-for,APPS,$(m))/package.dex.apk)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).DEX_PREOPT:=$(DEXPREOPT.$(m).DEX_PREOPT)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).MULTILIB:=$(DEXPREOPT.$(m).MULTILIB)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).DEX_PREOPT_FLAGS:=$(DEXPREOPT.$(m).DEX_PREOPT_FLAGS)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).PRIVILEGED_MODULE:=$(DEXPREOPT.$(m).PRIVILEGED_MODULE)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).PROPRIETARY_MODULE:=$(DEXPREOPT.$(m).PROPRIETARY_MODULE)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).TARGET_ARCH:=$(DEXPREOPT.$(m).TARGET_ARCH)" >> $@$(newline)\
	  $(hide) echo "PDK.DEXPREOPT.$(m).STRIPPED_SRC:=$(patsubst $(PRODUCT_OUT)/%,%,$(DEXPREOPT.$(m).INSTALLED_STRIPPED))" >> $@$(newline)\
	  )

PDK_PLATFORM_ZIP_PRODUCT_BINARIES := $(filter-out $(OUT_DIR)/%,$(PDK_PLATFORM_ZIP_PRODUCT_BINARIES))
INSTALLED_PLATFORM_ZIP := $(PRODUCT_OUT)/platform.zip

$(INSTALLED_PLATFORM_ZIP): PRIVATE_DEX_FILES := $(pdk_classes_dex)
$(INSTALLED_PLATFORM_ZIP): PRIVATE_ODEX_CONFIG := $(pdk_odex_config_mk)
$(INSTALLED_PLATFORM_ZIP) : $(INTERNAL_SYSTEMIMAGE_FILES) $(pdk_odex_config_mk)
	$(call pretty,"Platform zip package: $(INSTALLED_PLATFORM_ZIP)")
	$(hide) rm -f $@
	$(hide) cd $(dir $@) && zip -qryX $(notdir $@) \
		$(TARGET_COPY_OUT_SYSTEM) \
		$(patsubst $(PRODUCT_OUT)/%, %, $(TARGET_OUT_NOTICE_FILES)) \
		$(addprefix symbols/,$(PDK_SYMBOL_FILES_LIST))
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
	$(hide) cd $(dir $@) && zip -qryX $(notdir $@) \
		$(TARGET_COPY_OUT_VENDOR)
endif
ifneq ($(PDK_PLATFORM_JAVA_ZIP_CONTENTS),)
	$(hide) cd $(OUT_DIR) && zip -qryX $(patsubst $(OUT_DIR)/%,%,$@) $(PDK_PLATFORM_JAVA_ZIP_CONTENTS)
endif
ifneq ($(PDK_PLATFORM_ZIP_PRODUCT_BINARIES),)
	$(hide) zip -qryX $@ $(PDK_PLATFORM_ZIP_PRODUCT_BINARIES)
endif
	@# Add dex-preopt files and config.
	$(if $(PRIVATE_DEX_FILES),$(hide) cd $(OUT_DIR) && zip -qryX $(patsubst $(OUT_DIR)/%,%,$@ $(PRIVATE_DEX_FILES)))
	$(hide) zip -qryXj $@ $(PRIVATE_ODEX_CONFIG)

.PHONY: platform
platform: $(INSTALLED_PLATFORM_ZIP)

.PHONY: platform-java
platform-java: platform

# Dist the platform.zip
ifneq (,$(filter platform platform-java, $(MAKECMDGOALS)))
$(call dist-for-goals, platform platform-java, $(INSTALLED_PLATFORM_ZIP))
endif

# -----------------------------------------------------------------
## boot tarball
define build-boottarball-target
    $(hide) echo "Target boot fs tarball: $(INSTALLED_BOOTTARBALL_TARGET)"
    $(hide) mkdir -p $(PRODUCT_OUT)/boot
    $(hide) cp -f $(INTERNAL_BOOTIMAGE_FILES) $(PRODUCT_OUT)/boot/.
    $(hide) echo $(BOARD_KERNEL_CMDLINE) > $(PRODUCT_OUT)/boot/cmdline
    $(hide) $(MKTARBALL) $(FS_GET_STATS) \
                 $(PRODUCT_OUT) boot $(PRIVATE_BOOT_TAR) \
                 $(INSTALLED_BOOTTARBALL_TARGET) $(TARGET_OUT)
endef

ifndef BOOT_TARBALL_FORMAT
    BOOT_TARBALL_FORMAT := bz2
endif

boot_tar := $(PRODUCT_OUT)/boot.tar
INSTALLED_BOOTTARBALL_TARGET := $(boot_tar).$(BOOT_TARBALL_FORMAT)
$(INSTALLED_BOOTTARBALL_TARGET): PRIVATE_BOOT_TAR := $(boot_tar)
$(INSTALLED_BOOTTARBALL_TARGET): $(FS_GET_STATS) $(INTERNAL_BOOTIMAGE_FILES)
	$(build-boottarball-target)

.PHONY: boottarball-nodeps btnod
boottarball-nodeps btnod: $(FS_GET_STATS) \
                      $(filter-out boottarball-nodeps btnod,$(MAKECMDGOALS))
	$(build-boottarball-target)


# -----------------------------------------------------------------
# data partition image
INTERNAL_USERDATAIMAGE_FILES := \
    $(filter $(TARGET_OUT_DATA)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

# Don't build userdata.img if it's extfs but no partition size
skip_userdata.img :=
ifdef INTERNAL_USERIMAGES_EXT_VARIANT
ifndef BOARD_USERDATAIMAGE_PARTITION_SIZE
skip_userdata.img := true
endif
endif

ifneq ($(skip_userdata.img),true)
userdataimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,userdata)
BUILT_USERDATAIMAGE_TARGET := $(PRODUCT_OUT)/userdata.img

define build-userdataimage-target
  $(call pretty,"Target userdata fs image: $(INSTALLED_USERDATAIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_DATA)
  @mkdir -p $(userdataimage_intermediates) && rm -rf $(userdataimage_intermediates)/userdata_image_info.txt
  $(call generate-userimage-prop-dictionary, $(userdataimage_intermediates)/userdata_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_DATA) $(userdataimage_intermediates)/userdata_image_info.txt $(INSTALLED_USERDATAIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
$(INSTALLED_USERDATAIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) \
                                   $(INTERNAL_USERDATAIMAGE_FILES)
	$(build-userdataimage-target)

.PHONY: userdataimage-nodeps
userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-userdataimage-target)

endif # not skip_userdata.img
skip_userdata.img :=

#######
## data partition tarball
define build-userdatatarball-target
    $(call pretty,"Target userdata fs tarball: " \
                  "$(INSTALLED_USERDATATARBALL_TARGET)")
    $(MKTARBALL) $(FS_GET_STATS) \
		$(PRODUCT_OUT) data $(PRIVATE_USERDATA_TAR) \
		$(INSTALLED_USERDATATARBALL_TARGET) $(TARGET_OUT)
endef

userdata_tar := $(PRODUCT_OUT)/userdata.tar
INSTALLED_USERDATATARBALL_TARGET := $(userdata_tar).bz2
$(INSTALLED_USERDATATARBALL_TARGET): PRIVATE_USERDATA_TAR := $(userdata_tar)
$(INSTALLED_USERDATATARBALL_TARGET): $(FS_GET_STATS) $(INTERNAL_USERDATAIMAGE_FILES)
	$(build-userdatatarball-target)

$(call dist-for-goals,userdatatarball,$(INSTALLED_USERDATATARBALL_TARGET))

.PHONY: userdatatarball-nodeps
userdatatarball-nodeps: $(FS_GET_STATS)
	$(build-userdatatarball-target)


# -----------------------------------------------------------------
# cache partition image
ifdef BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
INTERNAL_CACHEIMAGE_FILES := \
    $(filter $(TARGET_OUT_CACHE)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

cacheimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,cache)
BUILT_CACHEIMAGE_TARGET := $(PRODUCT_OUT)/cache.img

define build-cacheimage-target
  $(call pretty,"Target cache fs image: $(INSTALLED_CACHEIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_CACHE)
  @mkdir -p $(cacheimage_intermediates) && rm -rf $(cacheimage_intermediates)/cache_image_info.txt
  $(call generate-userimage-prop-dictionary, $(cacheimage_intermediates)/cache_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_CACHE) $(cacheimage_intermediates)/cache_image_info.txt $(INSTALLED_CACHEIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_CACHEIMAGE_TARGET),$(BOARD_CACHEIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_CACHEIMAGE_TARGET := $(BUILT_CACHEIMAGE_TARGET)
$(INSTALLED_CACHEIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES)
	$(build-cacheimage-target)

.PHONY: cacheimage-nodeps
cacheimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-cacheimage-target)

else # BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
# we need to ignore the broken cache link when doing the rsync
IGNORE_CACHE_LINK := --exclude=cache
endif # BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE


# -----------------------------------------------------------------
# system_other partition image
ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
BOARD_USES_SYSTEM_OTHER := true

# Marker file to identify that odex files are installed
INSTALLED_SYSTEM_OTHER_ODEX_MARKER := $(TARGET_OUT_SYSTEM_OTHER)/system-other-odex-marker
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_SYSTEM_OTHER_ODEX_MARKER)
$(INSTALLED_SYSTEM_OTHER_ODEX_MARKER):
	$(hide) touch $@
endif

ifdef BOARD_USES_SYSTEM_OTHER
INTERNAL_SYSTEMOTHERIMAGE_FILES := \
    $(filter $(TARGET_OUT_SYSTEM_OTHER)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES)\
      $(ALL_PDK_FUSION_FILES))

INSTALLED_FILES_FILE_SYSTEMOTHER := $(PRODUCT_OUT)/installed-files-system-other.txt
$(INSTALLED_FILES_FILE_SYSTEMOTHER) : $(INTERNAL_SYSTEMOTHERIMAGE_FILES)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) build/tools/fileslist.py $(TARGET_OUT_SYSTEM_OTHER) > $@

systemotherimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,system_other)
BUILT_SYSTEMOTHERIMAGE_TARGET := $(PRODUCT_OUT)/system_other.img

# Note that we assert the size is SYSTEMIMAGE_PARTITION_SIZE since this is the 'b' system image.
define build-systemotherimage-target
  $(call pretty,"Target system_other fs image: $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_SYSTEM_OTHER)
  @mkdir -p $(systemotherimage_intermediates) && rm -rf $(systemotherimage_intermediates)/system_other_image_info.txt
  $(call generate-userimage-prop-dictionary, $(systemotherimage_intermediates)/system_other_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_SYSTEM_OTHER) $(systemotherimage_intermediates)/system_other_image_info.txt $(INSTALLED_SYSTEMOTHERIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_SYSTEMOTHERIMAGE_TARGET := $(BUILT_SYSTEMOTHERIMAGE_TARGET)
$(INSTALLED_SYSTEMOTHERIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEMOTHER)
	$(build-systemotherimage-target)

.PHONY: systemotherimage-nodeps
systemotherimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-systemotherimage-target)

endif # BOARD_USES_SYSTEM_OTHER


# -----------------------------------------------------------------
# vendor partition image
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
INTERNAL_VENDORIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES)\
      $(ALL_PDK_FUSION_FILES))

# platform.zip depends on $(INTERNAL_VENDORIMAGE_FILES).
$(INSTALLED_PLATFORM_ZIP) : $(INTERNAL_VENDORIMAGE_FILES)

INSTALLED_FILES_FILE_VENDOR := $(PRODUCT_OUT)/installed-files-vendor.txt
$(INSTALLED_FILES_FILE_VENDOR) : $(INTERNAL_VENDORIMAGE_FILES)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) build/tools/fileslist.py $(TARGET_OUT_VENDOR) > $(@:.txt=.json)
	$(hide) build/tools/fileslist_util.py -c $(@:.txt=.json) > $@

vendorimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor)
BUILT_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img

define build-vendorimage-target
  $(call pretty,"Target vendor fs image: $(INSTALLED_VENDORIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR)
  @mkdir -p $(vendorimage_intermediates) && rm -rf $(vendorimage_intermediates)/vendor_image_info.txt
  $(call generate-userimage-prop-dictionary, $(vendorimage_intermediates)/vendor_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_VENDOR) $(vendorimage_intermediates)/vendor_image_info.txt $(INSTALLED_VENDORIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_VENDORIMAGE_TARGET),$(BOARD_VENDORIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_VENDORIMAGE_TARGET := $(BUILT_VENDORIMAGE_TARGET)
$(INSTALLED_VENDORIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDORIMAGE_FILES) $(INSTALLED_FILES_FILE_VENDOR)
	$(build-vendorimage-target)

.PHONY: vendorimage-nodeps
vendorimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-vendorimage-target)

else ifdef BOARD_PREBUILT_VENDORIMAGE
INSTALLED_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDORIMAGE),$(INSTALLED_VENDORIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# bring in the installer image generation defines if necessary
ifeq ($(TARGET_USE_DISKINSTALLER),true)
include bootable/diskinstaller/config.mk
endif

# -----------------------------------------------------------------
# host tools needed to build dist and OTA packages

build_ota_package := true
ifeq ($(TARGET_SKIP_OTA_PACKAGE),true)
build_ota_package := false
endif
ifeq ($(BUILD_OS),darwin)
build_ota_package := false
endif
ifneq ($(strip $(SANITIZE_TARGET)),)
build_ota_package := false
endif
ifeq ($(TARGET_PRODUCT),sdk)
build_ota_package := false
endif
ifneq ($(filter generic%,$(TARGET_DEVICE)),)
build_ota_package := false
endif
ifeq ($(TARGET_NO_KERNEL),true)
build_ota_package := false
endif
ifeq ($(recovery_fstab),)
build_ota_package := false
endif
ifeq ($(TARGET_BUILD_PDK),true)
build_ota_package := false
endif

ifeq ($(build_ota_package),true)
OTATOOLS :=  $(HOST_OUT_EXECUTABLES)/minigzip \
  $(HOST_OUT_EXECUTABLES)/aapt \
  $(HOST_OUT_EXECUTABLES)/mkbootfs \
  $(HOST_OUT_EXECUTABLES)/mkbootimg \
  $(HOST_OUT_EXECUTABLES)/fs_config \
  $(HOST_OUT_EXECUTABLES)/zipalign \
  $(HOST_OUT_EXECUTABLES)/bsdiff \
  $(HOST_OUT_EXECUTABLES)/imgdiff \
  $(HOST_OUT_JAVA_LIBRARIES)/dumpkey.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/signapk.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/BootSignature.jar \
  $(HOST_OUT_EXECUTABLES)/mkuserimg.sh \
  $(HOST_OUT_EXECUTABLES)/make_ext4fs \
  $(HOST_OUT_EXECUTABLES)/mksquashfsimage.sh \
  $(HOST_OUT_EXECUTABLES)/mksquashfs \
  $(HOST_OUT_EXECUTABLES)/mkf2fsuserimg.sh \
  $(HOST_OUT_EXECUTABLES)/make_f2fs \
  $(HOST_OUT_EXECUTABLES)/simg2img \
  $(HOST_OUT_EXECUTABLES)/e2fsck \
  $(HOST_OUT_EXECUTABLES)/build_verity_tree \
  $(HOST_OUT_EXECUTABLES)/verity_signer \
  $(HOST_OUT_EXECUTABLES)/verity_verifier \
  $(HOST_OUT_EXECUTABLES)/append2simg \
  $(HOST_OUT_EXECUTABLES)/img2simg \
  $(HOST_OUT_EXECUTABLES)/boot_signer \
  $(HOST_OUT_EXECUTABLES)/fec \
  $(HOST_OUT_EXECUTABLES)/brillo_update_payload \
  $(HOST_OUT_EXECUTABLES)/lib/shflags/shflags \
  $(HOST_OUT_EXECUTABLES)/delta_generator \
  $(BLK_ALLOC_TO_BASE_FS)

# Shared libraries.
OTATOOLS += \
  $(HOST_LIBRARY_PATH)/libc++$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/liblog$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcutils$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libselinux$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcrypto-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libdivsufsort$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libdivsufsort64$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2fs-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_blkid-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_com_err-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_e2p-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_profile-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_quota-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_uuid-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libconscrypt_openjdk_jni$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrillo$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrillo-stream$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrillo-http$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libchrome$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcurl-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libevent-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libprotobuf-cpp-lite$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libssl-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libz-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbase$(HOST_SHLIB_SUFFIX)

.PHONY: otatools
otatools: $(OTATOOLS)

BUILT_OTATOOLS_PACKAGE := $(PRODUCT_OUT)/otatools.zip
$(BUILT_OTATOOLS_PACKAGE): zip_root := $(call intermediates-dir-for,PACKAGING,otatools)/otatools

$(BUILT_OTATOOLS_PACKAGE): $(OTATOOLS) | $(ACP)
	@echo "Package OTA tools: $@"
	$(hide) rm -rf $@ $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)/bin $(zip_root)/framework $(zip_root)/releasetools $(zip_root)/system/extras/verity
	$(call copy-files-with-structure,$(OTATOOLS),$(HOST_OUT)/,$(zip_root))
	$(hide) $(ACP) $(HOST_OUT_JAVA_LIBRARIES)/VeritySigner.jar $(zip_root)/framework/
	$(hide) $(ACP) -p system/extras/verity/build_verity_metadata.py $(zip_root)/system/extras/verity/
	$(hide) $(ACP) -r -d -p build/tools/releasetools/* $(zip_root)/releasetools
	$(hide) rm -rf $@ $(zip_root)/releasetools/*.pyc
	$(hide) (cd $(zip_root) && zip -qryX $(abspath $@) *)
	$(hide) zip -qryX $(abspath $@) build/target/product/security/
	$(hide) find device vendor -name \*.pk8 -o -name verifiedboot\* -o -name \*.x509.pem -o -name oem\*.prop | xargs zip -qryX $(abspath $@)>/dev/null || true

.PHONY: otatools-package
otatools-package: $(BUILT_OTATOOLS_PACKAGE)

endif # build_ota_package

# -----------------------------------------------------------------
# A zip of the directories that map to the target filesystem.
# This zip can be used to create an OTA package or filesystem image
# as a post-build step.
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-target_files-$(FILE_NAME_TAG)

intermediates := $(call intermediates-dir-for,PACKAGING,target_files)
BUILT_TARGET_FILES_PACKAGE := $(intermediates)/$(name).zip
$(BUILT_TARGET_FILES_PACKAGE): intermediates := $(intermediates)
$(BUILT_TARGET_FILES_PACKAGE): \
		zip_root := $(intermediates)/$(name)

# $(1): Directory to copy
# $(2): Location to copy it to
# The "ls -A" is to prevent "acp s/* d" from failing if s is empty.
define package_files-copy-root
  if [ -d "$(strip $(1))" -a "$$(ls -A $(1))" ]; then \
    mkdir -p $(2) && \
    $(ACP) -rd $(strip $(1))/* $(2); \
  fi
endef

built_ota_tools :=

# We can't build static executables when SANITIZE_TARGET=address
ifeq ($(strip $(SANITIZE_TARGET)),)
built_ota_tools += \
    $(call intermediates-dir-for,EXECUTABLES,updater,,,$(TARGET_PREFER_32_BIT))/updater
endif

$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_OTA_TOOLS := $(built_ota_tools)

$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_API_VERSION := $(RECOVERY_API_VERSION)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_FSTAB_VERSION := $(RECOVERY_FSTAB_VERSION)

ifeq ($(TARGET_RELEASETOOLS_EXTENSIONS),)
# default to common dir for device vendor
$(BUILT_TARGET_FILES_PACKAGE): tool_extensions := $(TARGET_DEVICE_DIR)/../common
else
$(BUILT_TARGET_FILES_PACKAGE): tool_extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif

# Build OTA tools if not using the AB Updater.
ifneq ($(AB_OTA_UPDATER),true)
$(BUILT_TARGET_FILES_PACKAGE): $(built_ota_tools)
endif

# If we are using recovery as boot, output recovery files to BOOT/.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := BOOT
else
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := RECOVERY
endif

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_PACKAGE): \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_RADIOIMAGE_TARGET) \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_CACHEIMAGE_TARGET) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_SYSTEMOTHERIMAGE_TARGET) \
		$(INSTALLED_ANDROID_INFO_TXT_TARGET) \
		$(SELINUX_FC) \
		$(APKCERTS_FILE) \
		$(HOST_OUT_EXECUTABLES)/fs_config \
		| $(ACP)
	@echo "Package target files: $@"
	$(hide) rm -rf $@ $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/$(PRIVATE_RECOVERY_OUT)
	$(hide) $(call package_files-copy-root, \
		$(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/$(PRIVATE_RECOVERY_OUT)/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) $(ACP) $(INSTALLED_KERNEL_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) $(ACP) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/second
endif
ifdef BOARD_KERNEL_CMDLINE
	$(hide) echo "$(BOARD_KERNEL_CMDLINE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/cmdline
endif
ifdef BOARD_KERNEL_BASE
	$(hide) echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	$(hide) echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/pagesize
endif
endif # INSTALLED_RECOVERYIMAGE_TARGET defined or BOARD_USES_RECOVERY_AS_BOOT is true
	@# Components of the boot image
	$(hide) mkdir -p $(zip_root)/BOOT
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	$(hide) mkdir -p $(zip_root)/ROOT
	$(hide) $(call package_files-copy-root, \
		$(TARGET_ROOT_OUT),$(zip_root)/ROOT)
else
	$(hide) $(call package_files-copy-root, \
		$(TARGET_ROOT_OUT),$(zip_root)/BOOT/RAMDISK)
endif
	@# If we are using recovery as boot, this is already done when processing recovery.
ifneq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) $(ACP) $(INSTALLED_KERNEL_TARGET) $(zip_root)/BOOT/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) $(ACP) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/BOOT/second
endif
ifdef BOARD_KERNEL_CMDLINE
	$(hide) echo "$(BOARD_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
endif
ifdef BOARD_KERNEL_BASE
	$(hide) echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/BOOT/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	$(hide) echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/BOOT/pagesize
endif
endif # BOARD_USES_RECOVERY_AS_BOOT
	$(hide) $(foreach t,$(INSTALLED_RADIOIMAGE_TARGET),\
	            mkdir -p $(zip_root)/RADIO; \
	            $(ACP) $(t) $(zip_root)/RADIO/$(notdir $(t));)
	@# Contents of the system image
	$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR),$(zip_root)/SYSTEM)
	@# Contents of the data image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_DATA),$(zip_root)/DATA)
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
	@# Contents of the vendor image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_VENDOR),$(zip_root)/VENDOR)
endif
ifdef INSTALLED_SYSTEMOTHERIMAGE_TARGET
	@# Contents of the system_other image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_SYSTEM_OTHER),$(zip_root)/SYSTEM_OTHER)
endif
	@# Extra contents of the OTA package
	$(hide) mkdir -p $(zip_root)/OTA
	$(hide) $(ACP) $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(zip_root)/OTA/
ifneq ($(AB_OTA_UPDATER),true)
ifneq ($(built_ota_tools),)
	$(hide) mkdir -p $(zip_root)/OTA/bin
	$(hide) $(ACP) $(PRIVATE_OTA_TOOLS) $(zip_root)/OTA/bin/
endif
endif
	@# Files that do not end up in any images, but are necessary to
	@# build them.
	$(hide) mkdir -p $(zip_root)/META
	$(hide) $(ACP) $(APKCERTS_FILE) $(zip_root)/META/apkcerts.txt
	$(hide) if test -e $(tool_extensions)/releasetools.py; then $(ACP) $(tool_extensions)/releasetools.py $(zip_root)/META/; fi
	$(hide) echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) $(ACP) $(SELINUX_FC) $(zip_root)/META/file_contexts.bin
	$(hide) echo "recovery_api_version=$(PRIVATE_RECOVERY_API_VERSION)" > $(zip_root)/META/misc_info.txt
	$(hide) echo "fstab_version=$(PRIVATE_RECOVERY_FSTAB_VERSION)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_FLASH_BLOCK_SIZE
	$(hide) echo "blocksize=$(BOARD_FLASH_BLOCK_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
	$(hide) echo "boot_size=$(BOARD_BOOTIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),)
	$(hide) echo "recovery_as_boot=$(BOARD_USES_RECOVERY_AS_BOOT)" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) echo "no_recovery=true" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
	$(hide) echo "recovery_size=$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_HAS_EXT4_RESERVED_BLOCKS
	$(hide) echo "has_ext4_reserved_blocks=$(BOARD_HAS_EXT4_RESERVED_BLOCKS)" >> $(zip_root)/META/misc_info.txt
endif
ifdef TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS
	@# TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS can be empty to indicate that nothing but defaults should be used.
	$(hide) echo "recovery_mount_options=$(TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
else
	$(hide) echo "recovery_mount_options=$(DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo "tool_extensions=$(tool_extensions)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "default_system_dev_certificate=$(DEFAULT_SYSTEM_DEV_CERTIFICATE)" >> $(zip_root)/META/misc_info.txt
ifdef PRODUCT_EXTRA_RECOVERY_KEYS
	$(hide) echo "extra_recovery_keys=$(PRODUCT_EXTRA_RECOVERY_KEYS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo 'mkbootimg_args=$(BOARD_MKBOOTIMG_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo 'mkbootimg_version_args=$(INTERNAL_MKBOOTIMG_VERSION_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo "use_set_metadata=1" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "multistage_support=1" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "update_rename_support=1" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "blockimgdiff_versions=1,2,3,4" >> $(zip_root)/META/misc_info.txt
ifneq ($(OEM_THUMBPRINT_PROPERTIES),)
	# OTA scripts are only interested in fingerprint related properties
	$(hide) echo "oem_fingerprint_properties=$(OEM_THUMBPRINT_PROPERTIES)" >> $(zip_root)/META/misc_info.txt
endif
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH),)
	$(hide) $(ACP) $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH))
endif
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH),)
	$(hide) $(ACP) $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH))
endif
ifneq ($(strip $(SANITIZE_TARGET)),)
	# We need to create userdata.img with real data because the instrumented libraries are in userdata.img.
	$(hide) echo "userdata_img_with_data=true" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(BOARD_USES_FULL_RECOVERY_IMAGE),true)
	$(hide) echo "full_recovery_image=true" >> $(zip_root)/META/misc_info.txt
endif
	$(call generate-userimage-prop-dictionary, $(zip_root)/META/misc_info.txt)
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    ./build/tools/releasetools/make_recovery_patch $(zip_root) $(zip_root)
endif
ifeq ($(AB_OTA_UPDATER),true)
	@# When using the A/B updater, include the updater config files in the zip.
	$(hide) $(ACP) $(TOPDIR)system/update_engine/update_engine.conf $(zip_root)/META/update_engine_config.txt
	$(hide) for part in $(AB_OTA_PARTITIONS); do \
	  echo "$${part}" >> $(zip_root)/META/ab_partitions.txt; \
	done
	$(hide) for conf in $(AB_OTA_POSTINSTALL_CONFIG); do \
	  echo "$${conf}" >> $(zip_root)/META/postinstall_config.txt; \
	done
	@# Include the build type in META/misc_info.txt so the server can easily differentiate production builds.
	$(hide) echo "build_type=$(TARGET_BUILD_VARIANT)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "ab_update=true" >> $(zip_root)/META/misc_info.txt
ifdef OSRELEASED_DIRECTORY
	$(hide) $(ACP) $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/product_id $(zip_root)/META/product_id.txt
	$(hide) $(ACP) $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/product_version $(zip_root)/META/product_version.txt
endif
endif
ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
	@# If breakpad symbols have been generated, add them to the zip.
	$(hide) $(ACP) -r $(TARGET_OUT_BREAKPAD) $(zip_root)/BREAKPAD
endif
ifdef BOARD_PREBUILT_VENDORIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_VENDORIMAGE_TARGET) $(zip_root)/IMAGES/
endif
	@# Zip everything up, preserving symlinks and placing META/ files first to
	@# help early validation of the .zip file while uploading it.
	$(hide) (cd $(zip_root) && \
	        zip -qryX ../$(notdir $@) ./META && \
	        zip -qryXu ../$(notdir $@) .)
	@# Run fs_config on all the system, vendor, boot ramdisk,
	@# and recovery ramdisk files in the zip, and save the output
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="SYSTEM/" } /^SYSTEM\// {print "system/" $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/filesystem_config.txt
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="VENDOR/" } /^VENDOR\// {print "vendor/" $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/vendor_filesystem_config.txt
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="ROOT/" } /^ROOT\// {print $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/root_filesystem_config.txt
endif
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="BOOT/RAMDISK/" } /^BOOT\/RAMDISK\// {print $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/boot_filesystem_config.txt
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="RECOVERY/RAMDISK/" } /^RECOVERY\/RAMDISK\// {print $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/recovery_filesystem_config.txt
endif
ifdef INSTALLED_SYSTEMOTHERIMAGE_TARGET
	$(hide) zipinfo -1 $@ | awk 'BEGIN { FS="SYSTEM_OTHER/" } /^SYSTEM_OTHER\// { print "system/" $$2}' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) > $(zip_root)/META/system_other_filesystem_config.txt
endif
	$(hide) (cd $(zip_root) && zip -qX ../$(notdir $@) META/*filesystem_config.txt)
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    ./build/tools/releasetools/add_img_to_target_files -a -v -p $(HOST_OUT) $@

.PHONY: target-files-package
target-files-package: $(BUILT_TARGET_FILES_PACKAGE)

ifneq ($(filter $(MAKECMDGOALS),target-files-package),)
$(call dist-for-goals, target-files-package, $(BUILT_TARGET_FILES_PACKAGE))
endif

ifeq ($(build_ota_package),true)
# -----------------------------------------------------------------
# OTA update package

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-ota-$(FILE_NAME_TAG)

INTERNAL_OTA_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_OTA_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)

$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE)
	@echo "Package OTA: $@"
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   ./build/tools/releasetools/ota_from_target_files -v \
	   --block \
	   -p $(HOST_OUT) \
	   -k $(KEY_CERT_PAIR) \
	   $(if $(OEM_OTA_CONFIG), -o $(OEM_OTA_CONFIG)) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: otapackage
otapackage: $(INTERNAL_OTA_PACKAGE_TARGET)

endif    # build_ota_package

# -----------------------------------------------------------------
# The update package

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-img-$(FILE_NAME_TAG)

INTERNAL_UPDATE_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_UPDATE_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE)
	@echo "Package: $@"
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   ./build/tools/releasetools/img_from_target_files -v \
	   -p $(HOST_OUT) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: updatepackage
updatepackage: $(INTERNAL_UPDATE_PACKAGE_TARGET)

# -----------------------------------------------------------------
# A zip of the symbols directory.  Keep the full paths to make it
# more obvious where these files came from.
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-symbols-$(FILE_NAME_TAG)

SYMBOLS_ZIP := $(PRODUCT_OUT)/$(name).zip
# For apps_only build we'll establish the dependency later in build/core/main.mk.
ifndef TARGET_BUILD_APPS
$(SYMBOLS_ZIP): $(INSTALLED_SYSTEMIMAGE) $(INSTALLED_BOOTIMAGE_TARGET)
endif
$(SYMBOLS_ZIP):
	@echo "Package symbols: $@"
	$(hide) rm -rf $@
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_UNSTRIPPED)
	$(hide) zip -qrX $@ $(TARGET_OUT_UNSTRIPPED)

# -----------------------------------------------------------------
# A zip of the Android Apps. Not keeping full path so that we don't
# include product names when distributing
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-apps-$(FILE_NAME_TAG)

APPS_ZIP := $(PRODUCT_OUT)/$(name).zip
$(APPS_ZIP): $(INSTALLED_SYSTEMIMAGE)
	@echo "Package apps: $@"
	$(hide) rm -rf $@
	$(hide) mkdir -p $(dir $@)
	$(hide) apps_to_zip=`find $(TARGET_OUT_APPS) $(TARGET_OUT_APPS_PRIVILEGED) -mindepth 2 -maxdepth 3 -name "*.apk"`; \
	if [ -z "$$apps_to_zip" ]; then \
		echo "No apps to zip up. Generating empty apps archive." ; \
		a=$$(mktemp /tmp/XXXXXXX) && touch $$a && zip $@ $$a && zip -d $@ $$a; \
	else \
		zip -qjX $@ $$apps_to_zip; \
	fi

#------------------------------------------------------------------
# A zip of emma code coverage meta files. Generated for fully emma
# instrumented build.
#
ifeq (true,$(EMMA_INSTRUMENT))
EMMA_META_ZIP := $(PRODUCT_OUT)/emma_meta.zip
# the dependency will be set up later in build/core/main.mk.
$(EMMA_META_ZIP) :
	@echo "Collecting Emma coverage meta files."
	$(hide) find $(TARGET_COMMON_OUT_ROOT) $(HOST_COMMON_OUT_ROOT) -name "coverage.em" | \
		zip -@ -qX $@

endif # EMMA_INSTRUMENT=true

#------------------------------------------------------------------
# A zip of Proguard obfuscation dictionary files.
# Only for apps_only build.
#
ifdef TARGET_BUILD_APPS
PROGUARD_DICT_ZIP := $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-dict-$(FILE_NAME_TAG).zip
# the dependency will be set up later in build/core/main.mk.
$(PROGUARD_DICT_ZIP) :
	@echo "Packaging Proguard obfuscation dictionary files."
	$(hide) dict_files=`find $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS -name proguard_dictionary -o -name jack_dictionary`; \
		if [ -n "$$dict_files" ]; then \
		  unobfuscated_jars=$${dict_files//proguard_dictionary/classes.jar}; \
		  zip -qX $@ $$dict_files $$unobfuscated_jars; \
		else \
		  touch $(dir $@)/zipdummy; \
		  (cd $(dir $@) && zip -q $(notdir $@) zipdummy); \
		  zip -qd $@ zipdummy; \
		  rm $(dir $@)/zipdummy; \
		fi

endif # TARGET_BUILD_APPS

# -----------------------------------------------------------------
# dalvik something
.PHONY: dalvikfiles
dalvikfiles: $(INTERNAL_DALVIK_MODULES)

# -----------------------------------------------------------------
# The emulator package
ifeq ($(BUILD_EMULATOR),true)
INTERNAL_EMULATOR_PACKAGE_FILES += \
        $(HOST_OUT_EXECUTABLES)/emulator$(HOST_EXECUTABLE_SUFFIX) \
        prebuilts/qemu-kernel/$(TARGET_ARCH)/kernel-qemu \
        $(INSTALLED_RAMDISK_TARGET) \
		$(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_USERDATAIMAGE_TARGET)

name := $(TARGET_PRODUCT)-emulator-$(FILE_NAME_TAG)

INTERNAL_EMULATOR_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_EMULATOR_PACKAGE_TARGET): $(INTERNAL_EMULATOR_PACKAGE_FILES)
	@echo "Package: $@"
	$(hide) zip -qjX $@ $(INTERNAL_EMULATOR_PACKAGE_FILES)

endif
# -----------------------------------------------------------------
# Old PDK stuffs, retired
# The pdk package (Platform Development Kit)

#ifneq (,$(filter pdk,$(MAKECMDGOALS)))
#  include development/pdk/Pdk.mk
#endif


# -----------------------------------------------------------------
# The SDK

# The SDK includes host-specific components, so it belongs under HOST_OUT.
sdk_dir := $(HOST_OUT)/sdk/$(TARGET_PRODUCT)

# Build a name that looks like:
#
#     linux-x86   --> android-sdk_12345_linux-x86
#     darwin-x86  --> android-sdk_12345_mac-x86
#     windows-x86 --> android-sdk_12345_windows
#
sdk_name := android-sdk_$(FILE_NAME_TAG)
ifeq ($(HOST_OS),darwin)
  INTERNAL_SDK_HOST_OS_NAME := mac
else
  INTERNAL_SDK_HOST_OS_NAME := $(HOST_OS)
endif
ifneq ($(HOST_OS),windows)
  INTERNAL_SDK_HOST_OS_NAME := $(INTERNAL_SDK_HOST_OS_NAME)-$(SDK_HOST_ARCH)
endif
sdk_name := $(sdk_name)_$(INTERNAL_SDK_HOST_OS_NAME)

sdk_dep_file := $(sdk_dir)/sdk_deps.mk

ATREE_FILES :=
-include $(sdk_dep_file)

# if we don't have a real list, then use "everything"
ifeq ($(strip $(ATREE_FILES)),)
ATREE_FILES := \
	$(ALL_PREBUILT) \
	$(ALL_DEFAULT_INSTALLED_MODULES) \
	$(INSTALLED_RAMDISK_TARGET) \
	$(ALL_DOCS) \
	$(ALL_SDK_FILES)
endif

atree_dir := development/build


sdk_atree_files := \
	$(atree_dir)/sdk.exclude.atree \
	$(atree_dir)/sdk-$(HOST_OS)-$(SDK_HOST_ARCH).atree

# development/build/sdk-android-<abi>.atree is used to differentiate
# between architecture models (e.g. ARMv5TE versus ARMv7) when copying
# files like the kernel image. We use TARGET_CPU_ABI because we don't
# have a better way to distinguish between CPU models.
ifneq (,$(strip $(wildcard $(atree_dir)/sdk-android-$(TARGET_CPU_ABI).atree)))
  sdk_atree_files += $(atree_dir)/sdk-android-$(TARGET_CPU_ABI).atree
endif

ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ATREE_FILES),)
sdk_atree_files += $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SDK_ATREE_FILES)
else
sdk_atree_files += $(atree_dir)/sdk.atree
endif

include $(BUILD_SYSTEM)/sdk_font.mk

deps := \
	$(target_notice_file_txt) \
	$(tools_notice_file_txt) \
	$(OUT_DOCS)/offline-sdk-timestamp \
	$(SYMBOLS_ZIP) \
	$(INSTALLED_SYSTEMIMAGE) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INSTALLED_RAMDISK_TARGET) \
	$(INSTALLED_SDK_BUILD_PROP_TARGET) \
	$(INSTALLED_BUILD_PROP_TARGET) \
	$(ATREE_FILES) \
	$(sdk_atree_files) \
	$(HOST_OUT_EXECUTABLES)/atree \
	$(HOST_OUT_EXECUTABLES)/line_endings \
	$(SDK_FONT_DEPS)

INTERNAL_SDK_TARGET := $(sdk_dir)/$(sdk_name).zip
$(INTERNAL_SDK_TARGET): PRIVATE_NAME := $(sdk_name)
$(INTERNAL_SDK_TARGET): PRIVATE_DIR := $(sdk_dir)/$(sdk_name)
$(INTERNAL_SDK_TARGET): PRIVATE_DEP_FILE := $(sdk_dep_file)
$(INTERNAL_SDK_TARGET): PRIVATE_INPUT_FILES := $(sdk_atree_files)

# Set SDK_GNU_ERROR to non-empty to fail when a GNU target is built.
#
#SDK_GNU_ERROR := true

$(INTERNAL_SDK_TARGET): $(deps)
	@echo "Package SDK: $@"
	$(hide) rm -rf $(PRIVATE_DIR) $@
	$(hide) for f in $(target_gnu_MODULES); do \
	  if [ -f $$f ]; then \
	    echo SDK: $(if $(SDK_GNU_ERROR),ERROR:,warning:) \
	        including GNU target $$f >&2; \
	    FAIL=$(SDK_GNU_ERROR); \
	  fi; \
	done; \
	if [ $$FAIL ]; then exit 1; fi
	$(hide) echo $(notdir $(SDK_FONT_DEPS)) | tr " " "\n"  > $(SDK_FONT_TEMP)/fontsInSdk.txt
	$(hide) ( \
		ATREE_STRIP="strip -x" \
		$(HOST_OUT_EXECUTABLES)/atree \
		$(addprefix -f ,$(PRIVATE_INPUT_FILES)) \
			-m $(PRIVATE_DEP_FILE) \
			-I . \
			-I $(PRODUCT_OUT) \
			-I $(HOST_OUT) \
			-I $(TARGET_COMMON_OUT_ROOT) \
			-v "PLATFORM_NAME=android-$(PLATFORM_VERSION)" \
			-v "OUT_DIR=$(OUT_DIR)" \
			-v "HOST_OUT=$(HOST_OUT)" \
			-v "TARGET_ARCH=$(TARGET_ARCH)" \
			-v "TARGET_CPU_ABI=$(TARGET_CPU_ABI)" \
			-v "DLL_EXTENSION=$(HOST_SHLIB_SUFFIX)" \
			-v "FONT_OUT=$(SDK_FONT_TEMP)" \
			-v "JACK_SDKTOOL_VERSION=$(JACK_SDKTOOL_VERSION)" \
			-o $(PRIVATE_DIR) && \
		cp -f $(target_notice_file_txt) \
				$(PRIVATE_DIR)/system-images/android-$(PLATFORM_VERSION)/$(TARGET_CPU_ABI)/NOTICE.txt && \
		cp -f $(tools_notice_file_txt) $(PRIVATE_DIR)/platform-tools/NOTICE.txt && \
		HOST_OUT_EXECUTABLES=$(HOST_OUT_EXECUTABLES) HOST_OS=$(HOST_OS) \
			development/build/tools/sdk_clean.sh $(PRIVATE_DIR) && \
		chmod -R ug+rwX $(PRIVATE_DIR) && \
		cd $(dir $@) && zip -rqX $(notdir $@) $(PRIVATE_NAME) \
	) || ( rm -rf $(PRIVATE_DIR) $@ && exit 44 )


# Is a Windows SDK requested? If so, we need some definitions from here
# in order to find the Linux SDK used to create the Windows one.
MAIN_SDK_NAME := $(sdk_name)
MAIN_SDK_DIR  := $(sdk_dir)
MAIN_SDK_ZIP  := $(INTERNAL_SDK_TARGET)
ifneq ($(filter win_sdk winsdk-tools,$(MAKECMDGOALS)),)
include $(TOPDIR)development/build/tools/windows_sdk.mk
endif

# -----------------------------------------------------------------
# Findbugs
INTERNAL_FINDBUGS_XML_TARGET := $(PRODUCT_OUT)/findbugs.xml
INTERNAL_FINDBUGS_HTML_TARGET := $(PRODUCT_OUT)/findbugs.html
$(INTERNAL_FINDBUGS_XML_TARGET): $(ALL_FINDBUGS_FILES)
	@echo UnionBugs: $@
	$(hide) $(FINDBUGS_DIR)/unionBugs $(ALL_FINDBUGS_FILES) \
	> $@
$(INTERNAL_FINDBUGS_HTML_TARGET): $(INTERNAL_FINDBUGS_XML_TARGET)
	@echo ConvertXmlToText: $@
	$(hide) $(FINDBUGS_DIR)/convertXmlToText -html:fancy.xsl \
	$(INTERNAL_FINDBUGS_XML_TARGET) > $@

# -----------------------------------------------------------------
# Findbugs

# -----------------------------------------------------------------
# These are some additional build tasks that need to be run.
ifneq ($(dont_bother),true)
include $(sort $(wildcard $(BUILD_SYSTEM)/tasks/*.mk))
-include $(sort $(wildcard vendor/*/build/tasks/*.mk))
-include $(sort $(wildcard device/*/build/tasks/*.mk))
-include $(sort $(wildcard product/*/build/tasks/*.mk))
# Also the project-specific tasks
-include $(sort $(wildcard vendor/*/*/build/tasks/*.mk))
-include $(sort $(wildcard device/*/*/build/tasks/*.mk))
-include $(sort $(wildcard product/*/*/build/tasks/*.mk))
endif

include $(BUILD_SYSTEM)/product-graph.mk

# -----------------------------------------------------------------
# Create SDK repository packages. Must be done after tasks/* since
# we need the addon rules defined.
ifneq ($(sdk_repo_goal),)
include $(TOPDIR)development/build/tools/sdk_repo.mk
endif
