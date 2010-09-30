# Put some miscellaneous rules here

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
# PRODUCT_COPY_FILES contains words like <source file>:<dest file>.
# <dest file> is relative to $(PRODUCT_OUT), so it should look like,
# e.g., "system/etc/file.xml".
# The filter part means "only eval the copy-one-file rule if this
# src:dest pair is the first one to match %:dest"
$(foreach cf,$(PRODUCT_COPY_FILES), \
  $(eval _src := $(call word-colon,1,$(cf))) \
  $(eval _dest := $(call word-colon,2,$(cf))) \
  $(eval _fulldest := $(call append-path,$(PRODUCT_OUT),$(_dest))) \
  $(if $(filter $(_src):$(_dest),$(firstword $(filter %:$(_dest),$(PRODUCT_COPY_FILES)))), \
    $(eval $(call copy-one-file,$(_src),$(_fulldest))),) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(_fulldest)) \
 )

# -----------------------------------------------------------------
# docs/index.html
gen := $(OUT_DOCS)/index.html
ALL_DOCS += $(gen)
$(gen): frameworks/base/docs/docs-redirect-index.html
	@mkdir -p $(dir $@)
	@cp -f $< $@

# -----------------------------------------------------------------
# default.prop
INSTALLED_DEFAULT_PROP_TARGET := $(TARGET_ROOT_OUT)/default.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_DEFAULT_PROP_TARGET)
ADDITIONAL_DEFAULT_PROPERTIES := \
	$(call collapse-pairs, $(ADDITIONAL_DEFAULT_PROPERTIES))

$(INSTALLED_DEFAULT_PROP_TARGET):
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) echo "#" > $@; \
	        echo "# ADDITIONAL_DEFAULT_PROPERTIES" >> $@; \
	        echo "#" >> $@;
	$(hide) $(foreach line,$(ADDITIONAL_DEFAULT_PROPERTIES), \
		echo "$(line)" >> $@;)

# -----------------------------------------------------------------
# build.prop
INSTALLED_BUILD_PROP_TARGET := $(TARGET_OUT)/build.prop
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_BUILD_PROP_TARGET)
ADDITIONAL_BUILD_PROPERTIES := \
	$(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))

# A list of arbitrary tags describing the build configuration.
# Force ":=" so we can use +=
BUILD_VERSION_TAGS := $(BUILD_VERSION_TAGS)
ifeq ($(TARGET_BUILD_TYPE),debug)
  BUILD_VERSION_TAGS += debug
endif
# Apps are always signed with test keys, and may be re-signed in a post-build
# step.  If that happens, the "test-keys" tag will be removed by that step.
BUILD_VERSION_TAGS += test-keys
BUILD_VERSION_TAGS := $(subst $(space),$(comma),$(sort $(BUILD_VERSION_TAGS)))

# A human-readable string that descibes this build in detail.
build_desc := $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) $(PLATFORM_VERSION) $(BUILD_ID) $(BUILD_NUMBER) $(BUILD_VERSION_TAGS)
$(INSTALLED_BUILD_PROP_TARGET): PRIVATE_BUILD_DESC := $(build_desc)

# The string used to uniquely identify this build;  used by the OTA server.
ifeq (,$(strip $(BUILD_FINGERPRINT)))
  BUILD_FINGERPRINT := $(PRODUCT_BRAND)/$(TARGET_PRODUCT)/$(TARGET_DEVICE):$(PLATFORM_VERSION)/$(BUILD_ID)/$(BUILD_NUMBER):$(TARGET_BUILD_VARIANT)/$(BUILD_VERSION_TAGS)
endif
ifneq ($(words $(BUILD_FINGERPRINT)),1)
  $(error BUILD_FINGERPRINT cannot contain spaces: "$(BUILD_FINGERPRINT)")
endif

# Display parameters shown under Settings -> About Phone
ifeq ($(TARGET_BUILD_VARIANT),user)
  # User builds should show:
  # release build number or branch.buld_number non-release builds

  # Dev. branches should have DISPLAY_BUILD_NUMBER set
  ifeq "true" "$(DISPLAY_BUILD_NUMBER)"
    BUILD_DISPLAY_ID := $(BUILD_ID).$(BUILD_NUMBER)
  else
    BUILD_DISPLAY_ID := $(BUILD_ID)
  endif
else
  # Non-user builds should show detailed build information
  BUILD_DISPLAY_ID := $(build_desc)
endif

# Whether there is default locale set in PRODUCT_PROPERTY_OVERRIDES
product_property_override_locale_language := $(strip \
    $(patsubst ro.product.locale.language=%,%,\
    $(filter ro.product.locale.language=%,$(PRODUCT_PROPERTY_OVERRIDES))))
product_property_overrides_locale_region := $(strip \
    $(patsubst ro.product.locale.region=%,%,\
    $(filter ro.product.locale.region=%,$(PRODUCT_PROPERTY_OVERRIDES))))

# Selects the first locale in the list given as the argument,
# and splits it into language and region, which each may be
# empty.
define default-locale
$(subst _, , $(firstword $(1)))
endef

# Selects the first locale in the list given as the argument
# and returns the language (or the region), if it's not set in PRODUCT_PROPERTY_OVERRIDES;
# Return empty string if it's already set in PRODUCT_PROPERTY_OVERRIDES.
define default-locale-language
$(if $(product_property_override_locale_language),,$(word 1, $(call default-locale, $(1))))
endef
define default-locale-region
$(if $(product_property_overrides_locale_region),,$(word 2, $(call default-locale, $(1))))
endef

