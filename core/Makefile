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
     Prebuilt apk found in PRODUCT_COPY_FILES: $(1), use BUILD_PREBUILT instead!))) \
$(if $(filter true,$(BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES)),, \
  $(if $(filter $(TARGET_COPY_OUT_SYSTEM)/etc/vintf/% \
                $(TARGET_COPY_OUT_SYSTEM)/manifest.xml \
                $(TARGET_COPY_OUT_SYSTEM)/compatibility_matrix.xml,$(2)), \
    $(error VINTF metadata found in PRODUCT_COPY_FILES: $(1), use vintf_fragments instead!)) \
  $(if $(filter $(TARGET_COPY_OUT_PRODUCT)/etc/vintf/%,$(2)), \
    $(error VINTF metadata found in PRODUCT_COPY_FILES: $(1), \
      use PRODUCT_MANIFEST_FILES / DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE / vintf_compatibility_matrix / vintf_fragments instead!)) \
  $(if $(filter $(TARGET_COPY_OUT_SYSTEM_EXT)/etc/vintf/%,$(2)), \
    $(error VINTF metadata found in PRODUCT_COPY_FILES: $(1), \
      use vintf_compatibility_matrix / vintf_fragments instead!)) \
  $(if $(filter $(TARGET_COPY_OUT_VENDOR)/etc/vintf/% \
                $(TARGET_COPY_OUT_VENDOR)/manifest.xml \
                $(TARGET_COPY_OUT_VENDOR)/compatibility_matrix.xml,$(2)), \
    $(error VINTF metadata found in PRODUCT_COPY_FILES: $(1), \
      use DEVICE_MANIFEST_FILE / DEVICE_MATRIX_FILE / vintf_compatibility_matrix / vintf_fragments instead!)) \
  $(if $(filter $(TARGET_COPY_OUT_ODM)/etc/vintf/% \
                $(TARGET_COPY_OUT_ODM)/etc/manifest%,$(2)), \
    $(error VINTF metadata found in PRODUCT_COPY_FILES: $(1), \
      use ODM_MANIFEST_FILES / vintf_fragments instead!)) \
)
endef

check_elf_prebuilt_product_copy_files := true
ifneq (,$(filter true,$(BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES)))
check_elf_prebuilt_product_copy_files :=
endif
check_elf_prebuilt_product_copy_files_hint := \
    found ELF prebuilt in PRODUCT_COPY_FILES, use cc_prebuilt_binary / cc_prebuilt_library_shared instead.

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
                $(if $(filter init%rc,$(notdir $(_dest)))$(filter %/etc/init,$(dir $(_dest))),\
                    $(eval $(call copy-init-script-file-checked,$(_src),$(_fulldest))),\
                    $(if $(and $(filter true,$(check_elf_prebuilt_product_copy_files)), \
                               $(filter bin lib lib64,$(subst /,$(space),$(_dest)))), \
                        $(eval $(call copy-non-elf-file-checked,$(_src),$(_fulldest),$(check_elf_prebuilt_product_copy_files_hint))), \
                        $(eval $(call copy-one-file,$(_src),$(_fulldest))))))) \
        $(eval unique_product_copy_files_destinations += $(_dest))))

# Dump a list of overriden (and ignored PRODUCT_COPY_FILES entries)
pcf_ignored_file := $(PRODUCT_OUT)/product_copy_files_ignored.txt
$(pcf_ignored_file): PRIVATE_IGNORED := $(sort $(product_copy_files_ignored))
$(pcf_ignored_file):
	echo "$(PRIVATE_IGNORED)" | tr " " "\n" >$@

$(call dist-for-goals,droidcore,$(pcf_ignored_file):logs/$(notdir $(pcf_ignored_file)))

pcf_ignored_file :=
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
has_dup_copy_headers :=
$(foreach dest,$(ALL_COPIED_HEADERS), \
    $(eval _srcs := $(ALL_COPIED_HEADERS.$(dest).SRC)) \
    $(eval _src := $(lastword $(_srcs))) \
    $(if $(call streq,$(_src),$(_srcs)),, \
        $(warning Duplicate header copy: $(dest)) \
        $(warning _ Using $(_src)) \
        $(warning __ from $(lastword $(ALL_COPIED_HEADERS.$(dest).MAKEFILE))) \
        $(eval _makefiles := $$(wordlist 1,$(call int_subtract,$(words $(ALL_COPIED_HEADERS.$(dest).MAKEFILE)),1),$$(ALL_COPIED_HEADERS.$$(dest).MAKEFILE))) \
        $(foreach src,$(wordlist 1,$(call int_subtract,$(words $(_srcs)),1),$(_srcs)), \
            $(warning _ Ignoring $(src)) \
            $(warning __ from $(firstword $(_makefiles))) \
            $(eval _makefiles := $$(wordlist 2,9999,$$(_makefiles)))) \
        $(eval has_dup_copy_headers := true)) \
    $(eval $(call copy-one-header,$(_src),$(dest))))
all_copied_headers: $(ALL_COPIED_HEADERS)

ifdef has_dup_copy_headers
  has_dup_copy_headers :=
  $(error duplicate header copies are no longer allowed. For more information about headers, see: https://android.googlesource.com/platform/build/soong/+/master/docs/best_practices.md#headers)
endif

$(file >$(PRODUCT_OUT)/.copied_headers_list,$(TARGET_OUT_HEADERS) $(ALL_COPIED_HEADERS))

# -----------------------------------------------------------------
# docs/index.html
ifeq (,$(TARGET_BUILD_UNBUNDLED))
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

$(call dist-for-goals,sdk,$(API_FINGERPRINT))

INSTALLED_RECOVERYIMAGE_TARGET :=
# Build recovery image if
# BUILDING_RECOVERY_IMAGE && !BOARD_USES_RECOVERY_AS_BOOT && !BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT.
# If BOARD_USES_RECOVERY_AS_BOOT is true, leave empty because INSTALLED_BOOTIMAGE_TARGET is built
#   with recovery resources.
# If BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT is true, leave empty to build recovery resources
#   but not the final recovery image.
ifdef BUILDING_RECOVERY_IMAGE
ifneq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifneq ($(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT),true)
INSTALLED_RECOVERYIMAGE_TARGET := $(PRODUCT_OUT)/recovery.img
endif
endif
endif

include $(BUILD_SYSTEM)/sysprop.mk

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
# kernel modules

# Depmod requires a well-formed kernel version so 0.0 is used as a placeholder.
DEPMOD_STAGING_SUBDIR :=$= lib/modules/0.0

define copy-and-strip-kernel-module
$(2): $(1)
	$(LLVM_STRIP) -o $(2) --strip-debug $(1)
endef

# $(1): modules list
# $(2): output dir
# $(3): mount point
# $(4): staging dir
# $(5): module load list
# $(6): module load list filename
# $(7): module archive
# $(8): staging dir for stripped modules
# $(9): module directory name
# Returns the a list of src:dest pairs to install the modules using copy-many-files.
define build-image-kernel-modules
  $(if $(9), \
    $(eval _dir := $(9)/), \
    $(eval _dir :=)) \
  $(foreach module,$(1), \
    $(eval _src := $(module)) \
    $(if $(8), \
      $(eval _src := $(8)/$(notdir $(module))) \
      $(eval $(call copy-and-strip-kernel-module,$(module),$(_src)))) \
    $(_src):$(2)/lib/modules/$(_dir)$(notdir $(module))) \
  $(eval $(call build-image-kernel-modules-depmod,$(1),$(3),$(4),$(5),$(6),$(7),$(2),$(9))) \
  $(4)/$(DEPMOD_STAGING_SUBDIR)/modules.dep:$(2)/lib/modules/$(_dir)modules.dep \
  $(4)/$(DEPMOD_STAGING_SUBDIR)/modules.alias:$(2)/lib/modules/$(_dir)modules.alias \
  $(4)/$(DEPMOD_STAGING_SUBDIR)/modules.softdep:$(2)/lib/modules/$(_dir)modules.softdep \
  $(4)/$(DEPMOD_STAGING_SUBDIR)/$(6):$(2)/lib/modules/$(_dir)$(6)
endef

# $(1): modules list
# $(2): mount point
# $(3): staging dir
# $(4): module load list
# $(5): module load list filename
# $(6): module archive
# $(7): output dir
# $(8): module directory name
# TODO(b/144844424): If a module archive is being used, this step (which
# generates obj/PACKAGING/.../modules.dep) also unzips the module archive into
# the output directory. This should be moved to a module with a
# LOCAL_POST_INSTALL_CMD so that if modules.dep is removed from the output dir,
# the archive modules are restored along with modules.dep.
define build-image-kernel-modules-depmod
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: .KATI_IMPLICIT_OUTPUTS := $(3)/$(DEPMOD_STAGING_SUBDIR)/modules.alias $(3)/$(DEPMOD_STAGING_SUBDIR)/modules.softdep $(3)/$(DEPMOD_STAGING_SUBDIR)/$(5)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: $(DEPMOD)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MODULES := $(1)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MOUNT_POINT := $(2)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MODULE_DIR := $(3)/$(DEPMOD_STAGING_SUBDIR)/$(2)/lib/modules/$(8)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_STAGING_DIR := $(3)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_LOAD_MODULES := $(4)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_LOAD_FILE := $(3)/$(DEPMOD_STAGING_SUBDIR)/$(5)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MODULE_ARCHIVE := $(6)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_OUTPUT_DIR := $(7)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: $(1) $(6)
	@echo depmod $$(PRIVATE_STAGING_DIR)
	rm -rf $$(PRIVATE_STAGING_DIR)
	mkdir -p $$(PRIVATE_MODULE_DIR)
	$(if $(6),\
	  unzip -qoDD -d $$(PRIVATE_MODULE_DIR) $$(PRIVATE_MODULE_ARCHIVE); \
	  mkdir -p $$(PRIVATE_OUTPUT_DIR)/lib; \
	  cp -r  $(3)/$(DEPMOD_STAGING_SUBDIR)/$(2)/lib/modules $$(PRIVATE_OUTPUT_DIR)/lib/; \
	  find $$(PRIVATE_MODULE_DIR) -type f -name *.ko | xargs basename -a > $$(PRIVATE_LOAD_FILE); \
	)
	$(if $(1),\
	  cp $$(PRIVATE_MODULES) $$(PRIVATE_MODULE_DIR)/; \
	  for MODULE in $$(PRIVATE_LOAD_MODULES); do \
	    basename $$$$MODULE >> $$(PRIVATE_LOAD_FILE); \
	  done; \
	)
	$(DEPMOD) -b $$(PRIVATE_STAGING_DIR) 0.0
	# Turn paths in modules.dep into absolute paths
	sed -i.tmp -e 's|\([^: ]*lib/modules/[^: ]*\)|/\1|g' $$(PRIVATE_STAGING_DIR)/$$(DEPMOD_STAGING_SUBDIR)/modules.dep
	touch $$(PRIVATE_LOAD_FILE)
endef

# $(1): staging dir
# $(2): modules list
# $(3): module load list
# $(4): module load list filename
# $(5): output dir
define module-load-list-copy-paths
  $(eval $(call build-image-module-load-list,$(1),$(2),$(3),$(4))) \
  $(1)/$(DEPMOD_STAGING_SUBDIR)/$(4):$(5)/lib/modules/$(4)
endef

# $(1): staging dir
# $(2): modules list
# $(3): module load list
# $(4): module load list filename
define build-image-module-load-list
$(1)/$(DEPMOD_STAGING_SUBDIR)/$(4): PRIVATE_LOAD_MODULES := $(3)
$(1)/$(DEPMOD_STAGING_SUBDIR)/$(4): $(2)
	@echo load-list $$(@)
	@echo '$$(strip $$(notdir $$(PRIVATE_LOAD_MODULES)))' | tr ' ' '\n' > $$(@)
endef

# $(1): image name
# $(2): build output directory (TARGET_OUT_VENDOR, TARGET_RECOVERY_ROOT_OUT, etc)
# $(3): mount point
# $(4): module load filename
# $(5): stripped staging directory
# $(6): kernel module directory name (top is an out of band value for no directory)
define build-image-kernel-modules-dir
$(if $(filter top,$(6)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(6))$(eval _sep :=_))\
$(if $(5),\
  $(eval _stripped_staging_dir := $(5)$(_sep)$(_kver)),\
  $(eval _stripped_staging_dir :=))\
$(if $(strip $(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver))$(BOARD_$(1)_KERNEL_MODULES_ARCHIVE$(_sep)$(_kver))),\
  $(if $(BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver)),,\
    $(eval BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver) := $(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver)))) \
  $(call copy-many-files,$(call build-image-kernel-modules,$(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver)),$(2),$(3),$(call intermediates-dir-for,PACKAGING,depmod_$(1)$(_sep)$(_kver)),$(BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver)),$(4),$(BOARD_$(1)_KERNEL_MODULES_ARCHIVE$(_sep)$(_kver)),$(_stripped_staging_dir),$(_kver))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-recovery-as-boot-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_GENERIC_RAMDISK_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,ramdisk_module_list$(_sep)$(_kver)),$(BOARD_GENERIC_RAMDISK_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_GENERIC_RAMDISK_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load,$(TARGET_RECOVERY_ROOT_OUT))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-vendor-ramdisk-recovery-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_ramdisk_recovery_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_RAMDISK_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.recovery,$(TARGET_VENDOR_RAMDISK_OUT))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-vendor-charger-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_charger_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_CHARGER_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.charger,$(TARGET_OUT_VENDOR))))
endef

ifneq ($(BUILDING_VENDOR_BOOT_IMAGE),true)
  # If there is no vendor boot partition, store vendor ramdisk kernel modules in the
  # boot ramdisk.
  BOARD_GENERIC_RAMDISK_KERNEL_MODULES += $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES)
  BOARD_GENERIC_RAMDISK_KERNEL_MODULES_LOAD += $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD)
endif

ifeq ($(BOARD_GENERIC_RAMDISK_KERNEL_MODULES_LOAD),)
  BOARD_GENERIC_RAMDISK_KERNEL_MODULES_LOAD := $(BOARD_GENERIC_RAMDISK_KERNEL_MODULES)
endif

ifneq ($(strip $(BOARD_GENERIC_RAMDISK_KERNEL_MODULES)),)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT), true)
    BOARD_RECOVERY_KERNEL_MODULES += $(BOARD_GENERIC_RAMDISK_KERNEL_MODULES)
  endif
endif

ifneq ($(BOARD_DO_NOT_STRIP_VENDOR_MODULES),true)
	VENDOR_STRIPPED_MODULE_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_vendor_stripped)
else
	VENDOR_STRIPPED_MODULE_STAGING_DIR :=
endif

ifneq ($(BOARD_DO_NOT_STRIP_VENDOR_RAMDISK_MODULES),true)
  VENDOR_RAMDISK_STRIPPED_MODULE_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_vendor_ramdisk_stripped)
else
  VENDOR_RAMDISK_STRIPPED_MODULE_STAGING_DIR :=
endif

BOARD_KERNEL_MODULE_DIRS += top
$(foreach dir,$(BOARD_KERNEL_MODULE_DIRS), \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,RECOVERY,$(TARGET_RECOVERY_ROOT_OUT),,modules.load.recovery,,$(dir))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,VENDOR_RAMDISK,$(TARGET_VENDOR_RAMDISK_OUT),,modules.load,$(VENDOR_RAMDISK_STRIPPED_MODULE_STAGING_DIR),$(dir))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-ramdisk-recovery-load,$(dir))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,VENDOR,$(if $(filter true,$(BOARD_USES_VENDOR_DLKMIMAGE)),$(TARGET_OUT_VENDOR_DLKM),$(TARGET_OUT_VENDOR)),vendor,modules.load,$(VENDOR_STRIPPED_MODULE_STAGING_DIR),$(dir))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-charger-load,$(dir))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,ODM,$(if $(filter true,$(BOARD_USES_ODM_DLKMIMAGE)),$(TARGET_OUT_ODM_DLKM),$(TARGET_OUT_ODM)),odm,modules.load,,$(dir))) \
  $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-recovery-as-boot-load,$(dir))),\
    $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,GENERIC_RAMDISK,$(TARGET_RAMDISK_OUT),,modules.load,,$(dir)))))

# -----------------------------------------------------------------
# Cert-to-package mapping.  Used by the post-build signing tools.
# Use a macro to add newline to each echo command
# $1 stem name of the package
# $2 certificate
# $3 private key
# $4 compressed
# $5 partition tag
# $6 output file
define _apkcerts_write_line
$(hide) echo -n 'name="$(1).apk" certificate="$2" private_key="$3"' >> $6
$(if $(4), $(hide) echo -n ' compressed="$4"' >> $6)
$(if $(5), $(hide) echo -n ' partition="$5"' >> $6)
$(hide) echo '' >> $6

endef

# -----------------------------------------------------------------
# Merge an individual apkcerts output into the final apkcerts.txt output.
# Use a macro to make it compatible with _apkcerts_write_line
# $1 apkcerts file to be merged
# $2 output file
define _apkcerts_merge
$(hide) cat $1 >> $2

endef

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-apkcerts-$(FILE_NAME_TAG)
intermediates := \
	$(call intermediates-dir-for,PACKAGING,apkcerts)
APKCERTS_FILE := $(intermediates)/$(name).txt
all_apkcerts_files := $(sort $(foreach p,$(PACKAGES),$(PACKAGES.$(p).APKCERTS_FILE)))
$(APKCERTS_FILE): $(all_apkcerts_files)
# We don't need to really build all the modules.
# TODO: rebuild APKCERTS_FILE if any app change its cert.
$(APKCERTS_FILE):
	@echo APK certs list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(foreach p,$(sort $(PACKAGES)),\
	  $(if $(PACKAGES.$(p).APKCERTS_FILE),\
	    $(call _apkcerts_merge,$(PACKAGES.$(p).APKCERTS_FILE), $@),\
	    $(if $(PACKAGES.$(p).EXTERNAL_KEY),\
	      $(call _apkcerts_write_line,$(PACKAGES.$(p).STEM),"EXTERNAL","",$(PACKAGES.$(p).COMPRESSED),$(PACKAGES.$(p).PARTITION),$@),\
	      $(call _apkcerts_write_line,$(PACKAGES.$(p).STEM),$(PACKAGES.$(p).CERTIFICATE),$(PACKAGES.$(p).PRIVATE_KEY),$(PACKAGES.$(p).COMPRESSED),$(PACKAGES.$(p).PARTITION),$@))))
	# In case value of PACKAGES is empty.
	$(hide) touch $@

.PHONY: apkcerts-list
apkcerts-list: $(APKCERTS_FILE)

ifneq (,$(TARGET_BUILD_APPS))
  $(call dist-for-goals, apps_only, $(APKCERTS_FILE):apkcerts.txt)
  $(call dist-for-goals, apps_only, $(SOONG_APEX_KEYS_FILE):apexkeys.txt)
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
# build /product/etc/security/avb/system_other.avbpubkey if needed
ifdef BUILDING_SYSTEM_OTHER_IMAGE
ifeq ($(BOARD_AVB_ENABLE),true)
INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET := $(TARGET_OUT_PRODUCT_ETC)/security/avb/system_other.avbpubkey
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET)
endif # BOARD_AVB_ENABLE
endif # BUILDING_SYSTEM_OTHER_IMAGE

# -----------------------------------------------------------------
# Modules ready to be converted to Soong, ordered by how many
# modules depend on them.
SOONG_CONV := $(sort $(SOONG_CONV))
SOONG_CONV_DATA := $(call intermediates-dir-for,PACKAGING,soong_conversion)/soong_conv_data
$(SOONG_CONV_DATA):
	@rm -f $@
	@$(foreach s,$(SOONG_CONV),echo "$(s),$(SOONG_CONV.$(s).TYPE),$(sort $(SOONG_CONV.$(s).PROBLEMS)),$(sort $(filter-out $(SOONG_ALREADY_CONV),$(SOONG_CONV.$(s).DEPS))),$(sort $(SOONG_CONV.$(s).MAKEFILES)),$(sort $(SOONG_CONV.$(s).INSTALLED))" >>$@;)

SOONG_TO_CONVERT_SCRIPT := build/make/tools/soong_to_convert.py
SOONG_TO_CONVERT := $(PRODUCT_OUT)/soong_to_convert.txt
$(SOONG_TO_CONVERT): $(SOONG_CONV_DATA) $(SOONG_TO_CONVERT_SCRIPT)
	@rm -f $@
	$(hide) $(SOONG_TO_CONVERT_SCRIPT) $< >$@
$(call dist-for-goals,droidcore,$(SOONG_TO_CONVERT))

MK2BP_CATALOG_SCRIPT := build/make/tools/mk2bp_catalog.py
MK2BP_REMAINING_HTML := $(PRODUCT_OUT)/mk2bp_remaining.html
$(MK2BP_REMAINING_HTML): PRIVATE_CODE_SEARCH_BASE_URL := "https://cs.android.com/android/platform/superproject/+/master:"
$(MK2BP_REMAINING_HTML): $(SOONG_CONV_DATA) $(MK2BP_CATALOG_SCRIPT)
	@rm -f $@
	$(hide) $(MK2BP_CATALOG_SCRIPT) \
		--device=$(TARGET_DEVICE) \
		--title="Remaining Android.mk files for $(TARGET_DEVICE)-$(TARGET_BUILD_VARIANT)" \
		--codesearch=$(PRIVATE_CODE_SEARCH_BASE_URL) \
		--out_dir="$(OUT_DIR)" \
		--mode=html \
		> $@
$(call dist-for-goals,droidcore,$(MK2BP_REMAINING_HTML))

MK2BP_REMAINING_CSV := $(PRODUCT_OUT)/mk2bp_remaining.csv
$(MK2BP_REMAINING_CSV): $(SOONG_CONV_DATA) $(MK2BP_CATALOG_SCRIPT)
	@rm -f $@
	$(hide) $(MK2BP_CATALOG_SCRIPT) \
		--device=$(TARGET_DEVICE) \
		--out_dir="$(OUT_DIR)" \
		--mode=csv \
		> $@
$(call dist-for-goals,droidcore,$(MK2BP_REMAINING_CSV))

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
# C/C++ flag information for modules
$(call dist-for-goals,droidcore,$(SOONG_MODULES_CFLAG_ARTIFACTS))

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
DEFAULT_KEY_CERT_PAIR := $(strip $(DEFAULT_SYSTEM_DEV_CERTIFICATE))


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

$(all_event_log_tags_file): PRIVATE_SRC_FILES := $(all_event_log_tags_src)
$(all_event_log_tags_file): $(all_event_log_tags_src) $(MERGETAGS) build/make/tools/event_log_tags.py
	$(hide) mkdir -p $(dir $@)
	$(hide) $(MERGETAGS) -o $@ $(PRIVATE_SRC_FILES)

# Include tags from all packages included in this product, plus all
# tags that are part of the system (ie, not in a vendor/ or device/
# directory).
event_log_tags_src := \
    $(sort $(foreach m,\
      $(call resolve-bitness-for-modules,TARGET,$(PRODUCT_PACKAGES)) \
      $(call module-names-for-tag-list,user), \
      $(ALL_MODULES.$(m).EVENT_LOG_TAGS)) \
      $(filter-out vendor/% device/% out/%,$(all_event_log_tags_src)))

$(event_log_tags_file): PRIVATE_SRC_FILES := $(event_log_tags_src)
$(event_log_tags_file): PRIVATE_MERGED_FILE := $(all_event_log_tags_file)
$(event_log_tags_file): $(event_log_tags_src) $(all_event_log_tags_file) $(MERGETAGS) build/make/tools/event_log_tags.py
	$(hide) mkdir -p $(dir $@)
	$(hide) $(MERGETAGS) -o $@ -m $(PRIVATE_MERGED_FILE) $(PRIVATE_SRC_FILES)

event-log-tags: $(event_log_tags_file)

ALL_DEFAULT_INSTALLED_MODULES += $(event_log_tags_file)


# #################################################################
# Targets for boot/OS images
# #################################################################
ifneq ($(strip $(TARGET_NO_BOOTLOADER)),true)
  INSTALLED_BOOTLOADER_MODULE := $(PRODUCT_OUT)/bootloader
  ifdef BOARD_PREBUILT_BOOTLOADER
    $(eval $(call copy-one-file,$(BOARD_PREBUILT_BOOTLOADER),$(INSTALLED_BOOTLOADER_MODULE)))
    $(call dist-for-goals,dist_files,$(INSTALLED_BOOTLOADER_MODULE))
  endif # BOARD_PREBUILT_BOOTLOADER
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
  ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
    INSTALLED_KERNEL_TARGET := $(foreach k,$(BOARD_KERNEL_BINARIES), \
      $(PRODUCT_OUT)/$(k))
  else
    INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
  endif
else
  INSTALLED_KERNEL_TARGET :=
endif

