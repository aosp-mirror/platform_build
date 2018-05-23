# Put some miscellaneous rules here

# HACK: clear LOCAL_PATH from including last build target before calling
# intermedites-dir-for
LOCAL_PATH := $(BUILD_SYSTEM)

# -----------------------------------------------------------------
# Define rules to copy PRODUCT_COPY_FILES defined by the product.
# PRODUCT_COPY_FILES contains words like <source file>:<dest file>[:<owner>].
# <dest file> is relative to $(PRODUCT_OUT), so it should look like,
# e.g., "system/etc/file.xml".
# The filter part means "only eval the copy-one-file rule if this
# src:dest pair is the first one to match the same dest"
#$(1): the src:dest pair
#$(2): the dest
define check-product-copy-files
$(if $(filter-out $(TARGET_COPY_OUT_SYSTEM_OTHER)/%,$(2)), \
  $(if $(filter %.apk, $(2)),$(error \
     Prebuilt apk found in PRODUCT_COPY_FILES: $(1), use BUILD_PREBUILT instead!)))
endef
# filter out the duplicate <source file>:<dest file> pairs.
unique_product_copy_files_pairs :=
$(foreach cf,$(PRODUCT_COPY_FILES), \
    $(if $(filter $(unique_product_copy_files_pairs),$(cf)),,\
        $(eval unique_product_copy_files_pairs += $(cf))))
unique_product_copy_files_destinations :=
product_copy_files_ignored :=
$(foreach cf,$(unique_product_copy_files_pairs), \
    $(eval _src := $(call word-colon,1,$(cf))) \
    $(eval _dest := $(call word-colon,2,$(cf))) \
    $(call check-product-copy-files,$(cf),$(_dest)) \
    $(if $(filter $(unique_product_copy_files_destinations),$(_dest)), \
        $(eval product_copy_files_ignored += $(cf)), \
        $(eval _fulldest := $(call append-path,$(PRODUCT_OUT),$(_dest))) \
        $(if $(filter %.xml,$(_dest)),\
            $(eval $(call copy-xml-file-checked,$(_src),$(_fulldest))),\
            $(if $(and $(filter %.jar,$(_dest)),$(filter $(basename $(notdir $(_dest))),$(PRODUCT_LOADED_BY_PRIVILEGED_MODULES))),\
                $(eval $(call copy-and-uncompress-dexs,$(_src),$(_fulldest))), \
                $(eval $(call copy-one-file,$(_src),$(_fulldest))))) \
        $(eval ALL_DEFAULT_INSTALLED_MODULES += $(_fulldest)) \
        $(eval unique_product_copy_files_destinations += $(_dest))))

# Dump a list of overriden (and ignored PRODUCT_COPY_FILES entries)
$(file >$(PRODUCT_OUT)/product_copy_files_ignored.txt,$(subst $(space),$(newline),$(strip $(product_copy_files_ignored))))
ifdef dist_goal
$(file >$(DIST_DIR)/logs/product_copy_files_ignored.txt,$(subst $(space),$(newline),$(strip $(product_copy_files_ignored))))
endif

product_copy_files_ignored :=
unique_product_copy_files_pairs :=
unique_product_copy_files_destinations :=

# -----------------------------------------------------------------
# Returns the max allowed size for an image suitable for hash verification
# (e.g., boot.img, recovery.img, etc).
# The value 69632 derives from MAX_VBMETA_SIZE + MAX_FOOTER_SIZE in $(AVBTOOL).
# $(1): partition size to flash the image
define get-hash-image-max-size
$(if $(1), \
  $(if $(filter true,$(BOARD_AVB_ENABLE)), \
    $(eval _hash_meta_size := 69632), \
    $(eval _hash_meta_size := 0)) \
  $(1)-$(_hash_meta_size))
endef

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

ndk_doxygen_out := $(OUT_NDK_DOCS)
ndk_headers := $(SOONG_OUT_DIR)/ndk/sysroot/usr/include
ndk_docs_src_dir := frameworks/native/docs
ndk_doxyfile := $(ndk_docs_src_dir)/Doxyfile
ifneq ($(wildcard $(ndk_docs_src_dir)),)
ndk_docs_srcs := $(addprefix $(ndk_docs_src_dir)/,\
    $(call find-files-in-subdirs,$(ndk_docs_src_dir),"*",.))
$(ndk_doxygen_out)/index.html: $(ndk_docs_srcs) $(SOONG_OUT_DIR)/ndk.timestamp
	@mkdir -p $(ndk_doxygen_out)
	@echo "Generating NDK docs to $(ndk_doxygen_out)"
	@( cat $(ndk_doxyfile); \
	    echo "INPUT=$(ndk_headers)"; \
	    echo "HTML_OUTPUT=$(ndk_doxygen_out)" \
	) | doxygen -

# Note: Not a part of the docs target because we don't have doxygen available.
# You can run this target locally if you have doxygen installed.
ndk-docs: $(ndk_doxygen_out)/index.html
.PHONY: ndk-docs
endif

# -----------------------------------------------------------------
# property_overrides_split_enabled
property_overrides_split_enabled :=
ifeq ($(BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED), true)
  property_overrides_split_enabled := true
endif

# -----------------------------------------------------------------
# FINAL_VENDOR_DEFAULT_PROPERTIES will be installed in vendor/default.prop if
# property_overrides_split_enabled is true. Otherwise it will be installed in
# ROOT/default.prop.
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
FINAL_VENDOR_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_VENDOR_DEFAULT_PROPERTIES),=)

# -----------------------------------------------------------------
# prop.default
ifdef property_overrides_split_enabled
INSTALLED_DEFAULT_PROP_TARGET := $(TARGET_OUT)/etc/prop.default
INSTALLED_DEFAULT_PROP_OLD_TARGET := $(TARGET_ROOT_OUT)/default.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DEFAULT_PROP_OLD_TARGET)
$(INSTALLED_DEFAULT_PROP_OLD_TARGET): $(INSTALLED_DEFAULT_PROP_TARGET)
else
# legacy path
INSTALLED_DEFAULT_PROP_TARGET := $(TARGET_ROOT_OUT)/default.prop
endif
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DEFAULT_PROP_TARGET)
FINAL_DEFAULT_PROPERTIES := \
    $(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES)) \
    $(call collapse-pairs, $(PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
ifndef property_overrides_split_enabled
  FINAL_DEFAULT_PROPERTIES += \
      $(call collapse-pairs, $(FINAL_VENDOR_DEFAULT_PROPERTIES))
endif
FINAL_DEFAULT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_DEFAULT_PROPERTIES),=)

intermediate_system_build_prop := $(call intermediates-dir-for,ETC,system_build_prop)/build.prop

$(INSTALLED_DEFAULT_PROP_TARGET): $(intermediate_system_build_prop)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) echo "#" > $@; \
	        echo "# ADDITIONAL_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) echo "#" >> $@; \
	        echo "# BOOTIMAGE_BUILD_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) echo ro.bootimage.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.bootimage.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.bootimage.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
	$(hide) build/make/tools/post_process_props.py $@
ifdef property_overrides_split_enabled
	$(hide) mkdir -p $(TARGET_ROOT_OUT)
	$(hide) ln -sf system/etc/prop.default $(INSTALLED_DEFAULT_PROP_OLD_TARGET)
endif

# -----------------------------------------------------------------
# vendor default.prop
INSTALLED_VENDOR_DEFAULT_PROP_TARGET :=
ifdef property_overrides_split_enabled
INSTALLED_VENDOR_DEFAULT_PROP_TARGET := $(TARGET_OUT_VENDOR)/default.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_VENDOR_DEFAULT_PROP_TARGET)

$(INSTALLED_VENDOR_DEFAULT_PROP_TARGET): $(INSTALLED_DEFAULT_PROP_TARGET)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# ADDITIONAL VENDOR DEFAULT PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_VENDOR_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) build/make/tools/post_process_props.py $@

endif  # property_overrides_split_enabled

# -----------------------------------------------------------------
# build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)
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
  ifeq ($(strip $(HAS_BUILD_NUMBER)),false)
    BF_BUILD_NUMBER := $(USER)$$($(DATE_FROM_FILE) +%m%d%H%M)
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
    $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OEM_PROPERTIES))

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

BUILDINFO_SH := build/make/tools/buildinfo.sh
VENDOR_BUILDINFO_SH := build/make/tools/vendor_buildinfo.sh

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
			PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION="$(PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION)" \
			BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
			BUILD_FINGERPRINT="$(BUILD_FINGERPRINT_FROM_FILE)" \
			$(if $(OEM_THUMBPRINT_PROPERTIES),BUILD_THUMBPRINT="$(BUILD_THUMBPRINT_FROM_FILE)") \
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
	$(if $(FINAL_BUILD_PROPERTIES), \
		$(hide) echo >> $@; \
		        echo "#" >> $@; \
		        echo "# ADDITIONAL_BUILD_PROPERTIES" >> $@; \
		        echo "#" >> $@; )
	$(hide) $(foreach line,$(FINAL_BUILD_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) cat $(INSTALLED_ANDROID_INFO_TXT_TARGET) | grep 'require version-' | sed -e 's/require version-/ro.build.expect./g' >> $@
	$(hide) build/make/tools/post_process_props.py $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_PROPERTY_BLACKLIST)

build_desc :=

ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
else
INSTALLED_RECOVERYIMAGE_TARGET :=
endif

$(INSTALLED_BUILD_PROP_TARGET): $(intermediate_system_build_prop) $(INSTALLED_RECOVERYIMAGE_TARGET)
	@echo "Target build info: $@"
	$(hide) grep -v 'ro.product.first_api_level' $(intermediate_system_build_prop) > $@
ifdef INSTALLED_RECOVERYIMAGE_TARGET
	$(hide) echo ro.expect.recovery_id=`cat $(RECOVERYIMAGE_ID_FILE)` >> $@
endif

# -----------------------------------------------------------------
# vendor build.prop
#
# For verifying that the vendor build is what we think it is
INSTALLED_VENDOR_BUILD_PROP_TARGET := $(TARGET_OUT_VENDOR)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_VENDOR_BUILD_PROP_TARGET)

ifdef property_overrides_split_enabled
FINAL_VENDOR_BUILD_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_PROPERTY_OVERRIDES))
FINAL_VENDOR_BUILD_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_VENDOR_BUILD_PROPERTIES),=)
endif  # property_overrides_split_enabled

$(INSTALLED_VENDOR_BUILD_PROP_TARGET): $(VENDOR_BUILDINFO_SH) $(intermediate_system_build_prop)
	@echo Target vendor buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo > $@
	$(hide) grep 'ro.product.first_api_level' $(intermediate_system_build_prop) >> $@ || true
	$(hide) echo ro.vendor.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.vendor.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.vendor.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
	$(hide) echo ro.vendor.build.security_patch="$(VENDOR_SECURITY_PATCH)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist="$(TARGET_CPU_ABI_LIST)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist32="$(TARGET_CPU_ABI_LIST_32_BIT)">>$@
	$(hide) echo ro.vendor.product.cpu.abilist64="$(TARGET_CPU_ABI_LIST_64_BIT)">>$@
	$(hide) TARGET_DEVICE="$(TARGET_DEVICE)" \
			PRODUCT_NAME="$(TARGET_PRODUCT)" \
			PRODUCT_BRAND="$(PRODUCT_BRAND)" \
			PRODUCT_MODEL="$(PRODUCT_MODEL)" \
			PRODUCT_MANUFACTURER="$(PRODUCT_MANUFACTURER)" \
			TARGET_BOOTLOADER_BOARD_NAME="$(TARGET_BOOTLOADER_BOARD_NAME)" \
			TARGET_BOARD_PLATFORM="$(TARGET_BOARD_PLATFORM)" \
	        bash $(VENDOR_BUILDINFO_SH) >> $@
ifdef property_overrides_split_enabled
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL VENDOR BUILD PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_VENDOR_BUILD_PROPERTIES), \
		echo "$(line)" >> $@;)