BUILDINFO_SH := build/tools/buildinfo.sh
$(INSTALLED_BUILD_PROP_TARGET): $(BUILDINFO_SH) $(INTERNAL_BUILD_ID_MAKEFILE) $(wildcard $(TARGET_DEVICE_DIR)/system.prop)
	@echo Target buildinfo: $@
	@mkdir -p $(dir $@)
	$(hide) TARGET_BUILD_TYPE="$(TARGET_BUILD_VARIANT)" \
			TARGET_DEVICE="$(TARGET_DEVICE)" \
			PRODUCT_NAME="$(TARGET_PRODUCT)" \
			PRODUCT_BRAND="$(PRODUCT_BRAND)" \
			PRODUCT_DEFAULT_LANGUAGE="$(call default-locale-language,$(PRODUCT_LOCALES))" \
			PRODUCT_DEFAULT_REGION="$(call default-locale-region,$(PRODUCT_LOCALES))" \
			PRODUCT_DEFAULT_WIFI_CHANNELS="$(PRODUCT_DEFAULT_WIFI_CHANNELS)" \
			PRODUCT_MODEL="$(PRODUCT_MODEL)" \
			PRODUCT_MANUFACTURER="$(PRODUCT_MANUFACTURER)" \
			PRIVATE_BUILD_DESC="$(PRIVATE_BUILD_DESC)" \
			BUILD_ID="$(BUILD_ID)" \
			BUILD_DISPLAY_ID="$(BUILD_DISPLAY_ID)" \
			BUILD_NUMBER="$(BUILD_NUMBER)" \
			PLATFORM_VERSION="$(PLATFORM_VERSION)" \
			PLATFORM_SDK_VERSION="$(PLATFORM_SDK_VERSION)" \
			PLATFORM_VERSION_CODENAME="$(PLATFORM_VERSION_CODENAME)" \
			BUILD_VERSION_TAGS="$(BUILD_VERSION_TAGS)" \
			TARGET_BOOTLOADER_BOARD_NAME="$(TARGET_BOOTLOADER_BOARD_NAME)" \
			BUILD_FINGERPRINT="$(BUILD_FINGERPRINT)" \
			TARGET_BOARD_PLATFORM="$(TARGET_BOARD_PLATFORM)" \
			TARGET_CPU_ABI="$(TARGET_CPU_ABI)" \
			TARGET_CPU_ABI2="$(TARGET_CPU_ABI2)" \
	        bash $(BUILDINFO_SH) > $@
	$(hide) if [ -f $(TARGET_DEVICE_DIR)/system.prop ]; then \
	          cat $(TARGET_DEVICE_DIR)/system.prop >> $@; \
	        fi
	$(if $(ADDITIONAL_BUILD_PROPERTIES), \
		$(hide) echo >> $@; \
		        echo "#" >> $@; \
		        echo "# ADDITIONAL_BUILD_PROPERTIES" >> $@; \
		        echo "#" >> $@; )
	$(hide) $(foreach line,$(ADDITIONAL_BUILD_PROPERTIES), \
		echo "$(line)" >> $@;)

build_desc :=

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
	$(hide) build/tools/dump-package-stats $^ > $@

.PHONY: package-stats
package-stats: $(PACKAGE_STATS_FILE)

# -----------------------------------------------------------------
# Cert-to-package mapping.  Used by the post-build signing tools.
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-apkcerts-$(FILE_NAME_TAG)
intermediates := \
	$(call intermediates-dir-for,PACKAGING,apkcerts)
APKCERTS_FILE := $(intermediates)/$(name).txt
# Depending on the built packages isn't exactly right,
# but it should guarantee that the apkcerts file is rebuilt
# if any packages change which certs they're signed with.
all_built_packages := $(foreach p,$(PACKAGES),$(ALL_MODULES.$(p).BUILT))
ifneq ($(TARGET_BUILD_APPS),)
# We don't need to really build all the modules for apps_only build.
$(APKCERTS_FILE):
else
$(APKCERTS_FILE): $(all_built_packages)
endif
	@echo APK certs list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(foreach p,$(PACKAGES),\
          $(if $(PACKAGES.$(p).EXTERNAL_KEY),\
	    echo 'name="$(p).apk" certificate="EXTERNAL" \
	         private_key=""' >> $@;,\
	    echo 'name="$(p).apk" certificate="$(PACKAGES.$(p).CERTIFICATE)" \
	         private_key="$(PACKAGES.$(p).PRIVATE_KEY)"' >> $@;))

.PHONY: apkcerts-list
apkcerts-list: $(APKCERTS_FILE)

$(call dist-for-goals, apps_only, $(APKCERTS_FILE):apkcerts.txt)

# -----------------------------------------------------------------
# module info file
ifdef CREATE_MODULE_INFO_FILE
  MODULE_INFO_FILE := $(PRODUCT_OUT)/module-info.txt
  $(info Generating $(MODULE_INFO_FILE)...)
  $(shell rm -f $(MODULE_INFO_FILE))
  $(foreach m,$(ALL_MODULES), \
    $(shell echo "NAME=\"$(m)\"" \
	"PATH=\"$(strip $(ALL_MODULES.$(m).PATH))\"" \
	"TAGS=\"$(strip $(filter-out _%,$(ALL_MODULES.$(m).TAGS)))\"" \
	"BUILT=\"$(strip $(ALL_MODULES.$(m).BUILT))\"" \
	"INSTALLED=\"$(strip $(ALL_MODULES.$(m).INSTALLED))\"" >> $(MODULE_INFO_FILE)))
endif

# -----------------------------------------------------------------

# The test key is used to sign this package, and as the key required
# for future OTA packages installed by this system.  Actual product
# deliverables will be re-signed by hand.  We expect this file to
# exist with the suffixes ".x509.pem" and ".pk8".
DEFAULT_KEY_CERT_PAIR := $(SRC_TARGET_DIR)/product/security/testkey


# Rules that need to be present for the simulator, even
# if they don't do anything.
.PHONY: systemimage
systemimage:

# -----------------------------------------------------------------

.PHONY: event-log-tags

# Produce an event logs tag file for everything we know about, in order
# to properly allocate numbers.  Then produce a file that's filtered
# for what's going to be installed.

all_event_log_tags_file := $(TARGET_OUT_COMMON_INTERMEDIATES)/all-event-log-tags.txt

# Include tags from all packages that we know about
all_event_log_tags_src := \
    $(sort $(foreach m, $(ALL_MODULES), $(ALL_MODULES.$(m).EVENT_LOG_TAGS)))

$(all_event_log_tags_file): PRIVATE_SRC_FILES := $(all_event_log_tags_src)
$(all_event_log_tags_file): $(all_event_log_tags_src)
	$(hide) mkdir -p $(dir $@)
	$(hide) build/tools/merge-event-log-tags.py -o $@ $(PRIVATE_SRC_FILES)


event_log_tags_file := $(TARGET_OUT)/etc/event-log-tags

# Include tags from all packages included in this product.
event_log_tags_src := \
    $(sort $(foreach m,\
      $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES) \
      $(call module-names-for-tag-list,user), \
      $(ALL_MODULES.$(m).EVENT_LOG_TAGS)))