# -----------------------------------------------------------------
# the root dir
INTERNAL_ROOT_FILES := $(filter $(TARGET_ROOT_OUT)/%, \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_ROOT := $(PRODUCT_OUT)/installed-files-root.txt
INSTALLED_FILES_JSON_ROOT := $(INSTALLED_FILES_FILE_ROOT:.txt=.json)
$(INSTALLED_FILES_FILE_ROOT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ROOT)
$(INSTALLED_FILES_FILE_ROOT) : $(INTERNAL_ROOT_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_ROOT_OUT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call dist-for-goals, sdk win_sdk sdk_addon, $(INSTALLED_FILES_FILE_ROOT))

#------------------------------------------------------------------
# dtb
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
INSTALLED_DTBIMAGE_TARGET := $(PRODUCT_OUT)/dtb.img
ifdef BOARD_PREBUILT_DTBIMAGE_DIR
$(INSTALLED_DTBIMAGE_TARGET) : $(sort $(wildcard $(BOARD_PREBUILT_DTBIMAGE_DIR)/*.dtb))
	cat $^ > $@
endif
endif

# -----------------------------------------------------------------
# the ramdisk
ifdef BUILDING_RAMDISK_IMAGE
INTERNAL_RAMDISK_FILES := $(filter $(TARGET_RAMDISK_OUT)/%, \
	$(ALL_GENERATED_SOURCES) \
	$(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_RAMDISK := $(PRODUCT_OUT)/installed-files-ramdisk.txt
INSTALLED_FILES_JSON_RAMDISK := $(INSTALLED_FILES_FILE_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_RAMDISK)
$(INSTALLED_FILES_FILE_RAMDISK) : $(INTERNAL_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(TARGET_RAMDISK_OUT)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_RAMDISK_OUT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call dist-for-goals, sdk win_sdk sdk_addon, $(INSTALLED_FILES_FILE_RAMDISK))
BUILT_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img

ifeq ($(BOARD_RAMDISK_USE_LZ4),true)
# -l enables the legacy format used by the Linux kernel
COMPRESSION_COMMAND_DEPS := $(LZ4)
COMPRESSION_COMMAND := $(LZ4) -l -12 --favor-decSpeed
RAMDISK_EXT := .lz4
else
COMPRESSION_COMMAND_DEPS := $(MINIGZIP)
COMPRESSION_COMMAND := $(MINIGZIP)
RAMDISK_EXT := .gz
endif

# We just build this directly to the install location.
INSTALLED_RAMDISK_TARGET := $(BUILT_RAMDISK_TARGET)
$(INSTALLED_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_RAMDISK_FILES) $(INSTALLED_FILES_FILE_RAMDISK) | $(COMPRESSION_COMMAND_DEPS)
	$(call pretty,"Target ram disk: $@")
	$(hide) $(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_RAMDISK_OUT) | $(COMPRESSION_COMMAND) > $@

.PHONY: ramdisk-nodeps
ramdisk-nodeps: $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	@echo "make $@: ignoring dependencies"
	$(hide) $(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_RAMDISK_OUT) | $(COMPRESSION_COMMAND) > $(INSTALLED_RAMDISK_TARGET)

endif # BUILDING_RAMDISK_IMAGE

# -----------------------------------------------------------------
# the boot image, which is a collection of other images.

# This is defined here since we may be building recovery as boot
# below and only want to define this once
ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
  BUILT_BOOTIMAGE_TARGET := $(foreach k,$(subst kernel,boot,$(BOARD_KERNEL_BINARIES)), $(PRODUCT_OUT)/$(k).img)
else
  BUILT_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img
endif

# $1: boot image target
# returns the kernel used to make the bootimage
define bootimage-to-kernel
  $(if $(BOARD_KERNEL_BINARIES),\
    $(PRODUCT_OUT)/$(subst .img,,$(subst boot,kernel,$(notdir $(1)))),\
    $(INSTALLED_KERNEL_TARGET))
endef

ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
  BOARD_KERNEL_BOOTIMAGE_PARTITION_SIZE := $(BOARD_BOOTIMAGE_PARTITION_SIZE)
endif

# $1: boot image file name
# $2: boot image variant (boot, boot-debug)
define get-bootimage-partition-size
  $(BOARD_$(call to-upper,$(subst .img,,$(subst $(2),kernel,$(notdir $(1)))))_BOOTIMAGE_PARTITION_SIZE)
endef

ifneq ($(strip $(TARGET_NO_KERNEL)),true)
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET))

ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
INTERNAL_BOOTIMAGE_ARGS += --ramdisk $(INSTALLED_RAMDISK_TARGET)
endif

ifndef BUILDING_VENDOR_BOOT_IMAGE
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  INTERNAL_BOOTIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
endif
endif

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

ifeq ($(PRODUCT_SUPPORTS_VERITY),true)
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
VERITY_KEYID := veritykeyid=id:`openssl x509 -in $(PRODUCT_VERITY_SIGNING_KEY).x509.pem -text \
                | grep keyid | sed 's/://g' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/keyid//g'`
endif
endif

INTERNAL_KERNEL_CMDLINE := $(strip $(INTERNAL_KERNEL_CMDLINE) buildvariant=$(TARGET_BUILD_VARIANT) $(VERITY_KEYID))

boot_uses_generic_kernel_image :=
ifdef BUILDING_VENDOR_BOOT_IMAGE
  # building vendor boot image, dtb/base/pagesize go there
  boot_uses_generic_kernel_image := true
else ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
  boot_uses_generic_kernel_image := true
endif

ifeq (true,$(boot_uses_generic_kernel_image))
  ifdef GENERIC_KERNEL_CMDLINE
    INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(GENERIC_KERNEL_CMDLINE)"
  endif
else # boot_uses_generic_kernel_image != true
ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif
ifdef INTERNAL_KERNEL_CMDLINE
  INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif
endif # boot_uses_generic_kernel_image == true
boot_uses_generic_kernel_image :=

INTERNAL_MKBOOTIMG_VERSION_ARGS := \
    --os_version $(PLATFORM_VERSION_LAST_STABLE) \
    --os_patch_level $(PLATFORM_SECURITY_PATCH)

# Define these only if we are building boot
ifdef BUILDING_BOOT_IMAGE
INSTALLED_BOOTIMAGE_TARGET := $(BUILT_BOOTIMAGE_TARGET)

ifeq ($(TARGET_BOOTIMAGE_USE_EXT2),true)
$(error TARGET_BOOTIMAGE_USE_EXT2 is not supported anymore)
endif # TARGET_BOOTIMAGE_USE_EXT2

$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET), $(eval $(call add-dependency,$(b),$(call bootimage-to-kernel,$(b)))))

ifeq (true,$(BOARD_AVB_ENABLE))

# $1: boot image target
define build_boot_board_avb_enabled
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1)
  $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE)))
  $(AVBTOOL) add_hash_footer \
          --image $(1) \
          --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) \
          --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
          $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_board_avb_enabled,$@)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_board_avb_enabled,$(b)))

else ifeq (true,$(PRODUCT_SUPPORTS_BOOT_SIGNER)) # BOARD_AVB_ENABLE != true

# $1: boot image target
define build_boot_supports_boot_signer
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1)
  $(BOOT_SIGNER) /boot $@ $(PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCT_VERITY_SIGNING_KEY).x509.pem $(1)
  $(call assert-max-image-size,$(1),$(BOARD_BOOTIMAGE_PARTITION_SIZE))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(BOOT_SIGNER)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_supports_boot_signer,$@)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(BOOT_SIGNER)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_supports_boot_signer,$(b)))

else ifeq (true,$(PRODUCT_SUPPORTS_VBOOT)) # PRODUCT_SUPPORTS_BOOT_SIGNER != true

# $1: boot image target
define build_boot_supports_vboot
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1).unsigned
  $(VBOOT_SIGNER) $(FUTILITY) $(1).unsigned $(PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(1).keyblock $(1)
  $(call assert-max-image-size,$(1),$(BOARD_BOOTIMAGE_PARTITION_SIZE))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(VBOOT_SIGNER) $(FUTILITY)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_supports_vboot,$@)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(VBOOT_SIGNER) $(FUTILITY)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_supports_vboot,$(b)))

else # PRODUCT_SUPPORTS_VBOOT != true

# $1: boot image target
define build_boot_novboot
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1)
  $(call assert-max-image-size,$1,$(BOARD_BOOTIMAGE_PARTITION_SIZE))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_novboot,$@)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_novboot,$(b)))

endif # BOARD_AVB_ENABLE
endif # BUILDING_BOOT_IMAGE

else # TARGET_NO_KERNEL == "true"
ifdef BOARD_PREBUILT_BOOTIMAGE
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
# Remove when b/63676296 is resolved.
$(error Prebuilt bootimage is only supported for AB targets)
endif
INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_BOOTIMAGE),$(INSTALLED_BOOTIMAGE_TARGET)))
else # BOARD_PREBUILT_BOOTIMAGE not defined
INSTALLED_BOOTIMAGE_TARGET :=
endif # BOARD_PREBUILT_BOOTIMAGE
endif # TARGET_NO_KERNEL

# -----------------------------------------------------------------
# declare recovery ramdisk files
ifeq ($(BUILDING_RECOVERY_IMAGE),true)
INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP := $(call intermediates-dir-for,PACKAGING,recovery)/ramdisk_files-timestamp
endif

# -----------------------------------------------------------------
# vendor boot image
ifeq ($(BUILDING_VENDOR_BOOT_IMAGE),true)

ifeq ($(PRODUCT_SUPPORTS_VERITY),true)
  $(error vboot 1.0 does not support vendor_boot partition)
endif

INTERNAL_VENDOR_RAMDISK_FILES := $(filter $(TARGET_VENDOR_RAMDISK_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES))

INTERNAL_VENDOR_RAMDISK_TARGET := $(call intermediates-dir-for,PACKAGING,vendor-boot)/vendor-ramdisk.cpio$(RAMDISK_EXT)

ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
$(INTERNAL_VENDOR_RAMDISK_TARGET): $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
$(INTERNAL_VENDOR_RAMDISK_TARGET): PRIVATE_ADDITIONAL_DIR := $(TARGET_RECOVERY_ROOT_OUT)
endif

$(INTERNAL_VENDOR_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_VENDOR_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_VENDOR_RAMDISK_OUT) $(PRIVATE_ADDITIONAL_DIR) | $(COMPRESSION_COMMAND) > $@

ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  INTERNAL_VENDOR_BOOTIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
endif
ifdef BOARD_KERNEL_BASE
  INTERNAL_VENDOR_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_VENDOR_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif
ifdef INTERNAL_KERNEL_CMDLINE
  INTERNAL_VENDOR_BOOTIMAGE_ARGS += --vendor_cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif

INSTALLED_VENDOR_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/vendor_boot.img
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_DTBIMAGE_TARGET)
ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_BOOTIMAGE_KEY_PATH)
	$(call pretty,"Target vendor_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_RAMDISK_TARGET) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
	$(AVBTOOL) add_hash_footer \
           --image $@ \
	   --partition_size $(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE) \
	   --partition_name vendor_boot $(INTERNAL_AVB_VENDOR_BOOT_SIGNING_ARGS) \
	   $(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)
else
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET):
	$(call pretty,"Target vendor_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_RAMDISK_TARGET) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
endif
endif # BUILDING_VENDOR_BOOT_IMAGE

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
# $(1) - xml_excluded_system_product_odm_vendor_dlkm_odm_dlkm|
#        xml_excluded_vendor_product_odm_vendor_dlkm_odm_dlkm|
#        xml_product|xml_odm|xml_system_ext|xml_system|xml_vendor_dlkm|
#        xml_odm_dlkm|html
# $(2) - Plain text output file
# $(3) - HTML/XML output file
# $(4) - File title
# $(5) - Directory to use.  Notice files are all $(5)/src.  Other
#		 directories in there will be used for scratch
# $(6) - Dependencies for the output files
# $(7) - Directories to exclude
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
$(2): PRIVATE_MESSAGE := $(4)
$(2): PRIVATE_DIR := $(5)
$(2): .KATI_IMPLICIT_OUTPUTS := $(3)
$(2): $(6) $(BUILD_SYSTEM)/Makefile build/make/tools/generate-notice-files.py
	build/make/tools/generate-notice-files.py --text-output $(2) $(foreach xdir, $(7), -e $(xdir) )\
	    $(if $(filter $(1),xml_excluded_vendor_product_odm_vendor_dlkm_odm_dlkm),-e vendor -e product -e system_ext -e odm -e vendor_dlkm -e odm_dlkm --xml-output, \
	      $(if $(filter $(1),xml_excluded_system_product_odm_vendor_dlkm_odm_dlkm),-e system -e product -e system_ext -e odm -e vendor_dlkm -e odm_dlkm --xml-output, \
	        $(if $(filter $(1),xml_product),-i product --xml-output, \
	          $(if $(filter $(1),xml_system_ext),-i system_ext --xml-output, \
	            $(if $(filter $(1),xml_system),-i system --xml-output, \
	              $(if $(filter $(1),xml_odm),-i odm --xml-output, \
	                $(if $(filter $(1),xml_vendor_dlkm),-i vendor_dlkm --xml-output, \
	                  $(if $(filter $(1),xml_odm_dlkm),-i odm_dlkm --xml-output, \
	                    --html-output)))))))) $(3) \
	    -t $$(PRIVATE_MESSAGE) $$(foreach dir,$$(sort $$(PRIVATE_DIR)), -s $$(dir)/src)
notice_files: $(2) $(3)
endef

# Notice file logic isn't relevant for TARGET_BUILD_APPS
ifndef TARGET_BUILD_APPS

# TODO These intermediate NOTICE.txt/NOTICE.html files should go into
# TARGET_OUT_NOTICE_FILES now that the notice files are gathered from
# the src subdirectory.
target_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE.txt
tools_notice_file_txt := $(HOST_OUT_INTERMEDIATES)/NOTICE.txt
tools_notice_file_html := $(HOST_OUT_INTERMEDIATES)/NOTICE.html
kernel_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/kernel.txt
winpthreads_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/winpthreads.txt

# Some targets get included under $(PRODUCT_OUT) for debug symbols or other
# reasons--not to be flashed onto any device. Targets under these directories
# need no associated notice file on the device UI.
exclude_target_dirs := apex

# TODO(b/69865032): Make PRODUCT_NOTICE_SPLIT the default behavior.
ifneq ($(PRODUCT_NOTICE_SPLIT),true)
target_notice_file_html := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html
target_notice_file_html_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.html.gz
$(eval $(call combine-notice-files, html, \
	        $(target_notice_file_txt), \
	        $(target_notice_file_html), \
	        "Notices for files contained in the filesystem images in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file), \
	        $(exclude_target_dirs)))
$(target_notice_file_html_gz): $(target_notice_file_html) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(installed_notice_html_or_xml_gz): $(target_notice_file_html_gz)
	$(copy-file-to-target)
else
target_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml
target_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.xml.gz

target_vendor_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.txt
target_vendor_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.xml
target_vendor_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.xml.gz
installed_vendor_notice_xml_gz := $(TARGET_OUT_VENDOR)/etc/NOTICE.xml.gz

target_product_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_PRODUCT.txt
target_product_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_PRODUCT.xml
target_product_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_PRODUCT.xml.gz
installed_product_notice_xml_gz := $(TARGET_OUT_PRODUCT)/etc/NOTICE.xml.gz

target_system_ext_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_EXT.txt
target_system_ext_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_EXT.xml
target_system_ext_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_EXT.xml.gz
installed_system_ext_notice_xml_gz := $(TARGET_OUT_SYSTEM_EXT)/etc/NOTICE.xml.gz

target_odm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM.txt
target_odm_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM.xml
target_odm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM.xml.gz
installed_odm_notice_xml_gz := $(TARGET_OUT_ODM)/etc/NOTICE.xml.gz

target_vendor_dlkm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR_DLKM.txt
target_vendor_dlkm_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR_DLKM.xml
target_vendor_dlkm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR_DLKM.xml.gz
installed_vendor_dlkm_notice_xml_gz := $(TARGET_OUT_VENDOR_DLKM)/etc/NOTICE.xml.gz

target_odm_dlkm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM_DLKM.txt
target_odm_dlkm_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM_DLKM.xml
target_odm_dlkm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM_DLKM.xml.gz
installed_odm_dlkm_notice_xml_gz := $(TARGET_OUT_ODM_DLKM)/etc/NOTICE.xml.gz

# Notice files are copied to TARGET_OUT_NOTICE_FILES as a side-effect of their module
# being built. A notice xml file must depend on all modules that could potentially
# install a license file relevant to it.
license_modules := $(ALL_DEFAULT_INSTALLED_MODULES) $(kernel_notice_file)
# Only files copied to a system image need system image notices.
license_modules := $(filter $(PRODUCT_OUT)/%,$(license_modules))
# Phonys/fakes don't have notice files (though their deps might)
license_modules := $(filter-out $(TARGET_OUT_FAKE)/%,$(license_modules))
# testcases are not relevant to the system image.
license_modules := $(filter-out $(TARGET_OUT_TESTCASES)/%,$(license_modules))
# filesystem images: system, vendor, product, system_ext, odm, vendor_dlkm, and odm_dlkm
license_modules_system := $(filter $(TARGET_OUT)/%,$(license_modules))
# system_other is relevant to system partition.
license_modules_system += $(filter $(TARGET_OUT_SYSTEM_OTHER)/%,$(license_modules))
license_modules_vendor := $(filter $(TARGET_OUT_VENDOR)/%,$(license_modules))
license_modules_product := $(filter $(TARGET_OUT_PRODUCT)/%,$(license_modules))
license_modules_system_ext := $(filter $(TARGET_OUT_SYSTEM_EXT)/%,$(license_modules))
license_modules_odm := $(filter $(TARGET_OUT_ODM)/%,$(license_modules))
license_modules_vendor_dlkm := $(filter $(TARGET_OUT_VENDOR_DLKM)/%,$(license_modules))
license_modules_odm_dlkm := $(filter $(TARGET_OUT_ODM_DLKM)/%,$(license_modules))
license_modules_agg := $(license_modules_system) \
                       $(license_modules_vendor) \
                       $(license_modules_product) \
                       $(license_modules_system_ext) \
                       $(license_modules_odm) \
                       $(license_modules_vendor_dlkm) \
                       $(license_modules_odm_dlkm)
# targets used for debug symbols only and do not get copied to the device
license_modules_symbols_only := $(filter $(PRODUCT_OUT)/apex/%,$(license_modules))

license_modules_rest := $(filter-out $(license_modules_agg),$(license_modules))
license_modules_rest := $(filter-out $(license_modules_symbols_only),$(license_modules_rest))

# Identify the other targets we expect to have notices for:
# targets copied to the device but are not readable by the UI (e.g. must boot
# into a different partition to read or don't have an associated /etc
# directory) must have their notices built somewhere readable.
license_modules_rehomed := $(filter-out $(PRODUCT_OUT)/%/%,$(license_modules_rest))  # files in root have no /etc
license_modules_rehomed += $(filter $(PRODUCT_OUT)/recovery/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/root/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/data/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/ramdisk/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/debug_ramdisk/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/vendor-ramdisk/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/persist/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/persist.img,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/system_other/%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/kernel%,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/%.img,$(license_modules_rest))
license_modules_rehomed += $(filter $(PRODUCT_OUT)/%.bin,$(license_modules_rest))

# after removing targets in system images, targets reported in system images, and
# targets used for debug symbols that do not need notices, nothing must remain.
license_modules_rest := $(filter-out $(license_modules_rehomed),$(license_modules_rest))
$(call maybe-print-list-and-error, $(license_modules_rest), \
        "Targets added under $(PRODUCT_OUT)/ unaccounted for notice handling.")

# If we are building in a configuration that includes a prebuilt vendor.img, we can't
# update its notice file, so include those notices in the system partition instead
ifdef BOARD_PREBUILT_VENDORIMAGE
license_modules_system += $(license_modules_rehomed)
system_xml_directories := xml_excluded_vendor_product_odm_vendor_dlkm_odm_dlkm
system_notice_file_message := "Notices for files contained in all filesystem images except vendor/system_ext/product/odm/vendor_dlkm/odm_dlkm in this directory:"
else
license_modules_vendor += $(license_modules_rehomed)
system_xml_directories := xml_system
system_notice_file_message := "Notices for files contained in the system filesystem image in this directory:"
endif

$(eval $(call combine-notice-files, $(system_xml_directories), \
	        $(target_notice_file_txt), \
	        $(target_notice_file_xml), \
	        $(system_notice_file_message), \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_system), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_excluded_system_product_odm_vendor_dlkm_odm_dlkm, \
	        $(target_vendor_notice_file_txt), \
	        $(target_vendor_notice_file_xml), \
	        "Notices for files contained in all filesystem images except system/system_ext/product/odm/vendor_dlkm/odm_dlkm in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_vendor), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_product, \
	        $(target_product_notice_file_txt), \
	        $(target_product_notice_file_xml), \
	        "Notices for files contained in the product filesystem image in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_product), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_system_ext, \
	        $(target_system_ext_notice_file_txt), \
	        $(target_system_ext_notice_file_xml), \
	        "Notices for files contained in the system_ext filesystem image in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_system_ext), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_odm, \
	        $(target_odm_notice_file_txt), \
	        $(target_odm_notice_file_xml), \
	        "Notices for files contained in the odm filesystem image in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_odm), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_vendor_dlkm, \
	        $(target_vendor_dlkm_notice_file_txt), \
	        $(target_vendor_dlkm_notice_file_xml), \
	        "Notices for files contained in the vendor_dlkm filesystem image in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_vendor_dlkm), \
	        $(exclude_target_dirs)))
$(eval $(call combine-notice-files, xml_odm_dlkm, \
	        $(target_odm_dlkm_notice_file_txt), \
	        $(target_odm_dlkm_notice_file_xml), \
	        "Notices for files contained in the odm_dlkm filesystem image in this directory:", \
	        $(TARGET_OUT_NOTICE_FILES), \
	        $(license_modules_odm_dlkm), \
	        $(exclude_target_dirs)))

$(target_notice_file_xml_gz): $(target_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_vendor_notice_file_xml_gz): $(target_vendor_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_product_notice_file_xml_gz): $(target_product_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_system_ext_notice_file_xml_gz): $(target_system_ext_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_odm_notice_file_xml_gz): $(target_odm_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_vendor_dlkm_notice_file_xml_gz): $(target_vendor_dlkm_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(target_odm_dlkm_notice_file_xml_gz): $(target_odm_dlkm_notice_file_xml) | $(MINIGZIP)
	$(hide) $(MINIGZIP) -9 < $< > $@
$(installed_notice_html_or_xml_gz): $(target_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_vendor_notice_xml_gz): $(target_vendor_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_product_notice_xml_gz): $(target_product_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_system_ext_notice_xml_gz): $(target_system_ext_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_odm_notice_xml_gz): $(target_odm_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_vendor_dlkm_notice_xml_gz): $(target_vendor_dlkm_notice_file_xml_gz)
	$(copy-file-to-target)
$(installed_odm_dlkm_notice_xml_gz): $(target_odm_dlkm_notice_file_xml_gz)
	$(copy-file-to-target)

ALL_DEFAULT_INSTALLED_MODULES += $(installed_notice_html_or_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_vendor_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_product_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_system_ext_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_odm_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_vendor_dlkm_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_odm_dlkm_notice_xml_gz)
endif # PRODUCT_NOTICE_SPLIT

ALL_DEFAULT_INSTALLED_MODULES += $(installed_notice_html_or_xml_gz)

$(eval $(call combine-notice-files, html, \
	        $(tools_notice_file_txt), \
	        $(tools_notice_file_html), \
	        "Notices for files contained in the tools directory:", \
	        $(HOST_OUT_NOTICE_FILES), \
	        $(ALL_DEFAULT_INSTALLED_MODULES) \
	        $(winpthreads_notice_file), \
	        $(exclude_target_dirs)))

endif  # TARGET_BUILD_APPS

# The kernel isn't really a module, so to get its module file in there, we
# make the target NOTICE files depend on this particular file too, which will
# then be in the right directory for the find in combine-notice-files to work.
$(eval $(call copy-one-file,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,$(kernel_notice_file)))

$(eval $(call copy-one-file,$(BUILD_SYSTEM)/WINPTHREADS_COPYING,$(winpthreads_notice_file)))


# #################################################################
# Targets for user images
# #################################################################

INTERNAL_USERIMAGES_EXT_VARIANT :=
ifeq ($(TARGET_USERIMAGES_USE_EXT2),true)
INTERNAL_USERIMAGES_EXT_VARIANT := ext2
else
ifeq ($(TARGET_USERIMAGES_USE_EXT3),true)
INTERNAL_USERIMAGES_EXT_VARIANT := ext3
else
ifeq ($(TARGET_USERIMAGES_USE_EXT4),true)
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
ifneq (true,$(TARGET_USERIMAGES_SPARSE_SQUASHFS_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG := -s
endif
ifneq (true,$(TARGET_USERIMAGES_SPARSE_F2FS_DISABLED))
  INTERNAL_USERIMAGES_SPARSE_F2FS_FLAG := -S
endif

INTERNAL_USERIMAGES_DEPS := \
    $(BUILD_IMAGE) \
    $(MKE2FS_CONF) \
    $(MKEXTUSERIMG)

ifeq ($(TARGET_USERIMAGES_USE_F2FS),true)
INTERNAL_USERIMAGES_DEPS += $(MKF2FSUSERIMG)
endif

ifneq ($(filter \
    $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_ODMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE) \
  ,squashfs),)
INTERNAL_USERIMAGES_DEPS += $(MKSQUASHFSUSERIMG)
endif

ifeq (true,$(PRODUCT_SUPPORTS_VERITY))
INTERNAL_USERIMAGES_DEPS += $(BUILD_VERITY_METADATA) $(BUILD_VERITY_TREE) $(APPEND2SIMG) $(VERITY_SIGNER)
ifeq (true,$(PRODUCT_SUPPORTS_VERITY_FEC))
INTERNAL_USERIMAGES_DEPS += $(FEC)
endif
endif

ifeq ($(BOARD_AVB_ENABLE),true)
INTERNAL_USERIMAGES_DEPS += $(AVBTOOL)
endif

# Get a colon-separated list of search paths.
INTERNAL_USERIMAGES_BINARY_PATHS := $(subst $(space),:,$(sort $(dir $(INTERNAL_USERIMAGES_DEPS))))

# Collects file_contexts files from modules to be installed
$(call merge-fc-files, \
  $(sort $(foreach m,$(product_MODULES),$(ALL_MODULES.$(m).FILE_CONTEXTS))),\
  $(call intermediates-dir-for,ETC,file_contexts.bin)/file_contexts.modules.tmp)

SELINUX_FC := $(call intermediates-dir-for,ETC,file_contexts.bin)/file_contexts.bin

INTERNAL_USERIMAGES_DEPS += $(SELINUX_FC)

ifeq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))

ifeq ($(PRODUCT_SUPPORTS_VERITY),true)
  $(error vboot 1.0 doesn't support logical partition)
endif

endif # PRODUCT_USE_DYNAMIC_PARTITIONS

# $(1): the path of the output dictionary file
# $(2): a subset of "system vendor cache userdata product system_ext oem odm vendor_dlkm odm_dlkm"
# $(3): additional "key=value" pairs to append to the dictionary file.
define generate-image-prop-dictionary
$(if $(filter $(2),system),\
    $(if $(BOARD_SYSTEMIMAGE_PARTITION_SIZE),$(hide) echo "system_size=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(INTERNAL_SYSTEM_OTHER_PARTITION_SIZE),$(hide) echo "system_other_size=$(INTERNAL_SYSTEM_OTHER_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "system_fs_type=$(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "system_extfs_inode_count=$(BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_EXTFS_RSV_PCT),$(hide) echo "system_extfs_rsv_pct=$(BOARD_SYSTEMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_JOURNAL_SIZE),$(hide) echo "system_journal_size=$(BOARD_SYSTEMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "system_squashfs_compressor=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "system_squashfs_compressor_opt=$(BOARD_SYSTEMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "system_squashfs_block_size=$(BOARD_SYSTEMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "system_squashfs_disable_4k_align=$(BOARD_SYSTEMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(PRODUCT_SYSTEM_BASE_FS_PATH),$(hide) echo "system_base_fs_file=$(PRODUCT_SYSTEM_BASE_FS_PATH)" >> $(1))
    $(if $(PRODUCT_SYSTEM_HEADROOM),$(hide) echo "system_headroom=$(PRODUCT_SYSTEM_HEADROOM)" >> $(1))
    $(if $(BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "system_reserved_size=$(BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "system_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_system_image=$(BUILDING_SYSTEM_IMAGE)" >> $(1)
)
$(if $(filter $(2),system_other),\
    $(hide) echo "building_system_other_image=$(BUILDING_SYSTEM_OTHER_IMAGE)" >> $(1)
)
$(if $(filter $(2),userdata),\
    $(if $(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "userdata_fs_type=$(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(hide) echo "userdata_size=$(BOARD_USERDATAIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(PRODUCT_FS_CASEFOLD),$(hide) echo "needs_casefold=$(PRODUCT_FS_CASEFOLD)" >> $(1))
    $(if $(PRODUCT_QUOTA_PROJID),$(hide) echo "needs_projid=$(PRODUCT_QUOTA_PROJID)" >> $(1))
    $(if $(PRODUCT_FS_COMPRESSION),$(hide) echo "needs_compress=$(PRODUCT_FS_COMPRESSION)" >> $(1))
    $(hide) echo "userdata_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_userdata_image=$(BUILDING_USERDATA_IMAGE)" >> $(1)
)
$(if $(filter $(2),cache),\
    $(if $(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "cache_fs_type=$(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_CACHEIMAGE_PARTITION_SIZE),$(hide) echo "cache_size=$(BOARD_CACHEIMAGE_PARTITION_SIZE)" >> $(1))
    $(hide) echo "cache_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_cache_image=$(BUILDING_CACHE_IMAGE)" >> $(1)
)
$(if $(filter $(2),vendor),\
    $(if $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "vendor_fs_type=$(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT),$(hide) echo "vendor_extfs_inode_count=$(BOARD_VENDORIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_EXTFS_RSV_PCT),$(hide) echo "vendor_extfs_rsv_pct=$(BOARD_VENDORIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_PARTITION_SIZE),$(hide) echo "vendor_size=$(BOARD_VENDORIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_JOURNAL_SIZE),$(hide) echo "vendor_journal_size=$(BOARD_VENDORIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "vendor_squashfs_compressor=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "vendor_squashfs_compressor_opt=$(BOARD_VENDORIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "vendor_squashfs_block_size=$(BOARD_VENDORIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "vendor_squashfs_disable_4k_align=$(BOARD_VENDORIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(PRODUCT_VENDOR_BASE_FS_PATH),$(hide) echo "vendor_base_fs_file=$(PRODUCT_VENDOR_BASE_FS_PATH)" >> $(1))
    $(if $(BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "vendor_reserved_size=$(BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "vendor_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_vendor_image=$(BUILDING_VENDOR_IMAGE)" >> $(1)
)
$(if $(filter $(2),product),\
    $(if $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "product_fs_type=$(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT),$(hide) echo "product_extfs_inode_count=$(BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_EXTFS_RSV_PCT),$(hide) echo "product_extfs_rsv_pct=$(BOARD_PRODUCTIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_PARTITION_SIZE),$(hide) echo "product_size=$(BOARD_PRODUCTIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_JOURNAL_SIZE),$(hide) echo "product_journal_size=$(BOARD_PRODUCTIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "product_squashfs_compressor=$(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "product_squashfs_compressor_opt=$(BOARD_PRODUCTIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "product_squashfs_block_size=$(BOARD_PRODUCTIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "product_squashfs_disable_4k_align=$(BOARD_PRODUCTIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(PRODUCT_PRODUCT_BASE_FS_PATH),$(hide) echo "product_base_fs_file=$(PRODUCT_PRODUCT_BASE_FS_PATH)" >> $(1))
    $(if $(BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "product_reserved_size=$(BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "product_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_product_image=$(BUILDING_PRODUCT_IMAGE)" >> $(1)
)
$(if $(filter $(2),system_ext),\
    $(if $(BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "system_ext_fs_type=$(BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_EXTFS_INODE_COUNT),$(hide) echo "system_ext_extfs_inode_count=$(BOARD_SYSTEM_EXTIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_EXTFS_RSV_PCT),$(hide) echo "system_ext_extfs_rsv_pct=$(BOARD_SYSTEM_EXTIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE),$(hide) echo "system_ext_size=$(BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_JOURNAL_SIZE),$(hide) echo "system_ext_journal_size=$(BOARD_SYSTEM_EXTIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "system_ext_squashfs_compressor=$(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "system_ext_squashfs_compressor_opt=$(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "system_ext_squashfs_block_size=$(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "system_ext_squashfs_disable_4k_align=$(BOARD_SYSTEM_EXTIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "system_ext_reserved_size=$(BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "system_ext_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_system_ext_image=$(BUILDING_SYSTEM_EXT_IMAGE)" >> $(1)
)
$(if $(filter $(2),odm),\
    $(if $(BOARD_ODMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "odm_fs_type=$(BOARD_ODMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_ODMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "odm_extfs_inode_count=$(BOARD_ODMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_ODMIMAGE_EXTFS_RSV_PCT),$(hide) echo "odm_extfs_rsv_pct=$(BOARD_ODMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_ODMIMAGE_PARTITION_SIZE),$(hide) echo "odm_size=$(BOARD_ODMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_ODMIMAGE_JOURNAL_SIZE),$(hide) echo "odm_journal_size=$(BOARD_ODMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_ODMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "odm_squashfs_compressor=$(BOARD_ODMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_ODMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "odm_squashfs_compressor_opt=$(BOARD_ODMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_ODMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "odm_squashfs_block_size=$(BOARD_ODMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_ODMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "odm_squashfs_disable_4k_align=$(BOARD_ODMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(PRODUCT_ODM_BASE_FS_PATH),$(hide) echo "odm_base_fs_file=$(PRODUCT_ODM_BASE_FS_PATH)" >> $(1))
    $(if $(BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "odm_reserved_size=$(BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "odm_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_odm_image=$(BUILDING_ODM_IMAGE)" >> $(1)
)
$(if $(filter $(2),vendor_dlkm),\
    $(if $(BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "vendor_dlkm_fs_type=$(BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "vendor_dlkm_extfs_inode_count=$(BOARD_VENDOR_DLKMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_EXTFS_RSV_PCT),$(hide) echo "vendor_dlkm_extfs_rsv_pct=$(BOARD_VENDOR_DLKMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE),$(hide) echo "vendor_dlkm_size=$(BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_JOURNAL_SIZE),$(hide) echo "vendor_dlkm_journal_size=$(BOARD_VENDOR_DLKMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "vendor_dlkm_squashfs_compressor=$(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "vendor_dlkm_squashfs_compressor_opt=$(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "vendor_dlkm_squashfs_block_size=$(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "vendor_dlkm_squashfs_disable_4k_align=$(BOARD_VENDOR_DLKMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(BOARD_VENDOR_DLKMIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "vendor_dlkm_reserved_size=$(BOARD_VENDOR_DLKMIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "vendor_dlkm_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_vendor_dlkm_image=$(BUILDING_VENDOR_DLKM_IMAGE)" >> $(1)
)
$(if $(filter $(2),odm_dlkm),\
    $(if $(BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "odm_dlkm_fs_type=$(BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "odm_dlkm_extfs_inode_count=$(BOARD_ODM_DLKMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_EXTFS_RSV_PCT),$(hide) echo "odm_dlkm_extfs_rsv_pct=$(BOARD_ODM_DLKMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_PARTITION_SIZE),$(hide) echo "odm_dlkm_size=$(BOARD_ODM_DLKMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_JOURNAL_SIZE),$(hide) echo "odm_dlkm_journal_size=$(BOARD_ODM_DLKMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "odm_dlkm_squashfs_compressor=$(BOARD_ODM_DLKMIMAGE_SQUASHFS_COMPRESSOR)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "odm_dlkm_squashfs_compressor_opt=$(BOARD_ODM_DLKMIMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "odm_dlkm_squashfs_block_size=$(BOARD_ODM_DLKMIMAGE_SQUASHFS_BLOCK_SIZE)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "odm_dlkm_squashfs_disable_4k_align=$(BOARD_ODM_DLKMIMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(1))
    $(if $(BOARD_ODM_DLKMIMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "odm_dlkm_reserved_size=$(BOARD_ODM_DLKMIMAGE_PARTITION_RESERVED_SIZE)" >> $(1))
    $(hide) echo "odm_dlkm_selinux_fc=$(SELINUX_FC)" >> $(1)
    $(hide) echo "building_odm_dlkm_image=$(BUILDING_ODM_DLKM_IMAGE)" >> $(1)
)
$(if $(filter $(2),oem),\
    $(if $(BOARD_OEMIMAGE_PARTITION_SIZE),$(hide) echo "oem_size=$(BOARD_OEMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_OEMIMAGE_JOURNAL_SIZE),$(hide) echo "oem_journal_size=$(BOARD_OEMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_OEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "oem_extfs_inode_count=$(BOARD_OEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_OEMIMAGE_EXTFS_RSV_PCT),$(hide) echo "oem_extfs_rsv_pct=$(BOARD_OEMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(hide) echo "oem_selinux_fc=$(SELINUX_FC)" >> $(1)
)
$(hide) echo "ext_mkuserimg=$(notdir $(MKEXTUSERIMG))" >> $(1)

$(if $(INTERNAL_USERIMAGES_EXT_VARIANT),$(hide) echo "fs_type=$(INTERNAL_USERIMAGES_EXT_VARIANT)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG),$(hide) echo "extfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_EXT_FLAG)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG),$(hide) echo "squashfs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_SQUASHFS_FLAG)" >> $(1))
$(if $(INTERNAL_USERIMAGES_SPARSE_F2FS_FLAG),$(hide) echo "f2fs_sparse_flag=$(INTERNAL_USERIMAGES_SPARSE_F2FS_FLAG)" >> $(1))
$(if $(BOARD_EXT4_SHARE_DUP_BLOCKS),$(hide) echo "ext4_share_dup_blocks=$(BOARD_EXT4_SHARE_DUP_BLOCKS)" >> $(1))
$(if $(BOARD_FLASH_LOGICAL_BLOCK_SIZE), $(hide) echo "flash_logical_block_size=$(BOARD_FLASH_LOGICAL_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_FLASH_ERASE_BLOCK_SIZE), $(hide) echo "flash_erase_block_size=$(BOARD_FLASH_ERASE_BLOCK_SIZE)" >> $(1))
$(if $(PRODUCT_SUPPORTS_BOOT_SIGNER),$(hide) echo "boot_signer=$(PRODUCT_SUPPORTS_BOOT_SIGNER)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity=$(PRODUCT_SUPPORTS_VERITY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_key=$(PRODUCT_VERITY_SIGNING_KEY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VERITY),$(hide) echo "verity_signer_cmd=$(notdir $(VERITY_SIGNER))" >> $(1))
$(if $(PRODUCT_SUPPORTS_VERITY_FEC),$(hide) echo "verity_fec=$(PRODUCT_SUPPORTS_VERITY_FEC)" >> $(1))
$(if $(filter eng, $(TARGET_BUILD_VARIANT)),$(hide) echo "verity_disable=true" >> $(1))
$(if $(PRODUCT_SYSTEM_VERITY_PARTITION),$(hide) echo "system_verity_block_device=$(PRODUCT_SYSTEM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_VENDOR_VERITY_PARTITION),$(hide) echo "vendor_verity_block_device=$(PRODUCT_VENDOR_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_PRODUCT_VERITY_PARTITION),$(hide) echo "product_verity_block_device=$(PRODUCT_PRODUCT_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_SYSTEM_EXT_VERITY_PARTITION),$(hide) echo "system_ext_verity_block_device=$(PRODUCT_SYSTEM_EXT_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_VENDOR_DLKM_VERITY_PARTITION),$(hide) echo "vendor_dlkm_verity_block_device=$(PRODUCT_VENDOR_DLKM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_ODM_DLKM_VERITY_PARTITION),$(hide) echo "odm_dlkm_verity_block_device=$(PRODUCT_ODM_DLKM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot=$(PRODUCT_SUPPORTS_VBOOT)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_key=$(PRODUCT_VBOOT_SIGNING_KEY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_subkey=$(PRODUCT_VBOOT_SIGNING_SUBKEY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "futility=$(notdir $(FUTILITY))" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_signer_cmd=$(VBOOT_SIGNER)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_avbtool=$(notdir $(AVBTOOL))" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_SYSTEM_KEY_PATH),\
        $(hide) echo "avb_system_key_path=$(BOARD_AVB_SYSTEM_KEY_PATH)" >> $(1)
        $(hide) echo "avb_system_algorithm=$(BOARD_AVB_SYSTEM_ALGORITHM)" >> $(1)
        $(hide) echo "avb_system_rollback_index_location=$(BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_other_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_other_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_OTHER_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_SYSTEM_OTHER_KEY_PATH),\
        $(hide) echo "avb_system_other_key_path=$(BOARD_AVB_SYSTEM_OTHER_KEY_PATH)" >> $(1)
        $(hide) echo "avb_system_other_algorithm=$(BOARD_AVB_SYSTEM_OTHER_ALGORITHM)" >> $(1)))
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
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_system_ext_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(hide) echo "avb_system_ext_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_SYSTEM_EXT_KEY_PATH),\
        $(hide) echo "avb_system_ext_key_path=$(BOARD_AVB_SYSTEM_EXT_KEY_PATH)" >> $(1)
        $(hide) echo "avb_system_ext_algorithm=$(BOARD_AVB_SYSTEM_EXT_ALGORITHM)" >> $(1)
        $(hide) echo "avb_system_ext_rollback_index_location=$(BOARD_AVB_SYSTEM_EXT_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_odm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_odm_add_hashtree_footer_args=$(BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_ODM_KEY_PATH),\
        $(hide) echo "avb_odm_key_path=$(BOARD_AVB_ODM_KEY_PATH)" >> $(1)
        $(hide) echo "avb_odm_algorithm=$(BOARD_AVB_ODM_ALGORITHM)" >> $(1)
        $(hide) echo "avb_odm_rollback_index_location=$(BOARD_AVB_ODM_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_vendor_dlkm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(hide) echo "avb_vendor_dlkm_add_hashtree_footer_args=$(BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_VENDOR_DLKM_KEY_PATH),\
        $(hide) echo "avb_vendor_dlkm_key_path=$(BOARD_AVB_VENDOR_DLKM_KEY_PATH)" >> $(1)
        $(hide) echo "avb_vendor_dlkm_algorithm=$(BOARD_AVB_VENDOR_DLKM_ALGORITHM)" >> $(1)
        $(hide) echo "avb_vendor_dlkm_rollback_index_location=$(BOARD_AVB_VENDOR_DLKM_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(BOARD_AVB_ENABLE),$(hide) echo "avb_odm_dlkm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(hide) echo "avb_odm_dlkm_add_hashtree_footer_args=$(BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1))
$(if $(BOARD_AVB_ENABLE),\
    $(if $(BOARD_AVB_ODM_DLKM_KEY_PATH),\
        $(hide) echo "avb_odm_dlkm_key_path=$(BOARD_AVB_ODM_DLKM_KEY_PATH)" >> $(1)
        $(hide) echo "avb_odm_dlkm_algorithm=$(BOARD_AVB_ODM_DLKM_ALGORITHM)" >> $(1)
        $(hide) echo "avb_odm_dlkm_rollback_index_location=$(BOARD_AVB_ODM_DLKM_ROLLBACK_INDEX_LOCATION)" >> $(1)))
$(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(hide) echo "recovery_as_boot=true" >> $(1))
$(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)),\
    $(hide) echo "system_root_image=true" >> $(1))
$(hide) echo "root_dir=$(TARGET_ROOT_OUT)" >> $(1)
$(if $(filter true,$(PRODUCT_USE_DYNAMIC_PARTITION_SIZE)),\
    $(hide) echo "use_dynamic_partition_size=true" >> $(1))
$(if $(3),$(hide) $(foreach kv,$(3),echo "$(kv)" >> $(1);))
endef

# $(1): the path of the output dictionary file
# $(2): additional "key=value" pairs to append to the dictionary file.
PROP_DICTIONARY_IMAGES := oem
ifdef BUILDING_CACHE_IMAGE
  PROP_DICTIONARY_IMAGES += cache
endif
ifdef BUILDING_SYSTEM_IMAGE
  PROP_DICTIONARY_IMAGES += system
endif
ifdef BUILDING_SYSTEM_OTHER_IMAGE
  PROP_DICTIONARY_IMAGES += system_other
endif
ifdef BUILDING_USERDATA_IMAGE
  PROP_DICTIONARY_IMAGES += userdata
endif
ifdef BUILDING_VENDOR_IMAGE
  PROP_DICTIONARY_IMAGES += vendor
endif
ifdef BUILDING_PRODUCT_IMAGE
  PROP_DICTIONARY_IMAGES += product
endif
ifdef BUILDING_SYSTEM_EXT_IMAGE
  PROP_DICTIONARY_IMAGES += system_ext
endif
ifdef BUILDING_ODM_IMAGE
  PROP_DICTIONARY_IMAGES += odm
endif
ifdef BUILDING_VENDOR_DLKM_IMAGE
  PROP_DICTIONARY_IMAGES += vendor_dlkm
endif
ifdef BUILDING_ODM_DLKM_IMAGE
  PROP_DICTIONARY_IMAGES += odm_dlkm
endif
define generate-userimage-prop-dictionary
  $(call generate-image-prop-dictionary,$(1),$(PROP_DICTIONARY_IMAGES),$(2))
endef

# $(1): the path of the input dictionary file, where each line has the format key=value
# $(2): the key to look up
define read-image-prop-dictionary
$$(grep '$(2)=' $(1) | cut -f2- -d'=')
endef

# -----------------------------------------------------------------
# Recovery image

# Recovery image exists if we are building recovery, or building recovery as boot.
ifdef BUILDING_RECOVERY_IMAGE

INTERNAL_RECOVERYIMAGE_FILES := $(filter $(TARGET_RECOVERY_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_RECOVERY := $(PRODUCT_OUT)/installed-files-recovery.txt
INSTALLED_FILES_JSON_RECOVERY := $(INSTALLED_FILES_FILE_RECOVERY:.txt=.json)

# TODO(b/30414428): Can't depend on INTERNAL_RECOVERYIMAGE_FILES alone like other
# INSTALLED_FILES_FILE_* rules. Because currently there're cp/rsync/rm commands in
# build-recoveryimage-target, which would touch the files under TARGET_RECOVERY_OUT and race with
# the call to FILELIST.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
INSTALLED_BOOTIMAGE_TARGET := $(BUILT_BOOTIMAGE_TARGET)
$(INSTALLED_FILES_FILE_RECOVERY): $(INSTALLED_BOOTIMAGE_TARGET)
else
$(INSTALLED_FILES_FILE_RECOVERY): $(INSTALLED_RECOVERYIMAGE_TARGET)
endif

$(INSTALLED_FILES_FILE_RECOVERY): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_RECOVERY)
$(INSTALLED_FILES_FILE_RECOVERY): $(INTERNAL_RECOVERYIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_RECOVERY_ROOT_OUT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

recovery_sepolicy := \
    $(TARGET_RECOVERY_ROOT_OUT)/sepolicy \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/system_ext_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/system_ext_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/product_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/product_property_contexts

# Passed into rsync from non-recovery root to recovery root, to avoid overwriting recovery-specific
# SELinux files
IGNORE_RECOVERY_SEPOLICY := $(patsubst $(TARGET_RECOVERY_OUT)/%,--exclude=/%,$(recovery_sepolicy))

# if building multiple boot images from multiple kernels, use the first kernel listed
# for the recovery image
recovery_kernel := $(firstword $(INSTALLED_KERNEL_TARGET))
recovery_ramdisk := $(PRODUCT_OUT)/ramdisk-recovery.img
recovery_resources_common := bootable/recovery/res

# Set recovery_density to a density bucket based on TARGET_SCREEN_DENSITY, PRODUCT_AAPT_PREF_CONFIG,
# or mdpi, in order of preference. We support both specific buckets (e.g. xdpi) and numbers,
# which get remapped to a bucket.
recovery_density := $(or $(TARGET_SCREEN_DENSITY),$(PRODUCT_AAPT_PREF_CONFIG),mdpi)
ifeq (,$(filter xxxhdpi xxhdpi xhdpi hdpi mdpi,$(recovery_density)))
recovery_density_value := $(patsubst %dpi,%,$(recovery_density))
# We roughly use the medium point between the primary densities to split buckets.
# ------160------240------320----------480------------640------
#       mdpi     hdpi    xhdpi        xxhdpi        xxxhdpi
recovery_density := $(strip \
  $(or $(if $(filter $(shell echo $$(($(recovery_density_value) >= 560))),1),xxxhdpi),\
       $(if $(filter $(shell echo $$(($(recovery_density_value) >= 400))),1),xxhdpi),\
       $(if $(filter $(shell echo $$(($(recovery_density_value) >= 280))),1),xhdpi),\
       $(if $(filter $(shell echo $$(($(recovery_density_value) >= 200))),1),hdpi,mdpi)))
endif

ifneq (,$(wildcard $(recovery_resources_common)-$(recovery_density)))
recovery_resources_common := $(recovery_resources_common)-$(recovery_density)
else
recovery_resources_common := $(recovery_resources_common)-xhdpi
endif

# Select the 18x32 font on high-density devices (xhdpi and up); and the 12x22 font on other devices.
# Note that the font selected here can be overridden for a particular device by putting a font.png
# in its private recovery resources.
ifneq (,$(filter xxxhdpi xxhdpi xhdpi,$(recovery_density)))
recovery_font := bootable/recovery/fonts/18x32.png
else
recovery_font := bootable/recovery/fonts/12x22.png
endif


# We will only generate the recovery background text images if the variable
# TARGET_RECOVERY_UI_SCREEN_WIDTH is defined. For devices with xxxhdpi and xxhdpi, we set the
# variable to the commonly used values here, if it hasn't been intialized elsewhere. While for
# devices with lower density, they must have TARGET_RECOVERY_UI_SCREEN_WIDTH defined in their
# BoardConfig in order to use this feature.
ifeq ($(recovery_density),xxxhdpi)
TARGET_RECOVERY_UI_SCREEN_WIDTH ?= 1440
else ifeq ($(recovery_density),xxhdpi)
TARGET_RECOVERY_UI_SCREEN_WIDTH ?= 1080
endif

ifneq ($(TARGET_RECOVERY_UI_SCREEN_WIDTH),)
# Subtracts the margin width and menu indent from the screen width; it's safe to be conservative.
ifeq ($(TARGET_RECOVERY_UI_MARGIN_WIDTH),)
  recovery_image_width := $$(($(TARGET_RECOVERY_UI_SCREEN_WIDTH) - 10))
else
  recovery_image_width := $$(($(TARGET_RECOVERY_UI_SCREEN_WIDTH) - $(TARGET_RECOVERY_UI_MARGIN_WIDTH) - 10))
endif


RECOVERY_INSTALLING_TEXT_FILE := $(call intermediates-dir-for,ETC,recovery_text_res)/installing_text.png
RECOVERY_INSTALLING_SECURITY_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/installing_security_text.png
RECOVERY_ERASING_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/erasing_text.png
RECOVERY_ERROR_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/error_text.png
RECOVERY_NO_COMMAND_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/no_command_text.png

RECOVERY_CANCEL_WIPE_DATA_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/cancel_wipe_data_text.png
RECOVERY_FACTORY_DATA_RESET_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/factory_data_reset_text.png
RECOVERY_TRY_AGAIN_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/try_again_text.png
RECOVERY_WIPE_DATA_CONFIRMATION_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/wipe_data_confirmation_text.png
RECOVERY_WIPE_DATA_MENU_HEADER_TEXT_FILE := $(dir $(RECOVERY_INSTALLING_TEXT_FILE))/wipe_data_menu_header_text.png

generated_recovery_text_files := \
  $(RECOVERY_INSTALLING_TEXT_FILE) \
  $(RECOVERY_INSTALLING_SECURITY_TEXT_FILE) \
  $(RECOVERY_ERASING_TEXT_FILE) \
  $(RECOVERY_ERROR_TEXT_FILE) \
  $(RECOVERY_NO_COMMAND_TEXT_FILE) \
  $(RECOVERY_CANCEL_WIPE_DATA_TEXT_FILE) \
  $(RECOVERY_FACTORY_DATA_RESET_TEXT_FILE) \
  $(RECOVERY_TRY_AGAIN_TEXT_FILE) \
  $(RECOVERY_WIPE_DATA_CONFIRMATION_TEXT_FILE) \
  $(RECOVERY_WIPE_DATA_MENU_HEADER_TEXT_FILE)

resource_dir := bootable/recovery/tools/recovery_l10n/res/
resource_dir_deps := $(sort $(shell find $(resource_dir) -name *.xml -not -name .*))
image_generator_jar := $(HOST_OUT_JAVA_LIBRARIES)/RecoveryImageGenerator.jar
zopflipng := $(HOST_OUT_EXECUTABLES)/zopflipng
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_SOURCE_FONTS := $(recovery_noto-fonts_dep) $(recovery_roboto-fonts_dep)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_RECOVERY_FONT_FILES_DIR := $(call intermediates-dir-for,ETC,recovery_font_files)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_RESOURCE_DIR := $(resource_dir)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_IMAGE_GENERATOR_JAR := $(image_generator_jar)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_ZOPFLIPNG := $(zopflipng)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_RECOVERY_IMAGE_WIDTH := $(recovery_image_width)
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_RECOVERY_BACKGROUND_TEXT_LIST := \
  recovery_installing \
  recovery_installing_security \
  recovery_erasing \
  recovery_error \
  recovery_no_command
$(RECOVERY_INSTALLING_TEXT_FILE): PRIVATE_RECOVERY_WIPE_DATA_TEXT_LIST := \
  recovery_cancel_wipe_data \
  recovery_factory_data_reset \
  recovery_try_again \
  recovery_wipe_data_menu_header \
  recovery_wipe_data_confirmation
$(RECOVERY_INSTALLING_TEXT_FILE): .KATI_IMPLICIT_OUTPUTS := $(filter-out $(RECOVERY_INSTALLING_TEXT_FILE),$(generated_recovery_text_files))
$(RECOVERY_INSTALLING_TEXT_FILE): $(image_generator_jar) $(resource_dir_deps) $(recovery_noto-fonts_dep) $(recovery_roboto-fonts_dep) $(zopflipng)
	# Prepares the font directory.
	@rm -rf $(PRIVATE_RECOVERY_FONT_FILES_DIR)
	@mkdir -p $(PRIVATE_RECOVERY_FONT_FILES_DIR)
	$(foreach filename,$(PRIVATE_SOURCE_FONTS), cp $(filename) $(PRIVATE_RECOVERY_FONT_FILES_DIR) &&) true
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	$(foreach text_name,$(PRIVATE_RECOVERY_BACKGROUND_TEXT_LIST) $(PRIVATE_RECOVERY_WIPE_DATA_TEXT_LIST), \
	  $(eval output_file := $(dir $@)/$(patsubst recovery_%,%_text.png,$(text_name))) \
	  $(eval center_alignment := $(if $(filter $(text_name),$(PRIVATE_RECOVERY_BACKGROUND_TEXT_LIST)), --center_alignment)) \
	  java -jar $(PRIVATE_IMAGE_GENERATOR_JAR) \
	    --image_width $(PRIVATE_RECOVERY_IMAGE_WIDTH) \
	    --text_name $(text_name) \
	    --font_dir $(PRIVATE_RECOVERY_FONT_FILES_DIR) \
	    --resource_dir $(PRIVATE_RESOURCE_DIR) \
	    --output_file $(output_file) $(center_alignment) && \
	  $(PRIVATE_ZOPFLIPNG) -y --iterations=1 --filters=0 $(output_file) $(output_file) > /dev/null &&) true
else
RECOVERY_INSTALLING_TEXT_FILE :=
RECOVERY_INSTALLING_SECURITY_TEXT_FILE :=
RECOVERY_ERASING_TEXT_FILE :=
RECOVERY_ERROR_TEXT_FILE :=
RECOVERY_NO_COMMAND_TEXT_FILE :=
RECOVERY_CANCEL_WIPE_DATA_TEXT_FILE :=
RECOVERY_FACTORY_DATA_RESET_TEXT_FILE :=
RECOVERY_TRY_AGAIN_TEXT_FILE :=
RECOVERY_WIPE_DATA_CONFIRMATION_TEXT_FILE :=
RECOVERY_WIPE_DATA_MENU_HEADER_TEXT_FILE :=
endif # TARGET_RECOVERY_UI_SCREEN_WIDTH

ifndef TARGET_PRIVATE_RES_DIRS
TARGET_PRIVATE_RES_DIRS := $(wildcard $(TARGET_DEVICE_DIR)/recovery/res)
endif
recovery_resource_deps := $(shell find $(recovery_resources_common) \
  $(TARGET_PRIVATE_RES_DIRS) -type f)
recovery_resource_deps += $(generated_recovery_text_files)


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
#   c) We mount the system image as / and therefore do not have a ramdisk in boot.img
#      (BOARD_BUILD_SYSTEM_ROOT_IMAGE = true).
#   d) We include the recovery DTBO image within recovery - not needing the resource file as we
#      do bsdiff because boot and recovery will contain different number of entries
#      (BOARD_INCLUDE_RECOVERY_DTBO = true).
#   e) We include the recovery ACPIO image within recovery - not needing the resource file as we
#      do bsdiff because boot and recovery will contain different number of entries
#      (BOARD_INCLUDE_RECOVERY_ACPIO = true).
#   f) We build a single image that contains vendor_boot and recovery both - no recovery image to
#      install
#      (BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT = true).

ifeq (,$(filter true, $(BOARD_USES_FULL_RECOVERY_IMAGE) $(BOARD_USES_RECOVERY_AS_BOOT) \
  $(BOARD_BUILD_SYSTEM_ROOT_IMAGE) $(BOARD_INCLUDE_RECOVERY_DTBO) $(BOARD_INCLUDE_RECOVERY_ACPIO) \
  $(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)))
# Named '.dat' so we don't attempt to use imgdiff for patching it.
RECOVERY_RESOURCE_ZIP := $(TARGET_OUT_VENDOR)/etc/recovery-resource.dat
ALL_DEFAULT_INSTALLED_MODULES += $(RECOVERY_RESOURCE_ZIP)
else
RECOVERY_RESOURCE_ZIP :=
endif

INSTALLED_RECOVERY_BUILD_PROP_TARGET := $(TARGET_RECOVERY_ROOT_OUT)/prop.default

$(INSTALLED_RECOVERY_BUILD_PROP_TARGET): PRIVATE_RECOVERY_UI_PROPERTIES := \
    TARGET_RECOVERY_UI_ANIMATION_FPS:animation_fps \
    TARGET_RECOVERY_UI_MARGIN_HEIGHT:margin_height \
    TARGET_RECOVERY_UI_MARGIN_WIDTH:margin_width \
    TARGET_RECOVERY_UI_MENU_UNUSABLE_ROWS:menu_unusable_rows \
    TARGET_RECOVERY_UI_PROGRESS_BAR_BASELINE:progress_bar_baseline \
    TARGET_RECOVERY_UI_TOUCH_LOW_THRESHOLD:touch_low_threshold \
    TARGET_RECOVERY_UI_TOUCH_HIGH_THRESHOLD:touch_high_threshold \
    TARGET_RECOVERY_UI_VR_STEREO_OFFSET:vr_stereo_offset

# Parses the given list of build variables and writes their values as build properties if defined.
# For example, if a target defines `TARGET_RECOVERY_UI_MARGIN_HEIGHT := 100`,
# `ro.recovery.ui.margin_height=100` will be appended to the given output file.
# $(1): Map from the build variable names to property names
# $(2): Output file
define append-recovery-ui-properties
echo "#" >> $(2)
echo "# RECOVERY UI BUILD PROPERTIES" >> $(2)
echo "#" >> $(2)
$(foreach prop,$(1), \
    $(eval _varname := $(call word-colon,1,$(prop))) \
    $(eval _propname := $(call word-colon,2,$(prop))) \
    $(eval _value := $($(_varname))) \
    $(if $(_value), \
        echo ro.recovery.ui.$(_propname)=$(_value) >> $(2) &&)) true
endef

$(INSTALLED_RECOVERY_BUILD_PROP_TARGET): \
	    $(INSTALLED_BUILD_PROP_TARGET) \
	    $(INSTALLED_VENDOR_BUILD_PROP_TARGET) \
	    $(INSTALLED_ODM_BUILD_PROP_TARGET) \
	    $(INSTALLED_PRODUCT_BUILD_PROP_TARGET) \
	    $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET)
	@echo "Target recovery buildinfo: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) cat $(INSTALLED_BUILD_PROP_TARGET) >> $@
	$(hide) cat $(INSTALLED_VENDOR_BUILD_PROP_TARGET) >> $@
	$(hide) cat $(INSTALLED_ODM_BUILD_PROP_TARGET) >> $@
	$(hide) cat $(INSTALLED_PRODUCT_BUILD_PROP_TARGET) >> $@
	$(hide) cat $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET) >> $@
	$(call append-recovery-ui-properties,$(PRIVATE_RECOVERY_UI_PROPERTIES),$@)

# Only install boot/etc/build.prop to recovery image on recovery_as_boot.
# On device with dedicated recovery partition, the file should come from the boot
# ramdisk.
ifeq (true,$(BOARD_USES_RECOVERY_AS_BOOT))
INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET := $(TARGET_RECOVERY_ROOT_OUT)/$(RAMDISK_BUILD_PROP_REL_PATH)
$(INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET): $(INSTALLED_RAMDISK_BUILD_PROP_TARGET)
	$(copy-file-to-target)
endif

ifeq (truetrue,$(strip $(BUILDING_VENDOR_BOOT_IMAGE))$(strip $(AB_OTA_UPDATER)))
  INTERNAL_RECOVERYIMAGE_ARGS := --ramdisk $(recovery_ramdisk)

ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
ifdef GENERIC_KERNEL_CMDLINE
  INTERNAL_RECOVERYIMAGE_ARGS += --cmdline "$(GENERIC_KERNEL_CMDLINE)"
endif # GENERIC_KERNEL_CMDLINE != ""
endif # BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE != true

else # not (BUILDING_VENDOR_BOOT_IMAGE and AB_OTA_UPDATER)
  INTERNAL_RECOVERYIMAGE_ARGS := \
      $(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
      --ramdisk $(recovery_ramdisk)
# Assumes this has already been stripped
ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
ifdef INTERNAL_KERNEL_CMDLINE
  INTERNAL_RECOVERYIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif # INTERNAL_KERNEL_CMDLINE != ""
endif # BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE != true
ifdef BOARD_KERNEL_BASE
  INTERNAL_RECOVERYIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_RECOVERYIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
ifdef BOARD_PREBUILT_RECOVERY_DTBOIMAGE
  INTERNAL_RECOVERYIMAGE_ARGS += --recovery_dtbo $(BOARD_PREBUILT_RECOVERY_DTBOIMAGE)
else
  INTERNAL_RECOVERYIMAGE_ARGS += --recovery_dtbo $(BOARD_PREBUILT_DTBOIMAGE)
endif
endif # BOARD_INCLUDE_RECOVERY_DTBO
ifdef BOARD_INCLUDE_RECOVERY_ACPIO
  INTERNAL_RECOVERYIMAGE_ARGS += --recovery_acpio $(BOARD_RECOVERY_ACPIO)
endif
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  INTERNAL_RECOVERYIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
endif
endif # INSTALLED_VENDOR_BOOTIMAGE_TARGET not defined
ifndef BOARD_RECOVERY_MKBOOTIMG_ARGS
  BOARD_RECOVERY_MKBOOTIMG_ARGS := $(BOARD_MKBOOTIMG_ARGS)
endif

$(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP): $(MKBOOTFS) $(COMPRESSION_COMMAND_DEPS) \
	    $(INTERNAL_ROOT_FILES) \
	    $(INSTALLED_RAMDISK_TARGET) \
	    $(INTERNAL_RECOVERYIMAGE_FILES) \
	    $(recovery_sepolicy) \
	    $(INSTALLED_2NDBOOTLOADER_TARGET) \
	    $(INSTALLED_RECOVERY_BUILD_PROP_TARGET) \
	    $(INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET) \
	    $(recovery_resource_deps) \
	    $(recovery_fstab)
	# Making recovery image
	mkdir -p $(TARGET_RECOVERY_OUT)
	mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/sdcard $(TARGET_RECOVERY_ROOT_OUT)/tmp
	# Copying baseline ramdisk...
	# Use rsync because "cp -Rf" fails to overwrite broken symlinks on Mac.
	rsync -a --exclude=sdcard $(IGNORE_RECOVERY_SEPOLICY) $(IGNORE_CACHE_LINK) $(TARGET_ROOT_OUT) $(TARGET_RECOVERY_OUT)
	# Modifying ramdisk contents...
	$(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)),, \
	  ln -sf /system/bin/init $(TARGET_RECOVERY_ROOT_OUT)/init)
	# Removes $(TARGET_RECOVERY_ROOT_OUT)/init*.rc EXCEPT init.recovery*.rc.
	find $(TARGET_RECOVERY_ROOT_OUT) -maxdepth 1 -name 'init*.rc' -type f -not -name "init.recovery.*.rc" | xargs rm -f
	cp $(TARGET_ROOT_OUT)/init.recovery.*.rc $(TARGET_RECOVERY_ROOT_OUT)/ 2> /dev/null || true # Ignore error when the src file doesn't exist.
	mkdir -p $(TARGET_RECOVERY_ROOT_OUT)/res
	rm -rf $(TARGET_RECOVERY_ROOT_OUT)/res/*
	cp -rf $(recovery_resources_common)/* $(TARGET_RECOVERY_ROOT_OUT)/res
	$(foreach recovery_text_file,$(generated_recovery_text_files), \
	  cp -rf $(recovery_text_file) $(TARGET_RECOVERY_ROOT_OUT)/res/images/ &&) true
	cp -f $(recovery_font) $(TARGET_RECOVERY_ROOT_OUT)/res/images/font.png
	$(foreach item,$(TARGET_PRIVATE_RES_DIRS), \
	  cp -rf $(item) $(TARGET_RECOVERY_ROOT_OUT)/$(newline))
	$(foreach item,$(recovery_fstab), \
	  cp -f $(item) $(TARGET_RECOVERY_ROOT_OUT)/system/etc/recovery.fstab)
	$(if $(strip $(recovery_wipe)), \
	  cp -f $(recovery_wipe) $(TARGET_RECOVERY_ROOT_OUT)/system/etc/recovery.wipe)
	ln -sf prop.default $(TARGET_RECOVERY_ROOT_OUT)/default.prop
	$(BOARD_RECOVERY_IMAGE_PREPARE)
	$(hide) touch $@

$(recovery_ramdisk): $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
	$(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_RECOVERY_ROOT_OUT) | $(COMPRESSION_COMMAND) > $(recovery_ramdisk)

# $(1): output file
# $(2): optional kernel file
define build-recoveryimage-target
  $(if $(filter true,$(PRODUCT_SUPPORTS_VBOOT)), \
    $(MKBOOTIMG) $(if $(strip $(2)),--kernel $(strip $(2))) $(INTERNAL_RECOVERYIMAGE_ARGS) \
                 $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_RECOVERY_MKBOOTIMG_ARGS) \
                 --output $(1).unsigned, \
    $(MKBOOTIMG) $(if $(strip $(2)),--kernel $(strip $(2))) $(INTERNAL_RECOVERYIMAGE_ARGS) \
                 $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_RECOVERY_MKBOOTIMG_ARGS) \
                 --output $(1))
  $(if $(filter true,$(PRODUCT_SUPPORTS_BOOT_SIGNER)),\
    $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
      $(BOOT_SIGNER) /boot $(1) $(PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCT_VERITY_SIGNING_KEY).x509.pem $(1),\
      $(BOOT_SIGNER) /recovery $(1) $(PRODUCT_VERITY_SIGNING_KEY).pk8 $(PRODUCT_VERITY_SIGNING_KEY).x509.pem $(1)\
    )\
  )
  $(if $(filter true,$(PRODUCT_SUPPORTS_VBOOT)), \
    $(VBOOT_SIGNER) $(FUTILITY) $(1).unsigned $(PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(1).keyblock $(1))
  $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
    $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$(1),boot))), \
    $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE))))
  $(if $(filter true,$(BOARD_AVB_ENABLE)), \
    $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
      $(AVBTOOL) add_hash_footer --image $(1) --partition_size $(call get-bootimage-partition-size,$(1),boot) --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS),\
      $(AVBTOOL) add_hash_footer --image $(1) --partition_size $(BOARD_RECOVERYIMAGE_PARTITION_SIZE) --partition_name recovery $(INTERNAL_AVB_RECOVERY_SIGNING_ARGS) $(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)))
endef

recoveryimage-deps := $(MKBOOTIMG) $(recovery_ramdisk) $(recovery_kernel)
ifeq (true,$(PRODUCT_SUPPORTS_BOOT_SIGNER))
  recoveryimage-deps += $(BOOT_SIGNER)
endif
ifeq (true,$(PRODUCT_SUPPORTS_VBOOT))
  recoveryimage-deps += $(VBOOT_SIGNER)
endif
ifeq (true,$(BOARD_AVB_ENABLE))
  recoveryimage-deps += $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH)
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
  ifdef BOARD_PREBUILT_RECOVERY_DTBOIMAGE
    recoveryimage-deps += $(BOARD_PREBUILT_RECOVERY_DTBOIMAGE)
  else
    recoveryimage-deps += $(BOARD_PREBUILT_DTBOIMAGE)
  endif
endif
ifdef BOARD_INCLUDE_RECOVERY_ACPIO
  recoveryimage-deps += $(BOARD_RECOVERY_ACPIO)
endif
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  recoveryimage-deps += $(INSTALLED_DTBIMAGE_TARGET)
endif

ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET), $(eval $(call add-dependency,$(b),$(call bootimage-to-kernel,$(b)))))
$(INSTALLED_BOOTIMAGE_TARGET): $(recoveryimage-deps)
	$(call pretty,"Target boot image from recovery: $@")
	$(call build-recoveryimage-target, $@, $(PRODUCT_OUT)/$(subst .img,,$(subst boot,kernel,$(notdir $@))))
endif # BOARD_USES_RECOVERY_AS_BOOT

$(INSTALLED_RECOVERYIMAGE_TARGET): $(recoveryimage-deps)
	$(call build-recoveryimage-target, $@, \
	  $(if $(filter true, $(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE)),, $(recovery_kernel)))

ifdef RECOVERY_RESOURCE_ZIP
$(RECOVERY_RESOURCE_ZIP): $(INSTALLED_RECOVERYIMAGE_TARGET) | $(ZIPTIME)
	$(hide) mkdir -p $(dir $@)
	$(hide) find $(TARGET_RECOVERY_ROOT_OUT)/res -type f | sort | zip -0qrjX $@ -@
	$(remove-timestamps-from-package)
endif

.PHONY: recoveryimage-nodeps
recoveryimage-nodeps:
	@echo "make $@: ignoring dependencies"
	$(call build-recoveryimage-target, $(INSTALLED_RECOVERYIMAGE_TARGET), \
	  $(if $(filter true, $(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE)),, $(recovery_kernel)))

else # BUILDING_RECOVERY_IMAGE
RECOVERY_RESOURCE_ZIP :=
endif # BUILDING_RECOVERY_IMAGE

.PHONY: recoveryimage
recoveryimage: $(INSTALLED_RECOVERYIMAGE_TARGET) $(RECOVERY_RESOURCE_ZIP)

ifneq ($(BOARD_NAND_PAGE_SIZE),)
$(error MTD device is no longer supported and thus BOARD_NAND_PAGE_SIZE is deprecated.)
endif

ifneq ($(BOARD_NAND_SPARE_SIZE),)
$(error MTD device is no longer supported and thus BOARD_NAND_SPARE_SIZE is deprecated.)
endif

ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
# -----------------------------------------------------------------
# the debug ramdisk, which is the original ramdisk plus additional
# files: force_debuggable, adb_debug.prop and userdebug sepolicy.
# When /force_debuggable is present, /init will load userdebug sepolicy
# and property files to allow adb root, if the device is unlocked.

ifdef BUILDING_RAMDISK_IMAGE
BUILT_DEBUG_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk-debug.img
INSTALLED_DEBUG_RAMDISK_TARGET := $(BUILT_DEBUG_RAMDISK_TARGET)

INTERNAL_DEBUG_RAMDISK_FILES := $(filter $(TARGET_DEBUG_RAMDISK_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# Note: TARGET_DEBUG_RAMDISK_OUT will be $(PRODUCT_OUT)/debug_ramdisk/first_stage_ramdisk,
# if BOARD_USES_RECOVERY_AS_BOOT is true. Otherwise, it will be $(PRODUCT_OUT)/debug_ramdisk.
# But the root dir of the ramdisk to build is always $(PRODUCT_OUT)/debug_ramdisk.
my_debug_ramdisk_root_dir := $(PRODUCT_OUT)/debug_ramdisk

INSTALLED_FILES_FILE_DEBUG_RAMDISK := $(PRODUCT_OUT)/installed-files-ramdisk-debug.txt
INSTALLED_FILES_JSON_DEBUG_RAMDISK := $(INSTALLED_FILES_FILE_DEBUG_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_DEBUG_RAMDISK)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK): DEBUG_RAMDISK_ROOT_DIR := $(my_debug_ramdisk_root_dir)

# Cannot just depend on INTERNAL_DEBUG_RAMDISK_FILES like other INSTALLED_FILES_FILE_* rules.
# Because ramdisk-debug.img will rsync from either ramdisk.img or ramdisk-recovery.img.
# Need to depend on the built ramdisk-debug.img, to get a complete list of the installed files.
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK) : $(INSTALLED_DEBUG_RAMDISK_TARGET)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK) : $(INTERNAL_DEBUG_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(DEBUG_RAMDISK_ROOT_DIR) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

# ramdisk-debug.img will rsync the content from either ramdisk.img or ramdisk-recovery.img,
# depending on whether BOARD_USES_RECOVERY_AS_BOOT is set or not.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
my_debug_ramdisk_sync_dir := $(TARGET_RECOVERY_ROOT_OUT)
else
my_debug_ramdisk_sync_dir := $(TARGET_RAMDISK_OUT)
endif # BOARD_USES_RECOVERY_AS_BOOT

$(INSTALLED_DEBUG_RAMDISK_TARGET): DEBUG_RAMDISK_SYNC_DIR := $(my_debug_ramdisk_sync_dir)
$(INSTALLED_DEBUG_RAMDISK_TARGET): DEBUG_RAMDISK_ROOT_DIR := $(my_debug_ramdisk_root_dir)

ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
# ramdisk-recovery.img isn't a make target, need to depend on boot.img if it's for recovery.
$(INSTALLED_DEBUG_RAMDISK_TARGET): $(INSTALLED_BOOTIMAGE_TARGET)
else
# Depends on ramdisk.img, note that some target has ramdisk.img but no boot.img, e.g., emulator.
$(INSTALLED_DEBUG_RAMDISK_TARGET): $(INSTALLED_RAMDISK_TARGET)
endif # BOARD_USES_RECOVERY_AS_BOOT
$(INSTALLED_DEBUG_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_DEBUG_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(call pretty,"Target debug ram disk: $@")
	mkdir -p $(TARGET_DEBUG_RAMDISK_OUT)
	touch $(TARGET_DEBUG_RAMDISK_OUT)/force_debuggable
	rsync -a $(DEBUG_RAMDISK_SYNC_DIR)/ $(DEBUG_RAMDISK_ROOT_DIR)
	$(MKBOOTFS) -d $(TARGET_OUT) $(DEBUG_RAMDISK_ROOT_DIR) | $(COMPRESSION_COMMAND) > $@

.PHONY: ramdisk_debug-nodeps
ramdisk_debug-nodeps: DEBUG_RAMDISK_SYNC_DIR := $(my_debug_ramdisk_sync_dir)
ramdisk_debug-nodeps: DEBUG_RAMDISK_ROOT_DIR := $(my_debug_ramdisk_root_dir)
ramdisk_debug-nodeps: $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	echo "make $@: ignoring dependencies"
	mkdir -p $(TARGET_DEBUG_RAMDISK_OUT)
	touch $(TARGET_DEBUG_RAMDISK_OUT)/force_debuggable
	rsync -a $(DEBUG_RAMDISK_SYNC_DIR)/ $(DEBUG_RAMDISK_ROOT_DIR)
	$(MKBOOTFS) -d $(TARGET_OUT) $(DEBUG_RAMDISK_ROOT_DIR) | $(COMPRESSION_COMMAND) > $(INSTALLED_DEBUG_RAMDISK_TARGET)

my_debug_ramdisk_sync_dir :=
my_debug_ramdisk_root_dir :=

endif # BUILDING_RAMDISK_IMAGE

# -----------------------------------------------------------------
# the boot-debug.img, which is the kernel plus ramdisk-debug.img
#
# Note: it's intentional to skip signing for boot-debug.img, because it
# can only be used if the device is unlocked with verification error.
ifneq ($(INSTALLED_BOOTIMAGE_TARGET),)
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
  INSTALLED_DEBUG_BOOTIMAGE_TARGET := $(foreach k,$(subst kernel,boot-debug,$(BOARD_KERNEL_BINARIES)), \
         $(PRODUCT_OUT)/$(k).img)
else
  INSTALLED_DEBUG_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot-debug.img
endif

# Replace ramdisk.img in $(MKBOOTIMG) ARGS with ramdisk-debug.img to build boot-debug.img
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
INTERNAL_DEBUG_BOOTIMAGE_ARGS := $(subst $(recovery_ramdisk),$(INSTALLED_DEBUG_RAMDISK_TARGET), $(INTERNAL_RECOVERYIMAGE_ARGS))
else
INTERNAL_DEBUG_BOOTIMAGE_ARGS := $(subst $(INSTALLED_RAMDISK_TARGET),$(INSTALLED_DEBUG_RAMDISK_TARGET), $(INTERNAL_BOOTIMAGE_ARGS))
endif

# If boot.img is chained but boot-debug.img is not signed, libavb in bootloader
# will fail to find valid AVB metadata from the end of /boot, thus stop booting.
# Using a test key to sign boot-debug.img to continue booting with the mismatched
# public key, if the device is unlocked.
ifneq ($(BOARD_AVB_BOOT_KEY_PATH),)
$(INSTALLED_DEBUG_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_BOOT_TEST_KEY_PATH)
endif

BOARD_AVB_BOOT_TEST_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
INTERNAL_AVB_BOOT_TEST_SIGNING_ARGS := --algorithm SHA256_RSA2048 --key $(BOARD_AVB_BOOT_TEST_KEY_PATH)
# $(1): the bootimage to sign
define test-key-sign-bootimage
$(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$(1),boot-debug)))
$(AVBTOOL) add_hash_footer \
  --image $(1) \
  --partition_size $(call get-bootimage-partition-size,$(1),boot-debug)\
  --partition_name boot $(INTERNAL_AVB_BOOT_TEST_SIGNING_ARGS) \
  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
$(call assert-max-image-size,$(1),$(call get-bootimage-partition-size,$(1),boot-debug))
endef

# $(1): output file
define build-debug-bootimage-target
  $(MKBOOTIMG) --kernel $(PRODUCT_OUT)/$(subst .img,,$(subst boot-debug,kernel,$(notdir $(1)))) \
    $(INTERNAL_DEBUG_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $1
  $(if $(BOARD_AVB_BOOT_KEY_PATH),$(call test-key-sign-bootimage,$1))
endef

# Depends on original boot.img and ramdisk-debug.img, to build the new boot-debug.img
$(INSTALLED_DEBUG_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_BOOTIMAGE_TARGET) $(INSTALLED_DEBUG_RAMDISK_TARGET)
	$(call pretty,"Target boot debug image: $@")
	$(call build-debug-bootimage-target, $@)

.PHONY: bootimage_debug-nodeps
bootimage_debug-nodeps: $(MKBOOTIMG)
	echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_DEBUG_BOOTIMAGE_TARGET),$(call build-debug-bootimage-target,$b))

endif # TARGET_NO_KERNEL
endif # INSTALLED_BOOTIMAGE_TARGET

ifeq ($(BUILDING_VENDOR_BOOT_IMAGE),true)
ifeq ($(BUILDING_RAMDISK_IMAGE),true)
# -----------------------------------------------------------------
# vendor debug ramdisk
# Combines vendor ramdisk files and debug ramdisk files to build the vendor debug ramdisk.
INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET := $(PRODUCT_OUT)/vendor-ramdisk-debug.cpio$(RAMDISK_EXT)
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): DEBUG_RAMDISK_FILES := $(INTERNAL_DEBUG_RAMDISK_FILES)
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): VENDOR_RAMDISK_DIR := $(TARGET_VENDOR_RAMDISK_OUT)

INTERNAL_VENDOR_DEBUG_RAMDISK_FILES := $(filter $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# Note: TARGET_VENDOR_DEBUG_RAMDISK_OUT will be $(PRODUCT_OUT)/vendor_debug_ramdisk/first_stage_ramdisk,
# if BOARD_USES_RECOVERY_AS_BOOT is true. Otherwise, it will be $(PRODUCT_OUT)/vendor_debug_ramdisk.
# But the path of $(VENDOR_DEBUG_RAMDISK_DIR) to build the vendor debug ramdisk, is always
# $(PRODUCT_OUT)/vendor_debug_ramdisk.
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): VENDOR_DEBUG_RAMDISK_DIR := $(PRODUCT_OUT)/vendor_debug_ramdisk
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_DEBUG_RAMDISK_TARGET)
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_VENDOR_DEBUG_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(call pretty,"Target vendor debug ram disk: $@")
	mkdir -p $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)
	touch $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)/force_debuggable
	$(foreach debug_file,$(DEBUG_RAMDISK_FILES), \
	  cp -f $(debug_file) $(subst $(PRODUCT_OUT)/debug_ramdisk,$(PRODUCT_OUT)/vendor_debug_ramdisk,$(debug_file)) &&) true
	rsync -a $(VENDOR_RAMDISK_DIR)/ $(VENDOR_DEBUG_RAMDISK_DIR)
	$(MKBOOTFS) -d $(TARGET_OUT) $(VENDOR_DEBUG_RAMDISK_DIR) | $(COMPRESSION_COMMAND) > $@

INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK := $(PRODUCT_OUT)/installed-files-vendor-ramdisk-debug.txt
INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK := $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): VENDOR_DEBUG_RAMDISK_DIR := $(PRODUCT_OUT)/vendor_debug_ramdisk

# The vendor debug ramdisk will rsync from $(TARGET_VENDOR_RAMDISK_OUT) and $(INTERNAL_DEBUG_RAMDISK_FILES),
# so we have to wait for the vendor debug ramdisk to be built before generating the installed file list.
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): $(INTERNAL_VENDOR_DEBUG_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(VENDOR_DEBUG_RAMDISK_DIR) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

# -----------------------------------------------------------------
# vendor_boot-debug.img.
INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/vendor_boot-debug.img

# The util to sign vendor_boot-debug.img with a test key.
BOARD_AVB_VENDOR_BOOT_TEST_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
INTERNAL_AVB_VENDOR_BOOT_TEST_SIGNING_ARGS := --algorithm SHA256_RSA2048 --key $(BOARD_AVB_VENDOR_BOOT_TEST_KEY_PATH)
# $(1): the vendor bootimage to sign
define test-key-sign-vendor-bootimage
$(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE)))
$(AVBTOOL) add_hash_footer \
  --image $(1) \
  --partition_size $(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE) \
  --partition_name vendor_boot $(INTERNAL_AVB_VENDOR_BOOT_TEST_SIGNING_ARGS) \
  $(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)
$(call assert-max-image-size,$(1),$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
endef

ifneq ($(BOARD_AVB_VENDOR_BOOT_KEY_PATH),)
$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_BOOT_TEST_KEY_PATH)
endif

# Depends on vendor_boot.img and vendor-ramdisk-debug.cpio.gz to build the new vendor_boot-debug.img
$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_VENDOR_BOOTIMAGE_TARGET) $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET)
	$(call pretty,"Target vendor_boot debug image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
	$(if $(BOARD_AVB_VENDOR_BOOT_KEY_PATH),$(call test-key-sign-vendor-bootimage,$@))

endif # BUILDING_RAMDISK_IMAGE
endif # BUILDING_VENDOR_BOOT_IMAGE

# -----------------------------------------------------------------
# The test harness ramdisk, which is based off debug_ramdisk, plus a
# few additional test-harness-specific properties in adb_debug.prop.

ifdef BUILDING_RAMDISK_IMAGE
BUILT_TEST_HARNESS_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk-test-harness.img
INSTALLED_TEST_HARNESS_RAMDISK_TARGET := $(BUILT_TEST_HARNESS_RAMDISK_TARGET)

# rsync the content from ramdisk-debug.img to ramdisk-test-harness.img, then
# appends a few test harness specific properties into the adb_debug.prop.
TEST_HARNESS_RAMDISK_SYNC_DIR := $(PRODUCT_OUT)/debug_ramdisk
TEST_HARNESS_RAMDISK_ROOT_DIR := $(PRODUCT_OUT)/test_harness_ramdisk

# The following TARGET_TEST_HARNESS_RAMDISK_OUT will be $(PRODUCT_OUT)/test_harness_ramdisk/first_stage_ramdisk,
# if BOARD_USES_RECOVERY_AS_BOOT is true. Otherwise, it will be $(PRODUCT_OUT)/test_harness_ramdisk.
TEST_HARNESS_PROP_TARGET := $(TARGET_TEST_HARNESS_RAMDISK_OUT)/adb_debug.prop
ADDITIONAL_TEST_HARNESS_PROPERTIES := ro.audio.silent=1
ADDITIONAL_TEST_HARNESS_PROPERTIES += ro.test_harness=1

# $(1): a list of key=value pairs for additional property assignments
# $(2): the target .prop file to append the properties from $(1)
define append-test-harness-props
  echo "#" >> $(2); \
  echo "# ADDITIONAL TEST HARNESS_PROPERTIES" >> $(2); \
  echo "#" >> $(2);
  $(foreach line,$(1), echo "$(line)" >> $(2);)
endef

$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET): $(INSTALLED_DEBUG_RAMDISK_TARGET)
$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_TEST_HARNESS_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(call pretty,"Target test harness ram disk: $@")
	rsync -a $(TEST_HARNESS_RAMDISK_SYNC_DIR)/ $(TEST_HARNESS_RAMDISK_ROOT_DIR)
	$(call append-test-harness-props,$(ADDITIONAL_TEST_HARNESS_PROPERTIES),$(TEST_HARNESS_PROP_TARGET))
	$(MKBOOTFS) -d $(TARGET_OUT) $(TEST_HARNESS_RAMDISK_ROOT_DIR) | $(COMPRESSION_COMMAND) > $@

.PHONY: ramdisk_test_harness-nodeps
ramdisk_test_harness-nodeps: $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	echo "make $@: ignoring dependencies"
	rsync -a $(TEST_HARNESS_RAMDISK_SYNC_DIR)/ $(TEST_HARNESS_RAMDISK_ROOT_DIR)
	$(call append-test-harness-props,$(ADDITIONAL_TEST_HARNESS_PROPERTIES),$(TEST_HARNESS_PROP_TARGET))
	$(MKBOOTFS) -d $(TARGET_OUT) $(TEST_HARNESS_RAMDISK_ROOT_DIR) | $(COMPRESSION_COMMAND) > $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)

endif # BUILDING_RAMDISK_IMAGE

# -----------------------------------------------------------------
# the boot-test-harness.img, which is the kernel plus ramdisk-test-harness.img
#
# Note: it's intentional to skip signing for boot-test-harness.img, because it
# can only be used if the device is unlocked with verification error.
ifneq ($(strip $(TARGET_NO_KERNEL)),true)

ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
  INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET := $(foreach k,$(subst kernel,boot-test-harness,$(BOARD_KERNEL_BINARIES)), \
    $(PRODUCT_OUT)/$(k).img)
else
  INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot-test-harness.img
endif

# Replace ramdisk-debug.img in $(MKBOOTIMG) ARGS with ramdisk-test-harness.img to build boot-test-harness.img
INTERNAL_TEST_HARNESS_BOOTIMAGE_ARGS := $(subst $(INSTALLED_DEBUG_RAMDISK_TARGET),$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET),$(INTERNAL_DEBUG_BOOTIMAGE_ARGS))

# If boot.img is chained but boot-test-harness.img is not signed, libavb in bootloader
# will fail to find valid AVB metadata from the end of /boot, thus stop booting.
# Using a test key to sign boot-test-harness.img to continue booting with the mismatched
# public key, if the device is unlocked.
ifneq ($(BOARD_AVB_BOOT_KEY_PATH),)
$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_BOOT_TEST_KEY_PATH)
endif

# $(1): output file
define build-boot-test-harness-target
  $(MKBOOTIMG) --kernel $(PRODUCT_OUT)/$(subst .img,,$(subst boot-test-harness,kernel,$(notdir $(1)))) \
    $(INTERNAL_TEST_HARNESS_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
  $(if $(BOARD_AVB_BOOT_KEY_PATH),$(call test-key-sign-bootimage,$@))
endef

# Build the new boot-test-harness.img, based on boot-debug.img and ramdisk-test-harness.img.
$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_DEBUG_BOOTIMAGE_TARGET) $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)
	$(call pretty,"Target boot test harness image: $@")
	$(call build-boot-test-harness-target,$@)

.PHONY: bootimage_test_harness-nodeps
bootimage_test_harness-nodeps: $(MKBOOTIMG)
	echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET),$(call build-boot-test-harness-target,$b))

endif # TARGET_NO_KERNEL
endif # BOARD_BUILD_SYSTEM_ROOT_IMAGE is not true

# Creates a compatibility symlink between two partitions, e.g. /system/vendor to /vendor
# $1: from location (e.g $(TARGET_OUT)/vendor)
# $2: destination location (e.g. /vendor)
# $3: partition image name (e.g. vendor.img)
define create-partition-compat-symlink
$(eval \
$1:
	@echo Symlink $(patsubst $(PRODUCT_OUT)/%,%,$1) to $2
	mkdir -p $(dir $1)
	if [ -d $1 ] && [ ! -h $1 ]; then \
	  echo 'Non-symlink $1 detected!' 1>&2; \
	  echo 'You cannot install files to $1 while building a separate $3!' 1>&2; \
	  exit 1; \
	fi
	ln -sfn $2 $1
$1: .KATI_SYMLINK_OUTPUTS := $1
)
$1
endef


# -----------------------------------------------------------------
# system image

INTERNAL_SYSTEMIMAGE_FILES := $(sort $(filter $(TARGET_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES)))

# Create symlink /system/vendor to /vendor if necessary.
ifdef BOARD_USES_VENDORIMAGE
  INTERNAL_SYSTEMIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT)/vendor,/vendor,vendor.img)
endif

# Create symlink /system/product to /product if necessary.
ifdef BOARD_USES_PRODUCTIMAGE
  INTERNAL_SYSTEMIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT)/product,/product,product.img)
endif

# Create symlink /system/system_ext to /system_ext if necessary.
ifdef BOARD_USES_SYSTEM_EXTIMAGE
  INTERNAL_SYSTEMIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT)/system_ext,/system_ext,system_ext.img)
endif

FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)

# ASAN libraries in the system image - add dependency.
ASAN_IN_SYSTEM_INSTALLED := $(TARGET_OUT)/asan.tar.bz2
ifneq (,$(filter address, $(SANITIZE_TARGET)))
  ifeq (true,$(SANITIZE_TARGET_SYSTEM))
    FULL_SYSTEMIMAGE_DEPS += $(ASAN_IN_SYSTEM_INSTALLED)
  endif
endif

FULL_SYSTEMIMAGE_DEPS += $(INTERNAL_ROOT_FILES) $(INSTALLED_FILES_FILE_ROOT)

# -----------------------------------------------------------------
ifdef BUILDING_SYSTEM_IMAGE

# installed file list
# Depending on anything that $(BUILT_SYSTEMIMAGE) depends on.
# We put installed-files.txt ahead of image itself in the dependency graph
# so that we can get the size stat even if the build fails due to too large
# system image.
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
INSTALLED_FILES_JSON := $(INSTALLED_FILES_FILE:.txt=.json)
$(INSTALLED_FILES_FILE): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON)
$(INSTALLED_FILES_FILE): $(FULL_SYSTEMIMAGE_DEPS) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

.PHONY: installed-file-list
installed-file-list: $(INSTALLED_FILES_FILE)

$(call dist-for-goals, sdk win_sdk sdk_addon, $(INSTALLED_FILES_FILE))

systemimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE := $(systemimage_intermediates)/system.img

# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-image-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt,system, \
      skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1) $(TARGET_OUT) \
          || ( mkdir -p $${DIST_DIR}; \
               cp $(INSTALLED_FILES_FILE) $${DIST_DIR}/installed-files-rescued.txt; \
               exit 1 )
endef

ifeq ($(BOARD_AVB_ENABLE),true)
$(BUILT_SYSTEMIMAGE): $(BOARD_AVB_SYSTEM_KEY_PATH)
endif
$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE)
	$(call build-systemimage-target,$@)

INSTALLED_SYSTEMIMAGE_TARGET := $(PRODUCT_OUT)/system.img
SYSTEMIMAGE_SOURCE_DIR := $(TARGET_OUT)

# INSTALLED_SYSTEMIMAGE_TARGET used to be named INSTALLED_SYSTEMIMAGE. Create an alias for backward
# compatibility, in case device-specific Makefiles still refer to the old name.
INSTALLED_SYSTEMIMAGE := $(INSTALLED_SYSTEMIMAGE_TARGET)

# The system partition needs room for the recovery image as well.  We
# now store the recovery image as a binary patch using the boot image
# as the source (since they are very similar).  Generate the patch so
# we can see how big it's going to be, and include that in the system
# image size check calculation.
ifneq ($(INSTALLED_BOOTIMAGE_TARGET),)
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
ifneq ($(BOARD_USES_FULL_RECOVERY_IMAGE),true)
ifneq (,$(filter true, $(BOARD_BUILD_SYSTEM_ROOT_IMAGE) $(BOARD_INCLUDE_RECOVERY_DTBO) $(BOARD_INCLUDE_RECOVERY_ACPIO)))
diff_tool := $(HOST_OUT_EXECUTABLES)/bsdiff
else
diff_tool := $(HOST_OUT_EXECUTABLES)/imgdiff
endif
intermediates := $(call intermediates-dir-for,PACKAGING,recovery_patch)
RECOVERY_FROM_BOOT_PATCH := $(intermediates)/recovery_from_boot.p
$(RECOVERY_FROM_BOOT_PATCH): PRIVATE_DIFF_TOOL := $(diff_tool)
$(RECOVERY_FROM_BOOT_PATCH): \
	    $(INSTALLED_RECOVERYIMAGE_TARGET) \
	    $(firstword $(INSTALLED_BOOTIMAGE_TARGET)) \
	    $(diff_tool)
	@echo "Construct recovery from boot"
	mkdir -p $(dir $@)
	$(PRIVATE_DIFF_TOOL) $(firstword $(INSTALLED_BOOTIMAGE_TARGET)) $(INSTALLED_RECOVERYIMAGE_TARGET) $@
else # $(BOARD_USES_FULL_RECOVERY_IMAGE) == true
RECOVERY_FROM_BOOT_PATCH := $(INSTALLED_RECOVERYIMAGE_TARGET)
endif # BOARD_USES_FULL_RECOVERY_IMAGE
endif # INSTALLED_RECOVERYIMAGE_TARGET
endif # INSTALLED_BOOTIMAGE_TARGET

$(INSTALLED_SYSTEMIMAGE_TARGET): $(BUILT_SYSTEMIMAGE)
	@echo "Install system fs image: $@"
	$(copy-file-to-target)
	$(hide) $(call assert-max-image-size,$@,$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))

systemimage: $(INSTALLED_SYSTEMIMAGE_TARGET)

.PHONY: systemimage-nodeps snod
systemimage-nodeps snod: $(filter-out systemimage-nodeps snod,$(MAKECMDGOALS)) \
	            | $(INTERNAL_USERIMAGES_DEPS)
	@echo "make $@: ignoring dependencies"
	$(call build-systemimage-target,$(INSTALLED_SYSTEMIMAGE_TARGET))
	$(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
ifeq (true,$(WITH_DEXPREOPT))
	$(warning Warning: with dexpreopt enabled, you may need a full rebuild.)
endif

endif # BUILDING_SYSTEM_IMAGE

.PHONY: sync syncsys
sync syncsys: $(INTERNAL_SYSTEMIMAGE_FILES)

# -----------------------------------------------------------------
# Old PDK fusion targets
.PHONY: platform
platform:
	echo "Warning: 'platform' is obsolete"

.PHONY: platform-java
platform-java:
	echo "Warning: 'platform-java' is obsolete"

# -----------------------------------------------------------------
# data partition image
INTERNAL_USERDATAIMAGE_FILES := \
    $(filter $(TARGET_OUT_DATA)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

ifdef BUILDING_USERDATA_IMAGE
userdataimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,userdata)
BUILT_USERDATAIMAGE_TARGET := $(PRODUCT_OUT)/userdata.img

define build-userdataimage-target
  $(call pretty,"Target userdata fs image: $(INSTALLED_USERDATAIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_DATA)
  @mkdir -p $(userdataimage_intermediates) && rm -rf $(userdataimage_intermediates)/userdata_image_info.txt
  $(call generate-image-prop-dictionary, $(userdataimage_intermediates)/userdata_image_info.txt,userdata,skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_DATA) $(userdataimage_intermediates)/userdata_image_info.txt \
          $(INSTALLED_USERDATAIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
INSTALLED_USERDATAIMAGE_TARGET_DEPS := \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_USERDATAIMAGE_FILES)
$(INSTALLED_USERDATAIMAGE_TARGET): $(INSTALLED_USERDATAIMAGE_TARGET_DEPS)
	$(build-userdataimage-target)

.PHONY: userdataimage-nodeps
userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-userdataimage-target)

endif # BUILDING_USERDATA_IMAGE

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
ifdef BUILDING_CACHE_IMAGE
INTERNAL_CACHEIMAGE_FILES := \
    $(filter $(TARGET_OUT_CACHE)/%,$(ALL_DEFAULT_INSTALLED_MODULES))

cacheimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,cache)
BUILT_CACHEIMAGE_TARGET := $(PRODUCT_OUT)/cache.img

define build-cacheimage-target
  $(call pretty,"Target cache fs image: $(INSTALLED_CACHEIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_CACHE)
  @mkdir -p $(cacheimage_intermediates) && rm -rf $(cacheimage_intermediates)/cache_image_info.txt
  $(call generate-image-prop-dictionary, $(cacheimage_intermediates)/cache_image_info.txt,cache,skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_CACHE) $(cacheimage_intermediates)/cache_image_info.txt \
          $(INSTALLED_CACHEIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_CACHEIMAGE_TARGET),$(BOARD_CACHEIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_CACHEIMAGE_TARGET := $(BUILT_CACHEIMAGE_TARGET)
$(INSTALLED_CACHEIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES)
	$(build-cacheimage-target)

.PHONY: cacheimage-nodeps
cacheimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-cacheimage-target)

else # BUILDING_CACHE_IMAGE
# we need to ignore the broken cache link when doing the rsync
IGNORE_CACHE_LINK := --exclude=cache
endif # BUILDING_CACHE_IMAGE

# -----------------------------------------------------------------
# system_other partition image
ifdef BUILDING_SYSTEM_OTHER_IMAGE
ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
# Marker file to identify that odex files are installed
INSTALLED_SYSTEM_OTHER_ODEX_MARKER := $(TARGET_OUT_SYSTEM_OTHER)/system-other-odex-marker
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_SYSTEM_OTHER_ODEX_MARKER)
$(INSTALLED_SYSTEM_OTHER_ODEX_MARKER):
	$(hide) touch $@
endif

INTERNAL_SYSTEMOTHERIMAGE_FILES := \
    $(filter $(TARGET_OUT_SYSTEM_OTHER)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

# system_other dex files are installed as a side-effect of installing system image files
INTERNAL_SYSTEMOTHERIMAGE_FILES += $(INTERNAL_SYSTEMIMAGE_FILES)

INSTALLED_FILES_FILE_SYSTEMOTHER := $(PRODUCT_OUT)/installed-files-system-other.txt
INSTALLED_FILES_JSON_SYSTEMOTHER := $(INSTALLED_FILES_FILE_SYSTEMOTHER:.txt=.json)
$(INSTALLED_FILES_FILE_SYSTEMOTHER): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_SYSTEMOTHER)
$(INSTALLED_FILES_FILE_SYSTEMOTHER) : $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_SYSTEM_OTHER) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

# Determines partition size for system_other.img.
ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)
ifneq ($(filter system,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)),)
INTERNAL_SYSTEM_OTHER_PARTITION_SIZE := $(BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE)
endif
endif

ifndef INTERNAL_SYSTEM_OTHER_PARTITION_SIZE
INTERNAL_SYSTEM_OTHER_PARTITION_SIZE:= $(BOARD_SYSTEMIMAGE_PARTITION_SIZE)
endif

systemotherimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,system_other)
BUILT_SYSTEMOTHERIMAGE_TARGET := $(PRODUCT_OUT)/system_other.img

# Note that we assert the size is SYSTEMIMAGE_PARTITION_SIZE since this is the 'b' system image.
define build-systemotherimage-target
  $(call pretty,"Target system_other fs image: $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_SYSTEM_OTHER)
  @mkdir -p $(systemotherimage_intermediates) && rm -rf $(systemotherimage_intermediates)/system_other_image_info.txt
  $(call generate-image-prop-dictionary, $(systemotherimage_intermediates)/system_other_image_info.txt,system,skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_SYSTEM_OTHER) $(systemotherimage_intermediates)/system_other_image_info.txt \
          $(INSTALLED_SYSTEMOTHERIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
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

endif # BUILDING_SYSTEM_OTHER_IMAGE


# -----------------------------------------------------------------
# vendor partition image
ifdef BUILDING_VENDOR_IMAGE
INTERNAL_VENDORIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))


# Create symlink /vendor/odm to /odm if necessary.
ifdef BOARD_USES_ODMIMAGE
  INTERNAL_VENDORIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT_VENDOR)/odm,/odm,odm.img)
endif

# Create symlinks for vendor_dlkm on devices with a vendor_dlkm partition:
# /vendor/lib/modules -> /vendor_dlkm/lib/modules
#
# On devices with a vendor_dlkm partition,
# - /vendor/lib/modules is a symlink to a directory that stores vendor DLKMs.
# - /vendor_dlkm/{etc,...} store other vendor_dlkm files directly. The vendor_dlkm partition is
#   mounted at /vendor_dlkm at runtime and the symlinks created in system/core/rootdir/Android.mk
#   are hidden.
# On devices without a vendor_dlkm partition,
# - /vendor/lib/modules stores vendor DLKMs directly.
# - /vendor_dlkm/{etc,...} are symlinks to directories that store other vendor_dlkm files.
#   See system/core/rootdir/Android.mk for a list of created symlinks.
# The vendor DLKMs and other vendor_dlkm files must not be accessed using other paths because they
# are not guaranteed to exist on all devices.
ifdef BOARD_USES_VENDOR_DLKMIMAGE
  INTERNAL_VENDORIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT_VENDOR)/lib/modules,/vendor_dlkm/lib/modules,vendor_dlkm.img)
endif

INSTALLED_FILES_FILE_VENDOR := $(PRODUCT_OUT)/installed-files-vendor.txt
INSTALLED_FILES_JSON_VENDOR := $(INSTALLED_FILES_FILE_VENDOR:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR)
$(INSTALLED_FILES_FILE_VENDOR) : $(INTERNAL_VENDORIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_VENDOR) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

vendorimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor)
BUILT_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
define build-vendorimage-target
  $(call pretty,"Target vendor fs image: $(INSTALLED_VENDORIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR)
  @mkdir -p $(vendorimage_intermediates) && rm -rf $(vendorimage_intermediates)/vendor_image_info.txt
  $(call generate-image-prop-dictionary, $(vendorimage_intermediates)/vendor_image_info.txt,vendor,skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_VENDOR) $(vendorimage_intermediates)/vendor_image_info.txt \
          $(INSTALLED_VENDORIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_VENDORIMAGE_TARGET) $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_VENDORIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_VENDORIMAGE_TARGET := $(BUILT_VENDORIMAGE_TARGET)
$(INSTALLED_VENDORIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_VENDORIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_VENDOR) \
    $(RECOVERY_FROM_BOOT_PATCH)
	$(build-vendorimage-target)

.PHONY: vendorimage-nodeps vnod
vendorimage-nodeps vnod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-vendorimage-target)

sync: $(INTERNAL_VENDORIMAGE_FILES)

else ifdef BOARD_PREBUILT_VENDORIMAGE
INSTALLED_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDORIMAGE),$(INSTALLED_VENDORIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# product partition image
ifdef BUILDING_PRODUCT_IMAGE
INTERNAL_PRODUCTIMAGE_FILES := \
    $(filter $(TARGET_OUT_PRODUCT)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_PRODUCT := $(PRODUCT_OUT)/installed-files-product.txt
INSTALLED_FILES_JSON_PRODUCT := $(INSTALLED_FILES_FILE_PRODUCT:.txt=.json)
$(INSTALLED_FILES_FILE_PRODUCT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_PRODUCT)
$(INSTALLED_FILES_FILE_PRODUCT) : $(INTERNAL_PRODUCTIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_PRODUCT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

productimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,product)
BUILT_PRODUCTIMAGE_TARGET := $(PRODUCT_OUT)/product.img
define build-productimage-target
  $(call pretty,"Target product fs image: $(INSTALLED_PRODUCTIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_PRODUCT)
  @mkdir -p $(productimage_intermediates) && rm -rf $(productimage_intermediates)/product_image_info.txt
  $(call generate-image-prop-dictionary, $(productimage_intermediates)/product_image_info.txt,product,skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_PRODUCT) $(productimage_intermediates)/product_image_info.txt \
          $(INSTALLED_PRODUCTIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_PRODUCTIMAGE_TARGET),$(BOARD_PRODUCTIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_PRODUCTIMAGE_TARGET := $(BUILT_PRODUCTIMAGE_TARGET)
$(INSTALLED_PRODUCTIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_PRODUCTIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_PRODUCT)
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
# system_ext partition image
ifdef BUILDING_SYSTEM_EXT_IMAGE
INTERNAL_SYSTEM_EXTIMAGE_FILES := \
    $(filter $(TARGET_OUT_SYSTEM_EXT)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_SYSTEM_EXT := $(PRODUCT_OUT)/installed-files-system_ext.txt
INSTALLED_FILES_JSON_SYSTEM_EXT := $(INSTALLED_FILES_FILE_SYSTEM_EXT:.txt=.json)
$(INSTALLED_FILES_FILE_SYSTEM_EXT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_SYSTEM_EXT)
$(INSTALLED_FILES_FILE_SYSTEM_EXT) : $(INTERNAL_SYSTEM_EXTIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_SYSTEM_EXT) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

system_extimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,system_ext)
BUILT_SYSTEM_EXTIMAGE_TARGET := $(PRODUCT_OUT)/system_ext.img
define build-system_extimage-target
  $(call pretty,"Target system_ext fs image: $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_SYSTEM_EXT)
  @mkdir -p $(system_extimage_intermediates) && rm -rf $(system_extimage_intermediates)/system_ext_image_info.txt
  $(call generate-image-prop-dictionary, $(system_extimage_intermediates)/system_ext_image_info.txt,system_ext, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_SYSTEM_EXT) \
          $(system_extimage_intermediates)/system_ext_image_info.txt \
          $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
          $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_PRODUCT_SERVICESIMAGE_TARGET),$(BOARD_PRODUCT_SERVICESIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_SYSTEM_EXTIMAGE_TARGET := $(BUILT_SYSTEM_EXTIMAGE_TARGET)
$(INSTALLED_SYSTEM_EXTIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_SYSTEM_EXT)
	$(build-system_extimage-target)

.PHONY: systemextimage-nodeps senod
systemextimage-nodeps senod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-system_extimage-target)

sync: $(INTERNAL_SYSTEM_EXTIMAGE_FILES)

else ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
INSTALLED_SYSTEM_EXTIMAGE_TARGET := $(PRODUCT_OUT)/system_ext.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_SYSTEM_EXTIMAGE),$(INSTALLED_SYSTEM_EXTIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# odm partition image
ifdef BUILDING_ODM_IMAGE
INTERNAL_ODMIMAGE_FILES := \
    $(filter $(TARGET_OUT_ODM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

# Create symlinks for odm_dlkm on devices with a odm_dlkm partition:
# /odm/lib/modules -> /odm_dlkm/lib/modules
#
# On devices with a odm_dlkm partition,
# - /odm/lib/modules is a symlink to a directory that stores odm DLKMs.
# - /odm_dlkm/{etc,...} store other odm_dlkm files directly. The odm_dlkm partition is
#   mounted at /odm_dlkm at runtime and the symlinks created in system/core/rootdir/Android.mk
#   are hidden.
# On devices without a odm_dlkm partition,
# - /odm/lib/modules stores odm DLKMs directly.
# - /odm_dlkm/{etc,...} are symlinks to directories that store other odm_dlkm files.
#   See system/core/rootdir/Android.mk for a list of created symlinks.
# The odm DLKMs and other odm_dlkm files must not be accessed using other paths because they
# are not guaranteed to exist on all devices.
ifdef BOARD_USES_ODM_DLKMIMAGE
  INTERNAL_ODMIMAGE_FILES += $(call create-partition-compat-symlink,$(TARGET_OUT_ODM)/lib/modules,/odm_dlkm/lib/modules,odm_dlkm.img)
endif

INSTALLED_FILES_FILE_ODM := $(PRODUCT_OUT)/installed-files-odm.txt
INSTALLED_FILES_JSON_ODM := $(INSTALLED_FILES_FILE_ODM:.txt=.json)
$(INSTALLED_FILES_FILE_ODM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ODM)
$(INSTALLED_FILES_FILE_ODM) : $(INTERNAL_ODMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_ODM) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

odmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,odm)
BUILT_ODMIMAGE_TARGET := $(PRODUCT_OUT)/odm.img
define build-odmimage-target
  $(call pretty,"Target odm fs image: $(INSTALLED_ODMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_ODM)
  @mkdir -p $(odmimage_intermediates) && rm -rf $(odmimage_intermediates)/odm_image_info.txt
  $(call generate-userimage-prop-dictionary, $(odmimage_intermediates)/odm_image_info.txt, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_ODM) $(odmimage_intermediates)/odm_image_info.txt \
          $(INSTALLED_ODMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_ODMIMAGE_TARGET),$(BOARD_ODMIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_ODMIMAGE_TARGET := $(BUILT_ODMIMAGE_TARGET)
$(INSTALLED_ODMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_ODMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_ODM)
	$(build-odmimage-target)

.PHONY: odmimage-nodeps onod
odmimage-nodeps onod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-odmimage-target)

sync: $(INTERNAL_ODMIMAGE_FILES)

else ifdef BOARD_PREBUILT_ODMIMAGE
INSTALLED_ODMIMAGE_TARGET := $(PRODUCT_OUT)/odm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_ODMIMAGE),$(INSTALLED_ODMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# vendor_dlkm partition image
ifdef BUILDING_VENDOR_DLKM_IMAGE
INTERNAL_VENDOR_DLKMIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR_DLKM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_VENDOR_DLKM := $(PRODUCT_OUT)/installed-files-vendor_dlkm.txt
INSTALLED_FILES_JSON_VENDOR_DLKM := $(INSTALLED_FILES_FILE_VENDOR_DLKM:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_DLKM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_DLKM)
$(INSTALLED_FILES_FILE_VENDOR_DLKM) : $(INTERNAL_VENDOR_DLKMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_VENDOR_DLKM) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

vendor_dlkmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor_dlkm)
BUILT_VENDOR_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/vendor_dlkm.img
define build-vendor_dlkmimage-target
  $(call pretty,"Target vendor_dlkm fs image: $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR_DLKM)
  @mkdir -p $(vendor_dlkmimage_intermediates) && rm -rf $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt
  $(call generate-userimage-prop-dictionary, $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_VENDOR_DLKM) $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt \
          $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_VENDOR_DLKMIMAGE_TARGET),$(BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_VENDOR_DLKMIMAGE_TARGET := $(BUILT_VENDOR_DLKMIMAGE_TARGET)
$(INSTALLED_VENDOR_DLKMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_VENDOR_DLKM)
	$(build-vendor_dlkmimage-target)

.PHONY: vendor_dlkmimage-nodeps vdnod
vendor_dlkmimage-nodeps vdnod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-vendor_dlkmimage-target)

sync: $(INTERNAL_VENDOR_DLKMIMAGE_FILES)

else ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
INSTALLED_VENDOR_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/vendor_dlkm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDOR_DLKMIMAGE),$(INSTALLED_VENDOR_DLKMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# odm_dlkm partition image
ifdef BUILDING_ODM_DLKM_IMAGE
INTERNAL_ODM_DLKMIMAGE_FILES := \
    $(filter $(TARGET_OUT_ODM_DLKM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_ODM_DLKM := $(PRODUCT_OUT)/installed-files-odm_dlkm.txt
INSTALLED_FILES_JSON_ODM_DLKM := $(INSTALLED_FILES_FILE_ODM_DLKM:.txt=.json)
$(INSTALLED_FILES_FILE_ODM_DLKM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ODM_DLKM)
$(INSTALLED_FILES_FILE_ODM_DLKM) : $(INTERNAL_ODM_DLKMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT_ODM_DLKM) > $(@:.txt=.json)
	$(hide) $(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

odm_dlkmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,odm_dlkm)
BUILT_ODM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/odm_dlkm.img
define build-odm_dlkmimage-target
  $(call pretty,"Target odm_dlkm fs image: $(INSTALLED_ODM_DLKMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_ODM_DLKM)
  @mkdir -p $(odm_dlkmimage_intermediates) && rm -rf $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt
  $(call generate-userimage-prop-dictionary, $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(TARGET_OUT_ODM_DLKM) $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt \
          $(INSTALLED_ODM_DLKMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_ODM_DLKMIMAGE_TARGET),$(BOARD_ODM_DLKMIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_ODM_DLKMIMAGE_TARGET := $(BUILT_ODM_DLKMIMAGE_TARGET)
$(INSTALLED_ODM_DLKMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_ODM_DLKMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_ODM_DLKM)
	$(build-odm_dlkmimage-target)

.PHONY: odm_dlkmimage-nodeps odnod
odm_dlkmimage-nodeps odnod: | $(INTERNAL_USERIMAGES_DEPS)
	$(build-odm_dlkmimage-target)

sync: $(INTERNAL_ODM_DLKMIMAGE_FILES)

else ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
INSTALLED_ODM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/odm_dlkm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_ODM_DLKMIMAGE),$(INSTALLED_ODM_DLKMIMAGE_TARGET)))
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

endif # BOARD_PREBUILT_DTBOIMAGE

# Returns a list of image targets corresponding to the given list of partitions. For example, it
# returns "$(INSTALLED_PRODUCTIMAGE_TARGET)" for "product", or "$(INSTALLED_SYSTEMIMAGE_TARGET)
# $(INSTALLED_VENDORIMAGE_TARGET)" for "system vendor".
# (1): list of partitions like "system", "vendor" or "system product system_ext".
define images-for-partitions
$(strip $(foreach item,$(1),$(INSTALLED_$(call to-upper,$(item))IMAGE_TARGET)))
endef

# -----------------------------------------------------------------
# custom images
INSTALLED_CUSTOMIMAGES_TARGET :=

ifneq ($(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)),)
INTERNAL_AVB_CUSTOMIMAGES_SIGNING_ARGS :=

# Sign custom image.
# $(1): the prebuilt custom image.
# $(2): the mount point of the prebuilt custom image.
# $(3): the signed custom image target.
define sign_custom_image
$(3): $(1) $(INTERNAL_USERIMAGES_DEPS)
	@echo Target custom image: $(3)
	mkdir -p $(dir $(3))
	cp $(1) $(3)
ifeq ($(BOARD_AVB_ENABLE),true)
	PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$$$PATH \
          $(AVBTOOL) add_hashtree_footer \
          --image $(3) \
          --key $(BOARD_AVB_$(call to-upper,$(2))_KEY_PATH) \
          --algorithm $(BOARD_AVB_$(call to-upper,$(2))_ALGORITHM) \
          --partition_size $(BOARD_AVB_$(call to-upper,$(2))_PARTITION_SIZE) \
          --partition_name $(2) \
          $(INTERNAL_AVB_CUSTOMIMAGES_SIGNING_ARGS) \
          $(BOARD_AVB_$(call to-upper,$(2))_ADD_HASHTREE_FOOTER_ARGS)
endif
INSTALLED_CUSTOMIMAGES_TARGET += $(3)
endef

$(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
  $(foreach image,$(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST), \
     $(eval $(call sign_custom_image,$(image),$(partition),$(PRODUCT_OUT)/$(notdir $(image))))))
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

# AVB signing for system_other.img.
ifdef BUILDING_SYSTEM_OTHER_IMAGE
ifdef BOARD_AVB_SYSTEM_OTHER_KEY_PATH
$(if $(BOARD_AVB_SYSTEM_OTHER_ALGORITHM),,$(error BOARD_AVB_SYSTEM_OTHER_ALGORITHM is not defined))
else
# If key path isn't specified, use the same key as BOARD_AVB_KEY_PATH.
BOARD_AVB_SYSTEM_OTHER_KEY_PATH := $(BOARD_AVB_KEY_PATH)
BOARD_AVB_SYSTEM_OTHER_ALGORITHM := $(BOARD_AVB_ALGORITHM)
endif

$(INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET): $(AVBTOOL) $(BOARD_AVB_SYSTEM_OTHER_KEY_PATH)
	@echo Extracting system_other avb key: $@
	@rm -f $@
	@mkdir -p $(dir $@)
	$(AVBTOOL) extract_public_key --key $(BOARD_AVB_SYSTEM_OTHER_KEY_PATH) --output $@

ifndef BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX
BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
endif

BOARD_AVB_SYSTEM_OTHER_ADD_HASHTREE_FOOTER_ARGS += --rollback_index $(BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX)
endif # end of AVB for BUILDING_SYSTEM_OTHER_IMAGE

INTERNAL_AVB_PARTITIONS_IN_CHAINED_VBMETA_IMAGES := \
    $(BOARD_AVB_VBMETA_SYSTEM) \
    $(BOARD_AVB_VBMETA_VENDOR)

# Not allowing the same partition to appear in multiple groups.
ifneq ($(words $(sort $(INTERNAL_AVB_PARTITIONS_IN_CHAINED_VBMETA_IMAGES))),$(words $(INTERNAL_AVB_PARTITIONS_IN_CHAINED_VBMETA_IMAGES)))
  $(error BOARD_AVB_VBMETA_SYSTEM and BOARD_AVB_VBMETA_VENDOR cannot have duplicates)
endif

# When building a standalone recovery image for non-A/B devices, recovery image must be self-signed
# to be verified independently, and cannot be chained into vbmeta.img. See the link below for
# details.
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
$(if $(BOARD_AVB_RECOVERY_KEY_PATH),,\
    $(error BOARD_AVB_RECOVERY_KEY_PATH must be defined for if non-A/B is supported. \
            See https://android.googlesource.com/platform/external/avb/+/master/README.md#booting-into-recovery))
endif
endif

# Appends os version and security patch level as a AVB property descriptor

BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.system.os_version:$(PLATFORM_VERSION_LAST_STABLE) \
    --prop com.android.build.system.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.product.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.product.os_version:$(PLATFORM_VERSION_LAST_STABLE) \
    --prop com.android.build.product.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_ext.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.system_ext.os_version:$(PLATFORM_VERSION_LAST_STABLE) \
    --prop com.android.build.system_ext.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.boot.os_version:$(PLATFORM_VERSION_LAST_STABLE)

BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.vendor_boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \

BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.recovery.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.vendor.os_version:$(PLATFORM_VERSION_LAST_STABLE)

BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.odm.os_version:$(PLATFORM_VERSION_LAST_STABLE)

BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor_dlkm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.vendor_dlkm.os_version:$(PLATFORM_VERSION_LAST_STABLE)

BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm_dlkm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.odm_dlkm.os_version:$(PLATFORM_VERSION_LAST_STABLE)

BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.dtbo.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

# The following vendor- and odm-specific images needs explicit SPL set per board.
ifdef BOOT_SECURITY_PATCH
BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.boot.security_patch:$(BOOT_SECURITY_PATCH)
endif

ifdef VENDOR_SECURITY_PATCH
BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor.security_patch:$(VENDOR_SECURITY_PATCH)
endif

ifdef ODM_SECURITY_PATCH
BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm.security_patch:$(ODM_SECURITY_PATCH)
endif

ifdef VENDOR_DLKM_SECURITY_PATCH
BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor_dlkm.security_patch:$(VENDOR_DLKM_SECURITY_PATCH)
endif

ifdef ODM_DLKM_SECURITY_PATCH
BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm_dlkm.security_patch:$(ODM_DLKM_SECURITY_PATCH)
endif

BOOT_FOOTER_ARGS := BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS
VENDOR_BOOT_FOOTER_ARGS := BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS
DTBO_FOOTER_ARGS := BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS
SYSTEM_FOOTER_ARGS := BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS
VENDOR_FOOTER_ARGS := BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS
RECOVERY_FOOTER_ARGS := BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS
PRODUCT_FOOTER_ARGS := BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS
SYSTEM_EXT_FOOTER_ARGS := BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS
ODM_FOOTER_ARGS := BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS
VENDOR_DLKM_FOOTER_ARGS := BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS
ODM_DLKM_FOOTER_ARGS := BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS

# Helper function that checks and sets required build variables for an AVB chained partition.
# $(1): the partition to enable AVB chain, e.g., boot or system or vbmeta_system.
define _check-and-set-avb-chain-args
$(eval part := $(1))
$(eval PART=$(call to-upper,$(part)))

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

# The recovery partition in non-A/B devices should be verified separately. Skip adding the chain
# partition descriptor for recovery partition into vbmeta.img.
$(if $(or $(filter-out true,$(TARGET_OTA_ALLOW_NON_AB)),$(filter-out recovery,$(part))),\
    $(eval INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
        --chain_partition $(part):$($(_rollback_index_location)):$(AVB_CHAIN_KEY_DIR)/$(part).avbpubkey))

# Set rollback_index via footer args for non-chained vbmeta image. Chained vbmeta image will pick up
# the index via a separate flag (e.g. BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX).
$(if $(filter $(part),$(part:vbmeta_%=%)),\
    $(eval _footer_args := $(PART)_FOOTER_ARGS) \
    $(eval $($(_footer_args)) += --rollback_index $($(_rollback_index))))
endef

# Checks and sets the required build variables for an AVB partition. The partition will be
# configured as a chained partition, if BOARD_AVB_<partition>_KEY_PATH is defined. Otherwise the
# image descriptor will be included into vbmeta.img, unless it has been already added to any chained
# VBMeta image.
# Multiple boot images can be generated based on BOARD_KERNEL_BINARIES
# but vbmeta would capture the image descriptor of only the first boot
# image specified in BUILT_BOOTIMAGE_TARGET.
# $(1): Partition name, e.g. boot or system.
define check-and-set-avb-args
$(eval _in_chained_vbmeta := $(filter $(1),$(INTERNAL_AVB_PARTITIONS_IN_CHAINED_VBMETA_IMAGES)))
$(if $(BOARD_AVB_$(call to-upper,$(1))_KEY_PATH),\
    $(if $(_in_chained_vbmeta),\
        $(error Chaining partition "$(1)" in chained VBMeta image is not supported)) \
    $(call _check-and-set-avb-chain-args,$(1)),\
    $(if $(_in_chained_vbmeta),,\
        $(if $(filter boot,$(1)),\
            $(eval INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
                --include_descriptors_from_image $(firstword $(call images-for-partitions,$(1)))),\
            $(eval INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
                --include_descriptors_from_image $(call images-for-partitions,$(1))))))
endef

# Checks and sets build variables for a custom chained partition to include it into vbmeta.img.
# $(1): the custom partition to enable AVB chain.
define check-and-set-custom-avb-chain-args
$(eval part := $(1))
$(eval PART=$(call to-upper,$(part)))
$(eval _rollback_index_location := BOARD_AVB_$(PART)_ROLLBACK_INDEX_LOCATION)
$(if $($(_rollback_index_location)),,$(error $(_rollback_index_location) is not defined))

INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --chain_partition $(part):$($(_rollback_index_location)):$(AVB_CHAIN_KEY_DIR)/$(part).avbpubkey
endef

ifdef INSTALLED_BOOTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,boot))
endif

ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,vendor_boot))
endif

$(eval $(call check-and-set-avb-args,system))

ifdef INSTALLED_VENDORIMAGE_TARGET
$(eval $(call check-and-set-avb-args,vendor))
endif

ifdef INSTALLED_PRODUCTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,product))
endif

ifdef INSTALLED_SYSTEM_EXTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,system_ext))
endif

ifdef INSTALLED_ODMIMAGE_TARGET
$(eval $(call check-and-set-avb-args,odm))
endif

ifdef INSTALLED_VENDOR_DLKMIMAGE_TARGET
$(eval $(call check-and-set-avb-args,vendor_dlkm))
endif

ifdef INSTALLED_ODM_DLKMIMAGE_TARGET
$(eval $(call check-and-set-avb-args,odm_dlkm))
endif

ifdef INSTALLED_DTBOIMAGE_TARGET
$(eval $(call check-and-set-avb-args,dtbo))
endif

ifdef INSTALLED_RECOVERYIMAGE_TARGET
$(eval $(call check-and-set-avb-args,recovery))
endif

# Not using INSTALLED_VBMETA_SYSTEMIMAGE_TARGET as it won't be set yet.
ifdef BOARD_AVB_VBMETA_SYSTEM
$(eval $(call check-and-set-avb-args,vbmeta_system))
endif

ifdef BOARD_AVB_VBMETA_VENDOR
$(eval $(call check-and-set-avb-args,vbmeta_vendor))
endif

ifneq ($(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)),)
$(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
    $(eval $(call check-and-set-custom-avb-chain-args,$(partition))))
endif

# Add kernel cmdline descriptor for kernel to mount system.img as root with
# dm-verity. This works when system.img is either chained or not-chained:
# - chained: The --setup_as_rootfs_from_kernel option will add dm-verity kernel
#   cmdline descriptor to system.img
# - not-chained: The --include_descriptors_from_image option for make_vbmeta_image
#   will include the kernel cmdline descriptor from system.img into vbmeta.img
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
ifeq ($(filter system, $(BOARD_SUPER_PARTITION_PARTITION_LIST)),)
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --setup_as_rootfs_from_kernel
endif
endif

BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --padding_size 4096
BOARD_AVB_MAKE_VBMETA_SYSTEM_IMAGE_ARGS += --padding_size 4096
BOARD_AVB_MAKE_VBMETA_VENDOR_IMAGE_ARGS += --padding_size 4096

ifeq (eng,$(filter eng, $(TARGET_BUILD_VARIANT)))
# We only need the flag in top-level vbmeta.img.
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --set_hashtree_disabled_flag
endif

ifdef BOARD_AVB_ROLLBACK_INDEX
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --rollback_index $(BOARD_AVB_ROLLBACK_INDEX)
endif

ifdef BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX
BOARD_AVB_MAKE_VBMETA_SYSTEM_IMAGE_ARGS += \
    --rollback_index $(BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX)
endif

ifdef BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX
BOARD_AVB_MAKE_VBMETA_VENDOR_IMAGE_ARGS += \
    --rollback_index $(BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX)
endif

# $(1): the directory to extract public keys to
define extract-avb-chain-public-keys
  $(if $(BOARD_AVB_BOOT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_BOOT_KEY_PATH) \
      --output $(1)/boot.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_BOOT_KEY_PATH),\
    $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_BOOT_KEY_PATH) \
      --output $(1)/vendor_boot.avbpubkey)
  $(if $(BOARD_AVB_SYSTEM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_SYSTEM_KEY_PATH) \
      --output $(1)/system.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_KEY_PATH) \
      --output $(1)/vendor.avbpubkey)
  $(if $(BOARD_AVB_PRODUCT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_PRODUCT_KEY_PATH) \
      --output $(1)/product.avbpubkey)
  $(if $(BOARD_AVB_SYSTEM_EXT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_SYSTEM_EXT_KEY_PATH) \
      --output $(1)/system_ext.avbpubkey)
  $(if $(BOARD_AVB_ODM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_ODM_KEY_PATH) \
      --output $(1)/odm.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_DLKM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_DLKM_KEY_PATH) \
      --output $(1)/vendor_dlkm.avbpubkey)
  $(if $(BOARD_AVB_ODM_DLKM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_ODM_DLKM_KEY_PATH) \
      --output $(1)/odm_dlkm.avbpubkey)
  $(if $(BOARD_AVB_DTBO_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_DTBO_KEY_PATH) \
      --output $(1)/dtbo.avbpubkey)
  $(if $(BOARD_AVB_RECOVERY_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_RECOVERY_KEY_PATH) \
      --output $(1)/recovery.avbpubkey)
  $(if $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH) \
        --output $(1)/vbmeta_system.avbpubkey)
  $(if $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH) \
        --output $(1)/vbmeta_vendor.avbpubkey)
  $(if $(BOARD_CUSTOMIMAGES_PARTITION_LIST),\
    $(hide) $(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
        $(AVBTOOL) extract_public_key --key $(BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH) \
            --output $(1)/$(partition).avbpubkey;))
endef

# Builds a chained VBMeta image. This VBMeta image will contain the descriptors for the partitions
# specified in BOARD_AVB_VBMETA_<NAME>. The built VBMeta image will be included into the top-level
# vbmeta image as a chained partition. For example, if a target defines `BOARD_AVB_VBMETA_SYSTEM
# := system system_ext`, `vbmeta_system.img` will be created that includes the descriptors for
# `system.img` and `system_ext.img`. `vbmeta_system.img` itself will be included into
# `vbmeta.img` as a chained partition.
# $(1): VBMeta image name, such as "vbmeta_system", "vbmeta_vendor" etc.
# $(2): Output filename.
define build-chained-vbmeta-image
  $(call pretty,"Target chained vbmeta image: $@")
  $(hide) $(AVBTOOL) make_vbmeta_image \
      $(INTERNAL_AVB_$(call to-upper,$(1))_SIGNING_ARGS) \
      $(BOARD_AVB_MAKE_$(call to-upper,$(1))_IMAGE_ARGS) \
      $(foreach image,$(BOARD_AVB_$(call to-upper,$(1))), \
          --include_descriptors_from_image $(call images-for-partitions,$(image))) \
      --output $@
endef

ifdef BUILDING_SYSTEM_IMAGE
ifdef BOARD_AVB_VBMETA_SYSTEM
INSTALLED_VBMETA_SYSTEMIMAGE_TARGET := $(PRODUCT_OUT)/vbmeta_system.img
$(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET): \
	    $(AVBTOOL) \
	    $(call images-for-partitions,$(BOARD_AVB_VBMETA_SYSTEM)) \
	    $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH)
	$(call build-chained-vbmeta-image,vbmeta_system)
endif
endif # BUILDING_SYSTEM_IMAGE

ifdef BOARD_AVB_VBMETA_VENDOR
INSTALLED_VBMETA_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vbmeta_vendor.img
$(INSTALLED_VBMETA_VENDORIMAGE_TARGET): \
	    $(AVBTOOL) \
	    $(call images-for-partitions,$(BOARD_AVB_VBMETA_VENDOR)) \
	    $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH)
	$(call build-chained-vbmeta-image,vbmeta_vendor)
endif

define build-vbmetaimage-target
  $(call pretty,"Target vbmeta image: $(INSTALLED_VBMETAIMAGE_TARGET)")
  $(hide) mkdir -p $(AVB_CHAIN_KEY_DIR)
  $(call extract-avb-chain-public-keys, $(AVB_CHAIN_KEY_DIR))
  $(hide) $(AVBTOOL) make_vbmeta_image \
    $(INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS) \
    $(PRIVATE_AVB_VBMETA_SIGNING_ARGS) \
    $(BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS) \
    --output $@
  $(hide) rm -rf $(AVB_CHAIN_KEY_DIR)
endef

ifdef BUILDING_VBMETA_IMAGE
INSTALLED_VBMETAIMAGE_TARGET := $(BUILT_VBMETAIMAGE_TARGET)
$(INSTALLED_VBMETAIMAGE_TARGET): PRIVATE_AVB_VBMETA_SIGNING_ARGS := \
    --algorithm $(BOARD_AVB_ALGORITHM) --key $(BOARD_AVB_KEY_PATH)

$(INSTALLED_VBMETAIMAGE_TARGET): \
	    $(AVBTOOL) \
	    $(INSTALLED_BOOTIMAGE_TARGET) \
	    $(INSTALLED_VENDOR_BOOTIMAGE_TARGET) \
	    $(INSTALLED_SYSTEMIMAGE_TARGET) \
	    $(INSTALLED_VENDORIMAGE_TARGET) \
	    $(INSTALLED_PRODUCTIMAGE_TARGET) \
	    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
	    $(INSTALLED_ODMIMAGE_TARGET) \
	    $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) \
	    $(INSTALLED_ODM_DLKMIMAGE_TARGET) \
	    $(INSTALLED_DTBOIMAGE_TARGET) \
	    $(INSTALLED_CUSTOMIMAGES_TARGET) \
	    $(INSTALLED_RECOVERYIMAGE_TARGET) \
	    $(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET) \
	    $(INSTALLED_VBMETA_VENDORIMAGE_TARGET) \
	    $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH) \
	    $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH) \
	    $(BOARD_AVB_KEY_PATH)
	$(build-vbmetaimage-target)

.PHONY: vbmetaimage-nodeps
vbmetaimage-nodeps: PRIVATE_AVB_VBMETA_SIGNING_ARGS := \
    --algorithm $(BOARD_AVB_ALGORITHM) --key $(BOARD_AVB_KEY_PATH)
vbmetaimage-nodeps:
	$(build-vbmetaimage-target)
endif # BUILDING_VBMETA_IMAGE

endif # BOARD_AVB_ENABLE

# -----------------------------------------------------------------
# Check VINTF of build

# Note: vendor_dlkm and odm_dlkm does not have VINTF files.
ifeq (,$(TARGET_BUILD_UNBUNDLED))

intermediates := $(call intermediates-dir-for,PACKAGING,check_vintf_all)
check_vintf_all_deps :=

# The build system only writes VINTF metadata to */etc/vintf paths. Legacy paths aren't needed here
# because they are only used for prebuilt images.
check_vintf_common_srcs_patterns := \
  $(TARGET_OUT)/etc/vintf/% \
  $(TARGET_OUT_VENDOR)/etc/vintf/% \
  $(TARGET_OUT_ODM)/etc/vintf/% \
  $(TARGET_OUT_PRODUCT)/etc/vintf/% \
  $(TARGET_OUT_SYSTEM_EXT)/etc/vintf/% \

check_vintf_common_srcs := $(sort $(filter $(check_vintf_common_srcs_patterns), \
  $(INTERNAL_SYSTEMIMAGE_FILES) \
  $(INTERNAL_VENDORIMAGE_FILES) \
  $(INTERNAL_ODMIMAGE_FILES) \
  $(INTERNAL_PRODUCTIMAGE_FILES) \
  $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
))
check_vintf_common_srcs_patterns :=

check_vintf_has_system :=
check_vintf_has_vendor :=

ifneq (,$(filter EMPTY_ODM_SKU_PLACEHOLDER,$(ODM_MANIFEST_SKUS)))
$(error EMPTY_ODM_SKU_PLACEHOLDER is an internal variable and cannot be used for ODM_MANIFEST_SKUS)
endif
ifneq (,$(filter EMPTY_VENDOR_SKU_PLACEHOLDER,$(DEVICE_MANIFEST_SKUS)))
$(error EMPTY_VENDOR_SKU_PLACEHOLDER is an internal variable and cannot be used for DEIVCE_MANIFEST_SKUS)
endif

# -- Check system manifest / matrix including fragments (excluding other framework manifests / matrices, e.g. product);
check_vintf_system_deps := $(filter $(TARGET_OUT)/etc/vintf/%, $(check_vintf_common_srcs))
ifneq ($(check_vintf_system_deps),)
check_vintf_has_system := true

check_vintf_system_log := $(intermediates)/check_vintf_system_log
check_vintf_all_deps += $(check_vintf_system_log)
$(check_vintf_system_log): $(HOST_OUT_EXECUTABLES)/checkvintf $(check_vintf_system_deps)
	@( $< --check-one --dirmap /system:$(TARGET_OUT) > $@ 2>&1 ) || ( cat $@ && exit 1 )
check_vintf_system_log :=

vintffm_log := $(intermediates)/vintffm_log
check_vintf_all_deps += $(vintffm_log)
$(vintffm_log): $(HOST_OUT_EXECUTABLES)/vintffm $(check_vintf_system_deps)
	@( $< --check --dirmap /system:$(TARGET_OUT) \
	  $(VINTF_FRAMEWORK_MANIFEST_FROZEN_DIR) > $@ 2>&1 ) || ( cat $@ && exit 1 )

endif # check_vintf_system_deps
check_vintf_system_deps :=

# -- Check vendor manifest / matrix including fragments (excluding other device manifests / matrices)
check_vintf_vendor_deps := $(filter $(TARGET_OUT_VENDOR)/etc/vintf/%, $(check_vintf_common_srcs))
ifneq ($(check_vintf_vendor_deps),)
check_vintf_has_vendor := true
check_vintf_vendor_log := $(intermediates)/check_vintf_vendor_log
check_vintf_all_deps += $(check_vintf_vendor_log)
# Check vendor SKU=(empty) case when:
# - DEVICE_MANIFEST_FILE is not empty; OR
# - DEVICE_MANIFEST_FILE is empty AND DEVICE_MANIFEST_SKUS is empty (only vendor manifest fragments are used)
$(check_vintf_vendor_log): PRIVATE_VENDOR_SKUS := \
  $(if $(DEVICE_MANIFEST_FILE),EMPTY_VENDOR_SKU_PLACEHOLDER,\
    $(if $(DEVICE_MANIFEST_SKUS),,EMPTY_VENDOR_SKU_PLACEHOLDER)) \
  $(DEVICE_MANIFEST_SKUS)
$(check_vintf_vendor_log): $(HOST_OUT_EXECUTABLES)/checkvintf $(check_vintf_vendor_deps)
	$(foreach vendor_sku,$(PRIVATE_VENDOR_SKUS), \
	  ( $< --check-one --dirmap /vendor:$(TARGET_OUT_VENDOR) \
	       --property ro.boot.product.vendor.sku=$(filter-out EMPTY_VENDOR_SKU_PLACEHOLDER,$(vendor_sku)) \
	       > $@ 2>&1 ) || ( cat $@ && exit 1 ); )
check_vintf_vendor_log :=
endif # check_vintf_vendor_deps
check_vintf_vendor_deps :=

# -- Check VINTF compatibility of build.
# Skip partial builds; only check full builds. Only check if:
# - PRODUCT_ENFORCE_VINTF_MANIFEST is true
# - system / vendor VINTF metadata exists
# - Building product / system_ext / odm images if board has product / system_ext / odm images
ifeq ($(PRODUCT_ENFORCE_VINTF_MANIFEST),true)
ifeq ($(check_vintf_has_system),true)
ifeq ($(check_vintf_has_vendor),true)
ifeq ($(filter true,$(BUILDING_ODM_IMAGE)),$(filter true,$(BOARD_USES_ODMIMAGE)))
ifeq ($(filter true,$(BUILDING_PRODUCT_IMAGE)),$(filter true,$(BOARD_USES_PRODUCTIMAGE)))
ifeq ($(filter true,$(BUILDING_SYSTEM_EXT_IMAGE)),$(filter true,$(BOARD_USES_SYSTEM_EXTIMAGE)))

check_vintf_compatible_log := $(intermediates)/check_vintf_compatible_log
check_vintf_all_deps += $(check_vintf_compatible_log)

check_vintf_compatible_args :=
check_vintf_compatible_deps := $(check_vintf_common_srcs)

# -- Kernel version and configurations.
ifeq ($(PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS),true)

BUILT_KERNEL_CONFIGS_FILE := $(intermediates)/kernel_configs.txt
BUILT_KERNEL_VERSION_FILE := $(intermediates)/kernel_version.txt

my_board_extracted_kernel :=

# BOARD_KERNEL_CONFIG_FILE and BOARD_KERNEL_VERSION can be used to override the values extracted
# from INSTALLED_KERNEL_TARGET.
ifdef BOARD_KERNEL_CONFIG_FILE
ifdef BOARD_KERNEL_VERSION
$(BUILT_KERNEL_CONFIGS_FILE): $(BOARD_KERNEL_CONFIG_FILE)
	cp $< $@
$(BUILT_KERNEL_VERSION_FILE):
	echo $(BOARD_KERNEL_VERSION) > $@

my_board_extracted_kernel := true
endif # BOARD_KERNEL_VERSION
endif # BOARD_KERNEL_CONFIG_FILE

ifneq ($(my_board_extracted_kernel),true)
ifndef INSTALLED_KERNEL_TARGET
$(warning No INSTALLED_KERNEL_TARGET is defined when PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS \
    is true. Information about the updated kernel cannot be built into OTA update package. \
    You can fix this by: (1) setting TARGET_NO_KERNEL to false and installing the built kernel \
    to $(PRODUCT_OUT)/kernel, so that kernel information will be extracted from the built kernel; \
    or (2) extracting kernel configuration and defining BOARD_KERNEL_CONFIG_FILE and \
    BOARD_KERNEL_VERSION manually; or (3) unsetting PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS \
    manually.)
else

# Tools for decompression that is not in PATH.
# Check $(EXTRACT_KERNEL) for decompression algorithms supported by the script.
# Algorithms that are in the script but not in this list will be found in PATH.
my_decompress_tools := \
    lz4:$(HOST_OUT_EXECUTABLES)/lz4 \

$(BUILT_KERNEL_CONFIGS_FILE): .KATI_IMPLICIT_OUTPUTS := $(BUILT_KERNEL_VERSION_FILE)
$(BUILT_KERNEL_CONFIGS_FILE): PRIVATE_DECOMPRESS_TOOLS := $(my_decompress_tools)
$(BUILT_KERNEL_CONFIGS_FILE): $(foreach pair,$(my_decompress_tools),$(call word-colon,2,$(pair)))
$(BUILT_KERNEL_CONFIGS_FILE): $(EXTRACT_KERNEL) $(firstword $(INSTALLED_KERNEL_TARGET))
	$< --tools $(PRIVATE_DECOMPRESS_TOOLS) --input $(firstword $(INSTALLED_KERNEL_TARGET)) \
	  --output-configs $@ \
	  --output-version $(BUILT_KERNEL_VERSION_FILE)

my_decompress_tools :=

endif # my_board_extracted_kernel
my_board_extracted_kernel :=

endif # INSTALLED_KERNEL_TARGET

check_vintf_compatible_args += --kernel $$(cat $(BUILT_KERNEL_VERSION_FILE)):$(BUILT_KERNEL_CONFIGS_FILE)
check_vintf_compatible_deps += $(BUILT_KERNEL_CONFIGS_FILE) $(BUILT_KERNEL_VERSION_FILE)

endif # PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS

check_vintf_compatible_args += \
  --dirmap /system:$(TARGET_OUT) \
  --dirmap /vendor:$(TARGET_OUT_VENDOR) \
  --dirmap /odm:$(TARGET_OUT_ODM) \
  --dirmap /product:$(TARGET_OUT_PRODUCT) \
  --dirmap /system_ext:$(TARGET_OUT_SYSTEM_EXT) \

ifdef PRODUCT_SHIPPING_API_LEVEL
check_vintf_compatible_args += --property ro.product.first_api_level=$(PRODUCT_SHIPPING_API_LEVEL)
endif # PRODUCT_SHIPPING_API_LEVEL

$(check_vintf_compatible_log): PRIVATE_CHECK_VINTF_ARGS := $(check_vintf_compatible_args)
$(check_vintf_compatible_log): PRIVATE_CHECK_VINTF_DEPS := $(check_vintf_compatible_deps)
# Check ODM SKU=(empty) case when:
# - ODM_MANIFEST_FILES is not empty; OR
# - ODM_MANIFEST_FILES is empty AND ODM_MANIFEST_SKUS is empty (only ODM manifest fragments are used)
$(check_vintf_compatible_log): PRIVATE_ODM_SKUS := \
  $(if $(ODM_MANIFEST_FILES),EMPTY_ODM_SKU_PLACEHOLDER,\
    $(if $(ODM_MANIFEST_SKUS),,EMPTY_ODM_SKU_PLACEHOLDER)) \
  $(ODM_MANIFEST_SKUS)
# Check vendor SKU=(empty) case when:
# - DEVICE_MANIFEST_FILE is not empty; OR
# - DEVICE_MANIFEST_FILE is empty AND DEVICE_MANIFEST_SKUS is empty (only vendor manifest fragments are used)
$(check_vintf_compatible_log): PRIVATE_VENDOR_SKUS := \
  $(if $(DEVICE_MANIFEST_FILE),EMPTY_VENDOR_SKU_PLACEHOLDER,\
    $(if $(DEVICE_MANIFEST_SKUS),,EMPTY_VENDOR_SKU_PLACEHOLDER)) \
  $(DEVICE_MANIFEST_SKUS)
$(check_vintf_compatible_log): $(HOST_OUT_EXECUTABLES)/checkvintf $(check_vintf_compatible_deps)
	@echo -n -e 'Deps: \n  ' > $@
	@sed 's/ /\n  /g' <<< "$(PRIVATE_CHECK_VINTF_DEPS)" >> $@
	@echo -n -e 'Args: \n  ' >> $@
	@cat <<< "$(PRIVATE_CHECK_VINTF_ARGS)" >> $@
	$(foreach odm_sku,$(PRIVATE_ODM_SKUS), $(foreach vendor_sku,$(PRIVATE_VENDOR_SKUS), \
	  echo "For ODM SKU = $(odm_sku), vendor SKU = $(vendor_sku)" >> $@; \
	  ( $< --check-compat $(PRIVATE_CHECK_VINTF_ARGS) \
	       --property ro.boot.product.hardware.sku=$(filter-out EMPTY_ODM_SKU_PLACEHOLDER,$(odm_sku)) \
	       --property ro.boot.product.vendor.sku=$(filter-out EMPTY_VENDOR_SKU_PLACEHOLDER,$(vendor_sku)) \
	       >> $@ 2>&1 ) || (cat $@ && exit 1); ))

check_vintf_compatible_log :=
check_vintf_compatible_args :=
check_vintf_compatible_deps :=

endif # BUILDING_SYSTEM_EXT_IMAGE equals BOARD_USES_SYSTEM_EXTIMAGE
endif # BUILDING_PRODUCT_IMAGE equals BOARD_USES_PRODUCTIMAGE
endif # BUILDING_ODM_IMAGE equals BOARD_USES_ODMIMAGE
endif # check_vintf_has_vendor
endif # check_vintf_has_system
endif # PRODUCT_ENFORCE_VINTF_MANIFEST

# Add all logs of VINTF checks to dist builds
droid_targets: $(check_vintf_all_deps)
$(call dist-for-goals, droid_targets, $(check_vintf_all_deps))

# Helper alias to check all VINTF of current build.
.PHONY: check-vintf-all
check-vintf-all: $(check_vintf_all_deps)
	$(foreach file,$^,echo "$(file)"; cat "$(file)"; echo;)

check_vintf_has_vendor :=
check_vintf_has_system :=
check_vintf_common_srcs :=
check_vintf_all_deps :=
intermediates :=
endif # !TARGET_BUILD_UNBUNDLED

# -----------------------------------------------------------------
# Check image sizes <= size of super partition

ifeq (,$(TARGET_BUILD_UNBUNDLED))

ifeq (true,$(PRODUCT_BUILD_SUPER_PARTITION))

# $(1): misc_info.txt
# #(2): optional log file
define check-all-partition-sizes-target
  mkdir -p $(dir $(1))
  rm -f $(1)
  $(call dump-super-image-info, $(1))
  $(foreach partition,$(BOARD_SUPER_PARTITION_PARTITION_LIST), \
    echo "$(partition)_image="$(call images-for-partitions,$(partition)) >> $(1);)
  $(CHECK_PARTITION_SIZES) $(if $(2),--logfile $(2),-v) $(1)
endef

check_all_partition_sizes_log := $(call intermediates-dir-for,PACKAGING,check-all-partition-sizes)/check_all_partition_sizes_log
droid_targets: $(check_all_partition_sizes_log)
$(call dist-for-goals, droid_targets, $(check_all_partition_sizes_log))

$(check_all_partition_sizes_log): \
    $(CHECK_PARTITION_SIZES) \
    $(call images-for-partitions,$(BOARD_SUPER_PARTITION_PARTITION_LIST))
	$(call check-all-partition-sizes-target, \
	  $(call intermediates-dir-for,PACKAGING,check-all-partition-sizes)/misc_info.txt, \
	  $@)

.PHONY: check-all-partition-sizes
check-all-partition-sizes: $(check_all_partition_sizes_log)

.PHONY: check-all-partition-sizes-nodeps
check-all-partition-sizes-nodeps:
	$(call check-all-partition-sizes-target, \
	  $(call intermediates-dir-for,PACKAGING,check-all-partition-sizes-nodeps)/misc_info.txt)

endif # PRODUCT_BUILD_SUPER_PARTITION

endif # !TARGET_BUILD_UNBUNDLED

# -----------------------------------------------------------------
# bring in the installer image generation defines if necessary
ifeq ($(TARGET_USE_DISKINSTALLER),true)
include bootable/diskinstaller/config.mk
endif

# -----------------------------------------------------------------
# host tools needed to build dist and OTA packages

ifeq ($(BUILD_OS),darwin)
  build_ota_package := false
  build_otatools_package := false
else
  # Set build_ota_package, and allow opt-out below.
  build_ota_package := true
  ifeq ($(TARGET_SKIP_OTA_PACKAGE),true)
    build_ota_package := false
  endif
  ifneq (,$(filter address, $(SANITIZE_TARGET)))
    build_ota_package := false
  endif
  ifeq ($(TARGET_PRODUCT),sdk)
    build_ota_package := false
  endif
  ifneq ($(PRODUCT_BUILD_GENERIC_OTA_PACKAGE),true)
    ifneq ($(filter generic%,$(TARGET_DEVICE)),)
      build_ota_package := false
    endif
    ifeq ($(TARGET_NO_KERNEL),true)
      build_ota_package := false
    endif
    ifeq ($(recovery_fstab),)
      build_ota_package := false
    endif
  endif # PRODUCT_BUILD_GENERIC_OTA_PACKAGE

  # Set build_otatools_package, and allow opt-out below.
  build_otatools_package := true
  ifeq ($(TARGET_SKIP_OTATOOLS_PACKAGE),true)
    build_otatools_package := false
  endif
endif

ifeq ($(build_otatools_package),true)

INTERNAL_OTATOOLS_MODULES := \
  aapt2 \
  add_img_to_target_files \
  aftltool \
  apksigner \
  append2simg \
  avbtool \
  blk_alloc_to_base_fs \
  boot_signer \
  brillo_update_payload \
  brotli \
  bsdiff \
  build_image \
  build_super_image \
  build_verity_metadata \
  build_verity_tree \
  care_map_generator \
  check_ota_package_signature \
  check_target_files_signatures \
  check_target_files_vintf \
  checkvintf \
  delta_generator \
  e2fsck \
  e2fsdroid \
  fc_sort \
  fec \
  fs_config \
  generate_verity_key \
  img2simg \
  img_from_target_files \
  imgdiff \
  libconscrypt_openjdk_jni \
  lpmake \
  lpunpack \
  lz4 \
  make_f2fs \
  make_f2fs_casefold \
  merge_target_files \
  minigzip \
  mk_combined_img \
  mkbootfs \
  mkbootimg \
  mke2fs \
  mke2fs.conf \
  mkf2fsuserimg.sh \
  mksquashfs \
  mksquashfsimage.sh \
  mkuserimg_mke2fs \
  ota_from_target_files \
  sefcontext_compile \
  sgdisk \
  shflags \
  sign_apex \
  sign_target_files_apks \
  signapk \
  simg2img \
  sload_f2fs \
  toybox \
  tune2fs \
  unpack_bootimg \
  update_host_simulator \
  validate_target_files \
  verity_signer \
  verity_verifier \
  zipalign \

# Additional tools to unpack and repack the apex file.
INTERNAL_OTATOOLS_MODULES += \
  apexer \
  deapexer \
  debugfs_static \
  merge_zips \
  resize2fs \
  soong_zip \

ifeq (true,$(PRODUCT_SUPPORTS_VBOOT))
INTERNAL_OTATOOLS_MODULES += \
  futility \
  vboot_signer
endif

INTERNAL_OTATOOLS_FILES := \
  $(filter $(HOST_OUT)/%,$(call module-installed-files,$(INTERNAL_OTATOOLS_MODULES)))

.PHONY: otatools
otatools: $(INTERNAL_OTATOOLS_FILES)

# For each module, recursively resolve its host shared library dependencies. Then we have a full
# list of modules whose installed files need to be packed.
INTERNAL_OTATOOLS_MODULES_WITH_DEPS := \
  $(sort $(INTERNAL_OTATOOLS_MODULES) \
      $(foreach m,$(INTERNAL_OTATOOLS_MODULES),$(call get-all-shared-libs-deps,$(m))))

INTERNAL_OTATOOLS_PACKAGE_FILES := \
  $(filter $(HOST_OUT)/%,$(call module-installed-files,$(INTERNAL_OTATOOLS_MODULES_WITH_DEPS)))

INTERNAL_OTATOOLS_PACKAGE_FILES += \
  $(sort $(shell find build/make/target/product/security -type f -name "*.x509.pem" -o \
      -name "*.pk8" -o -name verity_key))

ifneq (,$(wildcard device))
INTERNAL_OTATOOLS_PACKAGE_FILES += \
  $(sort $(shell find device $(wildcard vendor) -type f -name "*.pk8" -o -name "verifiedboot*" -o \
      -name "*.pem" -o -name "oem*.prop" -o -name "*.avbpubkey"))
endif
ifneq (,$(wildcard external/avb))
INTERNAL_OTATOOLS_PACKAGE_FILES += \
  $(sort $(shell find external/avb/test/data -type f -name "testkey_*.pem" -o \
      -name "atx_metadata.bin"))
endif
ifeq (true,$(PRODUCT_SUPPORTS_VBOOT))
INTERNAL_OTATOOLS_PACKAGE_FILES += \
  $(sort $(shell find external/vboot_reference/tests/devkeys -type f))
endif

INTERNAL_OTATOOLS_RELEASETOOLS := \
  $(sort $(shell find build/make/tools/releasetools -name "*.pyc" -prune -o \
      \( -type f -o -type l \) -print))

BUILT_OTATOOLS_PACKAGE := $(PRODUCT_OUT)/otatools.zip
$(BUILT_OTATOOLS_PACKAGE): PRIVATE_ZIP_ROOT := $(call intermediates-dir-for,PACKAGING,otatools)/otatools
$(BUILT_OTATOOLS_PACKAGE): PRIVATE_OTATOOLS_PACKAGE_FILES := $(INTERNAL_OTATOOLS_PACKAGE_FILES)
$(BUILT_OTATOOLS_PACKAGE): PRIVATE_OTATOOLS_RELEASETOOLS := $(INTERNAL_OTATOOLS_RELEASETOOLS)
$(BUILT_OTATOOLS_PACKAGE): $(INTERNAL_OTATOOLS_PACKAGE_FILES) $(INTERNAL_OTATOOLS_RELEASETOOLS)
$(BUILT_OTATOOLS_PACKAGE): $(SOONG_ZIP) $(ZIP2ZIP)
	@echo "Package OTA tools: $@"
	rm -rf $@ $(PRIVATE_ZIP_ROOT)
	mkdir -p $(dir $@)
	$(call copy-files-with-structure,$(PRIVATE_OTATOOLS_PACKAGE_FILES),$(HOST_OUT)/,$(PRIVATE_ZIP_ROOT))
	$(call copy-files-with-structure,$(PRIVATE_OTATOOLS_RELEASETOOLS),build/make/tools/,$(PRIVATE_ZIP_ROOT))
	cp $(SOONG_ZIP) $(ZIP2ZIP) $(MERGE_ZIPS) $(PRIVATE_ZIP_ROOT)/bin/
	$(SOONG_ZIP) -o $@ -C $(PRIVATE_ZIP_ROOT) -D $(PRIVATE_ZIP_ROOT)

.PHONY: otatools-package
otatools-package: $(BUILT_OTATOOLS_PACKAGE)

endif # build_otatools_package

# -----------------------------------------------------------------
#  misc_info.txt

INSTALLED_MISC_INFO_TARGET := $(PRODUCT_OUT)/misc_info.txt

ifeq ($(TARGET_RELEASETOOLS_EXTENSIONS),)
# default to common dir for device vendor
tool_extensions := $(TARGET_DEVICE_DIR)/../common
else
tool_extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif
.KATI_READONLY := tool_extensions

# $1: boot image file name
define misc_boot_size
$(subst .img,_size,$(1))=$(BOARD_KERNEL$(call to-upper,$(subst boot,,$(subst .img,,$(1))))_BOOTIMAGE_PARTITION_SIZE)
endef

$(INSTALLED_MISC_INFO_TARGET):
	rm -f $@
	$(call pretty,"Target misc_info.txt: $@")
	$(hide) echo "recovery_api_version=$(RECOVERY_API_VERSION)" >> $@
	$(hide) echo "fstab_version=$(RECOVERY_FSTAB_VERSION)" >> $@
ifdef BOARD_FLASH_BLOCK_SIZE
	$(hide) echo "blocksize=$(BOARD_FLASH_BLOCK_SIZE)" >> $@
endif
ifneq ($(strip $(BOARD_BOOTIMAGE_PARTITION_SIZE))$(strip $(BOARD_KERNEL_BINARIES)),)
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),\
		echo "$(call misc_boot_size,$(notdir $(b)))" >> $@;)
endif
ifeq ($(INSTALLED_BOOTIMAGE_TARGET),)
	$(hide) echo "no_boot=true" >> $@
else
	echo "boot_images=$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(notdir $(b)))" >> $@
endif
ifeq ($(BOARD_RAMDISK_USE_LZ4),true)
	echo "lz4_ramdisks=true" >> $@
endif
ifneq ($(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
	echo "vendor_boot=true" >> $@
	echo "vendor_boot_size=$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE)" >> $@
endif
ifeq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) echo "no_recovery=true" >> $@
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
	$(hide) echo "include_recovery_dtbo=true" >> $@
endif
ifdef BOARD_INCLUDE_RECOVERY_ACPIO
	$(hide) echo "include_recovery_acpio=true" >> $@
endif
ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
	$(hide) echo "recovery_size=$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)" >> $@
endif
ifdef TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS
	@# TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS can be empty to indicate that nothing but defaults should be used.
	$(hide) echo "recovery_mount_options=$(TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $@
else
	$(hide) echo "recovery_mount_options=$(DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $@
endif
	$(hide) echo "tool_extensions=$(tool_extensions)" >> $@
	$(hide) echo "default_system_dev_certificate=$(DEFAULT_SYSTEM_DEV_CERTIFICATE)" >> $@
ifdef PRODUCT_EXTRA_RECOVERY_KEYS
	$(hide) echo "extra_recovery_keys=$(PRODUCT_EXTRA_RECOVERY_KEYS)" >> $@
endif
	$(hide) echo 'mkbootimg_args=$(BOARD_MKBOOTIMG_ARGS)' >> $@
	$(hide) echo 'recovery_mkbootimg_args=$(BOARD_RECOVERY_MKBOOTIMG_ARGS)' >> $@
	$(hide) echo 'mkbootimg_version_args=$(INTERNAL_MKBOOTIMG_VERSION_ARGS)' >> $@
	$(hide) echo "multistage_support=1" >> $@
	$(hide) echo "blockimgdiff_versions=3,4" >> $@
ifeq ($(PRODUCT_BUILD_GENERIC_OTA_PACKAGE),true)
	$(hide) echo "build_generic_ota_package=true" >> $@
endif
ifneq ($(OEM_THUMBPRINT_PROPERTIES),)
	# OTA scripts are only interested in fingerprint related properties
	$(hide) echo "oem_fingerprint_properties=$(OEM_THUMBPRINT_PROPERTIES)" >> $@
endif
ifneq (,$(filter address, $(SANITIZE_TARGET)))
	# We need to create userdata.img with real data because the instrumented libraries are in userdata.img.
	$(hide) echo "userdata_img_with_data=true" >> $@
endif
ifeq ($(BOARD_USES_FULL_RECOVERY_IMAGE),true)
	$(hide) echo "full_recovery_image=true" >> $@
endif
ifdef BOARD_USES_VENDORIMAGE
	$(hide) echo "board_uses_vendorimage=true" >> $@
endif
ifeq ($(BOARD_AVB_ENABLE),true)
	$(hide) echo "avb_enable=true" >> $@
	$(hide) echo "avb_vbmeta_key_path=$(BOARD_AVB_KEY_PATH)" >> $@
	$(hide) echo "avb_vbmeta_algorithm=$(BOARD_AVB_ALGORITHM)" >> $@
	$(hide) echo "avb_vbmeta_args=$(BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS)" >> $@
	$(hide) echo "avb_boot_add_hash_footer_args=$(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_BOOT_KEY_PATH
	$(hide) echo "avb_boot_key_path=$(BOARD_AVB_BOOT_KEY_PATH)" >> $@
	$(hide) echo "avb_boot_algorithm=$(BOARD_AVB_BOOT_ALGORITHM)" >> $@
	$(hide) echo "avb_boot_rollback_index_location=$(BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_BOOT_KEY_PATH
	echo "avb_vendor_boot_add_hash_footer_args=$(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_VENDOR_BOOT_KEY_PATH
	echo "avb_vendor_boot_key_path=$(BOARD_AVB_VENDOR_BOOT_KEY_PATH)" >> $@
	echo "avb_vendor_boot_algorithm=$(BOARD_AVB_VENDOR_BOOT_ALGORITHM)" >> $@
	echo "avb_vendor_boot_rollback_index_location=$(BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VENDOR_BOOT_KEY_PATH
	$(hide) echo "avb_recovery_add_hash_footer_args=$(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_RECOVERY_KEY_PATH
	$(hide) echo "avb_recovery_key_path=$(BOARD_AVB_RECOVERY_KEY_PATH)" >> $@
	$(hide) echo "avb_recovery_algorithm=$(BOARD_AVB_RECOVERY_ALGORITHM)" >> $@
	$(hide) echo "avb_recovery_rollback_index_location=$(BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_RECOVERY_KEY_PATH
ifneq (,$(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)))
	$(hide) echo "avb_custom_images_partition_list=$(BOARD_CUSTOMIMAGES_PARTITION_LIST)" >> $@
	$(hide) $(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
	    echo "avb_$(partition)_key_path=$(BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH)"  >> $@; \
	    echo "avb_$(partition)_algorithm=$(BOARD_AVB_$(call to-upper,$(partition))_ALGORITHM)"  >> $@; \
	    echo "avb_$(partition)_add_hashtree_footer_args=$(BOARD_AVB_$(call to-upper,$(partition))_ADD_HASHTREE_FOOTER_ARGS)"  >> $@; \
	    echo "avb_$(partition)_rollback_index_location=$(BOARD_AVB_$(call to-upper,$(partition))_ROLLBACK_INDEX_LOCATION)"  >> $@; \
	    echo "avb_$(partition)_partition_size=$(BOARD_AVB_$(call to-upper,$(partition))_PARTITION_SIZE)"  >> $@; \
	    echo "avb_$(partition)_image_list=$(foreach image,$(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST),$(notdir $(image)))" >> $@;)
endif # BOARD_CUSTOMIMAGES_PARTITION_LIST
ifneq (,$(strip $(BOARD_AVB_VBMETA_SYSTEM)))
	$(hide) echo "avb_vbmeta_system=$(BOARD_AVB_VBMETA_SYSTEM)" >> $@
	$(hide) echo "avb_vbmeta_system_args=$(BOARD_AVB_MAKE_VBMETA_SYSTEM_IMAGE_ARGS)" >> $@
	$(hide) echo "avb_vbmeta_system_key_path=$(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH)" >> $@
	$(hide) echo "avb_vbmeta_system_algorithm=$(BOARD_AVB_VBMETA_SYSTEM_ALGORITHM)" >> $@
	$(hide) echo "avb_vbmeta_system_rollback_index_location=$(BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VBMETA_SYSTEM
ifneq (,$(strip $(BOARD_AVB_VBMETA_VENDOR)))
	$(hide) echo "avb_vbmeta_vendor=$(BOARD_AVB_VBMETA_VENDOR)" >> $@
	$(hide) echo "avb_vbmeta_vendor_args=$(BOARD_AVB_MAKE_VBMETA_SYSTEM_IMAGE_ARGS)" >> $@
	$(hide) echo "avb_vbmeta_vendor_key_path=$(BOARD_AVB_VBMETA_VENDOR_KEY_PATH)" >> $@
	$(hide) echo "avb_vbmeta_vendor_algorithm=$(BOARD_AVB_VBMETA_VENDOR_ALGORITHM)" >> $@
	$(hide) echo "avb_vbmeta_vendor_rollback_index_location=$(BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VBMETA_VENDOR_KEY_PATH
endif # BOARD_AVB_ENABLE
ifdef BOARD_BPT_INPUT_FILES
	$(hide) echo "board_bpt_enable=true" >> $@
	$(hide) echo "board_bpt_make_table_args=$(BOARD_BPT_MAKE_TABLE_ARGS)" >> $@
	$(hide) echo "board_bpt_input_files=$(BOARD_BPT_INPUT_FILES)" >> $@
endif
ifdef BOARD_BPT_DISK_SIZE
	$(hide) echo "board_bpt_disk_size=$(BOARD_BPT_DISK_SIZE)" >> $@
endif
	$(call generate-userimage-prop-dictionary, $@)
ifeq ($(AB_OTA_UPDATER),true)
	@# Include the build type in META/misc_info.txt so the server can easily differentiate production builds.
	$(hide) echo "build_type=$(TARGET_BUILD_VARIANT)" >> $@
	$(hide) echo "ab_update=true" >> $@
endif
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
	$(hide) echo "allow_non_ab=true" >> $@
endif
ifdef BOARD_PREBUILT_DTBOIMAGE
	$(hide) echo "has_dtbo=true" >> $@
ifeq ($(BOARD_AVB_ENABLE),true)
	$(hide) echo "dtbo_size=$(BOARD_DTBOIMG_PARTITION_SIZE)" >> $@
	$(hide) echo "avb_dtbo_add_hash_footer_args=$(BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_DTBO_KEY_PATH
	$(hide) echo "avb_dtbo_key_path=$(BOARD_AVB_DTBO_KEY_PATH)" >> $@
	$(hide) echo "avb_dtbo_algorithm=$(BOARD_AVB_DTBO_ALGORITHM)" >> $@
	$(hide) echo "avb_dtbo_rollback_index_location=$(BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_DTBO_KEY_PATH
endif # BOARD_AVB_ENABLE
endif # BOARD_PREBUILT_DTBOIMAGE
	$(call dump-dynamic-partitions-info,$@)
	@# VINTF checks
ifeq ($(PRODUCT_ENFORCE_VINTF_MANIFEST),true)
	$(hide) echo "vintf_enforce=true" >> $@
endif
ifdef ODM_MANIFEST_SKUS
	$(hide) echo "vintf_odm_manifest_skus=$(ODM_MANIFEST_SKUS)" >> $@
endif
ifdef ODM_MANIFEST_FILES
	$(hide) echo "vintf_include_empty_odm_sku=true" >> $@
endif
ifdef DEVICE_MANIFEST_SKUS
	$(hide) echo "vintf_vendor_manifest_skus=$(DEVICE_MANIFEST_SKUS)" >> $@
endif
ifdef DEVICE_MANIFEST_FILE
	$(hide) echo "vintf_include_empty_vendor_sku=true" >> $@
endif
ifeq ($(BOARD_BOOTLOADER_IN_UPDATE_PACKAGE),true)
	$(hide) echo "bootloader_in_update_package=true" >> $@
endif
ifeq ($(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE),true)
	$(hide) echo "exclude_kernel_from_recovery_image=true" >> $@
endif

.PHONY: misc_info
misc_info: $(INSTALLED_MISC_INFO_TARGET)

droidcore: $(INSTALLED_MISC_INFO_TARGET)

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
ifeq (,$(filter address, $(SANITIZE_TARGET)))
built_ota_tools += \
    $(call intermediates-dir-for,EXECUTABLES,updater)/updater
endif

$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_OTA_TOOLS := $(built_ota_tools)

tool_extension := $(wildcard $(tool_extensions)/releasetools.py)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_TOOL_EXTENSION := $(tool_extension)

ifeq ($(AB_OTA_UPDATER),true)
updater_dep := system/update_engine/update_engine.conf
endif

# Build OTA tools if non-A/B is allowed
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
updater_dep := $(built_ota_tools)
endif

$(BUILT_TARGET_FILES_PACKAGE): $(updater_dep)

# If we are using recovery as boot, output recovery files to BOOT/.
# If we are moving recovery resources to vendor_boot, output recovery files to VENDOR_BOOT/.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := BOOT
else ifeq ($(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT),true)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := VENDOR_BOOT
else
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := RECOVERY
endif

ifeq ($(AB_OTA_UPDATER),true)
  ifdef OSRELEASED_DIRECTORY
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version
  endif

  # Not checking in board_config.mk, since AB_OTA_PARTITIONS may be updated in Android.mk (e.g. to
  # additionally include radio or bootloader partitions).
  ifeq ($(AB_OTA_PARTITIONS),)
    $(error AB_OTA_PARTITIONS must be defined when using AB_OTA_UPDATER)
  endif
endif

ifneq ($(AB_OTA_PARTITIONS),)
  ifneq ($(AB_OTA_UPDATER),true)
    $(error AB_OTA_UPDATER must be true when defining AB_OTA_PARTITIONS)
  endif
endif

# Run fs_config while creating the target files package
# $1: root directory
# $2: add prefix
define fs_config
(cd $(1); find . -type d | sed 's,$$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,$(2),' | $(HOST_OUT_EXECUTABLES)/fs_config -C -D $(TARGET_OUT) -S $(SELINUX_FC) -R "$(2)"
endef

# Filter out vendor from the list for AOSP targets.
# $(1): list
define filter-out-missing-vendor
$(if $(INSTALLED_VENDORIMAGE_TARGET),$(1),$(filter-out vendor,$(1)))
endef

# Information related to dynamic partitions and virtual A/B. This information
# is needed for building the super image (see dump-super-image-info) and
# building OTA packages.
# $(1): file
define dump-dynamic-partitions-info
  $(if $(filter true,$(PRODUCT_USE_DYNAMIC_PARTITIONS)), \
    echo "use_dynamic_partitions=true" >> $(1))
  $(if $(filter true,$(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)), \
    echo "dynamic_partition_retrofit=true" >> $(1))
  echo "lpmake=$(notdir $(LPMAKE))" >> $(1)
  $(if $(filter true,$(PRODUCT_BUILD_SUPER_PARTITION)), $(if $(BOARD_SUPER_PARTITION_SIZE), \
    echo "build_super_partition=true" >> $(1)))
  $(if $(filter true,$(BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE)), \
    echo "build_retrofit_dynamic_partitions_ota_package=true" >> $(1))
  echo "super_metadata_device=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)" >> $(1)
  $(if $(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
    echo "super_block_devices=$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)" >> $(1))
  $(foreach device,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
    echo "super_$(device)_device_size=$(BOARD_SUPER_PARTITION_$(call to-upper,$(device))_DEVICE_SIZE)" >> $(1);)
  $(if $(BOARD_SUPER_PARTITION_PARTITION_LIST), \
    echo "dynamic_partition_list=$(call filter-out-missing-vendor,$(BOARD_SUPER_PARTITION_PARTITION_LIST))" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_GROUPS),
    echo "super_partition_groups=$(BOARD_SUPER_PARTITION_GROUPS)" >> $(1))
  $(foreach group,$(BOARD_SUPER_PARTITION_GROUPS), \
    echo "super_$(group)_group_size=$(BOARD_$(call to-upper,$(group))_SIZE)" >> $(1); \
    $(if $(BOARD_$(call to-upper,$(group))_PARTITION_LIST), \
      echo "super_$(group)_partition_list=$(call filter-out-missing-vendor,$(BOARD_$(call to-upper,$(group))_PARTITION_LIST))" >> $(1);))
  $(if $(filter true,$(TARGET_USERIMAGES_SPARSE_EXT_DISABLED)), \
    echo "build_non_sparse_super_partition=true" >> $(1))
  $(if $(filter true,$(TARGET_USERIMAGES_SPARSE_F2FS_DISABLED)), \
    echo "build_non_sparse_super_partition=true" >> $(1))
  $(if $(filter true,$(BOARD_SUPER_IMAGE_IN_UPDATE_PACKAGE)), \
    echo "super_image_in_update_package=true" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_SIZE), \
    echo "super_partition_size=$(BOARD_SUPER_PARTITION_SIZE)" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_ALIGNMENT), \
    echo "super_partition_alignment=$(BOARD_SUPER_PARTITION_ALIGNMENT)" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_WARN_LIMIT), \
    echo "super_partition_warn_limit=$(BOARD_SUPER_PARTITION_WARN_LIMIT)" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_ERROR_LIMIT), \
    echo "super_partition_error_limit=$(BOARD_SUPER_PARTITION_ERROR_LIMIT)" >> $(1))
  $(if $(filter true,$(PRODUCT_VIRTUAL_AB_OTA)), \
    echo "virtual_ab=true" >> $(1))
  $(if $(filter true,$(PRODUCT_VIRTUAL_AB_OTA_RETROFIT)), \
    echo "virtual_ab_retrofit=true" >> $(1))