endif  # property_overrides_split_enabled
	$(hide) build/make/tools/post_process_props.py $@ $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_PROPERTY_BLACKLIST)

# -----------------------------------------------------------------
# product build.prop
INSTALLED_PRODUCT_BUILD_PROP_TARGET := $(TARGET_OUT_PRODUCT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_PRODUCT_BUILD_PROP_TARGET)

FINAL_PRODUCT_PROPERTIES += \
    $(call collapse-pairs, $(PRODUCT_PRODUCT_PROPERTIES))
FINAL_PRODUCT_PROPERTIES := $(call uniq-pairs-by-first-component, \
    $(FINAL_PRODUCT_PROPERTIES),=)

$(INSTALLED_PRODUCT_BUILD_PROP_TARGET):
	@echo Target product buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo > $@
ifdef BOARD_USES_PRODUCTIMAGE
	$(hide) echo ro.product.build.date=`$(DATE_FROM_FILE)`>>$@
	$(hide) echo ro.product.build.date.utc=`$(DATE_FROM_FILE) +%s`>>$@
	$(hide) echo ro.product.build.fingerprint="$(BUILD_FINGERPRINT_FROM_FILE)">>$@
endif  # BOARD_USES_PRODUCTIMAGE
	$(hide) echo "#" >> $@; \
	        echo "# ADDITIONAL PRODUCT PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(FINAL_PRODUCT_PROPERTIES), \
		echo "$(line)" >> $@;)
	$(hide) build/make/tools/post_process_props.py $@

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
	$(hide) build/make/tools/dump-package-stats $^ > $@
endif

.PHONY: package-stats
package-stats: $(PACKAGE_STATS_FILE)

# -----------------------------------------------------------------
# Cert-to-package mapping.  Used by the post-build signing tools.
# Use a macro to add newline to each echo command
define _apkcerts_write_line
$(hide) echo -n 'name="$(1).apk" certificate="$2" private_key="$3"' >> $5
$(if $(4), $(hide) echo -n ' compressed="$4"' >> $5)
$(hide) echo '' >> $5

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
	    $(call _apkcerts_write_line,$(p),"EXTERNAL","",$(PACKAGES.$(p).COMPRESSED),$@),\
	    $(call _apkcerts_write_line,$(p),$(PACKAGES.$(p).CERTIFICATE),$(PACKAGES.$(p).PRIVATE_KEY),$(PACKAGES.$(p).COMPRESSED),$@)))
	# In case value of PACKAGES is empty.
	$(hide) touch $@

.PHONY: apkcerts-list
apkcerts-list: $(APKCERTS_FILE)

ifneq (,$(TARGET_BUILD_APPS))
  $(call dist-for-goals, apps_only, $(APKCERTS_FILE):apkcerts.txt)
endif

# -----------------------------------------------------------------
# build system stats
BUILD_SYSTEM_STATS := $(PRODUCT_OUT)/build_system_stats.txt
$(BUILD_SYSTEM_STATS):
	@rm -f $@
	@$(foreach s,$(STATS.MODULE_TYPE),echo "modules_type_make,$(s),$(words $(STATS.MODULE_TYPE.$(s)))" >>$@;)
	@$(foreach s,$(STATS.SOONG_MODULE_TYPE),echo "modules_type_soong,$(s),$(STATS.SOONG_MODULE_TYPE.$(s))" >>$@;)
$(call dist-for-goals,droidcore,$(BUILD_SYSTEM_STATS))

# -----------------------------------------------------------------
# Modules ready to be converted to Soong, ordered by how many
# modules depend on them.
SOONG_CONV := $(sort $(SOONG_CONV))
SOONG_CONV_DATA := $(call intermediates-dir-for,PACKAGING,soong_conversion)/soong_conv_data
$(SOONG_CONV_DATA):
	@rm -f $@
	@$(foreach s,$(SOONG_CONV),echo "$(s),$(SOONG_CONV.$(s).TYPE),$(sort $(SOONG_CONV.$(s).PROBLEMS)),$(sort $(filter-out $(SOONG_ALREADY_CONV),$(SOONG_CONV.$(s).DEPS)))" >>$@;)

SOONG_TO_CONVERT_SCRIPT := build/make/tools/soong_to_convert.py
SOONG_TO_CONVERT := $(PRODUCT_OUT)/soong_to_convert.txt
$(SOONG_TO_CONVERT): $(SOONG_CONV_DATA) $(SOONG_TO_CONVERT_SCRIPT)
	@rm -f $@
	$(hide) $(SOONG_TO_CONVERT_SCRIPT) $< >$@
$(call dist-for-goals,droidcore,$(SOONG_TO_CONVERT))

# -----------------------------------------------------------------
# Modules use -Wno-error, or added default -Wall -Werror
WALL_WERROR := $(PRODUCT_OUT)/wall_werror.txt
$(WALL_WERROR):
	@rm -f $@
	echo "# Modules using -Wno-error" >> $@
	for m in $(sort $(SOONG_MODULES_USING_WNO_ERROR) $(MODULES_USING_WNO_ERROR)); do echo $$m >> $@; done
	echo "# Modules added default -Wall" >> $@
	for m in $(sort $(SOONG_MODULES_ADDED_WALL) $(MODULES_ADDED_WALL)); do echo $$m >> $@; done

$(call dist-for-goals,droidcore,$(WALL_WERROR))

# -----------------------------------------------------------------
# Modules missing profile files
PGO_PROFILE_MISSING := $(PRODUCT_OUT)/pgo_profile_file_missing.txt
$(PGO_PROFILE_MISSING):
	@rm -f $@
	echo "# Modules missing PGO profile files" >> $@
	for m in $(SOONG_MODULES_MISSING_PGO_PROFILE_FILE); do echo $$m >> $@; done

$(call dist-for-goals,droidcore,$(PGO_PROFILE_MISSING))

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
$(all_event_log_tags_file): $(all_event_log_tags_src) $(pdk_fusion_log_tags_file) $(MERGETAGS) build/make/tools/event_log_tags.py
	$(hide) mkdir -p $(dir $@)
	$(hide) $(MERGETAGS) -o $@ $(PRIVATE_SRC_FILES)

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
$(event_log_tags_file): $(event_log_tags_src) $(all_event_log_tags_file) $(pdk_fusion_log_tags_file) $(MERGETAGS) build/make/tools/event_log_tags.py
	$(hide) mkdir -p $(dir $@)
	$(hide) $(MERGETAGS) -o $@ -m $(PRIVATE_MERGED_FILE) $(PRIVATE_SRC_FILES)

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

INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img

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

ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

ifeq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),true)
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
VERITY_KEYID := veritykeyid=id:`openssl x509 -in $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY).x509.pem -text \
                | grep keyid | sed 's/://g' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/keyid//g'`
endif
endif

INTERNAL_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE) buildvariant=$(TARGET_BUILD_VARIANT) $(VERITY_KEYID))
ifdef INTERNAL_KERNEL_CMDLINE
INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif

INTERNAL_MKBOOTIMG_VERSION_ARGS := \
    --os_version $(PLATFORM_VERSION) \
    --os_patch_level $(PLATFORM_SECURITY_PATCH)

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

else ifeq (true,$(BOARD_AVB_ENABLE)) # TARGET_BOOTIMAGE_USE_EXT2 != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(call get-hash-image-max-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE)))
	$(hide) $(AVBTOOL) add_hash_footer \
	  --image $@ \
	  --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) \
	  --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
	  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(INSTALLED_BOOTIMAGE_TARGET)
	$(hide) $(call assert-max-image-size,$(INSTALLED_BOOTIMAGE_TARGET),$(call get-hash-image-max-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE)))
	$(hide) $(AVBTOOL) add_hash_footer \
	  --image $(INSTALLED_BOOTIMAGE_TARGET) \
	  --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) \
	  --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
	  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)

else ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)) # BOARD_AVB_ENABLE != true

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

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(VBOOT_SIGNER) $(FUTILITY)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@.unsigned
	$(VBOOT_SIGNER) $(FUTILITY) $@.unsigned $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $@.keyblock $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE))

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(VBOOT_SIGNER) $(FUTILITY)
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
ifdef BOARD_PREBUILT_BOOTIMAGE
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
# Remove when b/63676296 is resolved.
$(error Prebuilt bootimage is only supported for AB targets)
endif
$(eval $(call copy-one-file,$(BOARD_PREBUILT_BOOTIMAGE),$(INSTALLED_BOOTIMAGE_TARGET)))
else
INTERNAL_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE))
# HACK: The top-level targets depend on the bootimage.  Not all targets
# can produce a bootimage, though, and emulator targets need the ramdisk
# instead.  Fake it out by calling the ramdisk the bootimage.
# TODO: make the emulator use bootimages, and make mkbootimg accept
#       kernel-less inputs.
INSTALLED_BOOTIMAGE_TARGET := $(INSTALLED_RAMDISK_TARGET)
endif
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

# Create the rule to combine the files into text and html/xml forms
# $(1) - xml_excluded_vendor|xml_vendor|html
# $(2) - Plain text output file
# $(3) - HTML/XML output file
# $(4) - File title
# $(5) - Directory to use.  Notice files are all $(4)/src.  Other
#		 directories in there will be used for scratch
# $(6) - Dependencies for the output files
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
$(2) $(3): PRIVATE_MESSAGE := $(4)
$(2) $(3): PRIVATE_DIR := $(5)
$(2) : $(3)
$(3) : $(6) $(BUILD_SYSTEM)/Makefile build/make/tools/generate-notice-files.py
	build/make/tools/generate-notice-files.py --text-output $(2) \
		$(if $(filter $(1),xml_excluded_vendor),-e vendor --xml-output, \
		  $(if $(filter $(1),xml_vendor),-i vendor --xml-output, \
		    --html-output)) $(3) \
		-t $$(PRIVATE_MESSAGE) -s $$(PRIVATE_DIR)/src
notice_files: $(2) $(3)
endef

# TODO These intermediate NOTICE.txt/NOTICE.html files should go into
# TARGET_OUT_NOTICE_FILES now that the notice files are gathered from
# the src subdirectory.

target_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE.txt
target_notice_file_html_or_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html
target_notice_file_html_or_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.html.gz
tools_notice_file_txt := $(HOST_OUT_INTERMEDIATES)/NOTICE.txt
tools_notice_file_html := $(HOST_OUT_INTERMEDIATES)/NOTICE.html

# TODO(b/69865032): Make PRODUCT_NOTICE_SPLIT the default behavior.
ifeq ($(PRODUCT_NOTICE_SPLIT),true)
target_notice_file_html_or_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml
target_notice_file_html_or_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.xml.gz

target_vendor_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.txt
target_vendor_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.xml
target_vendor_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.xml.gz
installed_vendor_notice_xml_gz := $(TARGET_OUT_VENDOR)/etc/NOTICE.xml.gz
endif

ifndef TARGET_BUILD_APPS
kernel_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/kernel.txt
winpthreads_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/winpthreads.txt
pdk_fusion_notice_files := $(filter $(TARGET_OUT_NOTICE_FILES)/%, $(ALL_PDK_FUSION_FILES))

ifdef target_vendor_notice_file_xml_gz
$(eval $(call combine-notice-files, xml_excluded_vendor, \
			$(target_notice_file_txt), \
			$(target_notice_file_html_or_xml), \
			"Notices for files contained in the filesystem images in this directory:", \
			$(TARGET_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file) $(pdk_fusion_notice_files)))
$(eval $(call combine-notice-files, xml_vendor, \
			$(target_vendor_notice_file_txt), \
			$(target_vendor_notice_file_xml), \
			"Notices for files contained in the vendor filesystem image in this directory:", \
			$(TARGET_OUT_NOTICE_FILES), \
			$(target_notice_file_html_or_xml)))