$(event_log_tags_file): PRIVATE_SRC_FILES := $(event_log_tags_src)
$(event_log_tags_file): PRIVATE_MERGED_FILE := $(all_event_log_tags_file)
$(event_log_tags_file): $(event_log_tags_src) $(all_event_log_tags_file)
	$(hide) mkdir -p $(dir $@)
	$(hide) build/tools/merge-event-log-tags.py -o $@ -m $(PRIVATE_MERGED_FILE) $(PRIVATE_SRC_FILES)

event-log-tags: $(event_log_tags_file)

ALL_DEFAULT_INSTALLED_MODULES += $(event_log_tags_file)


ifneq ($(TARGET_SIMULATOR),true)

# #################################################################
# Targets for boot/OS images
# #################################################################

# -----------------------------------------------------------------
# the ramdisk
INTERNAL_RAMDISK_FILES := $(filter $(TARGET_ROOT_OUT)/%, \
	$(ALL_PREBUILT) \
	$(ALL_COPIED_HEADERS) \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

BUILT_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img

# We just build this directly to the install location.
INSTALLED_RAMDISK_TARGET := $(BUILT_RAMDISK_TARGET)
$(INSTALLED_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_RAMDISK_FILES) | $(MINIGZIP)
	$(call pretty,"Target ram disk: $@")
	$(hide) $(MKBOOTFS) $(TARGET_ROOT_OUT) | $(MINIGZIP) > $@


ifneq ($(strip $(TARGET_NO_KERNEL)),true)

# -----------------------------------------------------------------
# the boot image, which is a collection of other images.
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET) \
	--ramdisk $(INSTALLED_RAMDISK_TARGET)

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

BOARD_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE))
ifdef BOARD_KERNEL_CMDLINE
  INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(BOARD_KERNEL_CMDLINE)"
endif

BOARD_KERNEL_BASE := $(strip $(BOARD_KERNEL_BASE))
ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

BOARD_KERNEL_PAGESIZE := $(strip $(BOARD_KERNEL_PAGESIZE))
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img

ifeq ($(TARGET_BOOTIMAGE_USE_EXT2),true)
tmp_dir_for_image := $(call intermediates-dir-for,EXECUTABLES,boot_img)/bootimg
INTERNAL_BOOTIMAGE_ARGS += --tmpdir $(tmp_dir_for_image)
INTERNAL_BOOTIMAGE_ARGS += --genext2fs $(MKEXT2IMG)
$(INSTALLED_BOOTIMAGE_TARGET): $(MKEXT2IMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKEXT2BOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) --output $@

else # TARGET_BOOTIMAGE_USE_EXT2 != true

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_BOOTIMAGE_PARTITION_SIZE),raw)
endif # TARGET_BOOTIMAGE_USE_EXT2

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
$(1) $(2) $(4)/hash-timestamp: PRIVATE_DIR := $(4)
$(4)/hash-timestamp: $(5) $(BUILD_SYSTEM)/Makefile
	@echo Finding NOTICE files: $$@
	$$(hide) rm -rf $$@ $$(PRIVATE_DIR)/hash
	$$(hide) mkdir -p $$(PRIVATE_DIR)/hash
	$$(hide) for file in $$$$(find $$(PRIVATE_DIR)/src -type f); do \
			hash=$$$$($(MD5SUM) $$$$file | sed -e "s/ .*//"); \
			hashfile=$$(PRIVATE_DIR)/hash/$$$$hash; \
			echo $$$$file >> $$$$hashfile; \
		done
	$$(hide) touch $$@
$(1): $(4)/hash-timestamp
	@echo Combining NOTICE files: $$@
	$$(hide) mkdir -p $$(dir $$@)
	$$(hide) echo $$(PRIVATE_MESSAGE) > $$@
	$$(hide) find $$(PRIVATE_DIR)/hash -type f | xargs cat | sort | \
		sed -e "s:$$(PRIVATE_DIR)/src\(.*\)\.txt:  \1:" >> $$@
	$$(hide) echo >> $$@
	$$(hide) echo >> $$@
	$$(hide) echo >> $$@
	$$(hide) for hashfile in $$$$(find $$(PRIVATE_DIR)/hash -type f); do \
			echo "============================================================"\
				>> $$@; \
			echo "Notices for file(s):" >> $$@; \
			cat $$$$hashfile | sort | \
				sed -e "s:$$(PRIVATE_DIR)/src\(.*\)\.txt:  \1:" >> \
				$$@; \
			echo "------------------------------------------------------------"\
				>> $$@; \
			echo >> $$@; \
			orig=$$$$(head -n 1 $$$$hashfile); \
			cat $$$$orig >> $$@; \
			echo >> $$@; \
			echo >> $$@; \
			echo >> $$@; \
		done
$(2): $(4)/hash-timestamp
	@echo Combining NOTICE files: $$@
	$$(hide) mkdir -p $$(dir $$@)
	$$(hide) echo "<html><head>" > $$@
	$$(hide) echo "<style type=\"text/css\">" >> $$@
	$$(hide) echo "body { padding: 0; font-family: sans-serif; }" >> $$@
	$$(hide) echo ".same-license { background-color: #eeeeee; border-top: 20px solid white; padding: 10px; }" >> $$@
	$$(hide) echo ".label { font-weight: bold; }" >> $$@
	$$(hide) echo ".file-list { margin-left: 1em; font-color: blue; }" >> $$@
	$$(hide) echo "</style>" >> $$@
	$$(hide) echo "</head><body topmargin=\"0\" leftmargin=\"0\" rightmargin=\"0\" bottommargin=\"0\">" >> $$@
	$$(hide) echo "<table cellpading=\"0\" cellspacing=\"0\" border=\"0\">" \
		>> $$@
	$$(hide) for hashfile in $$$$(find $$(PRIVATE_DIR)/hash -type f); do \
			cat $$$$hashfile | sort | \
				sed -e "s:$$(PRIVATE_DIR)/src\(.*\)\.txt:  <a name=\"\1\"></a>:" >> \
				$$@; \
			echo "<tr><td class=\"same-license\">" >> $$@; \
			echo "<div class=\"label\">Notices for file(s):</div>" >> $$@; \
			echo "<div class=\"file-list\">" >> $$@; \
			cat $$$$hashfile | sort | \
				sed -e "s:$$(PRIVATE_DIR)/src\(.*\)\.txt:  \1<br/>:" >> $$@; \
			echo "</div><!-- file-list -->" >> $$@; \
			echo >> $$@; \
			orig=$$$$(head -n 1 $$$$hashfile); \
			echo "<pre class=\"license-text\">" >> $$@; \
			cat $$$$orig | sed -e "s/\&/\&amp;/g" | sed -e "s/</\&lt;/g" \
					| sed -e "s/>/\&gt;/g" >> $$@; \
			echo "</pre><!-- license-text -->" >> $$@; \
			echo "</td></tr><!-- same-license -->" >> $$@; \
			echo >> $$@; \
			echo >> $$@; \
			echo >> $$@; \
		done
	$$(hide) echo "</table>" >> $$@
	$$(hide) echo "</body></html>" >> $$@
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