endef

# By conditionally including the dependency of the target files package on the
# full system image deps, we speed up builds that do not build the system
# image.
ifdef BUILDING_SYSTEM_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(FULL_SYSTEMIMAGE_DEPS)
endif

ifdef BUILDING_USERDATA_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_USERDATAIMAGE_FILES)
endif

ifdef BUILDING_SYSTEM_OTHER_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_SYSTEMOTHERIMAGE_FILES)
endif

ifdef BUILDING_VENDOR_BOOT_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_VENDOR_RAMDISK_FILES)
endif

ifdef BUILDING_RECOVERY_IMAGE
  # TODO(b/30414428): Can't depend on INTERNAL_RECOVERYIMAGE_FILES alone like other
  # BUILD_TARGET_FILES_PACKAGE dependencies because currently there're cp/rsync/rm
  # commands in build-recoveryimage-target, which would touch the files under
  # TARGET_RECOVERY_OUT and race with packaging target-files.zip.
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_BOOTIMAGE_TARGET)
  else
    $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_RECOVERYIMAGE_TARGET)
  endif
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_RECOVERYIMAGE_FILES)
endif

# Conditionally depend on the image files if the image is being built so the
# target-files.zip rule doesn't wait on the image creation rule, or the image
# if it is coming from a prebuilt.