else
$(eval $(call combine-notice-files, html, \
			$(target_notice_file_txt), \
			$(target_notice_file_html_or_xml), \
			"Notices for files contained in the filesystem images in this directory:", \
			$(TARGET_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file) $(pdk_fusion_notice_files)))
endif

$(eval $(call combine-notice-files, html, \
			$(tools_notice_file_txt), \
			$(tools_notice_file_html), \
			"Notices for files contained in the tools directory:", \
			$(HOST_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES) \
			$(winpthreads_notice_file)))

# Install the html file at /system/etc/NOTICE.html.gz.
# This is not ideal, but this is very late in the game, after a lot of
# the module processing has already been done -- in fact, we used the
# fact that all that has been done to get the list of modules that we
# need notice files for.
$(target_notice_file_html_or_xml_gz): $(target_notice_file_html_or_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(installed_notice_html_or_xml_gz): $(target_notice_file_html_or_xml_gz)
	$(copy-file-to-target)

ifdef target_vendor_notice_file_xml_gz
# Install the vendor html file at /vendor/etc/NOTICE.xml.gz.
$(target_vendor_notice_file_xml_gz): $(target_vendor_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(installed_vendor_notice_xml_gz): $(target_vendor_notice_file_xml_gz)
	$(copy-file-to-target)
endif

# if we've been run my mm, mmm, etc, don't reinstall this every time
ifeq ($(ONE_SHOT_MAKEFILE),)
  ALL_DEFAULT_INSTALLED_MODULES += $(installed_notice_html_or_xml_gz)
  ifdef target_vendor_notice_file_xml_gz
    ALL_DEFAULT_INSTALLED_MODULES += $(installed_vendor_notice_xml_gz)
  endif
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

$(winpthreads_notice_file): \
	    $(BUILD_SYSTEM)/WINPTHREADS_COPYING \
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

# Carry the public key for update_engine if it's a non-IoT target that
# uses the AB updater. We use the same key as otacerts but in RSA public key
# format.
ifeq ($(AB_OTA_UPDATER),true)
ifneq ($(PRODUCT_IOT),true)
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

ifeq ($(BOARD_AVB_ENABLE),true)
INTERNAL_USERIMAGES_DEPS += $(AVBTOOL)
endif

ifneq (true,$(TARGET_USERIMAGES_SPARSE_SQUASHFS_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG := -s
endif
ifneq ($(filter $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE) $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE) $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE),squashfs),)
INTERNAL_USERIMAGES_DEPS += $(MAKE_SQUASHFS) $(MKSQUASHFSUSERIMG) $(IMG2SIMG)
endif

INTERNAL_USERIMAGES_BINARY_PATHS := $(sort $(dir $(INTERNAL_USERIMAGES_DEPS)))

ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY))
INTERNAL_USERIMAGES_DEPS += $(BUILD_VERITY_TREE) $(APPEND2SIMG) $(VERITY_SIGNER)
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC))
INTERNAL_USERIMAGES_DEPS += $(FEC)
endif
endif

SELINUX_FC := $(call intermediates-dir-for,ETC,file_contexts.bin)/file_contexts.bin
INTERNAL_USERIMAGES_DEPS += $(SELINUX_FC)

INTERNAL_USERIMAGES_DEPS += $(BLK_ALLOC_TO_BASE_FS)

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
INTERNAL_USERIMAGES_DEPS += $(MKE2FS_CONF)
endif

# $(1): the path of the output dictionary file
# $(2): additional "key=value" pairs to append to the dictionary file.
define generate-userimage-prop-dictionary
$(hide) echo "ext_mkuserimg=$(notdir $(MKEXTUSERIMG))" >> $(1)
$(if $(INTERNAL_USERIMAGES_EXT_VARIANT),$(hide) echo "fs_type=$(INTERNAL_USERIMAGES_EXT_VARIANT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_PARTITION_SIZE),$(hide) echo "system_size=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "system_fs_type=$(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "system_extfs_inode_count=$(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_EXTFS_RSV_PCT),$(hide) echo "system_extfs_rsv_pct=$(BOARD_SYSTEMIMAGE_EXTFS_RSV_PCT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_JOURNAL_SIZE),$(hide) echo "system_journal_size=$(BOARD_SYSTEMIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_EXT4_SHARE_DUP_BLOCKS),$(hide) echo "ext4_share_dup_blocks=$(BOARD_EXT4_SHARE_DUP_BLOCKS)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "system_squashfs_compressor=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "system_squashfs_compressor_opt=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "system_squashfs_block_size=$(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "system_squashfs_disable_4k_align=$(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH),$(hide) echo "system_base_fs_file=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_HEADROOM),$(hide) echo "system_headroom=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_HEADROOM)" >> $(1))
$(if $(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "userdata_fs_type=$(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(hide) echo "userdata_size=$(BOARD_USERDATAIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_FLASH_LOGICAL_BLOCK_SIZE), $(hide) echo "flash_logical_block_size=$(BOARD_FLASH_LOGICAL_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_FLASH_ERASE_BLOCK_SIZE), $(hide) echo "flash_erase_block_size=$(BOARD_FLASH_ERASE_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "cache_fs_type=$(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_CACHEIMAGE_PARTITION_SIZE),$(hide) echo "cache_size=$(BOARD_CACHEIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "vendor_fs_type=$(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT),$(hide) echo "vendor_extfs_inode_count=$(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_VENDORIMAGE_EXTFS_RSV_PCT),$(hide) echo "vendor_extfs_rsv_pct=$(BOARD_VENDORIMAGE_EXTFS_RSV_PCT)" >> $(1))
$(if $(BOARD_VENDORIMAGE_PARTITION_SIZE),$(hide) echo "vendor_size=$(BOARD_VENDORIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_JOURNAL_SIZE),$(hide) echo "vendor_journal_size=$(BOARD_VENDORIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "vendor_squashfs_compressor=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "vendor_squashfs_compressor_opt=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "vendor_squashfs_block_size=$(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "vendor_squashfs_disable_4k_align=$(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH),$(hide) echo "vendor_base_fs_file=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "product_fs_type=$(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT),$(hide) echo "product_extfs_inode_count=$(BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_EXTFS_RSV_PCT),$(hide) echo "product_extfs_rsv_pct=$(BOARD_PRODUCTIMAGE_EXTFS_RSV_PCT)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_PARTITION_SIZE),$(hide) echo "product_size=$(BOARD_PRODUCTIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_JOURNAL_SIZE),$(hide) echo "product_journal_size=$(BOARD_PRODUCTIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "product_squashfs_compressor=$(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "product_squashfs_compressor_opt=$(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "product_squashfs_block_size=$(BOARD_PRODUCTIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_PRODUCTIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "product_squashfs_disable_4k_align=$(BOARD_PRODUCTIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH),$(hide) echo "product_base_fs_file=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH)" >> $(1))
$(if $(BOARD_OEMIMAGE_PARTITION_SIZE),$(hide) echo "oem_size=$(BOARD_OEMIMAGE_PARTITION_SIZE)" >> $(1))
$(if $(BOARD_OEMIMAGE_JOURNAL_SIZE),$(hide) echo "oem_journal_size=$(BOARD_OEMIMAGE_JOURNAL_SIZE)" >> $(1))
$(if $(BOARD_OEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "oem_extfs_inode_count=$(BOARD_OEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
$(if $(BOARD_OEMIMAGE_EXTFS_RSV_PCT),$(hide) echo "oem_extfs_rsv_pct=$(BOARD_OEMIMAGE_EXTFS_RSV_PCT)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG),$(hide) echo "extfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG),$(hide) echo "squashfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG)" >> $(1))
$(hide) echo "selinux_fc=$(SELINUX_FC)" >> $(1)
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER),$(hide) echo "boot_signer=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_key=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VERITY_SIGNING_KEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_signer_cmd=$(notdir $(VERITY_SIGNER))" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC),$(hide) echo "verity_fec=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VERITY_FEC)" >> $(1))
$(if $(filter eng, $(TARGET_BUILD_VARIANT)),$(hide) echo "verity_disable=true" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_VERITY_PARTITION),$(hide) echo "system_verity_block_device=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_VERITY_PARTITION),$(hide) echo "vendor_verity_block_device=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_VERITY_PARTITION),$(hide) echo "product_verity_block_device=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_key=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_KEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_subkey=$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VBOOT_SIGNING_SUBKEY)" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "futility=$(notdir $(FUTILITY))" >> $(1))
$(if $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_signer_cmd=$(VBOOT_SIGNER)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_avbtool=$(notdir $(AVBTOOL))" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_SYSTEM_KEY_PATH),\
        $(hide) echo "avb_system_key_path=$(BOARD_AVB_SYSTEM_KEY_PATH)" >> $(1)
        $(hide) echo "avb_system_algorithm=$(BOARD_AVB_SYSTEM_ALGORITHM)" >> $(1)
        $(hide) echo "avb_system_rollback_index_location=$(BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_vendor_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_vendor_add_hashtree_footer_args=$(BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_VENDOR_KEY_PATH),\
        $(hide) echo "avb_vendor_key_path=$(BOARD_AVB_VENDOR_KEY_PATH)" >> $(1)
        $(hide) echo "avb_vendor_algorithm=$(BOARD_AVB_VENDOR_ALGORITHM)" >> $(1)
        $(hide) echo "avb_vendor_rollback_index_location=$(BOARD_AVB_VENDOR_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_product_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_product_add_hashtree_footer_args=$(BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_PRODUCT_KEY_PATH),\
        $(hide) echo "avb_product_key_path=$(BOARD_AVB_PRODUCT_KEY_PATH)" >> $(1)
        $(hide) echo "avb_product_algorithm=$(BOARD_AVB_PRODUCT_ALGORITHM)" >> $(1)
        $(hide) echo "avb_product_rollback_index_location=$(BOARD_AVB_PRODUCT_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(hide) echo "recovery_as_boot=true" >> $(1))
$(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)),\
    $(hide) echo "system_root_image=true" >> $(1);\
    echo "ramdisk_dir=$(TARGET_ROOT_OUT)" >> $(1))
$(if $(2),$(hide) $(foreach kv,$(2),echo "$(kv)" >> $(1);))
endef

# $(1): modules list
# $(2): output dir
# $(3): mount point
# $(4): staging dir
# Depmod requires a well-formed kernel version so 0.0 is used as a placeholder.
define build-image-kernel-modules
    $(hide) rm -rf $(2)/lib/modules
    $(hide) mkdir -p $(2)/lib/modules
    $(hide) cp $(1) $(2)/lib/modules/
    $(hide) rm -rf $(4)
    $(hide) mkdir -p $(4)/lib/modules/0.0/$(3)lib/modules
    $(hide) cp $(1) $(4)/lib/modules/0.0/$(3)lib/modules
    $(hide) $(DEPMOD) -b $(4) 0.0
    $(hide) sed -e 's/\(.*modules.*\):/\/\1:/g' -e 's/ \([^ ]*modules[^ ]*\)/ \/\1/g' $(4)/lib/modules/0.0/modules.dep > $(2)/lib/modules/modules.dep
    $(hide) cp $(4)/lib/modules/0.0/modules.alias $(2)/lib/modules
endef

# -----------------------------------------------------------------
# Recovery image

# Recovery image exists if we are building recovery, or building recovery as boot.
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))