kernel_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/kernel.txt

$(eval $(call combine-notice-files, \
			$(target_notice_file_txt), \
			$(target_notice_file_html), \
			"Notices for files contained in the filesystem images in this directory:", \
			$(TARGET_OUT_NOTICE_FILES), \
			$(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file)))

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

# The kernel isn't really a module, so to get its module file in there, we
# make the target NOTICE files depend on this particular file too, which will
# then be in the right directory for the find in combine-notice-files to work.
$(kernel_notice_file): \
	    prebuilt/$(TARGET_PREBUILT_TAG)/kernel/LINUX_KERNEL_COPYING \
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
$(TARGET_OUT_ETC)/security/otacerts.zip: $(addsuffix .x509.pem,$(DEFAULT_KEY_CERT_PAIR))
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(hide) zip -qj $@ $<

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

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
INTERNAL_USERIMAGES_DEPS := $(MKEXT2USERIMG) $(MAKE_EXT4FS)
INTERNAL_USERIMAGES_BINARY_PATHS := $(sort $(dir $(INTERNAL_USERIMAGES_DEPS)))

# $(1): src directory
# $(2): output file
# $(3): mount point
# $(4): ext variant (ext2, ext3, ext4)
# $(5): size of the partition
define build-userimage-ext-target
  @mkdir -p $(dir $(2))
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$(PATH) \
	  $(MKEXT2USERIMG) $(1) $(2) $(4) $(3) $(5)
endef
else
INTERNAL_USERIMAGES_DEPS := $(MKYAFFS2)
endif

# -----------------------------------------------------------------
# Recovery image

# If neither TARGET_NO_KERNEL nor TARGET_NO_RECOVERY are true
ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY) $(BUILD_TINY_ANDROID)))

INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img

recovery_initrc := $(call include-path-for, recovery)/etc/init.rc
recovery_kernel := $(INSTALLED_KERNEL_TARGET) # same as a non-recovery system
recovery_ramdisk := $(PRODUCT_OUT)/ramdisk-recovery.img
recovery_build_prop := $(INSTALLED_BUILD_PROP_TARGET)
recovery_binary := $(call intermediates-dir-for,EXECUTABLES,recovery)/recovery
recovery_resources_common := $(call include-path-for, recovery)/res
recovery_resources_private := $(strip $(wildcard $(TARGET_DEVICE_DIR)/recovery/res))
recovery_resource_deps := $(shell find $(recovery_resources_common) \
  $(recovery_resources_private) -type f)
recovery_fstab := $(strip $(wildcard $(TARGET_DEVICE_DIR)/recovery.fstab))

ifeq ($(recovery_resources_private),)
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
# build always uses test-keys for this; release packaging tools will
# substitute other keys for this one.
OTA_PUBLIC_KEYS := $(SRC_TARGET_DIR)/product/security/testkey.x509.pem

# Generate a file containing the keys that will be read by the
# recovery binary.
RECOVERY_INSTALL_OTA_KEYS := \
	$(call intermediates-dir-for,PACKAGING,ota_keys)/keys
DUMPKEY_JAR := $(HOST_OUT_JAVA_LIBRARIES)/dumpkey.jar
$(RECOVERY_INSTALL_OTA_KEYS): PRIVATE_OTA_PUBLIC_KEYS := $(OTA_PUBLIC_KEYS)
$(RECOVERY_INSTALL_OTA_KEYS): $(OTA_PUBLIC_KEYS) $(DUMPKEY_JAR)
	@echo "DumpPublicKey: $@ <= $(PRIVATE_OTA_PUBLIC_KEYS)"
	@rm -rf $@
	@mkdir -p $(dir $@)
	java -jar $(DUMPKEY_JAR) $(PRIVATE_OTA_PUBLIC_KEYS) > $@

$(INSTALLED_RECOVERYIMAGE_TARGET): $(MKBOOTFS) $(MKBOOTIMG) $(MINIGZIP) \
		$(INSTALLED_RAMDISK_TARGET) \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(recovery_binary) \
		$(recovery_initrc) $(recovery_kernel) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(recovery_build_prop) $(recovery_resource_deps) \
		$(recovery_fstab) \
		$(RECOVERY_INSTALL_OTA_KEYS)
	@echo ----- Making recovery image ------
	rm -rf $(TARGET_RECOVERY_OUT)
	mkdir -p $(TARGET_RECOVERY_OUT)
	mkdir -p $(TARGET_RECOVERY_ROOT_OUT)
	mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/etc
	mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/tmp
	echo Copying baseline ramdisk...
	cp -R $(TARGET_ROOT_OUT) $(TARGET_RECOVERY_OUT)
	rm $(TARGET_RECOVERY_ROOT_OUT)/init*.rc
	echo Modifying ramdisk contents...
	cp -f $(recovery_initrc) $(TARGET_RECOVERY_ROOT_OUT)/
	cp -f $(recovery_binary) $(TARGET_RECOVERY_ROOT_OUT)/sbin/
	cp -rf $(recovery_resources_common) $(TARGET_RECOVERY_ROOT_OUT)/
	$(foreach item,$(recovery_resources_private), \
	  cp -rf $(item) $(TARGET_RECOVERY_ROOT_OUT)/)
	$(foreach item,$(recovery_fstab), \
	  cp -f $(item) $(TARGET_RECOVERY_ROOT_OUT)/etc/recovery.fstab)
	cp $(RECOVERY_INSTALL_OTA_KEYS) $(TARGET_RECOVERY_ROOT_OUT)/res/keys
	cat $(INSTALLED_DEFAULT_PROP_TARGET) $(recovery_build_prop) \
	        > $(TARGET_RECOVERY_ROOT_OUT)/default.prop
	$(MKBOOTFS) $(TARGET_RECOVERY_ROOT_OUT) | $(MINIGZIP) > $(recovery_ramdisk)
	$(MKBOOTIMG) $(INTERNAL_RECOVERYIMAGE_ARGS) --output $@
	@echo ----- Made recovery image -------- $@
	$(hide) $(call assert-max-image-size,$@,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE),raw)