ifdef BUILDING_VENDOR_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_VENDORIMAGE_FILES)
else ifdef BOARD_PREBUILT_VENDORIMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_VENDORIMAGE_TARGET)
endif

ifdef BUILDING_PRODUCT_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_PRODUCTIMAGE_FILES)
else ifdef BOARD_PREBUILT_PRODUCTIMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_PRODUCTIMAGE_TARGET)
endif

ifdef BUILDING_SYSTEM_EXT_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_SYSTEM_EXTIMAGE_FILES)
else ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)
endif

ifdef BUILDING_BOOT_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_RAMDISK_FILES)
else ifdef BOARD_PREBUILT_BOOTIMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_BOOTIMAGE_TARGET)
endif

ifdef BUILDING_ODM_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_ODMIMAGE_FILES)
else ifdef BOARD_PREBUILT_ODMIMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_ODMIMAGE_TARGET)
endif

ifdef BUILDING_VENDOR_DLKM_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_VENDOR_DLKMIMAGE_FILES)
else ifdef BOARD_PREBUILT_VENDOR_DLKIMMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)
endif

ifdef BUILDING_ODM_DLKM_IMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INTERNAL_ODM_DLKMIMAGE_FILES)
else ifdef BOARD_ODM_VENDOR_DLKIMMAGE
  $(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_ODM_DLKMIMAGE_TARGET)