INTERNAL_RECOVERYIMAGE_FILES := $(filter $(TARGET_RECOVERY_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

recovery_initrc := $(call include-path-for, recovery)/etc/init.rc
recovery_sepolicy := \
    $(TARGET_RECOVERY_ROOT_OUT)/sepolicy \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_property_contexts

ifdef BOARD_ODM_SEPOLICY_DIRS
recovery_sepolicy += \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_property_contexts
endif

# Passed into rsync from non-recovery root to recovery root, to avoid overwriting recovery-specific
# SELinux files
IGNORE_RECOVERY_SEPOLICY := $(patsubst $(TARGET_RECOVERY_OUT)/%,--exclude=/%,$(recovery_sepolicy))

recovery_kernel := $(INSTALLED_KERNEL_TARGET) # same as a non-recovery system
recovery_ramdisk := $(PRODUCT_OUT)/ramdisk-recovery.img
recovery_build_props := $(intermediate_system_build_prop)
ifdef property_overrides_split_enabled
recovery_build_props += $(INSTALLED_VENDOR_BUILD_PROP_TARGET)
endif
ifdef BOARD_USES_PRODUCTIMAGE
recovery_build_props += $(INSTALLED_PRODUCT_BUILD_PROP_TARGET)
endif
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

# Traditionally with non-A/B OTA we have:
#   boot.img + recovery-from-boot.p + recovery-resource.dat = recovery.img.
# recovery-resource.dat is needed only if we carry an imgdiff patch of the boot and recovery images
# and invoke install-recovery.sh on the first boot post an OTA update.
#
# We no longer need that if one of the following conditions holds:
#   a) We carry a full copy of the recovery image - no patching needed
#      (BOARD_USES_FULL_RECOVERY_IMAGE = true);
#   b) We build a single image that contains boot and recovery both - no recovery image to install
#      (BOARD_USES_RECOVERY_AS_BOOT = true);
#   c) We build the root into system image - not needing the resource file as we do bsdiff
#      (BOARD_BUILD_SYSTEM_ROOT_IMAGE = true).
#   d) We include the recovery DTBO image within recovery - not needing the resource file as we
#      do bsdiff because boot and recovery will contain different number of entries
#      (BOARD_INCLUDE_RECOVERY_DTBO = true).
# Note that condition b) implies condition c), because of the earlier check in this file:
# "BOARD_USES_RECOVERY_AS_BOOT = true must have BOARD_BUILD_SYSTEM_ROOT_IMAGE = true" (not vice
# versa though).

ifeq (,$(filter true, $(BOARD_USES_FULL_RECOVERY_IMAGE) $(BOARD_BUILD_SYSTEM_ROOT_IMAGE) \
  $(BOARD_INCLUDE_RECOVERY_DTBO)))
# Named '.dat' so we don't attempt to use imgdiff for patching it.
RECOVERY_RESOURCE_ZIP := $(TARGET_OUT)/etc/recovery-resource.dat
else
RECOVERY_RESOURCE_ZIP :=
endif

INTERNAL_RECOVERYIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(recovery_kernel) \
	--ramdisk $(recovery_ramdisk)

# Assumes this has already been stripped
ifdef INTERNAL_KERNEL_CMDLINE
  INTERNAL_RECOVERYIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif
ifdef BOARD_KERNEL_BASE
  INTERNAL_RECOVERYIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_RECOVERYIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
  INTERNAL_RECOVERYIMAGE_ARGS += --recovery_dtbo $(BOARD_PREBUILT_DTBOIMAGE)
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
	$(JAVA) -jar $(DUMPKEY_JAR) $(PRIVATE_OTA_PUBLIC_KEYS) $(extra_keys) > $@

RECOVERYIMAGE_ID_FILE := $(PRODUCT_OUT)/recovery.id

# $(1): output file
define build-recoveryimage-target
  # Making recovery image
  $(hide) mkdir -p $(TARGET_RECOVERY_OUT)
  $(hide) mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/etc $(TARGET_RECOVERY_ROOT_OUT)/sdcard $(TARGET_RECOVERY_ROOT_OUT)/tmp
  # Copying baseline ramdisk...
  # Use rsync because "cp -Rf" fails to overwrite broken symlinks on Mac.
  $(hide) rsync -a --exclude=etc --exclude=sdcard $(IGNORE_RECOVERY_SEPOLICY) $(IGNORE_CACHE_LINK) $(TARGET_ROOT_OUT) $(TARGET_RECOVERY_OUT)
  # Copy adbd from system/bin to recovery/root/sbin
  $(hide) cp -f $(TARGET_OUT_EXECUTABLES)/adbd $(TARGET_RECOVERY_ROOT_OUT)/sbin/adbd
  # Modifying ramdisk contents...
  $(if $(BOARD_RECOVERY_KERNEL_MODULES), \
    $(call build-image-kernel-modules,$(BOARD_RECOVERY_KERNEL_MODULES),$(TARGET_RECOVERY_ROOT_OUT),,$(call intermediates-dir-for,PACKAGING,depmod_recovery)))
  # Removes $(TARGET_RECOVERY_ROOT_OUT)/init*.rc EXCEPT init.recovery*.rc.
  $(hide) find $(TARGET_RECOVERY_ROOT_OUT) -maxdepth 1 -name 'init*.rc' -type f -not -name "init.recovery.*.rc" | xargs rm -f
  $(hide) cp -f $(recovery_initrc) $(TARGET_RECOVERY_ROOT_OUT)/
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
  $(hide) cat $(INSTALLED_DEFAULT_PROP_TARGET) \
          > $(TARGET_RECOVERY_ROOT_OUT)/prop.default
  $(if $(INSTALLED_VENDOR_DEFAULT_PROP_TARGET), \
    $(hide) cat $(INSTALLED_VENDOR_DEFAULT_PROP_TARGET) \
            >> $(TARGET_RECOVERY_ROOT_OUT)/prop.default)
  $(hide) cat $(recovery_build_props) \
          >> $(TARGET_RECOVERY_ROOT_OUT)/prop.default
  $(hide) ln -sf prop.default $(TARGET_RECOVERY_ROOT_OUT)/default.prop
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
    $(hide) $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE))), \
    $(hide) $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE))))
  $(if $(filter true,$(BOARD_AVB_ENABLE)), \
    $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
      $(hide) $(AVBTOOL) add_hash_footer --image $(1) --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS),\
      $(hide) $(AVBTOOL) add_hash_footer --image $(1) --partition_size $(BOARD_RECOVERYIMAGE_PARTITION_SIZE) --partition_name recovery $(INTERNAL_AVB_RECOVERY_SIGNING_ARGS) $(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)))
endef

ADBD := $(TARGET_OUT_EXECUTABLES)/adbd

ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_BOOT_SIGNER))
$(INSTALLED_BOOTIMAGE_TARGET) : $(BOOT_SIGNER)
endif
ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT))
$(INSTALLED_BOOTIMAGE_TARGET) : $(VBOOT_SIGNER)
endif
ifeq (true,$(BOARD_AVB_ENABLE))
$(INSTALLED_BOOTIMAGE_TARGET) : $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH)
endif
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTFS) $(MKBOOTIMG) $(MINIGZIP) $(ADBD) \
		$(INSTALLED_RAMDISK_TARGET) \
		$(INTERNAL_RECOVERYIMAGE_FILES) \
		$(recovery_initrc) $(recovery_sepolicy) $(recovery_kernel) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(recovery_build_props) $(recovery_resource_deps) \
		$(recovery_fstab) \
		$(RECOVERY_INSTALL_OTA_KEYS) \
		$(INSTALLED_VENDOR_DEFAULT_PROP_TARGET) \
		$(BOARD_RECOVERY_KERNEL_MODULES) \
		$(DEPMOD)
		$(call pretty,"Target boot image from recovery: $@")
		$(call build-recoveryimage-target, $@)
endif

$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTFS) $(MKBOOTIMG) $(MINIGZIP) $(ADBD) \
		$(INSTALLED_RAMDISK_TARGET) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INTERNAL_RECOVERYIMAGE_FILES) \
		$(recovery_initrc) $(recovery_sepolicy) $(recovery_kernel) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(recovery_build_props) $(recovery_resource_deps) \
		$(recovery_fstab) \
		$(RECOVERY_INSTALL_OTA_KEYS) \
		$(INSTALLED_VENDOR_DEFAULT_PROP_TARGET) \
		$(BOARD_RECOVERY_KERNEL_MODULES) \
		$(DEPMOD)
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

ifneq ($(BOARD_NAND_PAGE_SIZE),)
$(error MTD device is no longer supported and thus BOARD_NAND_PAGE_SIZE is deprecated.)
endif

ifneq ($(BOARD_NAND_SPARE_SIZE),)
$(error MTD device is no longer supported and thus BOARD_NAND_SPARE_SIZE is deprecated.)
endif

# -----------------------------------------------------------------
# system image
#
# Remove overridden packages from $(ALL_PDK_FUSION_FILES)
PDK_FUSION_SYSIMG_FILES := \
    $(filter-out $(foreach p,$(overridden_packages),$(p) %/$(p).apk), \
        $(ALL_PDK_FUSION_FILES))

INTERNAL_SYSTEMIMAGE_FILES := $(filter $(TARGET_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(PDK_FUSION_SYSIMG_FILES) \
    $(RECOVERY_RESOURCE_ZIP)) \
    $(PDK_FUSION_SYMLINK_STAMP)

FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)

# ASAN libraries in the system image - add dependency.
ASAN_IN_SYSTEM_INSTALLED := $(TARGET_OUT)/asan.tar.bz2
ifneq (,$(SANITIZE_TARGET))
  ifeq (true,$(SANITIZE_TARGET_SYSTEM))
    FULL_SYSTEMIMAGE_DEPS += $(ASAN_IN_SYSTEM_INSTALLED)
  endif
endif

# -----------------------------------------------------------------
# installed file list
# Depending on anything that $(BUILT_SYSTEMIMAGE) depends on.
# We put installed-files.txt ahead of image itself in the dependency graph
# so that we can get the size stat even if the build fails due to too large
# system image.
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
$(INSTALLED_FILES_FILE): $(FULL_SYSTEMIMAGE_DEPS) $(FILESLIST)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT) > $(@:.txt=.json)
	$(hide) build/make/tools/fileslist_util.py -c $(@:.txt=.json) > $@

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

# Create symlink /system/product to /product if necessary.
ifdef BOARD_USES_PRODUCTIMAGE
define create-system-product-symlink
$(hide) if [ -d $(TARGET_OUT)/product ] && [ ! -h $(TARGET_OUT)/product ]; then \
  echo 'Non-symlink $(TARGET_OUT)/product detected!' 1>&2; \
  echo 'You cannot install files to $(TARGET_OUT)/product while building a separate product.img!' 1>&2; \
  exit 1; \
fi
$(hide) ln -sf /product $(TARGET_OUT)/product
endef
else
define create-system-product-symlink
endef
endif

# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  $(call create-system-vendor-symlink)
  $(call create-system-product-symlink)
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-userimage-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt, \
      skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1) $(TARGET_OUT) \
      || ( echo "Out of space? the tree size of $(TARGET_OUT) is (MB): " 1>&2 ;\
           du -sm $(TARGET_OUT) 1>&2;\
           if [ "$(INTERNAL_USERIMAGES_EXT_VARIANT)" == "ext4" ]; then \
               maxsize=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE); \
               echo "The max is $$(( maxsize / 1048576 )) MB." 1>&2 ;\
           else \
               echo "The max is $$(( $(BOARD_SYSTEMIMAGE_PARTITION_SIZE) / 1048576 )) MB." 1>&2 ;\
           fi; \
           mkdir -p $(DIST_DIR); cp $(INSTALLED_FILES_FILE) $(DIST_DIR)/installed-files-rescued.txt; \
           exit 1 )
endef

$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE) $(BUILD_IMAGE_SRCS)
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
ifneq (,$(filter true, $(BOARD_BUILD_SYSTEM_ROOT_IMAGE) $(BOARD_INCLUDE_RECOVERY_DTBO)))
diff_tool := $(HOST_OUT_EXECUTABLES)/bsdiff
else
diff_tool := $(HOST_OUT_EXECUTABLES)/imgdiff
endif
intermediates := $(call intermediates-dir-for,PACKAGING,recovery_patch)
RECOVERY_FROM_BOOT_PATCH := $(intermediates)/recovery_from_boot.p
$(RECOVERY_FROM_BOOT_PATCH): PRIVATE_DIFF_TOOL := $(diff_tool)
$(RECOVERY_FROM_BOOT_PATCH): \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(diff_tool)
	@echo "Construct recovery from boot"
	mkdir -p $(dir $@)
	$(PRIVATE_DIFF_TOOL) $(INSTALLED_BOOTIMAGE_TARGET) $(INSTALLED_RECOVERYIMAGE_TARGET) $@