else
INSTALLED_RECOVERYIMAGE_TARGET :=
endif

.PHONY: recoveryimage
recoveryimage: $(INSTALLED_RECOVERYIMAGE_TARGET)

ifneq ($(BOARD_NAND_PAGE_SIZE),)
mkyaffs2_extra_flags := -c $(BOARD_NAND_PAGE_SIZE)
else
mkyaffs2_extra_flags :=
endif


# -----------------------------------------------------------------
# system image
#
systemimage_intermediates := \
	$(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE := $(systemimage_intermediates)/system.img

INTERNAL_SYSTEMIMAGE_FILES := $(filter $(TARGET_OUT)/%, \
	$(ALL_PREBUILT) \
	$(ALL_COPIED_HEADERS) \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
## generate an ext image
# $(1): output file
define build-systemimage-target
    @echo "Target system fs image: $(1)"
    $(call build-userimage-ext-target,$(TARGET_OUT),$(1),system,$(INTERNAL_USERIMAGES_EXT_VARIANT),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
endef

else # INTERNAL_USERIMAGES_USE_EXT != true

## generate a yaffs2 image
# $(1): output file
define build-systemimage-target
    @echo "Target system fs image: $(1)"
    @mkdir -p $(dir $(1))
    $(hide) $(MKYAFFS2) -f $(mkyaffs2_extra_flags) $(TARGET_OUT) $(1)
endef
endif # INTERNAL_USERIMAGES_USE_EXT

$(BUILT_SYSTEMIMAGE): $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)
	$(call build-systemimage-target,$@)

INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img
SYSTEMIMAGE_SOURCE_DIR := $(TARGET_OUT)

# The system partition needs room for the recovery image as well.  We
# now store the recovery image as a binary patch using the boot image
# as the source (since they are very similar).  Generate the patch so
# we can see how big it's going to be, and include that in the system
# image size check calculation.
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
intermediates := $(call intermediates-dir-for,PACKAGING,recovery_patch)
RECOVERY_FROM_BOOT_PATCH := $(intermediates)/recovery_from_boot.p
$(RECOVERY_FROM_BOOT_PATCH): $(INSTALLED_RECOVERYIMAGE_TARGET) \
                             $(INSTALLED_BOOTIMAGE_TARGET) \
			     $(HOST_OUT_EXECUTABLES)/imgdiff \
	                     $(HOST_OUT_EXECUTABLES)/bsdiff
	@echo "Construct recovery from boot"
	mkdir -p $(dir $@)
	PATH=$(HOST_OUT_EXECUTABLES):$$PATH $(HOST_OUT_EXECUTABLES)/imgdiff $(INSTALLED_BOOTIMAGE_TARGET) $(INSTALLED_RECOVERYIMAGE_TARGET) $@
endif


$(INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE) $(RECOVERY_FROM_BOOT_PATCH) | $(ACP)
	@echo "Install system fs image: $@"
	$(copy-file-to-target)
	$(hide) $(call assert-max-image-size,$@ $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE),yaffs)

systemimage: $(INSTALLED_SYSTEMIMAGE)

.PHONY: systemimage-nodeps snod
systemimage-nodeps snod: $(filter-out systemimage-nodeps snod,$(MAKECMDGOALS)) \
	            | $(INTERNAL_USERIMAGES_DEPS)
	@echo "make $@: ignoring dependencies"
	$(call build-systemimage-target,$(INSTALLED_SYSTEMIMAGE))
	$(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMIMAGE),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE),yaffs)

#######
## system tarball
define build-systemtarball-target
    $(call pretty,"Target system fs tarball: $(INSTALLED_SYSTEMTARBALL_TARGET)")
    $(MKTARBALL) $(FS_GET_STATS) \
		$(PRODUCT_OUT) system $(PRIVATE_SYSTEM_TAR) \
		$(INSTALLED_SYSTEMTARBALL_TARGET)
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


#######
## boot tarball
define build-boottarball-target
    $(hide) echo "Target boot fs tarball: $(INSTALLED_BOOTTARBALL_TARGET)"
    $(hide) mkdir -p $(PRODUCT_OUT)/boot
    $(hide) cp -f $(INTERNAL_BOOTIMAGE_FILES) $(PRODUCT_OUT)/boot/.
    $(hide) echo $(BOARD_KERNEL_CMDLINE) > $(PRODUCT_OUT)/boot/cmdline
    $(hide) $(MKTARBALL) $(FS_GET_STATS) \
                 $(PRODUCT_OUT) boot $(PRIVATE_BOOT_TAR) \
                 $(INSTALLED_BOOTTARBALL_TARGET)
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

ifeq ($(INTERNAL_USERIMAGES_USE_EXT),true)
## Generate an ext2 image
define build-userdataimage-target
    $(call pretty,"Target userdata fs image: $(INSTALLED_USERDATAIMAGE_TARGET)")
    @mkdir -p $(TARGET_OUT_DATA)
    $(call build-userimage-ext-target,$(TARGET_OUT_DATA),$(INSTALLED_USERDATAIMAGE_TARGET),data,$(INTERNAL_USERIMAGES_EXT_VARIANT),$(BOARD_USERDATAIMAGE_PARTITION_SIZE))
    $(hide) $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE),yaffs)
endef

else # INTERNAL_USERIMAGES_USE_EXT != true

## Generate a yaffs2 image
define build-userdataimage-target
    $(call pretty,"Target userdata fs image: $(INSTALLED_USERDATAIMAGE_TARGET)")
    @mkdir -p $(TARGET_OUT_DATA)
    $(hide) $(MKYAFFS2) -f $(mkyaffs2_extra_flags) $(TARGET_OUT_DATA) $(INSTALLED_USERDATAIMAGE_TARGET)
    $(hide) $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE),yaffs)