endif

ifeq ($(BUILD_QEMU_IMAGES),true)
  MK_VBMETA_BOOT_KERNEL_CMDLINE_SH := device/generic/goldfish/tools/mk_vbmeta_boot_params.sh
  $(BUILT_TARGET_FILES_PACKAGE): $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH)
endif

ifdef BOARD_PREBUILT_BOOTLOADER
$(BUILT_TARGET_FILES_PACKAGE): $(INSTALLED_BOOTLOADER_MODULE)
droidcore: $(INSTALLED_BOOTLOADER_MODULE)
endif

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_PACKAGE): \
	    $(INSTALLED_RADIOIMAGE_TARGET) \
	    $(INSTALLED_RECOVERYIMAGE_TARGET) \
	    $(INSTALLED_CACHEIMAGE_TARGET) \
	    $(INSTALLED_DTBOIMAGE_TARGET) \
	    $(INSTALLED_CUSTOMIMAGES_TARGET) \
	    $(INSTALLED_ANDROID_INFO_TXT_TARGET) \
	    $(INSTALLED_KERNEL_TARGET) \
	    $(INSTALLED_RAMDISK_TARGET) \
	    $(INSTALLED_DTBIMAGE_TARGET) \
	    $(INSTALLED_2NDBOOTLOADER_TARGET) \
	    $(BOARD_PREBUILT_DTBOIMAGE) \
	    $(BOARD_PREBUILT_RECOVERY_DTBOIMAGE) \
	    $(BOARD_RECOVERY_ACPIO) \
	    $(PRODUCT_SYSTEM_BASE_FS_PATH) \
	    $(PRODUCT_VENDOR_BASE_FS_PATH) \
	    $(PRODUCT_PRODUCT_BASE_FS_PATH) \
	    $(PRODUCT_SYSTEM_EXT_BASE_FS_PATH) \
	    $(PRODUCT_ODM_BASE_FS_PATH) \
	    $(PRODUCT_VENDOR_DLKM_BASE_FS_PATH) \
	    $(PRODUCT_ODM_DLKM_BASE_FS_PATH) \
	    $(LPMAKE) \
	    $(SELINUX_FC) \
	    $(INSTALLED_MISC_INFO_TARGET) \
	    $(APKCERTS_FILE) \
	    $(SOONG_APEX_KEYS_FILE) \
	    $(SOONG_ZIP) \
	    $(HOST_OUT_EXECUTABLES)/fs_config \
	    $(ADD_IMG_TO_TARGET_FILES) \
	    $(MAKE_RECOVERY_PATCH) \
	    $(BUILT_KERNEL_CONFIGS_FILE) \
	    $(BUILT_KERNEL_VERSION_FILE) \
	    | $(ACP)
	@echo "Package target files: $@"
	$(hide) rm -rf $@ $@.list $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT))$(filter true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)))
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/$(PRIVATE_RECOVERY_OUT)
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/$(PRIVATE_RECOVERY_OUT)/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
ifneq (,$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))
	cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/
else ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
	cp $(firstword $(INSTALLED_KERNEL_TARGET)) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/kernel
endif
endif
ifeq (truetrue,$(strip $(BUILDING_VENDOR_BOOT_IMAGE))$(strip $(AB_OTA_UPDATER)))
ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
	echo "$(GENERIC_KERNEL_CMDLINE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/cmdline
endif # BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE != true
else # not (BUILDING_VENDOR_BOOT_IMAGE and AB_OTA_UPDATER)
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	cp $(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/second
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
ifdef BOARD_PREBUILT_RECOVERY_DTBOIMAGE
	cp $(BOARD_PREBUILT_RECOVERY_DTBOIMAGE) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/recovery_dtbo
else
	cp $(BOARD_PREBUILT_DTBOIMAGE) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/recovery_dtbo
endif
endif # BOARD_INCLUDE_RECOVERY_DTBO
ifdef BOARD_INCLUDE_RECOVERY_ACPIO
	cp $(BOARD_RECOVERY_ACPIO) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/recovery_acpio
endif
ifdef INSTALLED_DTBIMAGE_TARGET
	cp $(INSTALLED_DTBIMAGE_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/dtb
endif
ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
ifdef INTERNAL_KERNEL_CMDLINE
	echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/cmdline
endif # INTERNAL_KERNEL_CMDLINE != ""
endif # BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE != true
ifdef BOARD_KERNEL_BASE
	echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/pagesize
endif
endif # not (BUILDING_VENDOR_BOOT_IMAGE and AB_OTA_UPDATER)
endif # INSTALLED_RECOVERYIMAGE_TARGET defined or BOARD_USES_RECOVERY_AS_BOOT is true
	@# Components of the boot image
	$(hide) mkdir -p $(zip_root)/BOOT
	$(hide) mkdir -p $(zip_root)/ROOT
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_ROOT_OUT),$(zip_root)/ROOT)
	@# If we are using recovery as boot, this is already done when processing recovery.