else # $(BOARD_USES_FULL_RECOVERY_IMAGE) == true
RECOVERY_FROM_BOOT_PATCH := $(INSTALLED_RECOVERYIMAGE_TARGET)
endif
endif


$(INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE) $(RECOVERY_FROM_BOOT_PATCH)
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

.PHONY: sync
sync: $(INTERNAL_SYSTEMIMAGE_FILES)

#######
## system tarball
define build-systemtarball-target
  $(call pretty,"Target system fs tarball: $(INSTALLED_SYSTEMTARBALL_TARGET)")
  $(call create-system-vendor-symlink)
  $(call create-system-product-symlink)
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
	  $(hide) echo "PDK.DEXPREOPT.$(m).VENDOR_MODULE:=$(DEXPREOPT.$(m).VENDOR_MODULE)" >> $@$(newline)\
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
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
	$(hide) cd $(dir $@) && zip -qryX $(notdir $@) \
		$(TARGET_COPY_OUT_PRODUCT)
endif
ifneq ($(PDK_PLATFORM_JAVA_ZIP_CONTENTS),)
	$(hide) cd $(OUT_DIR) && zip -qryX $(patsubst $(OUT_DIR)/%,%,$@) $(PDK_PLATFORM_JAVA_ZIP_CONTENTS)
endif
ifneq ($(PDK_PLATFORM_ZIP_PRODUCT_BINARIES),)
	$(hide) zip -qryX $@ $(PDK_PLATFORM_ZIP_PRODUCT_BINARIES)
endif
	@# Add dex-preopt files and config.
	$(if $(PRIVATE_DEX_FILES),$(hide) cd $(OUT_DIR) && zip -qryX $(patsubst $(OUT_DIR)/%,%,$@ $(PRIVATE_DEX_FILES)))
	$(hide) touch $(PRODUCT_OUT)/pdk.mk
	$(hide) zip -qryXj $@ $(PRIVATE_ODEX_CONFIG) $(PRODUCT_OUT)/pdk.mk

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
    $(hide) echo $(INTERNAL_KERNEL_CMDLINE) > $(PRODUCT_OUT)/boot/cmdline
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
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT_DATA) $(userdataimage_intermediates)/userdata_image_info.txt $(INSTALLED_USERDATAIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
INSTALLED_USERDATAIMAGE_TARGET_DEPS := \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_USERDATAIMAGE_FILES) \
    $(BUILD_IMAGE_SRCS)
$(INSTALLED_USERDATAIMAGE_TARGET): $(INSTALLED_USERDATAIMAGE_TARGET_DEPS)
	$(build-userdataimage-target)

.PHONY: userdataimage-nodeps
userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-userdataimage-target)

endif # not skip_userdata.img
skip_userdata.img :=

# ASAN libraries in the system image - build rule.
ASAN_OUT_DIRS_FOR_SYSTEM_INSTALL := $(sort $(patsubst $(PRODUCT_OUT)/%,%,\
  $(TARGET_OUT_SHARED_LIBRARIES) \
  $(2ND_TARGET_OUT_SHARED_LIBRARIES) \
  $(TARGET_OUT_VENDOR_SHARED_LIBRARIES) \
  $(2ND_TARGET_OUT_VENDOR_SHARED_LIBRARIES)))
# Extra options: Enforce the system user for the files to avoid having to change ownership.
ASAN_SYSTEM_INSTALL_OPTIONS := --owner=1000 --group=1000
# Note: experimentally, it seems not worth it to try to get "best" compression. We don't save
#       enough space.
$(ASAN_IN_SYSTEM_INSTALLED): $(INSTALLED_USERDATAIMAGE_TARGET_DEPS)
	tar cfj $(ASAN_IN_SYSTEM_INSTALLED) $(ASAN_SYSTEM_INSTALL_OPTIONS) -C $(TARGET_OUT_DATA)/.. $(ASAN_OUT_DIRS_FOR_SYSTEM_INSTALL) >/dev/null

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
# partition table image
ifdef BOARD_BPT_INPUT_FILES

BUILT_BPTIMAGE_TARGET := $(PRODUCT_OUT)/partition-table.img
BUILT_BPTJSON_TARGET := $(PRODUCT_OUT)/partition-table.bpt

INTERNAL_BVBTOOL_MAKE_TABLE_ARGS := \
	--output_gpt $(BUILT_BPTIMAGE_TARGET) \
	--output_json $(BUILT_BPTJSON_TARGET) \
	$(foreach file, $(BOARD_BPT_INPUT_FILES), --input $(file))

ifdef BOARD_BPT_DISK_SIZE
INTERNAL_BVBTOOL_MAKE_TABLE_ARGS += --disk_size $(BOARD_BPT_DISK_SIZE)
endif

define build-bptimage-target
  $(call pretty,"Target partition table image: $(INSTALLED_BPTIMAGE_TARGET)")
  $(hide) $(BPTTOOL) make_table $(INTERNAL_BVBTOOL_MAKE_TABLE_ARGS) $(BOARD_BPT_MAKE_TABLE_ARGS)
endef

INSTALLED_BPTIMAGE_TARGET := $(BUILT_BPTIMAGE_TARGET)
$(BUILT_BPTJSON_TARGET): $(INSTALLED_BPTIMAGE_TARGET)
	$(hide) touch -c $(BUILT_BPTJSON_TARGET)

$(INSTALLED_BPTIMAGE_TARGET): $(BPTTOOL) $(BOARD_BPT_INPUT_FILES)
	$(build-bptimage-target)

.PHONY: bptimage-nodeps
bptimage-nodeps:
	$(build-bptimage-target)

endif # BOARD_BPT_INPUT_FILES

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
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT_CACHE) $(cacheimage_intermediates)/cache_image_info.txt $(INSTALLED_CACHEIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_CACHEIMAGE_TARGET),$(BOARD_CACHEIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_CACHEIMAGE_TARGET := $(BUILT_CACHEIMAGE_TARGET)
$(INSTALLED_CACHEIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES) $(BUILD_IMAGE_SRCS)
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
      $(ALL_PDK_FUSION_FILES)) \
    $(PDK_FUSION_SYMLINK_STAMP)

INSTALLED_FILES_FILE_SYSTEMOTHER := $(PRODUCT_OUT)/installed-files-system-other.txt
$(INSTALLED_FILES_FILE_SYSTEMOTHER) : $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(FILESLIST)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_SYSTEM_OTHER) > $(@:.txt=.json)
	$(hide) build/make/tools/fileslist_util.py -c $(@:.txt=.json) > $@

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
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT_SYSTEM_OTHER) $(systemotherimage_intermediates)/system_other_image_info.txt $(INSTALLED_SYSTEMOTHERIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_SYSTEMOTHERIMAGE_TARGET := $(BUILT_SYSTEMOTHERIMAGE_TARGET)
ifneq (true,$(SANITIZE_LITE))
# Only create system_other when not building the second stage of a SANITIZE_LITE build.
$(INSTALLED_SYSTEMOTHERIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEMOTHER)
	$(build-systemotherimage-target)
endif

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
      $(ALL_PDK_FUSION_FILES)) \
    $(PDK_FUSION_SYMLINK_STAMP)

# platform.zip depends on $(INTERNAL_VENDORIMAGE_FILES).
$(INSTALLED_PLATFORM_ZIP) : $(INTERNAL_VENDORIMAGE_FILES)

INSTALLED_FILES_FILE_VENDOR := $(PRODUCT_OUT)/installed-files-vendor.txt
$(INSTALLED_FILES_FILE_VENDOR) : $(INTERNAL_VENDORIMAGE_FILES) $(FILESLIST)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_VENDOR) > $(@:.txt=.json)
	$(hide) build/make/tools/fileslist_util.py -c $(@:.txt=.json) > $@

vendorimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor)
BUILT_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
define build-vendorimage-target
  $(call pretty,"Target vendor fs image: $(INSTALLED_VENDORIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR)
  @mkdir -p $(vendorimage_intermediates) && rm -rf $(vendorimage_intermediates)/vendor_image_info.txt
  $(call generate-userimage-prop-dictionary, $(vendorimage_intermediates)/vendor_image_info.txt, skip_fsck=true)
  $(if $(BOARD_VENDOR_KERNEL_MODULES), \
    $(call build-image-kernel-modules,$(BOARD_VENDOR_KERNEL_MODULES),$(TARGET_OUT_VENDOR),vendor/,$(call intermediates-dir-for,PACKAGING,depmod_vendor)))
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT_VENDOR) $(vendorimage_intermediates)/vendor_image_info.txt $(INSTALLED_VENDORIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_VENDORIMAGE_TARGET),$(BOARD_VENDORIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_VENDORIMAGE_TARGET := $(BUILT_VENDORIMAGE_TARGET)
$(INSTALLED_VENDORIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDORIMAGE_FILES) $(INSTALLED_FILES_FILE_VENDOR) $(BUILD_IMAGE_SRCS) $(DEPMOD) $(BOARD_VENDOR_KERNEL_MODULES)
	$(build-vendorimage-target)

.PHONY: vendorimage-nodeps vnod
vendorimage-nodeps vnod: | $(INTERNAL_USERIMAGES_DEPS) $(DEPMOD)
	$(build-vendorimage-target)

sync: $(INTERNAL_VENDORIMAGE_FILES)

else ifdef BOARD_PREBUILT_VENDORIMAGE
INSTALLED_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDORIMAGE),$(INSTALLED_VENDORIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# product partition image
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
INTERNAL_PRODUCTIMAGE_FILES := \
    $(filter $(TARGET_OUT_PRODUCT)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES)\
      $(ALL_PDK_FUSION_FILES)) \
    $(PDK_FUSION_SYMLINK_STAMP)

# platform.zip depends on $(INTERNAL_PRODUCTIMAGE_FILES).
$(INSTALLED_PLATFORM_ZIP) : $(INTERNAL_PRODUCTIMAGE_FILES)

INSTALLED_FILES_FILE_PRODUCT := $(PRODUCT_OUT)/installed-files-product.txt
$(INSTALLED_FILES_FILE_PRODUCT) : $(INTERNAL_PRODUCTIMAGE_FILES) $(FILESLIST)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_PRODUCT) > $(@:.txt=.json)
	$(hide) build/tools/fileslist_util.py -c $(@:.txt=.json) > $@

productimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,product)
BUILT_PRODUCTIMAGE_TARGET := $(PRODUCT_OUT)/product.img
define build-productimage-target
  $(call pretty,"Target product fs image: $(INSTALLED_PRODUCTIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_PRODUCT)
  @mkdir -p $(productimage_intermediates) && rm -rf $(productimage_intermediates)/product_image_info.txt
  $(call generate-userimage-prop-dictionary, $(productimage_intermediates)/product_image_info.txt, skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      ./build/tools/releasetools/build_image.py \
      $(TARGET_OUT_PRODUCT) $(productimage_intermediates)/product_image_info.txt $(INSTALLED_PRODUCTIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_PRODUCTIMAGE_TARGET),$(BOARD_PRODUCTIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_PRODUCTIMAGE_TARGET := $(BUILT_PRODUCTIMAGE_TARGET)
$(INSTALLED_PRODUCTIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_PRODUCTIMAGE_FILES) $(INSTALLED_FILES_FILE_PRODUCT) $(BUILD_IMAGE_SRCS)
	$(build-productimage-target)

.PHONY: productimage-nodeps pnod
productimage-nodeps pnod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-productimage-target)

sync: $(INTERNAL_PRODUCTIMAGE_FILES)

else ifdef BOARD_PREBUILT_PRODUCTIMAGE
INSTALLED_PRODUCTIMAGE_TARGET := $(PRODUCT_OUT)/product.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_PRODUCTIMAGE),$(INSTALLED_PRODUCTIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# dtbo image
ifdef BOARD_PREBUILT_DTBOIMAGE
INSTALLED_DTBOIMAGE_TARGET := $(PRODUCT_OUT)/dtbo.img

ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_DTBOIMAGE_TARGET): $(BOARD_PREBUILT_DTBOIMAGE) $(AVBTOOL) $(BOARD_AVB_DTBO_KEY_PATH)
	cp $(BOARD_PREBUILT_DTBOIMAGE) $@
	$(AVBTOOL) add_hash_footer \
		--image $@ \
		--partition_size $(BOARD_DTBOIMG_PARTITION_SIZE) \
		--partition_name dtbo $(INTERNAL_AVB_DTBO_SIGNING_ARGS) \
		$(BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS)
else
$(INSTALLED_DTBOIMAGE_TARGET): $(BOARD_PREBUILT_DTBOIMAGE)
	cp $(BOARD_PREBUILT_DTBOIMAGE) $@
endif

endif

# -----------------------------------------------------------------
# vbmeta image
ifeq ($(BOARD_AVB_ENABLE),true)

BUILT_VBMETAIMAGE_TARGET := $(PRODUCT_OUT)/vbmeta.img
AVB_CHAIN_KEY_DIR := $(TARGET_OUT_INTERMEDIATES)/avb_chain_keys

ifdef BOARD_AVB_KEY_PATH
$(if $(BOARD_AVB_ALGORITHM),,$(error BOARD_AVB_ALGORITHM is not defined))
else
# If key path isn't specified, use the 4096-bit test key.
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
endif

INTERNAL_AVB_SIGNING_ARGS := \
    --algorithm $(BOARD_AVB_ALGORITHM) --key $(BOARD_AVB_KEY_PATH)

BOOT_FOOTER_ARGS := BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS
DTBO_FOOTER_ARGS := BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS
SYSTEM_FOOTER_ARGS := BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS
VENDOR_FOOTER_ARGS := BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS
RECOVERY_FOOTER_ARGS := BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS
PRODUCT_FOOTER_ARGS := BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS

# Check and set required build variables for a chain partition.
# $(1): the partition to enable AVB chain, e.g., BOOT or SYSTEM.
define check-and-set-avb-chain-args
$(eval PART := $(1))
$(eval part=$(call to-lower,$(PART)))

$(eval _key_path := BOARD_AVB_$(PART)_KEY_PATH)
$(eval _signing_algorithm := BOARD_AVB_$(PART)_ALGORITHM)
$(eval _rollback_index := BOARD_AVB_$(PART)_ROLLBACK_INDEX)
$(eval _rollback_index_location := BOARD_AVB_$(PART)_ROLLBACK_INDEX_LOCATION)
$(if $($(_key_path)),,$(error $(_key_path) is not defined))
$(if $($(_signing_algorithm)),,$(error $(_signing_algorithm) is not defined))
$(if $($(_rollback_index)),,$(error $(_rollback_index) is not defined))
$(if $($(_rollback_index_location)),,$(error $(_rollback_index_location) is not defined))

# Set INTERNAL_AVB_(PART)_SIGNING_ARGS
$(eval _signing_args := INTERNAL_AVB_$(PART)_SIGNING_ARGS)
$(eval $(_signing_args) := \
    --algorithm $($(_signing_algorithm)) --key $($(_key_path)))

$(eval INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --chain_partition $(part):$($(_rollback_index_location)):$(AVB_CHAIN_KEY_DIR)/$(part).avbpubkey)

# Set rollback_index via footer args
$(eval _footer_args := $(PART)_FOOTER_ARGS)
$(eval $($(_footer_args)) += --rollback_index $($(_rollback_index)))
endef

ifdef BOARD_AVB_BOOT_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,BOOT))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_BOOTIMAGE_TARGET)
endif

ifdef BOARD_AVB_SYSTEM_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,SYSTEM))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_SYSTEMIMAGE)
endif

ifdef INSTALLED_VENDORIMAGE_TARGET
ifdef BOARD_AVB_VENDOR_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,VENDOR))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_VENDORIMAGE_TARGET)
endif
endif

ifdef INSTALLED_PRODUCTIMAGE_TARGET
ifdef BOARD_AVB_PRODUCT_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,PRODUCT))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_PRODUCTIMAGE_TARGET)
endif
endif

ifdef INSTALLED_DTBOIMAGE_TARGET
ifdef BOARD_AVB_DTBO_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,DTBO))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_DTBOIMAGE_TARGET)
endif
endif

ifdef INSTALLED_RECOVERYIMAGE_TARGET
ifdef BOARD_AVB_RECOVERY_KEY_PATH
$(eval $(call check-and-set-avb-chain-args,RECOVERY))
else
INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --include_descriptors_from_image $(INSTALLED_RECOVERYIMAGE_TARGET)
endif
endif

BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --padding_size 4096

# Add kernel cmdline descriptor for kernel to mount system.img as root with
# dm-verity. This works when system.img is either chained or not-chained:
# - chained: The --setup_as_rootfs_from_kernel option will add dm-verity kernel
#   cmdline descriptor to system.img
# - not-chained: The --include_descriptors_from_image option for make_vbmeta_image
#   will include the kernel cmdline descriptor from system.img into vbmeta.img
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --setup_as_rootfs_from_kernel
endif

ifdef BOARD_AVB_ROLLBACK_INDEX
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --rollback_index $(BOARD_AVB_ROLLBACK_INDEX)
endif

ifndef BOARD_BOOTIMAGE_PARTITION_SIZE
  $(error BOARD_BOOTIMAGE_PARTITION_SIZE must be set for BOARD_AVB_ENABLE)
endif

ifndef BOARD_SYSTEMIMAGE_PARTITION_SIZE
  $(error BOARD_SYSTEMIMAGE_PARTITION_SIZE must be set for BOARD_AVB_ENABLE)
endif

# $(1): the directory to extract public keys to
define extract-avb-chain-public-keys
  $(if $(BOARD_AVB_BOOT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_BOOT_KEY_PATH) \
      --output $(1)/boot.avbpubkey)
  $(if $(BOARD_AVB_SYSTEM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_SYSTEM_KEY_PATH) \
      --output $(1)/system.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_KEY_PATH) \
      --output $(1)/vendor.avbpubkey)
  $(if $(BOARD_AVB_PRODUCT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_PRODUCT_KEY_PATH) \
      --output $(1)/product.avbpubkey)
  $(if $(BOARD_AVB_DTBO_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_DTBO_KEY_PATH) \
      --output $(1)/dtbo.avbpubkey)
  $(if $(BOARD_AVB_RECOVERY_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_RECOVERY_KEY_PATH) \
      --output $(1)/recovery.avbpubkey)
endef

define build-vbmetaimage-target
  $(call pretty,"Target vbmeta image: $(INSTALLED_VBMETAIMAGE_TARGET)")
  $(hide) mkdir -p $(AVB_CHAIN_KEY_DIR)
  $(call extract-avb-chain-public-keys, $(AVB_CHAIN_KEY_DIR))
  $(hide) $(AVBTOOL) make_vbmeta_image \
    $(INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS) \
    $(INTERNAL_AVB_SIGNING_ARGS) \
    $(BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS) \
    --output $@
  $(hide) rm -rf $(AVB_CHAIN_KEY_DIR)
endef

INSTALLED_VBMETAIMAGE_TARGET := $(BUILT_VBMETAIMAGE_TARGET)
$(INSTALLED_VBMETAIMAGE_TARGET): \
		$(AVBTOOL) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_PRODUCTIMAGE_TARGET) \
		$(INSTALLED_DTBOIMAGE_TARGET) \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(BOARD_AVB_KEY_PATH)
	$(build-vbmetaimage-target)

.PHONY: vbmetaimage-nodeps
vbmetaimage-nodeps:
	$(build-vbmetaimage-target)

else ifeq (true,$(BOARD_BUILD_DISABLED_VBMETAIMAGE))
BUILT_DISABLED_VBMETAIMAGE := $(PRODUCT_OUT)/vbmeta.img

INSTALLED_VBMETAIMAGE_TARGET := $(BUILT_DISABLED_VBMETAIMAGE)
$(INSTALLED_VBMETAIMAGE_TARGET): $(AVBTOOL)
	$(hide) $(AVBTOOL) make_vbmeta_image \
	  --flag 2 --padding_size 4096 --output $@

endif # BOARD_AVB_ENABLE

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
  $(HOST_OUT_EXECUTABLES)/checkvintf \
  $(HOST_OUT_EXECUTABLES)/mkbootfs \
  $(HOST_OUT_EXECUTABLES)/mkbootimg \
  $(HOST_OUT_EXECUTABLES)/fs_config \
  $(HOST_OUT_EXECUTABLES)/zipalign \
  $(HOST_OUT_EXECUTABLES)/bsdiff \
  $(HOST_OUT_EXECUTABLES)/imgdiff \
  $(HOST_OUT_JAVA_LIBRARIES)/dumpkey.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/signapk.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/BootSignature.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/VeritySigner.jar \
  $(HOST_OUT_EXECUTABLES)/mke2fs \
  $(HOST_OUT_EXECUTABLES)/mkuserimg_mke2fs.sh \
  $(HOST_OUT_EXECUTABLES)/e2fsdroid \
  $(HOST_OUT_EXECUTABLES)/mksquashfsimage.sh \
  $(HOST_OUT_EXECUTABLES)/mksquashfs \
  $(HOST_OUT_EXECUTABLES)/mkf2fsuserimg.sh \
  $(HOST_OUT_EXECUTABLES)/make_f2fs \
  $(HOST_OUT_EXECUTABLES)/sload_f2fs \
  $(HOST_OUT_EXECUTABLES)/simg2img \
  $(HOST_OUT_EXECUTABLES)/e2fsck \
  $(HOST_OUT_EXECUTABLES)/build_verity_tree \
  $(HOST_OUT_EXECUTABLES)/generate_verity_key \
  $(HOST_OUT_EXECUTABLES)/verity_signer \
  $(HOST_OUT_EXECUTABLES)/verity_verifier \
  $(HOST_OUT_EXECUTABLES)/append2simg \
  $(HOST_OUT_EXECUTABLES)/img2simg \
  $(HOST_OUT_EXECUTABLES)/boot_signer \
  $(HOST_OUT_EXECUTABLES)/fec \
  $(HOST_OUT_EXECUTABLES)/brillo_update_payload \
  $(HOST_OUT_EXECUTABLES)/lib/shflags/shflags \
  $(HOST_OUT_EXECUTABLES)/delta_generator \
  $(AVBTOOL) \
  $(BLK_ALLOC_TO_BASE_FS) \
  $(BROTLI)

ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT))
OTATOOLS += \
  $(FUTILITY) \
  $(VBOOT_SIGNER)
endif

# Shared libraries.
OTATOOLS += \
  $(HOST_LIBRARY_PATH)/libc++$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/liblog$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcutils$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libselinux$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcrypto_utils$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcrypto-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2fs-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_blkid-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_com_err-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_e2p-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_misc$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_profile-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_quota-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libext2_uuid-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libconscrypt_openjdk_jni$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrillo$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrillo-stream$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libchrome$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libcurl-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libevent-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libprotobuf-cpp-lite$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libssl-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libz-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libsparse-host$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbase$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libpcre2$(HOST_SHLIB_SUFFIX) \
  $(HOST_LIBRARY_PATH)/libbrotli$(HOST_SHLIB_SUFFIX)


.PHONY: otatools
otatools: $(OTATOOLS)

BUILT_OTATOOLS_PACKAGE := $(PRODUCT_OUT)/otatools.zip
$(BUILT_OTATOOLS_PACKAGE): zip_root := $(call intermediates-dir-for,PACKAGING,otatools)/otatools