endef
endif # INTERNAL_USERIMAGES_USE_EXT

BUILT_USERDATAIMAGE_TARGET := $(PRODUCT_OUT)/userdata.img

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
$(INSTALLED_USERDATAIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) \
                                   $(INTERNAL_USERDATAIMAGE_FILES)
	$(build-userdataimage-target)

.PHONY: userdataimage-nodeps
userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-userdataimage-target)

#######
## data partition tarball
define build-userdatatarball-target
    $(call pretty,"Target userdata fs tarball: " \
                  "$(INSTALLED_USERDATATARBALL_TARGET)")
    $(MKTARBALL) $(FS_GET_STATS) \
		$(PRODUCT_OUT) data $(PRIVATE_USERDATA_TAR) \
		$(INSTALLED_USERDATATARBALL_TARGET)
endef

userdata_tar := $(PRODUCT_OUT)/userdata.tar
INSTALLED_USERDATATARBALL_TARGET := $(userdata_tar).bz2
$(INSTALLED_USERDATATARBALL_TARGET): PRIVATE_USERDATA_TAR := $(userdata_tar)
$(INSTALLED_USERDATATARBALL_TARGET): $(FS_GET_STATS) $(INTERNAL_USERDATAIMAGE_FILES)
	$(build-userdatatarball-target)

.PHONY: userdatatarball-nodeps
userdatatarball-nodeps: $(FS_GET_STATS)
	$(build-userdatatarball-target)


# -----------------------------------------------------------------
# bring in the installer image generation defines if necessary
ifeq ($(TARGET_USE_DISKINSTALLER),true)
include bootable/diskinstaller/config.mk
endif

# -----------------------------------------------------------------
# host tools needed to build OTA packages

OTATOOLS :=  $(HOST_OUT_EXECUTABLES)/minigzip \
	  $(HOST_OUT_EXECUTABLES)/mkbootfs \
	  $(HOST_OUT_EXECUTABLES)/mkbootimg \
	  $(HOST_OUT_EXECUTABLES)/fs_config \
	  $(HOST_OUT_EXECUTABLES)/mkyaffs2image \
	  $(HOST_OUT_EXECUTABLES)/zipalign \
	  $(HOST_OUT_EXECUTABLES)/aapt \
	  $(HOST_OUT_EXECUTABLES)/bsdiff \
	  $(HOST_OUT_EXECUTABLES)/imgdiff \
	  $(HOST_OUT_JAVA_LIBRARIES)/dumpkey.jar \
	  $(HOST_OUT_JAVA_LIBRARIES)/signapk.jar \
	  $(HOST_OUT_EXECUTABLES)/mkuserimg.sh \
	  $(HOST_OUT_EXECUTABLES)/genext2fs \
	  $(HOST_OUT_EXECUTABLES)/tune2fs \
	  $(HOST_OUT_EXECUTABLES)/e2fsck


.PHONY: otatools
otatools: $(OTATOOLS)

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

built_ota_tools := \
	$(call intermediates-dir-for,EXECUTABLES,applypatch)/applypatch \
	$(call intermediates-dir-for,EXECUTABLES,applypatch_static)/applypatch_static \
	$(call intermediates-dir-for,EXECUTABLES,check_prereq)/check_prereq \
	$(call intermediates-dir-for,EXECUTABLES,updater)/updater
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_OTA_TOOLS := $(built_ota_tools)

$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_API_VERSION := $(RECOVERY_API_VERSION)

ifeq ($(TARGET_RELEASETOOLS_EXTENSIONS),)
# default to common dir for device vendor
$(BUILT_TARGET_FILES_PACKAGE): tool_extensions := $(TARGET_DEVICE_DIR)/../common
else
$(BUILT_TARGET_FILES_PACKAGE): tool_extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_PACKAGE): \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_RADIOIMAGE_TARGET) \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_ANDROID_INFO_TXT_TARGET) \
		$(built_ota_tools) \
		$(APKCERTS_FILE) \
		$(HOST_OUT_EXECUTABLES)/fs_config \
		| $(ACP)
	@echo "Package target files: $@"
	$(hide) rm -rf $@ $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/RECOVERY
	$(hide) $(call package_files-copy-root, \
		$(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/RECOVERY/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) $(ACP) $(INSTALLED_KERNEL_TARGET) $(zip_root)/RECOVERY/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) $(ACP) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/RECOVERY/second
endif
ifdef BOARD_KERNEL_CMDLINE
	$(hide) echo "$(BOARD_KERNEL_CMDLINE)" > $(zip_root)/RECOVERY/cmdline
endif
ifdef BOARD_KERNEL_BASE
	$(hide) echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/RECOVERY/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	$(hide) echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/RECOVERY/pagesize
endif
	@# Components of the boot image
	$(hide) mkdir -p $(zip_root)/BOOT
	$(hide) $(call package_files-copy-root, \
		$(TARGET_ROOT_OUT),$(zip_root)/BOOT/RAMDISK)
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
	$(hide) $(foreach t,$(INSTALLED_RADIOIMAGE_TARGET),\
	            mkdir -p $(zip_root)/RADIO; \
	            $(ACP) $(t) $(zip_root)/RADIO/$(notdir $(t));)
	@# Contents of the system image
	$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR),$(zip_root)/SYSTEM)
	@# Contents of the data image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_DATA),$(zip_root)/DATA)
	@# Extra contents of the OTA package
	$(hide) mkdir -p $(zip_root)/OTA/bin
	$(hide) $(ACP) $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(zip_root)/OTA/
	$(hide) $(ACP) $(PRIVATE_OTA_TOOLS) $(zip_root)/OTA/bin/
	@# Files that do not end up in any images, but are necessary to
	@# build them.
	$(hide) mkdir -p $(zip_root)/META
	$(hide) $(ACP) $(APKCERTS_FILE) $(zip_root)/META/apkcerts.txt
	$(hide)	echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) echo "recovery_api_version=$(PRIVATE_RECOVERY_API_VERSION)" > $(zip_root)/META/misc_info.txt