ifneq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_RAMDISK_OUT),$(zip_root)/BOOT/RAMDISK)
endif
ifdef INSTALLED_KERNEL_TARGET
	$(hide) cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/BOOT/
endif
ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
	echo "$(GENERIC_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
else ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
	echo "$(GENERIC_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
else # INSTALLED_VENDOR_BOOTIMAGE_TARGET == "" && BOARD_USES_GENERIC_KERNEL_IMAGE != true
	echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	cp $(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/BOOT/second
endif
ifdef INSTALLED_DTBIMAGE_TARGET
	cp $(INSTALLED_DTBIMAGE_TARGET) $(zip_root)/BOOT/dtb
endif
ifdef BOARD_KERNEL_BASE
	echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/BOOT/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/BOOT/pagesize
endif
endif # INSTALLED_VENDOR_BOOTIMAGE_TARGET == "" && BOARD_USES_GENERIC_KERNEL_IMAGE != true
endif # BOARD_USES_RECOVERY_AS_BOOT not true
	$(hide) $(foreach t,$(INSTALLED_RADIOIMAGE_TARGET),\
	            mkdir -p $(zip_root)/RADIO; \
	            cp $(t) $(zip_root)/RADIO/$(notdir $(t));)
ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
	mkdir -p $(zip_root)/VENDOR_BOOT
	$(call package_files-copy-root, \
	    $(TARGET_VENDOR_RAMDISK_OUT),$(zip_root)/VENDOR_BOOT/RAMDISK)
ifdef INSTALLED_DTBIMAGE_TARGET
	cp $(INSTALLED_DTBIMAGE_TARGET) $(zip_root)/VENDOR_BOOT/dtb
endif
ifdef BOARD_KERNEL_BASE
	echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/VENDOR_BOOT/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/VENDOR_BOOT/pagesize
endif
	echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/VENDOR_BOOT/vendor_cmdline
endif # INSTALLED_VENDOR_BOOTIMAGE_TARGET
ifdef BUILDING_SYSTEM_IMAGE
	@# Contents of the system image
	$(hide) $(call package_files-copy-root, \
	    $(SYSTEMIMAGE_SOURCE_DIR),$(zip_root)/SYSTEM)
endif
ifdef BUILDING_USERDATA_IMAGE
	@# Contents of the data image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_DATA),$(zip_root)/DATA)
endif
ifdef BUILDING_VENDOR_IMAGE
	@# Contents of the vendor image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_VENDOR),$(zip_root)/VENDOR)
endif
ifdef BUILDING_PRODUCT_IMAGE
	@# Contents of the product image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_PRODUCT),$(zip_root)/PRODUCT)
endif
ifdef BUILDING_SYSTEM_EXT_IMAGE
	@# Contents of the system_ext image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_SYSTEM_EXT),$(zip_root)/SYSTEM_EXT)
endif
ifdef BUILDING_ODM_IMAGE
	@# Contents of the odm image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_ODM),$(zip_root)/ODM)
endif
ifdef BUILDING_VENDOR_DLKM_IMAGE
	@# Contents of the vendor_dlkm image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_VENDOR_DLKM),$(zip_root)/VENDOR_DLKM)
endif
ifdef BUILDING_ODM_DLKM_IMAGE
	@# Contents of the odm_dlkm image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_ODM_DLKM),$(zip_root)/ODM_DLKM)
endif
ifdef BUILDING_SYSTEM_OTHER_IMAGE
	@# Contents of the system_other image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_SYSTEM_OTHER),$(zip_root)/SYSTEM_OTHER)
endif
	@# Extra contents of the OTA package
	$(hide) mkdir -p $(zip_root)/OTA
	$(hide) cp $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(zip_root)/OTA/
ifdef BUILDING_RAMDISK_IMAGE
ifeq (true,$(BOARD_IMG_USE_RAMDISK))
	@# Contents of the ramdisk image
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_RAMDISK_TARGET) $(zip_root)/IMAGES/
endif
endif
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
ifneq ($(built_ota_tools),)
	$(hide) mkdir -p $(zip_root)/OTA/bin
	$(hide) cp $(PRIVATE_OTA_TOOLS) $(zip_root)/OTA/bin/
endif
endif
	@# Files that do not end up in any images, but are necessary to
	@# build them.
	$(hide) mkdir -p $(zip_root)/META
	$(hide) cp $(APKCERTS_FILE) $(zip_root)/META/apkcerts.txt
	$(hide) cp $(SOONG_APEX_KEYS_FILE) $(zip_root)/META/apexkeys.txt
ifneq ($(tool_extension),)
	$(hide) cp $(PRIVATE_TOOL_EXTENSION) $(zip_root)/META/
endif
	$(hide) echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) cp $(SELINUX_FC) $(zip_root)/META/file_contexts.bin
	$(hide) cp $(INSTALLED_MISC_INFO_TARGET) $(zip_root)/META/misc_info.txt
ifneq ($(PRODUCT_SYSTEM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_SYSTEM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_SYSTEM_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_VENDOR_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_VENDOR_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_VENDOR_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_PRODUCT_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_PRODUCT_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_PRODUCT_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_SYSTEM_EXT_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_SYSTEM_EXT_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_SYSTEM_EXT_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_ODM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_ODM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_ODM_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_VENDOR_DLKM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_VENDOR_DLKM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_VENDOR_DLKM_BASE_FS_PATH))
endif
ifneq ($(PRODUCT_ODM_DLKM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_ODM_DLKM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_ODM_DLKM_BASE_FS_PATH))
endif
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    $(MAKE_RECOVERY_PATCH) $(zip_root) $(zip_root)
endif
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
ifdef OSRELEASED_DIRECTORY
	$(hide) cp $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id $(zip_root)/META/product_id.txt
	$(hide) cp $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version $(zip_root)/META/product_version.txt
	$(hide) cp $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version $(zip_root)/META/system_version.txt
endif
endif
ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
	@# If breakpad symbols have been generated, add them to the zip.
	$(hide) cp -R $(TARGET_OUT_BREAKPAD) $(zip_root)/BREAKPAD
endif
ifdef BOARD_PREBUILT_VENDORIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_VENDORIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_PRODUCTIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_PRODUCTIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_BOOTIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_BOOTIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_ODMIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_ODMIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_ODM_DLKMIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_DTBOIMAGE
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_DTBOIMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif # BOARD_PREBUILT_DTBOIMAGE
ifdef BOARD_PREBUILT_BOOTLOADER
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_BOOTLOADER_MODULE) $(zip_root)/IMAGES/
endif
ifneq ($(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)),)
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) $(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
	    $(foreach image,$(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST),cp $(image) $(zip_root)/PREBUILT_IMAGES/;))
endif # BOARD_CUSTOMIMAGES_PARTITION_LIST
	@# The radio images in BOARD_PACK_RADIOIMAGES will be additionally copied from RADIO/ into
	@# IMAGES/, which then will be added into <product>-img.zip. Such images must be listed in
	@# INSTALLED_RADIOIMAGE_TARGET.
	$(hide) $(foreach part,$(BOARD_PACK_RADIOIMAGES), \
	    echo $(part) >> $(zip_root)/META/pack_radioimages.txt;)
	@# Run fs_config on all the system, vendor, boot ramdisk,
	@# and recovery ramdisk files in the zip, and save the output
ifdef BUILDING_SYSTEM_IMAGE
	$(hide) $(call fs_config,$(zip_root)/SYSTEM,system/) > $(zip_root)/META/filesystem_config.txt