OTATOOLS_DEPS := \
  system/extras/verity/build_verity_metadata.py \
  system/extras/ext4_utils/mke2fs.conf \
  $(sort $(shell find external/avb/test/data -type f -name "testkey_*.pem" -o \
      -name "atx_metadata.bin")) \
  $(sort $(shell find system/update_engine/scripts -name \*.pyc -prune -o -type f -print)) \
  $(sort $(shell find build/target/product/security -type f -name \*.x509.pem -o -name \*.pk8 -o \
      -name verity_key)) \
  $(sort $(shell find device $(wildcard vendor) -type f -name \*.pk8 -o -name verifiedboot\* -o \
      -name \*.x509.pem -o -name oem\*.prop))

OTATOOLS_RELEASETOOLS := \
  $(sort $(shell find build/make/tools/releasetools -name \*.pyc -prune -o -type f))

ifeq (true,$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SUPPORTS_VBOOT))
OTATOOLS_DEPS += \
  $(sort $(shell find external/vboot_reference/tests/devkeys -type f))
endif

$(BUILT_OTATOOLS_PACKAGE): $(OTATOOLS) $(OTATOOLS_DEPS) $(OTATOOLS_RELEASETOOLS) | $(ACP)
	@echo "Package OTA tools: $@"
	$(hide) rm -rf $@ $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)/bin $(zip_root)/framework $(zip_root)/releasetools
	$(call copy-files-with-structure,$(OTATOOLS),$(HOST_OUT)/,$(zip_root))
	$(hide) $(ACP) -r -d -p build/make/tools/releasetools/* $(zip_root)/releasetools
	$(hide) rm -rf $@ $(zip_root)/releasetools/*.pyc
	$(hide) (cd $(zip_root) && zip -qryX $(abspath $@) *)
	$(hide) echo $(OTATOOLS_DEPS) | xargs zip -qryX $(abspath $@)>/dev/null || true

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
tool_extensions := $(TARGET_DEVICE_DIR)/../common
else
tool_extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif
tool_extension := $(wildcard $(tool_extensions)/releasetools.py)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_TOOL_EXTENSIONS := $(tool_extensions)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_TOOL_EXTENSION := $(tool_extension)

ifeq ($(AB_OTA_UPDATER),true)
updater_dep := system/update_engine/update_engine.conf
else
# Build OTA tools if not using the AB Updater.
updater_dep := $(built_ota_tools)
endif
$(BUILT_TARGET_FILES_PACKAGE): $(updater_dep)

# If we are using recovery as boot, output recovery files to BOOT/.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := BOOT
else
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := RECOVERY
endif

ifeq ($(AB_OTA_UPDATER),true)
  ifdef BRILLO_VENDOR_PARTITIONS
    $(BUILT_TARGET_FILES_PACKAGE): $(foreach p,$(BRILLO_VENDOR_PARTITIONS),\
                                     $(call word-colon,1,$(p))/$(call word-colon,2,$(p)))
  endif
  ifdef OSRELEASED_DIRECTORY
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version
  endif
endif

# Run fs_config while creating the target files package
# $1: root directory
# $2: add prefix
define fs_config
(cd $(1); find . -type d | sed 's,$$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,$(2),' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) -R "$(2)"
endef

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_PACKAGE): \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_RADIOIMAGE_TARGET) \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(FULL_SYSTEMIMAGE_DEPS) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_CACHEIMAGE_TARGET) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_PRODUCTIMAGE_TARGET) \
		$(INSTALLED_VBMETAIMAGE_TARGET) \
		$(INSTALLED_DTBOIMAGE_TARGET) \
		$(INTERNAL_SYSTEMOTHERIMAGE_FILES) \
		$(INSTALLED_ANDROID_INFO_TXT_TARGET) \
		$(INSTALLED_KERNEL_TARGET) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH) \
		$(SELINUX_FC) \
		$(APKCERTS_FILE) \
		$(SOONG_ZIP) \
		$(HOST_OUT_EXECUTABLES)/fs_config \
		$(HOST_OUT_EXECUTABLES)/imgdiff \
		$(HOST_OUT_EXECUTABLES)/bsdiff \
		$(BUILD_IMAGE_SRCS) \
		$(BUILT_VENDOR_MANIFEST) \
		$(BUILT_VENDOR_MATRIX) \
		| $(ACP)
	@echo "Package target files: $@"
	$(call create-system-vendor-symlink)
	$(call create-system-product-symlink)
	$(hide) rm -rf $@ $@.list $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/$(PRIVATE_RECOVERY_OUT)
	$(hide) $(call package_files-copy-root, \
		$(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/$(PRIVATE_RECOVERY_OUT)/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) cp $(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/second
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
	$(hide) cp $(INSTALLED_DTBOIMAGE_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/recovery_dtbo
endif
ifdef INTERNAL_KERNEL_CMDLINE
	$(hide) echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/cmdline
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
	$(hide) cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/BOOT/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) cp $(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/BOOT/second
endif
ifdef INTERNAL_KERNEL_CMDLINE
	$(hide) echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
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
	            cp $(t) $(zip_root)/RADIO/$(notdir $(t));)
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
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
	@# Contents of the product image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_PRODUCT),$(zip_root)/PRODUCT)
endif
ifdef INSTALLED_SYSTEMOTHERIMAGE_TARGET
	@# Contents of the system_other image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_SYSTEM_OTHER),$(zip_root)/SYSTEM_OTHER)
endif
	@# Extra contents of the OTA package
	$(hide) mkdir -p $(zip_root)/OTA
	$(hide) cp $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(zip_root)/OTA/
ifneq ($(AB_OTA_UPDATER),true)
ifneq ($(built_ota_tools),)
	$(hide) mkdir -p $(zip_root)/OTA/bin
	$(hide) cp $(PRIVATE_OTA_TOOLS) $(zip_root)/OTA/bin/
endif
endif
	@# Files that do not end up in any images, but are necessary to
	@# build them.
	$(hide) mkdir -p $(zip_root)/META
	$(hide) cp $(APKCERTS_FILE) $(zip_root)/META/apkcerts.txt
ifneq ($(tool_extension),)
	$(hide) cp $(PRIVATE_TOOL_EXTENSION) $(zip_root)/META/
endif
	$(hide) echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) cp $(SELINUX_FC) $(zip_root)/META/file_contexts.bin
	$(hide) echo "recovery_api_version=$(PRIVATE_RECOVERY_API_VERSION)" > $(zip_root)/META/misc_info.txt
	$(hide) echo "fstab_version=$(PRIVATE_RECOVERY_FSTAB_VERSION)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_FLASH_BLOCK_SIZE
	$(hide) echo "blocksize=$(BOARD_FLASH_BLOCK_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
	$(hide) echo "boot_size=$(BOARD_BOOTIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) echo "no_recovery=true" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
	$(hide) echo "include_recovery_dtbo=true" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
	$(hide) echo "recovery_size=$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS
	@# TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS can be empty to indicate that nothing but defaults should be used.
	$(hide) echo "recovery_mount_options=$(TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
else
	$(hide) echo "recovery_mount_options=$(DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo "tool_extensions=$(PRIVATE_TOOL_EXTENSIONS)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "default_system_dev_certificate=$(DEFAULT_SYSTEM_DEV_CERTIFICATE)" >> $(zip_root)/META/misc_info.txt
ifdef PRODUCT_EXTRA_RECOVERY_KEYS
	$(hide) echo "extra_recovery_keys=$(PRODUCT_EXTRA_RECOVERY_KEYS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo 'mkbootimg_args=$(BOARD_MKBOOTIMG_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo 'mkbootimg_version_args=$(INTERNAL_MKBOOTIMG_VERSION_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo "multistage_support=1" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "blockimgdiff_versions=3,4" >> $(zip_root)/META/misc_info.txt
ifneq ($(OEM_THUMBPRINT_PROPERTIES),)
	# OTA scripts are only interested in fingerprint related properties
	$(hide) echo "oem_fingerprint_properties=$(OEM_THUMBPRINT_PROPERTIES)" >> $(zip_root)/META/misc_info.txt
endif
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH))
endif
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH),)
	$(hide) cp $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH))
endif
ifneq ($(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH),)
	$(hide) cp $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH))
endif
ifneq ($(strip $(SANITIZE_TARGET)),)
	# We need to create userdata.img with real data because the instrumented libraries are in userdata.img.
	$(hide) echo "userdata_img_with_data=true" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(BOARD_USES_FULL_RECOVERY_IMAGE),true)
	$(hide) echo "full_recovery_image=true" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(BOARD_AVB_ENABLE),true)
	$(hide) echo "avb_enable=true" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_vbmeta_key_path=$(BOARD_AVB_KEY_PATH)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_vbmeta_algorithm=$(BOARD_AVB_ALGORITHM)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_vbmeta_args=$(BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_boot_add_hash_footer_args=$(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_AVB_BOOT_KEY_PATH
	$(hide) echo "avb_boot_key_path=$(BOARD_AVB_BOOT_KEY_PATH)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_boot_algorithm=$(BOARD_AVB_BOOT_ALGORITHM)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_boot_rollback_index_location=$(BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION)" >> $(zip_root)/META/misc_info.txt
endif # BOARD_AVB_BOOT_KEY_PATH
	$(hide) echo "avb_recovery_add_hash_footer_args=$(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_AVB_RECOVERY_KEY_PATH
	$(hide) echo "avb_recovery_key_path=$(BOARD_AVB_RECOVERY_KEY_PATH)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_recovery_algorithm=$(BOARD_AVB_RECOVERY_ALGORITHM)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_recovery_rollback_index_location=$(BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION)" >> $(zip_root)/META/misc_info.txt
endif # BOARD_AVB_RECOVERY_KEY_PATH
endif # BOARD_AVB_ENABLE
ifdef BOARD_BPT_INPUT_FILES
	$(hide) echo "board_bpt_enable=true" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "board_bpt_make_table_args=$(BOARD_BPT_MAKE_TABLE_ARGS)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "board_bpt_input_files=$(BOARD_BPT_INPUT_FILES)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_BPT_DISK_SIZE
	$(hide) echo "board_bpt_disk_size=$(BOARD_BPT_DISK_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
	$(call generate-userimage-prop-dictionary, $(zip_root)/META/misc_info.txt)
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    build/make/tools/releasetools/make_recovery_patch $(zip_root) $(zip_root)
endif
ifeq ($(AB_OTA_UPDATER),true)
	@# When using the A/B updater, include the updater config files in the zip.
	$(hide) cp $(TOPDIR)system/update_engine/update_engine.conf $(zip_root)/META/update_engine_config.txt
	$(hide) for part in $(AB_OTA_PARTITIONS); do \
	  echo "$${part}" >> $(zip_root)/META/ab_partitions.txt; \
	done
	$(hide) for conf in $(AB_OTA_POSTINSTALL_CONFIG); do \
	  echo "$${conf}" >> $(zip_root)/META/postinstall_config.txt; \
	done
	@# Include the build type in META/misc_info.txt so the server can easily differentiate production builds.
	$(hide) echo "build_type=$(TARGET_BUILD_VARIANT)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "ab_update=true" >> $(zip_root)/META/misc_info.txt
ifdef BRILLO_VENDOR_PARTITIONS
	$(hide) mkdir -p $(zip_root)/VENDOR_IMAGES
	$(hide) for f in $(BRILLO_VENDOR_PARTITIONS); do \
	  pair1="$$(echo $$f | awk -F':' '{print $$1}')"; \
	  pair2="$$(echo $$f | awk -F':' '{print $$2}')"; \
	  src=$${pair1}/$${pair2}; \
	  dest=$(zip_root)/VENDOR_IMAGES/$${pair2}; \
	  mkdir -p $$(dirname "$${dest}"); \
	  cp $${src} $${dest}; \
	done;
endif
ifdef OSRELEASED_DIRECTORY
	$(hide) cp $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id $(zip_root)/META/product_id.txt
	$(hide) cp $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version $(zip_root)/META/product_version.txt
	$(hide) cp $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version $(zip_root)/META/system_version.txt
endif
endif
ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
	@# If breakpad symbols have been generated, add them to the zip.
	$(hide) $(ACP) -r $(TARGET_OUT_BREAKPAD) $(zip_root)/BREAKPAD
endif
# BOARD_BUILD_DISABLED_VBMETAIMAGE is used to build a special vbmeta.img
# that disables AVB verification. The content is fixed and we can just copy
# it to $(zip_root)/IMAGES without passing some info into misc_info.txt for
# regeneration.
ifeq (true,$(BOARD_BUILD_DISABLED_VBMETAIMAGE))
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_VBMETAIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_VENDORIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_VENDORIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_PRODUCTIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_PRODUCTIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_BOOTIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_BOOTIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_DTBOIMAGE
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_DTBOIMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
	$(hide) echo "has_dtbo=true" >> $(zip_root)/META/misc_info.txt
ifeq ($(BOARD_AVB_ENABLE),true)
	$(hide) echo "dtbo_size=$(BOARD_DTBOIMG_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_dtbo_add_hash_footer_args=$(BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_AVB_DTBO_KEY_PATH
	$(hide) echo "avb_dtbo_key_path=$(BOARD_AVB_DTBO_KEY_PATH)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_dtbo_algorithm=$(BOARD_AVB_DTBO_ALGORITHM)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "avb_dtbo_rollback_index_location=$(BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION)" \
	    >> $(zip_root)/META/misc_info.txt
endif # BOARD_AVB_DTBO_KEY_PATH
endif # BOARD_AVB_ENABLE
endif # BOARD_PREBUILT_DTBOIMAGE
	@# The radio images in BOARD_PACK_RADIOIMAGES will be additionally copied from RADIO/ into
	@# IMAGES/, which then will be added into <product>-img.zip. Such images must be listed in
	@# INSTALLED_RADIOIMAGE_TARGET.
	$(hide) $(foreach part,$(BOARD_PACK_RADIOIMAGES), \
	    echo $(part) >> $(zip_root)/META/pack_radioimages.txt;)
	@# Run fs_config on all the system, vendor, boot ramdisk,
	@# and recovery ramdisk files in the zip, and save the output
	$(hide) $(call fs_config,$(zip_root)/SYSTEM,system/) > $(zip_root)/META/filesystem_config.txt
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
	$(hide) $(call fs_config,$(zip_root)/VENDOR,vendor/) > $(zip_root)/META/vendor_filesystem_config.txt
endif
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
	$(hide) $(call fs_config,$(zip_root)/PRODUCT,product/) > $(zip_root)/META/product_filesystem_config.txt
endif
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	@# When using BOARD_BUILD_SYSTEM_ROOT_IMAGE, ROOT always contains the files for the root under
	@# normal boot. BOOT/RAMDISK exists only if additionally using BOARD_USES_RECOVERY_AS_BOOT.
	$(hide) $(call fs_config,$(zip_root)/ROOT,) > $(zip_root)/META/root_filesystem_config.txt
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
	$(hide) $(call fs_config,$(zip_root)/BOOT/RAMDISK,) > $(zip_root)/META/boot_filesystem_config.txt
endif
else # BOARD_BUILD_SYSTEM_ROOT_IMAGE != true
	$(hide) $(call fs_config,$(zip_root)/BOOT/RAMDISK,) > $(zip_root)/META/boot_filesystem_config.txt
endif
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) $(call fs_config,$(zip_root)/RECOVERY/RAMDISK,) > $(zip_root)/META/recovery_filesystem_config.txt
endif
ifdef INSTALLED_SYSTEMOTHERIMAGE_TARGET
	$(hide) $(call fs_config,$(zip_root)/SYSTEM_OTHER,system/) > $(zip_root)/META/system_other_filesystem_config.txt
endif
	@# Metadata for compatibility verification.
	$(hide) cp $(BUILT_SYSTEM_MANIFEST) $(zip_root)/META/system_manifest.xml
	$(hide) cp $(BUILT_SYSTEM_COMPATIBILITY_MATRIX) $(zip_root)/META/system_matrix.xml
ifdef BUILT_VENDOR_MANIFEST
	$(hide) cp $(BUILT_VENDOR_MANIFEST) $(zip_root)/META/vendor_manifest.xml
endif
ifdef BUILT_VENDOR_MATRIX
	$(hide) cp $(BUILT_VENDOR_MATRIX) $(zip_root)/META/vendor_matrix.xml
endif

	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    build/make/tools/releasetools/add_img_to_target_files -a -v -p $(HOST_OUT) $(zip_root)
	@# Zip everything up, preserving symlinks and placing META/ files first to
	@# help early validation of the .zip file while uploading it.
	$(hide) find $(zip_root)/META | sort >$@.list
	$(hide) find $(zip_root) -path $(zip_root)/META -prune -o -print | sort >>$@.list
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(zip_root) -l $@.list

.PHONY: target-files-package
target-files-package: $(BUILT_TARGET_FILES_PACKAGE)

ifneq ($(filter $(MAKECMDGOALS),target-files-package),)
$(call dist-for-goals, target-files-package, $(BUILT_TARGET_FILES_PACKAGE))
endif

# -----------------------------------------------------------------
# NDK Sysroot Package
NDK_SYSROOT_TARGET := $(PRODUCT_OUT)/ndk_sysroot.tar.bz2
$(NDK_SYSROOT_TARGET): ndk
	@echo Package NDK sysroot...
	$(hide) tar cjf $@ -C $(SOONG_OUT_DIR) ndk

$(call dist-for-goals,sdk,$(NDK_SYSROOT_TARGET))

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

ifeq ($(AB_OTA_UPDATER),true)
$(INTERNAL_OTA_PACKAGE_TARGET): $(BRILLO_UPDATE_PAYLOAD)
else
$(INTERNAL_OTA_PACKAGE_TARGET): $(BROTLI)
endif

$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) \
		build/make/tools/releasetools/ota_from_target_files
	@echo "Package OTA: $@"
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   build/make/tools/releasetools/ota_from_target_files -v \
	   --block \
	   --extracted_input_target_files $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) \
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

$(INTERNAL_UPDATE_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(ZIP2ZIP)
	@echo "Package: $@"
	$(hide) $(ZIP2ZIP) -i $(BUILT_TARGET_FILES_PACKAGE) -o $@ \
	   OTA/android-info.txt:android-info.txt "IMAGES/*.img:."

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
# For apps_only build we'll establish the dependency later in build/make/core/main.mk.
ifndef TARGET_BUILD_APPS
$(SYMBOLS_ZIP): $(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_PRODUCTIMAGE_TARGET) \
		$(updater_dep)
endif
$(SYMBOLS_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,symbols)/filelist
$(SYMBOLS_ZIP): $(SOONG_ZIP)
	@echo "Package symbols: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_UNSTRIPPED) $(dir $(PRIVATE_LIST_FILE))
	$(hide) find $(TARGET_OUT_UNSTRIPPED) | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(OUT_DIR)/.. -l $(PRIVATE_LIST_FILE)
# -----------------------------------------------------------------
# A zip of the coverage directory.
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
name := $(name)_debug
endif
name := $(name)-coverage-$(FILE_NAME_TAG)
COVERAGE_ZIP := $(PRODUCT_OUT)/$(name).zip
ifndef TARGET_BUILD_APPS
$(COVERAGE_ZIP): $(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_PRODUCTIMAGE_TARGET)
endif
$(COVERAGE_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,coverage)/filelist
$(COVERAGE_ZIP): $(SOONG_ZIP)
	@echo "Package coverage: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_COVERAGE) $(dir $(PRIVATE_LIST_FILE))
	$(hide) find $(TARGET_OUT_COVERAGE) | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(TARGET_OUT_COVERAGE) -l $(PRIVATE_LIST_FILE)

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

ifeq (true,$(EMMA_INSTRUMENT))
#------------------------------------------------------------------
# An archive of classes for use in generating code-coverage reports
# These are the uninstrumented versions of any classes that were
# to be instrumented.
# Any dependencies are set up later in build/make/core/main.mk.

JACOCO_REPORT_CLASSES_ALL := $(PRODUCT_OUT)/jacoco-report-classes-all.jar
$(JACOCO_REPORT_CLASSES_ALL) :
	@echo "Collecting uninstrumented classes"
	$(hide) find $(TARGET_COMMON_OUT_ROOT) $(HOST_COMMON_OUT_ROOT) -name "jacoco-report-classes.jar" | \
		zip -@ -0 -q -X $@
# Meaning of these options:
# -@ scan stdin for file paths to add to the zip
# -0 don't do any compression
# -q supress most output
# -X skip storing extended file attributes

endif # EMMA_INSTRUMENT=true


#------------------------------------------------------------------
# A zip of Proguard obfuscation dictionary files.
# Only for apps_only build.
#
ifdef TARGET_BUILD_APPS
PROGUARD_DICT_ZIP := $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-dict-$(FILE_NAME_TAG).zip
# the dependency will be set up later in build/make/core/main.mk.
$(PROGUARD_DICT_ZIP) :
	@echo "Packaging Proguard obfuscation dictionary files."
	$(hide) dict_files=`find $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS -name proguard_dictionary`; \
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

ifeq ($(BUILD_QEMU_IMAGES),true)
INSTALLED_QEMU_SYSTEMIMAGE := $(PRODUCT_OUT)/system-qemu.img
MK_QEMU_IMAGE_SH := device/generic/goldfish/tools/mk_qemu_image.sh
SGDISK_HOST := $(HOST_OUT_EXECUTABLES)/sgdisk
$(INSTALLED_QEMU_SYSTEMIMAGE): $(INSTALLED_SYSTEMIMAGE) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create system-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) ${PRODUCT_OUT}/system.img)

systemimage: $(INSTALLED_QEMU_SYSTEMIMAGE)
droidcore: $(INSTALLED_QEMU_SYSTEMIMAGE)
ifeq ($(BOARD_USES_VENDORIMAGE),true)
INSTALLED_QEMU_VENDORIMAGE := $(PRODUCT_OUT)/vendor-qemu.img
$(INSTALLED_QEMU_VENDORIMAGE): $(INSTALLED_VENDORIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create vendor-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) ${PRODUCT_OUT}/vendor.img)

vendorimage: $(INSTALLED_QEMU_VENDORIMAGE)
droidcore: $(INSTALLED_QEMU_VENDORIMAGE)
endif
ifeq ($(BOARD_USES_PRODUCTIMAGE),true)
INSTALLED_QEMU_PRODUCTIMAGE := $(PRODUCT_OUT)/product-qemu.img
$(INSTALLED_QEMU_PRODUCTIMAGE): $(INSTALLED_PRODUCTIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create product-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) ${PRODUCT_OUT}/product.img)

productimage: $(INSTALLED_QEMU_PRODUCTIMAGE)
droidcore: $(INSTALLED_QEMU_PRODUCTIMAGE)
endif
endif
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
	$(COVERAGE_ZIP) \
	$(INSTALLED_SYSTEMIMAGE) \
	$(INSTALLED_QEMU_SYSTEMIMAGE) \
	$(INSTALLED_QEMU_VENDORIMAGE) \
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
# Also add test specifc tasks
include $(sort $(wildcard platform_testing/build/tasks/*.mk))
include $(sort $(wildcard test/vts/tools/build/tasks/*.mk))
endif

include $(BUILD_SYSTEM)/product-graph.mk

# -----------------------------------------------------------------
# Create SDK repository packages. Must be done after tasks/* since
# we need the addon rules defined.
ifneq ($(sdk_repo_goal),)
include $(TOPDIR)development/build/tools/sdk_repo.mk
endif

#------------------------------------------------------------------
# Find lsdump paths
FIND_LSDUMPS_FILE := $(PRODUCT_OUT)/lsdump_paths.txt
$(FIND_LSDUMPS_FILE) : $(LSDUMP_PATHS)
	$(hide) rm -rf $@ && echo "$^" > $@