ifdef BOARD_FLASH_BLOCK_SIZE
	$(hide) echo "blocksize=$(BOARD_FLASH_BLOCK_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
	$(hide) echo "boot_size=$(call image-size-from-data-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE))" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
	$(hide) echo "recovery_size=$(call image-size-from-data-size,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE))" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_SYSTEMIMAGE_PARTITION_SIZE
	$(hide) echo "system_size=$(call image-size-from-data-size,$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_USERDATAIMAGE_PARTITION_SIZE
	$(hide) echo "userdata_size=$(call image-size-from-data-size,$(BOARD_USERDATAIMAGE_PARTITION_SIZE))" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo "tool_extensions=$(tool_extensions)" >> $(zip_root)/META/misc_info.txt
ifdef mkyaffs2_extra_flags
	$(hide) echo "mkyaffs2_extra_flags=$(mkyaffs2_extra_flags)" >> $(zip_root)/META/misc_info.txt
endif
	@# Zip everything up, preserving symlinks
	$(hide) (cd $(zip_root) && zip -qry ../$(notdir $@) .)
	@# Run fs_config on all the system files in the zip, and save the output
	$(hide) zipinfo -1 $@ | awk -F/ 'BEGIN { OFS="/" } /^SYSTEM\// {$$1 = "system"; print}' | $(HOST_OUT_EXECUTABLES)/fs_config > $(zip_root)/META/filesystem_config.txt
	$(hide) (cd $(zip_root) && zip -q ../$(notdir $@) META/filesystem_config.txt)


target-files-package: $(BUILT_TARGET_FILES_PACKAGE)

# -----------------------------------------------------------------
# OTA update package

ifneq ($(TARGET_SIMULATOR),true)
ifneq ($(TARGET_PRODUCT),sdk)
ifneq ($(TARGET_DEVICE),generic)
ifneq ($(TARGET_NO_KERNEL),true)

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-ota-$(FILE_NAME_TAG)

INTERNAL_OTA_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_OTA_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)

$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(OTATOOLS)
	@echo "Package OTA: $@"
	$(hide) ./build/tools/releasetools/ota_from_target_files -v \
	   -p $(HOST_OUT) \
           -k $(KEY_CERT_PAIR) \
           $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: otapackage
otapackage: $(INTERNAL_OTA_PACKAGE_TARGET)

endif    # TARGET_NO_KERNEL != true
endif    # TARGET_DEVICE != generic
endif    # TARGET_PRODUCT != sdk
endif    # TARGET_SIMULATOR != true

# -----------------------------------------------------------------
# installed file list
# Depending on $(INSTALLED_SYSTEMIMAGE) ensures that it
# gets the DexOpt one if we're doing that.
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
$(INSTALLED_FILES_FILE): $(INSTALLED_SYSTEMIMAGE)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) build/tools/fileslist.py $(TARGET_OUT) $(TARGET_OUT_DATA) > $@

.PHONY: installed-file-list
installed-file-list: $(INSTALLED_FILES_FILE)
ifneq ($(filter sdk,$(MAKECMDGOALS)),)
$(call dist-for-goals, sdk, $(INSTALLED_FILES_FILE))
endif
ifneq ($(filter sdk_addon,$(MAKECMDGOALS)),)
$(call dist-for-goals, sdk_addon, $(INSTALLED_FILES_FILE))
endif

# -----------------------------------------------------------------
# A zip of the tests that are built when running "make tests".
# This is very similar to BUILT_TARGET_FILES_PACKAGE, but we
# only grab SYSTEM and DATA, and it's called "*-tests-*.zip".
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-tests-$(FILE_NAME_TAG)

intermediates := $(call intermediates-dir-for,PACKAGING,tests_zip)
BUILT_TESTS_ZIP_PACKAGE := $(intermediates)/$(name).zip
$(BUILT_TESTS_ZIP_PACKAGE): intermediates := $(intermediates)
$(BUILT_TESTS_ZIP_PACKAGE): zip_root := $(intermediates)/$(name)

# Depending on the images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TESTS_ZIP_PACKAGE): \
		$(BUILT_SYSTEMIMAGE) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		| $(ACP)
	@echo "Package test files: $@"
	$(hide) rm -rf $@ $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
	@# Some parts of the system image
	$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR)/xbin,$(zip_root)/SYSTEM/xbin)
	$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR)/lib,$(zip_root)/SYSTEM/lib)
	$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR)/framework, \
		$(zip_root)/SYSTEM/framework)
	$(hide) $(ACP) $(SYSTEMIMAGE_SOURCE_DIR)/build.prop $(zip_root)/SYSTEM
	@# Contents of the data image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_DATA),$(zip_root)/DATA)
	$(hide) (cd $(zip_root) && zip -qry ../$(notdir $@) .)

.PHONY: tests-zip-package
tests-zip-package: $(BUILT_TESTS_ZIP_PACKAGE)

# Target needed by tests build
.PHONY: tests-build-target
tests-build-target: $(BUILT_TESTS_ZIP_PACKAGE) \
                    $(BUILT_USERDATAIMAGE_TARGET)

ifneq (,$(filter $(MAKECMDGOALS),tests-build-target))
  $(call dist-for-goals, tests-build-target, \
          $(BUILT_TESTS_ZIP_PACKAGE) \
          $(BUILT_USERDATAIMAGE_TARGET))