endif
ifdef BUILDING_VENDOR_IMAGE
	$(hide) $(call fs_config,$(zip_root)/VENDOR,vendor/) > $(zip_root)/META/vendor_filesystem_config.txt
endif
ifdef BUILDING_PRODUCT_IMAGE
	$(hide) $(call fs_config,$(zip_root)/PRODUCT,product/) > $(zip_root)/META/product_filesystem_config.txt
endif
ifdef BUILDING_SYSTEM_EXT_IMAGE
	$(hide) $(call fs_config,$(zip_root)/SYSTEM_EXT,system_ext/) > $(zip_root)/META/system_ext_filesystem_config.txt
endif
ifdef BUILDING_ODM_IMAGE
	$(hide) $(call fs_config,$(zip_root)/ODM,odm/) > $(zip_root)/META/odm_filesystem_config.txt
endif
ifdef BUILDING_VENDOR_DLKM_IMAGE
	$(hide) $(call fs_config,$(zip_root)/VENDOR_DLKM,vendor_dlkm/) > $(zip_root)/META/vendor_dlkm_filesystem_config.txt
endif
ifdef BUILDING_ODM_DLKM_IMAGE
	$(hide) $(call fs_config,$(zip_root)/ODM_DLKM,odm_dlkm/) > $(zip_root)/META/odm_dlkm_filesystem_config.txt
endif
	@# ROOT always contains the files for the root under normal boot.
	$(hide) $(call fs_config,$(zip_root)/ROOT,) > $(zip_root)/META/root_filesystem_config.txt
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
	@# BOOT/RAMDISK exists and contains the ramdisk for recovery if using BOARD_USES_RECOVERY_AS_BOOT.
	$(hide) $(call fs_config,$(zip_root)/BOOT/RAMDISK,) > $(zip_root)/META/boot_filesystem_config.txt
endif
ifneq ($(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
	$(call fs_config,$(zip_root)/VENDOR_BOOT/RAMDISK,) > $(zip_root)/META/vendor_boot_filesystem_config.txt
endif
ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	@# BOOT/RAMDISK also exists and contains the first stage ramdisk if not using BOARD_BUILD_SYSTEM_ROOT_IMAGE.
	$(hide) $(call fs_config,$(zip_root)/BOOT/RAMDISK,) > $(zip_root)/META/boot_filesystem_config.txt
endif
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) $(call fs_config,$(zip_root)/RECOVERY/RAMDISK,) > $(zip_root)/META/recovery_filesystem_config.txt
endif
ifdef BUILDING_SYSTEM_OTHER_IMAGE
	$(hide) $(call fs_config,$(zip_root)/SYSTEM_OTHER,system/) > $(zip_root)/META/system_other_filesystem_config.txt
endif
	@# Metadata for compatibility verification.
ifdef BUILT_KERNEL_CONFIGS_FILE
	$(hide) cp $(BUILT_KERNEL_CONFIGS_FILE) $(zip_root)/META/kernel_configs.txt
endif
ifdef BUILT_KERNEL_VERSION_FILE
	$(hide) cp $(BUILT_KERNEL_VERSION_FILE) $(zip_root)/META/kernel_version.txt
endif
	rm -rf $(zip_root)/META/dynamic_partitions_info.txt
ifeq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))
	$(call dump-dynamic-partitions-info, $(zip_root)/META/dynamic_partitions_info.txt)
endif
	PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    $(ADD_IMG_TO_TARGET_FILES) -a -v -p $(HOST_OUT) $(zip_root)
ifeq ($(BUILD_QEMU_IMAGES),true)
	$(hide) AVBTOOL=$(AVBTOOL) $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH) $(zip_root)/IMAGES/vbmeta.img \
	    $(zip_root)/IMAGES/system.img $(zip_root)/IMAGES/VerifiedBootParams.textproto
endif
	@# Zip everything up, preserving symlinks and placing META/ files first to
	@# help early validation of the .zip file while uploading it.
	$(hide) find $(zip_root)/META | sort >$@.list
	$(hide) find $(zip_root) -path $(zip_root)/META -prune -o -print | sort >>$@.list
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(zip_root) -l $@.list

.PHONY: target-files-package
target-files-package: $(BUILT_TARGET_FILES_PACKAGE)

$(call dist-for-goals, target-files-package, $(BUILT_TARGET_FILES_PACKAGE))

# -----------------------------------------------------------------
# NDK Sysroot Package
NDK_SYSROOT_TARGET := $(PRODUCT_OUT)/ndk_sysroot.tar.bz2
$(NDK_SYSROOT_TARGET): $(SOONG_OUT_DIR)/ndk.timestamp
	@echo Package NDK sysroot...
	$(hide) tar cjf $@ -C $(SOONG_OUT_DIR) ndk

$(call dist-for-goals,sdk,$(NDK_SYSROOT_TARGET))

ifeq ($(build_ota_package),true)
# -----------------------------------------------------------------
# OTA update package

# $(1): output file
# $(2): additional args
define build-ota-package-target
PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
    $(OTA_FROM_TARGET_FILES) \
        --verbose \
        --extracted_input_target_files $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) \
        --path $(HOST_OUT) \
        $(if $(OEM_OTA_CONFIG), --oem_settings $(OEM_OTA_CONFIG)) \
        $(2) \
        $(BUILT_TARGET_FILES_PACKAGE) $(1)
endef

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-ota-$(FILE_NAME_TAG)

INTERNAL_OTA_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip
INTERNAL_OTA_METADATA := $(PRODUCT_OUT)/ota_metadata

$(INTERNAL_OTA_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(INTERNAL_OTA_PACKAGE_TARGET): .KATI_IMPLICIT_OUTPUTS := $(INTERNAL_OTA_METADATA)
$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES)
	@echo "Package OTA: $@"
	$(call build-ota-package-target,$@,-k $(KEY_CERT_PAIR) --output_metadata_path $(INTERNAL_OTA_METADATA))

.PHONY: otapackage
otapackage: $(INTERNAL_OTA_PACKAGE_TARGET)

ifeq ($(BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE),true)
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-ota-retrofit-$(FILE_NAME_TAG)

INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip
$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET): \
    $(BUILT_TARGET_FILES_PACKAGE) \
    $(OTA_FROM_TARGET_FILES) \
    $(INTERNAL_OTATOOLS_FILES)
	@echo "Package OTA (retrofit dynamic partitions): $@"
	$(call build-ota-package-target,$@,-k $(KEY_CERT_PAIR) --retrofit_dynamic_partitions)

.PHONY: otardppackage

otapackage otardppackage: $(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET)

endif # BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE

endif    # build_ota_package

# -----------------------------------------------------------------
# A zip of the appcompat directory containing logs
APPCOMPAT_ZIP := $(PRODUCT_OUT)/appcompat.zip
# For apps_only build we'll establish the dependency later in build/make/core/main.mk.
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(APPCOMPAT_ZIP): $(FULL_SYSTEMIMAGE_DEPS) \
	    $(INTERNAL_RAMDISK_FILES) \
	    $(INTERNAL_USERDATAIMAGE_FILES) \
	    $(INTERNAL_VENDORIMAGE_FILES) \
	    $(INTERNAL_PRODUCTIMAGE_FILES) \
	    $(INTERNAL_SYSTEM_EXTIMAGE_FILES)
endif
$(APPCOMPAT_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,appcompat)/filelist
$(APPCOMPAT_ZIP): $(SOONG_ZIP)
	@echo "appcompat logs: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(PRODUCT_OUT)/appcompat $(dir $(PRIVATE_LIST_FILE))
	$(hide) find $(PRODUCT_OUT)/appcompat | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(PRODUCT_OUT)/appcompat -l $(PRIVATE_LIST_FILE)

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
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(SYMBOLS_ZIP): $(FULL_SYSTEMIMAGE_DEPS) \
	    $(INTERNAL_RAMDISK_FILES) \
	    $(INTERNAL_USERDATAIMAGE_FILES) \
	    $(INTERNAL_VENDORIMAGE_FILES) \
	    $(INTERNAL_PRODUCTIMAGE_FILES) \
	    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
	    $(INTERNAL_ODMIMAGE_FILES) \
	    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
	    $(INTERNAL_ODM_DLKMIMAGE_FILES) \
	    $(updater_dep)
endif
$(SYMBOLS_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,symbols)/filelist
$(SYMBOLS_ZIP): $(SOONG_ZIP)
	@echo "Package symbols: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_UNSTRIPPED) $(dir $(PRIVATE_LIST_FILE))
	$(hide) find -L $(TARGET_OUT_UNSTRIPPED) -type f | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) --ignore_missing_files -d -o $@ -C $(OUT_DIR)/.. -l $(PRIVATE_LIST_FILE)
# -----------------------------------------------------------------
# A zip of the coverage directory.
#
name := gcov-report-files-all
ifeq ($(TARGET_BUILD_TYPE),debug)
name := $(name)_debug
endif
COVERAGE_ZIP := $(PRODUCT_OUT)/$(name).zip
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(COVERAGE_ZIP): $(FULL_SYSTEMIMAGE_DEPS) \
	    $(INTERNAL_RAMDISK_FILES) \
	    $(INTERNAL_USERDATAIMAGE_FILES) \
	    $(INTERNAL_VENDORIMAGE_FILES) \
	    $(INTERNAL_PRODUCTIMAGE_FILES) \
	    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
	    $(INTERNAL_ODMIMAGE_FILES) \
	    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
	    $(INTERNAL_ODM_DLKMIMAGE_FILES)
endif
$(COVERAGE_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,coverage)/filelist
$(COVERAGE_ZIP): $(SOONG_ZIP)
	@echo "Package coverage: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_COVERAGE) $(dir $(PRIVATE_LIST_FILE))
	$(hide) find $(TARGET_OUT_COVERAGE) | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(TARGET_OUT_COVERAGE) -l $(PRIVATE_LIST_FILE)

#------------------------------------------------------------------
# Export the LLVM profile data tool and dependencies for Clang coverage processing
#
ifeq (true,$(CLANG_COVERAGE))
  LLVM_PROFDATA := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/bin/llvm-profdata
  LIBCXX := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/lib64/libc++.so.1
  PROFDATA_ZIP := $(PRODUCT_OUT)/llvm-profdata.zip
  $(PROFDATA_ZIP): $(SOONG_ZIP)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION) -f $(LLVM_PROFDATA) -f $(LIBCXX)

  $(call dist-for-goals,droidcore apps_only,$(PROFDATA_ZIP))
endif

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
$(APPS_ZIP): $(FULL_SYSTEMIMAGE_DEPS)
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
	find $(TARGET_COMMON_OUT_ROOT) $(HOST_COMMON_OUT_ROOT) -name "jacoco-report-classes.jar" -o -name "proguard_usage.zip" 2>/dev/null | sort > $@.list
	$(SOONG_ZIP) -o $@ -L 0 -C $(OUT_DIR) -P out -l $@.list

endif # EMMA_INSTRUMENT=true


#------------------------------------------------------------------
# A zip of Proguard obfuscation dictionary files.
#
PROGUARD_DICT_ZIP := $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-dict-$(FILE_NAME_TAG).zip
# For apps_only build we'll establish the dependency later in build/make/core/main.mk.
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(PROGUARD_DICT_ZIP): \
    $(FULL_SYSTEMIMAGE_DEPS) \
    $(INTERNAL_RAMDISK_FILES) \
    $(INTERNAL_USERDATAIMAGE_FILES) \
    $(INTERNAL_VENDORIMAGE_FILES) \
    $(INTERNAL_PRODUCTIMAGE_FILES) \
    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
    $(INTERNAL_ODMIMAGE_FILES) \
    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
    $(INTERNAL_ODM_DLKMIMAGE_FILES) \
    $(updater_dep)
endif
$(PROGUARD_DICT_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,proguard)/filelist
$(PROGUARD_DICT_ZIP): $(SOONG_ZIP)
	@echo "Packaging Proguard obfuscation dictionary files."
	mkdir -p $(dir $@) $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS $(dir $(PRIVATE_LIST_FILE))
	find $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS -name proguard_dictionary | \
	    sed -e 's/\(.*\)\/proguard_dictionary/\0\n\1\/classes.jar/' > $(PRIVATE_LIST_FILE)
	$(SOONG_ZIP) --ignore_missing_files -d -o $@ -C $(OUT_DIR)/.. -l $(PRIVATE_LIST_FILE)

#------------------------------------------------------------------
# A zip of Proguard usage files.
#
PROGUARD_USAGE_ZIP := $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-usage-$(FILE_NAME_TAG).zip
# For apps_only build we'll establish the dependency later in build/make/core/main.mk.
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(PROGUARD_USAGE_ZIP): \
    $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(INSTALLED_BOOTIMAGE_TARGET) \
    $(INSTALLED_USERDATAIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
    $(INSTALLED_ODMIMAGE_TARGET) \
    $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) \
    $(INSTALLED_ODM_DLKMIMAGE_TARGET) \
    $(updater_dep)
endif
$(PROGUARD_USAGE_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,proguard_usage)/filelist
$(PROGUARD_USAGE_ZIP): $(MERGE_ZIPS)
	@echo "Packaging Proguard usage files."
	mkdir -p $(dir $@) $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS $(dir $(PRIVATE_LIST_FILE))
	find $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS -name proguard_usage.zip > $(PRIVATE_LIST_FILE)
	$(MERGE_ZIPS) $@ @$(PRIVATE_LIST_FILE)

ifeq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))

# Dump variables used by build_super_image.py (for building super.img and super_empty.img).
# $(1): output file
define dump-super-image-info
  $(call dump-dynamic-partitions-info,$(1))
  $(if $(filter true,$(AB_OTA_UPDATER)), \
    echo "ab_update=true" >> $(1))
endef

endif # PRODUCT_USE_DYNAMIC_PARTITIONS

# -----------------------------------------------------------------
# super partition image (dist)

ifeq (true,$(PRODUCT_BUILD_SUPER_PARTITION))

# BOARD_SUPER_PARTITION_SIZE must be defined to build super image.
ifneq ($(BOARD_SUPER_PARTITION_SIZE),)

ifneq (true,$(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS))

# For real devices and for dist builds, build super image from target files to an intermediate directory.
INTERNAL_SUPERIMAGE_DIST_TARGET := $(call intermediates-dir-for,PACKAGING,super.img)/super.img
$(INTERNAL_SUPERIMAGE_DIST_TARGET): extracted_input_target_files := $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE))
$(INTERNAL_SUPERIMAGE_DIST_TARGET): $(LPMAKE) $(BUILT_TARGET_FILES_PACKAGE) $(BUILD_SUPER_IMAGE)
	$(call pretty,"Target super fs image from target files: $@")
	PATH=$(dir $(LPMAKE)):$$PATH \
	    $(BUILD_SUPER_IMAGE) -v $(extracted_input_target_files) $@

# Skip packing it in dist package because it is in update package.
ifneq (true,$(BOARD_SUPER_IMAGE_IN_UPDATE_PACKAGE))
$(call dist-for-goals,dist_files,$(INTERNAL_SUPERIMAGE_DIST_TARGET))
endif

.PHONY: superimage_dist
superimage_dist: $(INTERNAL_SUPERIMAGE_DIST_TARGET)

endif # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS != "true"
endif # BOARD_SUPER_PARTITION_SIZE != ""
endif # PRODUCT_BUILD_SUPER_PARTITION == "true"

# -----------------------------------------------------------------
# super partition image for development

ifeq (true,$(PRODUCT_BUILD_SUPER_PARTITION))
ifneq ($(BOARD_SUPER_PARTITION_SIZE),)
ifneq (true,$(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS))

# Build super.img by using $(INSTALLED_*IMAGE_TARGET) to $(1)
# $(1): built image path
# $(2): misc_info.txt path; its contents should match expectation of build_super_image.py
define build-superimage-target
  mkdir -p $(dir $(2))
  rm -rf $(2)
  $(call dump-super-image-info,$(2))
  $(foreach p,$(BOARD_SUPER_PARTITION_PARTITION_LIST), \
    echo "$(p)_image=$(INSTALLED_$(call to-upper,$(p))IMAGE_TARGET)" >> $(2);)
  $(if $(BUILDING_SYSTEM_OTHER_IMAGE), $(if $(filter system,$(BOARD_SUPER_PARTITION_PARTITION_LIST)), \
    echo "system_other_image=$(INSTALLED_SYSTEMOTHERIMAGE_TARGET)" >> $(2);))
  mkdir -p $(dir $(1))
  PATH=$(dir $(LPMAKE)):$$PATH \
    $(BUILD_SUPER_IMAGE) -v $(2) $(1)
endef

INSTALLED_SUPERIMAGE_TARGET := $(PRODUCT_OUT)/super.img
INSTALLED_SUPERIMAGE_DEPENDENCIES := $(LPMAKE) $(BUILD_SUPER_IMAGE) \
    $(foreach p, $(BOARD_SUPER_PARTITION_PARTITION_LIST), $(INSTALLED_$(call to-upper,$(p))IMAGE_TARGET))

ifdef BUILDING_SYSTEM_OTHER_IMAGE
ifneq ($(filter system,$(BOARD_SUPER_PARTITION_PARTITION_LIST)),)
INSTALLED_SUPERIMAGE_DEPENDENCIES += $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)
endif
endif

# If BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT is set, super.img is built from images in the
# $(PRODUCT_OUT) directory, and is built to $(PRODUCT_OUT)/super.img. Also, it will
# be built for non-dist builds. This is useful for devices that uses super.img directly, e.g.
# virtual devices.
ifeq (true,$(BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT))
$(INSTALLED_SUPERIMAGE_TARGET): $(INSTALLED_SUPERIMAGE_DEPENDENCIES)
	$(call pretty,"Target super fs image for debug: $@")
	$(call build-superimage-target,$(INSTALLED_SUPERIMAGE_TARGET),\
          $(call intermediates-dir-for,PACKAGING,superimage_debug)/misc_info.txt)

droidcore: $(INSTALLED_SUPERIMAGE_TARGET)

# For devices that uses super image directly, the superimage target points to the file in $(PRODUCT_OUT).
.PHONY: superimage
superimage: $(INSTALLED_SUPERIMAGE_TARGET)

$(call dist-for-goals,dist_files,$(INSTALLED_MISC_INFO_TARGET):super_misc_info.txt)
endif # BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT

# Build $(PRODUCT_OUT)/super.img without dependencies.
.PHONY: superimage-nodeps supernod
superimage-nodeps supernod: intermediates :=
superimage-nodeps supernod: | $(INSTALLED_SUPERIMAGE_DEPENDENCIES)
	$(call pretty,"make $(INSTALLED_SUPERIMAGE_TARGET): ignoring dependencies")
	$(call build-superimage-target,$(INSTALLED_SUPERIMAGE_TARGET),\
	  $(call intermediates-dir-for,PACKAGING,superimage-nodeps)/misc_info.txt)

endif # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS != "true"
endif # BOARD_SUPER_PARTITION_SIZE != ""
endif # PRODUCT_BUILD_SUPER_PARTITION == "true"

# -----------------------------------------------------------------
# super empty image

ifeq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))
ifneq ($(BOARD_SUPER_PARTITION_SIZE),)

INSTALLED_SUPERIMAGE_EMPTY_TARGET := $(PRODUCT_OUT)/super_empty.img
$(INSTALLED_SUPERIMAGE_EMPTY_TARGET): intermediates := $(call intermediates-dir-for,PACKAGING,super_empty)
$(INSTALLED_SUPERIMAGE_EMPTY_TARGET): $(LPMAKE) $(BUILD_SUPER_IMAGE)
	$(call pretty,"Target empty super fs image: $@")
	mkdir -p $(intermediates)
	rm -rf $(intermediates)/misc_info.txt
	$(call dump-super-image-info,$(intermediates)/misc_info.txt)
	PATH=$(dir $(LPMAKE)):$$PATH \
	    $(BUILD_SUPER_IMAGE) -v $(intermediates)/misc_info.txt $@

$(call dist-for-goals,dist_files,$(INSTALLED_SUPERIMAGE_EMPTY_TARGET))

endif # BOARD_SUPER_PARTITION_SIZE != ""
endif # PRODUCT_USE_DYNAMIC_PARTITIONS == "true"


# -----------------------------------------------------------------
# The update package

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-img-$(FILE_NAME_TAG)

INTERNAL_UPDATE_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_UPDATE_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(IMG_FROM_TARGET_FILES)
	$(call pretty,"Package: $@")
	PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$(dir $(ZIP2ZIP)):$$PATH \
	    $(IMG_FROM_TARGET_FILES) \
	        --additional IMAGES/VerifiedBootParams.textproto:VerifiedBootParams.textproto \
	        $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: updatepackage
updatepackage: $(INTERNAL_UPDATE_PACKAGE_TARGET)
$(call dist-for-goals,updatepackage,$(INTERNAL_UPDATE_PACKAGE_TARGET))


# -----------------------------------------------------------------
# dalvik something
.PHONY: dalvikfiles
dalvikfiles: $(INTERNAL_DALVIK_MODULES)

ifeq ($(BUILD_QEMU_IMAGES),true)
MK_QEMU_IMAGE_SH := device/generic/goldfish/tools/mk_qemu_image.sh
MK_COMBINE_QEMU_IMAGE := $(HOST_OUT_EXECUTABLES)/mk_combined_img
SGDISK_HOST := $(HOST_OUT_EXECUTABLES)/sgdisk

ifdef INSTALLED_SYSTEMIMAGE_TARGET
INSTALLED_QEMU_SYSTEMIMAGE := $(PRODUCT_OUT)/system-qemu.img
INSTALLED_SYSTEM_QEMU_CONFIG := $(PRODUCT_OUT)/system-qemu-config.txt
$(INSTALLED_SYSTEM_QEMU_CONFIG): $(INSTALLED_SUPERIMAGE_TARGET) $(INSTALLED_VBMETAIMAGE_TARGET)
	@echo "$(PRODUCT_OUT)/vbmeta.img vbmeta 1" > $@
	@echo "$(INSTALLED_SUPERIMAGE_TARGET) super 2" >> $@
$(INSTALLED_QEMU_SYSTEMIMAGE): $(INSTALLED_VBMETAIMAGE_TARGET) $(MK_COMBINE_QEMU_IMAGE) $(SGDISK_HOST) $(SIMG2IMG) \
    $(INSTALLED_SUPERIMAGE_TARGET) $(INSTALLED_SYSTEM_QEMU_CONFIG)
	@echo Create system-qemu.img now
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); \
     $(MK_COMBINE_QEMU_IMAGE) -i $(INSTALLED_SYSTEM_QEMU_CONFIG) -o $@)

systemimage: $(INSTALLED_QEMU_SYSTEMIMAGE)
droidcore: $(INSTALLED_QEMU_SYSTEMIMAGE)
endif
ifdef INSTALLED_VENDORIMAGE_TARGET
INSTALLED_QEMU_VENDORIMAGE := $(PRODUCT_OUT)/vendor-qemu.img
$(INSTALLED_QEMU_VENDORIMAGE): $(INSTALLED_VENDORIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create vendor-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_VENDORIMAGE_TARGET))

vendorimage: $(INSTALLED_QEMU_VENDORIMAGE)
droidcore: $(INSTALLED_QEMU_VENDORIMAGE)
endif

ifdef INSTALLED_RAMDISK_TARGET
ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
ifdef INTERNAL_VENDOR_RAMDISK_TARGET
INSTALLED_QEMU_RAMDISKIMAGE := $(PRODUCT_OUT)/ramdisk-qemu.img
$(INSTALLED_QEMU_RAMDISKIMAGE): $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_RAMDISK_TARGET)
	@echo Create ramdisk-qemu.img
	(cat $(INSTALLED_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_TARGET) > $(INSTALLED_QEMU_RAMDISKIMAGE))

droidcore: $(INSTALLED_QEMU_RAMDISKIMAGE)
endif
endif
endif

ifdef INSTALLED_PRODUCTIMAGE_TARGET
INSTALLED_QEMU_PRODUCTIMAGE := $(PRODUCT_OUT)/product-qemu.img
$(INSTALLED_QEMU_PRODUCTIMAGE): $(INSTALLED_PRODUCTIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create product-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_PRODUCTIMAGE_TARGET))

productimage: $(INSTALLED_QEMU_PRODUCTIMAGE)
droidcore: $(INSTALLED_QEMU_PRODUCTIMAGE)
endif
ifdef INSTALLED_SYSTEM_EXTIMAGE_TARGET
INSTALLED_QEMU_SYSTEM_EXTIMAGE := $(PRODUCT_OUT)/system_ext-qemu.img
$(INSTALLED_QEMU_SYSTEM_EXTIMAGE): $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create system_ext-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_SYSTEM_EXTIMAGE_TARGET))

systemextimage: $(INSTALLED_QEMU_SYSTEM_EXTIMAGE)
droidcore: $(INSTALLED_QEMU_SYSTEM_EXTIMAGE)
endif
ifdef INSTALLED_ODMIMAGE_TARGET
INSTALLED_QEMU_ODMIMAGE := $(PRODUCT_OUT)/odm-qemu.img
$(INSTALLED_QEMU_ODMIMAGE): $(INSTALLED_ODMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create odm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_ODMIMAGE_TARGET))

odmimage: $(INSTALLED_QEMU_ODMIMAGE)
droidcore: $(INSTALLED_QEMU_ODMIMAGE)
endif

ifdef INSTALLED_VENDOR_DLKMIMAGE_TARGET
INSTALLED_QEMU_VENDOR_DLKMIMAGE := $(PRODUCT_OUT)/vendor_dlkm-qemu.img
$(INSTALLED_QEMU_VENDOR_DLKMIMAGE): $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create vendor_dlkm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_VENDOR_DLKMIMAGE_TARGET))

vendor_dlkmimage: $(INSTALLED_QEMU_VENDOR_DLKMIMAGE)
droidcore: $(INSTALLED_QEMU_VENDOR_DLKMIMAGE)
endif

ifdef INSTALLED_ODM_DLKMIMAGE_TARGET
INSTALLED_QEMU_ODM_DLKMIMAGE := $(PRODUCT_OUT)/odm_dlkm-qemu.img
$(INSTALLED_QEMU_ODM_DLKMIMAGE): $(INSTALLED_ODM_DLKMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create odm_dlkm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_ODM_DLKMIMAGE_TARGET))

odm_dlkmimage: $(INSTALLED_QEMU_ODM_DLKMIMAGE)
droidcore: $(INSTALLED_QEMU_ODM_DLKMIMAGE)
endif

QEMU_VERIFIED_BOOT_PARAMS := $(PRODUCT_OUT)/VerifiedBootParams.textproto
$(QEMU_VERIFIED_BOOT_PARAMS): $(INSTALLED_VBMETAIMAGE_TARGET) $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH) $(AVBTOOL)
	@echo Creating $@
	(export AVBTOOL=$(AVBTOOL); $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH) $(INSTALLED_VBMETAIMAGE_TARGET) \
    $(INSTALLED_SYSTEMIMAGE_TARGET) $(QEMU_VERIFIED_BOOT_PARAMS))

systemimage: $(QEMU_VERIFIED_BOOT_PARAMS)
droidcore: $(QEMU_VERIFIED_BOOT_PARAMS)

endif
# -----------------------------------------------------------------
# The emulator package
ifeq ($(BUILD_EMULATOR),true)
INTERNAL_EMULATOR_PACKAGE_FILES += \
        $(HOST_OUT_EXECUTABLES)/emulator$(HOST_EXECUTABLE_SUFFIX) \
        prebuilts/qemu-kernel/$(TARGET_ARCH)/kernel-qemu \
        $(INSTALLED_RAMDISK_TARGET) \
        $(INSTALLED_SYSTEMIMAGE_TARGET) \
        $(INSTALLED_USERDATAIMAGE_TARGET)

name := $(TARGET_PRODUCT)-emulator-$(FILE_NAME_TAG)

INTERNAL_EMULATOR_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_EMULATOR_PACKAGE_TARGET): $(INTERNAL_EMULATOR_PACKAGE_FILES)
	@echo "Package: $@"
	$(hide) zip -qjX $@ $(INTERNAL_EMULATOR_PACKAGE_FILES)

endif


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

ifneq ($(PRODUCT_SDK_ATREE_FILES),)
sdk_atree_files += $(PRODUCT_SDK_ATREE_FILES)
else
sdk_atree_files += $(atree_dir)/sdk.atree
endif

include $(BUILD_SYSTEM)/sdk_font.mk

deps := \
	$(target_notice_file_txt) \
	$(tools_notice_file_txt) \
	$(OUT_DOCS)/offline-sdk-timestamp \
	$(SDK_METADATA_FILES) \
	$(SYMBOLS_ZIP) \
	$(COVERAGE_ZIP) \
	$(APPCOMPAT_ZIP) \
	$(INSTALLED_SYSTEMIMAGE_TARGET) \
	$(INSTALLED_QEMU_SYSTEMIMAGE) \
	$(INSTALLED_QEMU_RAMDISKIMAGE) \
	$(INSTALLED_QEMU_VENDORIMAGE) \
	$(QEMU_VERIFIED_BOOT_PARAMS) \
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
	    ATREE_STRIP="$(HOST_STRIP) -x" \
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

# -----------------------------------------------------------------
# Soong generates the list of all shared libraries that are depended on by fuzz
# targets. It saves this list as a source:destination pair to
# FUZZ_TARGET_SHARED_DEPS_INSTALL_PAIRS, where the source is the path to the
# build of the unstripped shared library, and the destination is the
# /data/fuzz/$ARCH/lib (for device) or /fuzz/$ARCH/lib (for host) directory
# where fuzz target shared libraries are to be "reinstalled". The
# copy-many-files below generates the rules to copy the unstripped shared
# libraries to the device or host "reinstallation" directory. These rules are
# depended on by each module in soong_cc_prebuilt.mk, where the module will have
# a dependency on each shared library that it needs to be "reinstalled".
FUZZ_SHARED_DEPS := $(call copy-many-files,$(strip $(FUZZ_TARGET_SHARED_DEPS_INSTALL_PAIRS)))

# -----------------------------------------------------------------
# The rule to build all fuzz targets, and package them.
# Note: The packages are created in Soong, and in a perfect world,
# we'd be able to create the phony rule there. But, if we want to
# have dist goals for the fuzz target, we need to have the PHONY
# target defined in make. MakeVarsContext.DistForGoal doesn't take
# into account that a PHONY rule create by Soong won't be available
# during make, and such will fail with `writing to readonly
# directory`, because kati will see 'haiku' as being a file, not a
# phony target.
.PHONY: haiku
haiku: $(SOONG_FUZZ_PACKAGING_ARCH_MODULES) $(ALL_FUZZ_TARGETS)
$(call dist-for-goals,haiku,$(SOONG_FUZZ_PACKAGING_ARCH_MODULES))