endif

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
$(SYMBOLS_ZIP): $(INSTALLED_SYSTEMIMAGE) $(INSTALLED_BOOTIMAGE_TARGET)
	@echo "Package symbols: $@"
	$(hide) rm -rf $@
	$(hide) mkdir -p $(dir $@)
	$(hide) zip -qr $@ $(TARGET_OUT_UNSTRIPPED)

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
	$(hide) zip -qj $@ $(TARGET_OUT_APPS)/*


#------------------------------------------------------------------
# A zip of emma code coverage meta files. Generated for fully emma
# instrumented build.
#
EMMA_META_ZIP := $(PRODUCT_OUT)/emma_meta.zip
$(EMMA_META_ZIP): $(INSTALLED_SYSTEMIMAGE)
	@echo "Collecting Emma coverage meta files."
	$(hide) find $(TARGET_COMMON_OUT_ROOT) -name "coverage.em" | \
		zip -@ -q $@

endif	# TARGET_SIMULATOR != true

# -----------------------------------------------------------------
# dalvik something
.PHONY: dalvikfiles
dalvikfiles: $(INTERNAL_DALVIK_MODULES)

# -----------------------------------------------------------------
# The update package

ifneq ($(TARGET_SIMULATOR),true)
ifneq ($(TARGET_PRODUCT),sdk)

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-img-$(FILE_NAME_TAG)

INTERNAL_UPDATE_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

ifeq ($(TARGET_RELEASETOOLS_EXTENSIONS),)
# default to common dir for device vendor
$(INTERNAL_UPDATE_PACKAGE_TARGET): extensions := $(TARGET_DEVICE_DIR)/../common
else
$(INTERNAL_UPDATE_PACKAGE_TARGET): extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif

$(INTERNAL_UPDATE_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(OTATOOLS)
	@echo "Package: $@"
	$(hide) ./build/tools/releasetools/img_from_target_files -v \
	   -s $(extensions) \
	   -p $(HOST_OUT) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: updatepackage
updatepackage: $(INTERNAL_UPDATE_PACKAGE_TARGET)

endif    # TARGET_PRODUCT != sdk
endif    # TARGET_SIMULATOR != true

# -----------------------------------------------------------------
# The emulator package

ifneq ($(TARGET_SIMULATOR),true)

INTERNAL_EMULATOR_PACKAGE_FILES += \
        $(HOST_OUT_EXECUTABLES)/emulator$(HOST_EXECUTABLE_SUFFIX) \
        prebuilt/android-arm/kernel/kernel-qemu \
        $(INSTALLED_RAMDISK_TARGET) \
		$(INSTALLED_SYSTEMIMAGE) \
		$(INSTALLED_USERDATAIMAGE_TARGET)

name := $(TARGET_PRODUCT)-emulator-$(FILE_NAME_TAG)

INTERNAL_EMULATOR_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_EMULATOR_PACKAGE_TARGET): $(INTERNAL_EMULATOR_PACKAGE_FILES)
	@echo "Package: $@"
	$(hide) zip -qj $@ $(INTERNAL_EMULATOR_PACKAGE_FILES)

endif

# -----------------------------------------------------------------
# The pdk package (Platform Development Kit)

ifneq (,$(filter pdk,$(MAKECMDGOALS)))
  include development/pdk/Pdk.mk
endif

# -----------------------------------------------------------------
# The SDK

ifneq ($(TARGET_SIMULATOR),true)

# The SDK includes host-specific components, so it belongs under HOST_OUT.
sdk_dir := $(HOST_OUT)/sdk

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
  INTERNAL_SDK_HOST_OS_NAME := $(INTERNAL_SDK_HOST_OS_NAME)-$(HOST_ARCH)
endif
sdk_name := $(sdk_name)_$(INTERNAL_SDK_HOST_OS_NAME)

sdk_dep_file := $(sdk_dir)/sdk_deps.mk

ATREE_FILES :=
-include $(sdk_dep_file)

# if we don't have a real list, then use "everything"
ifeq ($(strip $(ATREE_FILES)),)
ATREE_FILES := \
	$(ALL_PREBUILT) \
	$(ALL_COPIED_HEADERS) \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES) \
	$(INSTALLED_RAMDISK_TARGET) \
	$(ALL_DOCS) \
	$(ALL_SDK_FILES)
endif

atree_dir := development/build

sdk_atree_files := \
	$(atree_dir)/sdk.exclude.atree \
	$(atree_dir)/sdk.atree \
	$(atree_dir)/sdk-$(HOST_OS)-$(HOST_ARCH).atree \
	sdk/build/tools.atree

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
	$(atree_dir)/sdk.atree \
	sdk/build/tools.atree \
	$(HOST_OUT_EXECUTABLES)/atree \
    $(HOST_OUT_EXECUTABLES)/line_endings

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
	$(hide) ( \
		$(HOST_OUT_EXECUTABLES)/atree \
		$(addprefix -f ,$(PRIVATE_INPUT_FILES)) \
			-m $(PRIVATE_DEP_FILE) \
			-I . \
			-I $(PRODUCT_OUT) \
			-I $(HOST_OUT) \
			-I $(TARGET_COMMON_OUT_ROOT) \
			-v "PLATFORM_NAME=android-$(PLATFORM_VERSION)" \
			-o $(PRIVATE_DIR) && \
		cp -f $(target_notice_file_txt) \
				$(PRIVATE_DIR)/platforms/android-$(PLATFORM_VERSION)/images/NOTICE.txt && \
		cp -f $(tools_notice_file_txt) $(PRIVATE_DIR)/tools/NOTICE.txt && \
		HOST_OUT_EXECUTABLES=$(HOST_OUT_EXECUTABLES) HOST_OS=$(HOST_OS) \
                development/build/tools/sdk_clean.sh $(PRIVATE_DIR) && \
		chmod -R ug+rwX $(PRIVATE_DIR) && \
		cd $(dir $@) && zip -rq $(notdir $@) $(PRIVATE_NAME) \
	) || ( rm -rf $(PRIVATE_DIR) $@ && exit 44 )


# Is a Windows SDK requested? If so, we need some definitions from here
# in order to find the Linux SDK used to create the Windows one.
ifneq ($(filter win_sdk,$(MAKECMDGOALS)),)
LINUX_SDK_NAME := $(sdk_name)
LINUX_SDK_DIR  := $(sdk_dir)
include $(TOPDIR)development/build/tools/windows_sdk.mk
endif

endif # !simulator

# -----------------------------------------------------------------
# Findbugs
INTERNAL_FINDBUGS_XML_TARGET := $(PRODUCT_OUT)/findbugs.xml
INTERNAL_FINDBUGS_HTML_TARGET := $(PRODUCT_OUT)/findbugs.html
$(INTERNAL_FINDBUGS_XML_TARGET): $(ALL_FINDBUGS_FILES)
	@echo UnionBugs: $@
	$(hide) prebuilt/common/findbugs/bin/unionBugs $(ALL_FINDBUGS_FILES) \
	> $@
$(INTERNAL_FINDBUGS_HTML_TARGET): $(INTERNAL_FINDBUGS_XML_TARGET)
	@echo ConvertXmlToText: $@
	$(hide) prebuilt/common/findbugs/bin/convertXmlToText -html:fancy.xsl \
	$(INTERNAL_FINDBUGS_XML_TARGET)	> $@

# -----------------------------------------------------------------
# Findbugs

# -----------------------------------------------------------------
# These are some additional build tasks that need to be run.
include $(sort $(wildcard $(BUILD_SYSTEM)/tasks/*.mk))
