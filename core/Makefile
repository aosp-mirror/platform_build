# Put some miscellaneous rules here

# HACK: clear LOCAL_PATH from including last build target before calling
# intermedites-dir-for
LOCAL_PATH := $(BUILD_SYSTEM)

SYSTEM_NOTICE_DEPS :=
VENDOR_NOTICE_DEPS :=
UNMOUNTED_NOTICE_DEPS :=
UNMOUNTED_NOTICE_VENDOR_DEPS :=
ODM_NOTICE_DEPS :=
OEM_NOTICE_DEPS :=
PRODUCT_NOTICE_DEPS :=
SYSTEM_EXT_NOTICE_DEPS :=
VENDOR_DLKM_NOTICE_DEPS :=
ODM_DLKM_NOTICE_DEPS :=
SYSTEM_DLKM_NOTICE_DEPS :=


# IMAGES_TO_BUILD is a list of the partition .img files that will be created.
IMAGES_TO_BUILD:=
ifneq ($(BUILDING_BOOT_IMAGE),)
  IMAGES_TO_BUILD += boot
endif
ifneq ($(BUILDING_CACHE_IMAGE),)
  IMAGES_TO_BUILD += cache
endif
ifneq ($(BUILDING_DEBUG_BOOT_IMAGE),)
  IMAGES_TO_BUILD += debug_boot
endif
ifneq ($(BUILDING_DEBUG_VENDOR_BOOT_IMAGE),)
  IMAGES_TO_BUILD += debug_vendor_boot
endif
ifneq ($(BUILDING_INIT_BOOT_IMAGE),)
  IMAGES_TO_BUILD += init_boot
endif
ifneq ($(BUILDING_ODM_DLKM_IMAGE),)
  IMAGES_TO_BUILD += odm_dlkm
endif
ifneq ($(BUILDING_ODM_IMAGE),)
  IMAGES_TO_BUILD += odm
endif
ifneq ($(BUILDING_PRODUCT_IMAGE),)
  IMAGES_TO_BUILD += product
endif
ifneq ($(BUILDING_RAMDISK_IMAGE),)
  IMAGES_TO_BUILD += ramdisk
endif
ifneq ($(BUILDING_RECOVERY_IMAGE),)
  IMAGES_TO_BUILD += recovery
endif
ifneq ($(BUILDING_SUPER_EMPTY_IMAGE),)
  IMAGES_TO_BUILD += super_empty
endif
ifneq ($(BUILDING_SYSTEM_DLKM_IMAGE),)
  IMAGES_TO_BUILD += system_dlkm
endif
ifneq ($(BUILDING_SYSTEM_EXT_IMAGE),)
  IMAGES_TO_BUILD += system_ext
endif
ifneq ($(BUILDING_SYSTEM_IMAGE),)
  IMAGES_TO_BUILD += system
endif
ifneq ($(BUILDING_SYSTEM_OTHER_IMAGE),)
  IMAGES_TO_BUILD += system_other
endif
ifneq ($(BUILDING_USERDATA_IMAGE),)
  IMAGES_TO_BUILD += userdata
endif
ifneq ($(BUILDING_VBMETA_IMAGE),)
  IMAGES_TO_BUILD += vbmeta
endif
ifneq ($(BUILDING_VENDOR_BOOT_IMAGE),)
  IMAGES_TO_BUILD += vendor_boot
endif
ifneq ($(BUILDING_VENDOR_DLKM_IMAGE),)
  IMAGES_TO_BUILD += vendor_dlkm
endif
ifneq ($(BUILDING_VENDOR_IMAGE),)
  IMAGES_TO_BUILD += vendor
endif
ifneq ($(BUILDING_VENDOR_KERNEL_BOOT_IMAGE),)
  IMAGES_TO_BUILD += vendor_kernel_boot
endif


###########################################################
# Get the module names suitable for ALL_MODULES.* variables that are installed
# for a given partition
#
# $(1): Partition
###########################################################
define register-names-for-partition
$(sort $(foreach m,$(product_MODULES),\
	$(if $(filter $(PRODUCT_OUT)/$(strip $(1))/%, $(ALL_MODULES.$(m).INSTALLED)), \
		$(m)
	) \
))
endef


# Release & Aconfig Flags
# -----------------------------------------------------------------
include $(BUILD_SYSTEM)/packaging/flags.mk


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

# Phony target to check PRODUCT_COPY_FILES copy pairs don't contain ELF files
.PHONY: check-elf-prebuilt-product-copy-files
check-elf-prebuilt-product-copy-files:

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

$(call declare-0p-target,$(pcf_ignored_file))

$(call dist-for-goals,droidcore-unbundled,$(pcf_ignored_file):logs/$(notdir $(pcf_ignored_file)))

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

$(call declare-1p-target,$(ndk_doxygen_out)/index.html,)

# Note: Not a part of the docs target because we don't have doxygen available.
# You can run this target locally if you have doxygen installed.
ndk-docs: $(ndk_doxygen_out)/index.html
.PHONY: ndk-docs
endif

ifeq ($(HOST_OS),linux)
$(call dist-for-goals,sdk,$(API_FINGERPRINT))
$(call dist-for-goals,droidcore,$(API_FINGERPRINT))
endif

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
	$(hide) for x in $(strip $(sdk_build_prop_remove)); do \
	            echo "$$x"generic >> $@.tmp; done
	$(hide) mv $@.tmp $@

$(call declare-0p-target,$(INSTALLED_SDK_BUILD_PROP_TARGET))

# -----------------------------------------------------------------
# declare recovery ramdisk files
ifeq ($(BUILDING_RECOVERY_IMAGE),true)
INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP := $(call intermediates-dir-for,PACKAGING,recovery)/ramdisk_files-timestamp
endif

# -----------------------------------------------------------------
# Declare vendor ramdisk fragments
INTERNAL_VENDOR_RAMDISK_FRAGMENTS :=

ifeq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
  ifneq (,$(filter recovery,$(BOARD_VENDOR_RAMDISK_FRAGMENTS)))
    $(error BOARD_VENDOR_RAMDISK_FRAGMENTS must not contain "recovery" if \
      BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT is set)
  endif
  INTERNAL_VENDOR_RAMDISK_FRAGMENTS += recovery
  VENDOR_RAMDISK_FRAGMENT.recovery.STAGING_DIR := $(TARGET_RECOVERY_ROOT_OUT)
  VENDOR_RAMDISK_FRAGMENT.recovery.FILES := $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
  BOARD_VENDOR_RAMDISK_FRAGMENT.recovery.MKBOOTIMG_ARGS += --ramdisk_type RECOVERY
  .KATI_READONLY := VENDOR_RAMDISK_FRAGMENT.recovery.STAGING_DIR
endif

# Validation check and assign default --ramdisk_type.
$(foreach vendor_ramdisk_fragment,$(BOARD_VENDOR_RAMDISK_FRAGMENTS), \
  $(if $(and $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).KERNEL_MODULE_DIRS), \
             $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).PREBUILT)), \
    $(error Must not specify KERNEL_MODULE_DIRS for prebuilt vendor ramdisk fragment "$(vendor_ramdisk_fragment)": $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).KERNEL_MODULE_DIRS))) \
  $(eval VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).STAGING_DIR := $(call intermediates-dir-for,PACKAGING,vendor_ramdisk_fragment-stage-$(vendor_ramdisk_fragment))) \
  $(eval VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).FILES :=) \
  $(if $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).KERNEL_MODULE_DIRS), \
    $(if $(filter --ramdisk_type,$(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS)),, \
      $(eval BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS += --ramdisk_type DLKM))) \
)

# Create the "kernel module directory" to "vendor ramdisk fragment" inverse mapping.
$(foreach vendor_ramdisk_fragment,$(BOARD_VENDOR_RAMDISK_FRAGMENTS), \
  $(foreach kmd,$(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).KERNEL_MODULE_DIRS), \
    $(eval kmd_vrf := KERNEL_MODULE_DIR_VENDOR_RAMDISK_FRAGMENT_$(kmd)) \
    $(if $($(kmd_vrf)),$(error Kernel module directory "$(kmd)" belongs to multiple vendor ramdisk fragments: "$($(kmd_vrf))" "$(vendor_ramdisk_fragment)", each kernel module directory should belong to exactly one or none vendor ramdisk fragment)) \
    $(eval $(kmd_vrf) := $(vendor_ramdisk_fragment)) \
  ) \
)
INTERNAL_VENDOR_RAMDISK_FRAGMENTS += $(BOARD_VENDOR_RAMDISK_FRAGMENTS)

ifneq ($(BOARD_KERNEL_MODULES_16K),)
INTERNAL_VENDOR_RAMDISK_FRAGMENTS += 16K
endif

# Strip the list in case of any whitespace.
INTERNAL_VENDOR_RAMDISK_FRAGMENTS := \
  $(strip $(INTERNAL_VENDOR_RAMDISK_FRAGMENTS))

# Assign --ramdisk_name for each vendor ramdisk fragment.
$(foreach vendor_ramdisk_fragment,$(INTERNAL_VENDOR_RAMDISK_FRAGMENTS), \
  $(if $(filter --ramdisk_name,$(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS)), \
    $(error Must not specify --ramdisk_name for vendor ramdisk fragment: $(vendor_ramdisk_fragment))) \
  $(eval BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS += --ramdisk_name $(vendor_ramdisk_fragment)) \
  $(eval .KATI_READONLY := BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS) \
)

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
# $(10): extra modules that might be dependency of modules in this partition, but should not be copied to output dir
# $(11): mount point for extra modules
# Returns a list of src:dest pairs to install the modules using copy-many-files.
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
  $(eval $(call build-image-kernel-modules-depmod,$(1),$(3),$(4),$(5),$(6),$(7),$(2),$(9),$(10),$(11))) \
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
# $(9): extra modules which should not be copied to output dir, but might be dependency of modules in this partition
# $(10): mount point for extra modules
# TODO(b/144844424): If a module archive is being used, this step (which
# generates obj/PACKAGING/.../modules.dep) also unzips the module archive into
# the output directory. This should be moved to a module with a
# LOCAL_POST_INSTALL_CMD so that if modules.dep is removed from the output dir,
# the archive modules are restored along with modules.dep.
define build-image-kernel-modules-depmod
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: .KATI_IMPLICIT_OUTPUTS := $(3)/$(DEPMOD_STAGING_SUBDIR)/modules.alias $(3)/$(DEPMOD_STAGING_SUBDIR)/modules.softdep $(3)/$(DEPMOD_STAGING_SUBDIR)/$(5)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: $(DEPMOD)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MODULES := $(strip $(1))
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_EXTRA_MODULES := $(strip $(9))
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MOUNT_POINT := $(2)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_EXTRA_MOUNT_POINT := $(10)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_MODULE_DIR := $(3)/$(DEPMOD_STAGING_SUBDIR)/$(2)/lib/modules/$(8)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_EXTRA_MODULE_DIR := $(3)/$(DEPMOD_STAGING_SUBDIR)/$(10)/lib/modules/$(8)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_STAGING_DIR := $(3)
$(3)/$(DEPMOD_STAGING_SUBDIR)/modules.dep: PRIVATE_LOAD_MODULES := $(strip $(4))
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
	  find $$(PRIVATE_MODULE_DIR) -type f -name '*.ko' | xargs basename -a > $$(PRIVATE_LOAD_FILE); \
	)
	$(if $(1),\
	  cp $$(PRIVATE_MODULES) $$(PRIVATE_MODULE_DIR)/; \
	  for MODULE in $$(PRIVATE_LOAD_MODULES); do \
	    basename $$$$MODULE >> $$(PRIVATE_LOAD_FILE); \
	  done; \
	)
	# The ln -sf + find -delete sequence is to remove any modules in
	# PRIVATE_EXTRA_MODULES which have same basename as MODULES in PRIVATE_MODULES
	# Basically, it computes a set difference. When there is a duplicate module
	# present in both directories, we want modules in PRIVATE_MODULES to take
	# precedence. Since depmod does not provide any guarantee about ordering of
	# dependency resolution, we achieve this by maually removing any duplicate
	# modules with lower priority.
	$(if $(9),\
	  mkdir -p $$(PRIVATE_EXTRA_MODULE_DIR); \
	  find $$(PRIVATE_EXTRA_MODULE_DIR) -maxdepth 1 -type f -name "*.ko" -delete; \
	  cp $$(PRIVATE_EXTRA_MODULES) $$(PRIVATE_EXTRA_MODULE_DIR); \
	  ln -sf $$(PRIVATE_MODULE_DIR)/*.ko $$(PRIVATE_EXTRA_MODULE_DIR); \
	  find $$(PRIVATE_EXTRA_MODULE_DIR) -type l -delete; \
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

# $(1): source options file
# $(2): destination pathname
# Returns a build rule that checks the syntax of and installs a kernel modules
# options file. Strip and squeeze any extra space and blank lines.
# For use via $(eval).
define build-image-kernel-modules-options-file
$(2): $(1)
	@echo "libmodprobe options $$(@)"
	$(hide) mkdir -p "$$(dir $$@)"
	$(hide) rm -f "$$@"
	$(hide) awk <"$$<" >"$$@" \
	  '/^#/ { print; next } \
	   NF == 0 { next } \
	   NF < 2 || $$$$1 != "options" \
	     { print "Invalid options line " FNR ": " $$$$0 >"/dev/stderr"; \
	       exit_status = 1; next } \
	   { $$$$1 = $$$$1; print } \
	   END { exit exit_status }'
endef

# $(1): source blocklist file
# $(2): destination pathname
# Returns a build rule that checks the syntax of and installs a kernel modules
# blocklist file. Strip and squeeze any extra space and blank lines.
# For use via $(eval).
define build-image-kernel-modules-blocklist-file
$(2): $(1)
	@echo "libmodprobe blocklist $$(@)"
	$(hide) mkdir -p "$$(dir $$@)"
	$(hide) rm -f "$$@"
	$(hide) awk <"$$<" >"$$@" \
	  '/^#/ { print; next } \
	   NF == 0 { next } \
	   NF != 2 || $$$$1 != "blocklist" \
	     { print "Invalid blocklist line " FNR ": " $$$$0 >"/dev/stderr"; \
	       exit_status = 1; next } \
	   { $$$$1 = $$$$1; print } \
	   END { exit exit_status }'
endef

# $(1): image name
# $(2): build output directory (TARGET_OUT_VENDOR, TARGET_RECOVERY_ROOT_OUT, etc)
# $(3): mount point
# $(4): module load filename
# $(5): stripped staging directory
# $(6): kernel module directory name (top is an out of band value for no directory)
# $(7): list of extra modules that might be dependency of modules in this partition
# $(8): mount point for extra modules. e.g. system

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
  $(if $(filter false,$(BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver))),\
    $(eval BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver) :=),) \
  $(eval _files := $(call build-image-kernel-modules,$(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver)),$(2),$(3),$(call intermediates-dir-for,PACKAGING,depmod_$(1)$(_sep)$(_kver)),$(BOARD_$(1)_KERNEL_MODULES_LOAD$(_sep)$(_kver)),$(4),$(BOARD_$(1)_KERNEL_MODULES_ARCHIVE$(_sep)$(_kver)),$(_stripped_staging_dir),$(_kver),$(7),$(8))) \
  $(call copy-many-files,$(_files)) \
  $(eval _modules := $(BOARD_$(1)_KERNEL_MODULES$(_sep)$(_kver)) ANDROID-GEN ANDROID-GEN ANDROID-GEN ANDROID-GEN) \
  $(eval KERNEL_MODULE_COPY_FILES += $(join $(addsuffix :,$(_modules)),$(_files)))) \
$(if $(_kver), \
  $(eval _dir := $(_kver)/), \
  $(eval _dir :=)) \
$(if $(BOARD_$(1)_KERNEL_MODULES_OPTIONS_FILE$(_sep)$(_kver)), \
  $(eval $(call build-image-kernel-modules-options-file, \
    $(BOARD_$(1)_KERNEL_MODULES_OPTIONS_FILE$(_sep)$(_kver)), \
    $(2)/lib/modules/$(_dir)modules.options)) \
  $(2)/lib/modules/$(_dir)modules.options) \
$(if $(BOARD_$(1)_KERNEL_MODULES_BLOCKLIST_FILE$(_sep)$(_kver)), \
  $(eval $(call build-image-kernel-modules-blocklist-file, \
    $(BOARD_$(1)_KERNEL_MODULES_BLOCKLIST_FILE$(_sep)$(_kver)), \
    $(2)/lib/modules/$(_dir)modules.blocklist)) \
  $(eval ALL_KERNEL_MODULES_BLOCKLIST += $(2)/lib/modules/$(_dir)modules.blocklist) \
  $(2)/lib/modules/$(_dir)modules.blocklist)
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
define build-vendor-kernel-ramdisk-recovery-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_KERNEL_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_kernel_ramdisk_recovery_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_KERNEL_RAMDISK_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_KERNEL_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.recovery,$(TARGET_VENDOR_KERNEL_RAMDISK_OUT))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-vendor-charger-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_charger_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_CHARGER_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.charger,$(TARGET_OUT_VENDOR))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-vendor-ramdisk-charger-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_RAMDISK_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_ramdisk_charger_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_RAMDISK_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_RAMDISK_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.charger,$(TARGET_VENDOR_RAMDISK_OUT))))
endef

# $(1): kernel module directory name (top is an out of band value for no directory)
define build-vendor-kernel-ramdisk-charger-load
$(if $(filter top,$(1)),\
  $(eval _kver :=)$(eval _sep :=),\
  $(eval _kver := $(1))$(eval _sep :=_))\
  $(if $(BOARD_VENDOR_KERNEL_RAMDISK_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),\
    $(call copy-many-files,$(call module-load-list-copy-paths,$(call intermediates-dir-for,PACKAGING,vendor_kernel_ramdisk_charger_module_list$(_sep)$(_kver)),$(BOARD_VENDOR_KERNEL_RAMDISK_KERNEL_MODULES$(_sep)$(_kver)),$(BOARD_VENDOR_KERNEL_RAMDISK_CHARGER_KERNEL_MODULES_LOAD$(_sep)$(_kver)),modules.load.charger,$(TARGET_VENDOR_KERNEL_RAMDISK_OUT))))
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

ifneq ($(BOARD_DO_NOT_STRIP_GENERIC_RAMDISK_MODULES),true)
  GENERIC_RAMDISK_STRIPPED_MODULE_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_generic_ramdisk_kernel_stripped)
else
  GENERIC_RAMDISK_STRIPPED_MODULE_STAGING_DIR :=
endif

ifneq ($(BOARD_DO_NOT_STRIP_RECOVERY_MODULES),true)
	RECOVERY_STRIPPED_MODULE_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_recovery_stripped)
else
	RECOVERY_STRIPPED_MODULE_STAGING_DIR :=
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

ifneq ($(BOARD_DO_NOT_STRIP_VENDOR_KERNEL_RAMDISK_MODULES),true)
  VENDOR_KERNEL_RAMDISK_STRIPPED_MODULE_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_vendor_kernel_ramdisk_stripped)
else
  VENDOR_KERNEL_RAMDISK_STRIPPED_MODULE_STAGING_DIR :=
endif

BOARD_KERNEL_MODULE_DIRS += top

# Default to not generating modules.dep for kernel modules on system
# side. We should only load these modules if they are depended by vendor
# side modules.
ifeq ($(BOARD_SYSTEM_KERNEL_MODULES_LOAD),)
  BOARD_SYSTEM_KERNEL_MODULES_LOAD := false
endif

$(foreach kmd,$(BOARD_KERNEL_MODULE_DIRS), \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,RECOVERY,$(TARGET_RECOVERY_ROOT_OUT),,modules.load.recovery,$(RECOVERY_STRIPPED_MODULE_STAGING_DIR),$(kmd))) \
  $(eval vendor_ramdisk_fragment := $(KERNEL_MODULE_DIR_VENDOR_RAMDISK_FRAGMENT_$(kmd))) \
  $(if $(vendor_ramdisk_fragment), \
    $(eval output_dir := $(VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).STAGING_DIR)) \
    $(eval result_var := VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).FILES) \
    $(eval ### else ###), \
    $(eval output_dir := $(TARGET_VENDOR_RAMDISK_OUT)) \
    $(eval result_var := ALL_DEFAULT_INSTALLED_MODULES)) \
  $(eval $(result_var) += $(call build-image-kernel-modules-dir,VENDOR_RAMDISK,$(output_dir),,modules.load,$(VENDOR_RAMDISK_STRIPPED_MODULE_STAGING_DIR),$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,VENDOR_KERNEL_RAMDISK,$(TARGET_VENDOR_KERNEL_RAMDISK_OUT),,modules.load,$(VENDOR_KERNEL_RAMDISK_STRIPPED_MODULE_STAGING_DIR),$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-ramdisk-recovery-load,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-kernel-ramdisk-recovery-load,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,VENDOR,$(if $(filter true,$(BOARD_USES_VENDOR_DLKMIMAGE)),$(TARGET_OUT_VENDOR_DLKM),$(TARGET_OUT_VENDOR)),vendor,modules.load,$(VENDOR_STRIPPED_MODULE_STAGING_DIR),$(kmd),$(BOARD_SYSTEM_KERNEL_MODULES),system)) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-charger-load,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-ramdisk-charger-load,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-vendor-kernel-ramdisk-charger-load,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,ODM,$(if $(filter true,$(BOARD_USES_ODM_DLKMIMAGE)),$(TARGET_OUT_ODM_DLKM),$(TARGET_OUT_ODM)),odm,modules.load,,$(kmd))) \
  $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,SYSTEM,$(if $(filter true,$(BOARD_USES_SYSTEM_DLKMIMAGE)),$(TARGET_OUT_SYSTEM_DLKM),$(TARGET_OUT_SYSTEM)),system,modules.load,,$(kmd))) \
  $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-recovery-as-boot-load,$(kmd))),\
    $(eval ALL_DEFAULT_INSTALLED_MODULES += $(call build-image-kernel-modules-dir,GENERIC_RAMDISK,$(TARGET_RAMDISK_OUT),,modules.load,$(GENERIC_RAMDISK_STRIPPED_MODULE_STAGING_DIR),$(kmd)))))

ifeq ($(BOARD_SYSTEM_KERNEL_MODULES),)
ifneq ($(BOARD_SYSTEM_DLKM_SRC),)
ifneq ($(wildcard $(BOARD_SYSTEM_DLKM_SRC)/*),)
  SYSTEM_KERNEL_MODULES := $(shell find $(BOARD_SYSTEM_DLKM_SRC) -type f)
  SRC_SYSTEM_KERNEL_MODULES := $(SYSTEM_KERNEL_MODULES)
  DST_SYSTEM_KERNEL_MODULES := $(patsubst $(BOARD_SYSTEM_DLKM_SRC)/%,:$(TARGET_OUT_SYSTEM_DLKM)/%,$(SRC_SYSTEM_KERNEL_MODULES))
  SYSTEM_KERNEL_MODULE_COPY_PAIRS := $(join $(SRC_SYSTEM_KERNEL_MODULES),$(DST_SYSTEM_KERNEL_MODULES))
  ALL_DEFAULT_INSTALLED_MODULES += $(call copy-many-files,$(SYSTEM_KERNEL_MODULE_COPY_PAIRS))
endif
endif
endif


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
name := $(name)-apkcerts
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
	      $(call _apkcerts_write_line,$(PACKAGES.$(p).STEM),EXTERNAL,,$(PACKAGES.$(p).COMPRESSED),$(PACKAGES.$(p).PARTITION),$@),\
	      $(call _apkcerts_write_line,$(PACKAGES.$(p).STEM),$(PACKAGES.$(p).CERTIFICATE),$(PACKAGES.$(p).PRIVATE_KEY),$(PACKAGES.$(p).COMPRESSED),$(PACKAGES.$(p).PARTITION),$@))))
	$(if $(filter true,$(PRODUCT_FSVERITY_GENERATE_METADATA)),\
	  $(call _apkcerts_write_line,BuildManifest,$(FSVERITY_APK_KEY_PATH).x509.pem,$(FSVERITY_APK_KEY_PATH).pk8,,system,$@) \
	  $(if $(filter true,$(BUILDING_SYSTEM_EXT_IMAGE)),\
            $(call _apkcerts_write_line,BuildManifestSystemExt,$(FSVERITY_APK_KEY_PATH).x509.pem,$(FSVERITY_APK_KEY_PATH).pk8,,system_ext,$@)))
	# In case value of PACKAGES is empty.
	$(hide) touch $@

$(call declare-0p-target,$(APKCERTS_FILE))

.PHONY: apkcerts-list
apkcerts-list: $(APKCERTS_FILE)

intermediates := $(call intermediates-dir-for,PACKAGING,apexkeys)
APEX_KEYS_FILE := $(intermediates)/apexkeys.txt

all_apex_keys_files := $(sort $(foreach m,$(call product-installed-modules,$(INTERNAL_PRODUCT)),$(ALL_MODULES.$(m).APEX_KEYS_FILE)))
$(APEX_KEYS_FILE): $(all_apex_keys_files)
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) touch $@
	$(hide) $(foreach file,$^,cat $(file) >> $@ $(newline))
all_apex_keys_files :=

$(call declare-0p-target,$(APEX_KEYS_FILE))

.PHONY: apexkeys.txt
apexkeys.txt: $(APEX_KEYS_FILE)

ifneq (,$(TARGET_BUILD_APPS))
  $(call dist-for-goals, apps_only, $(APKCERTS_FILE):apkcerts.txt)
  $(call dist-for-goals, apps_only, $(APEX_KEYS_FILE):apexkeys.txt)
endif


# -----------------------------------------------------------------
# build system stats
BUILD_SYSTEM_STATS := $(PRODUCT_OUT)/build_system_stats.txt
$(BUILD_SYSTEM_STATS):
	@rm -f $@
	@$(foreach s,$(STATS.MODULE_TYPE),echo "modules_type_make,$(s),$(words $(STATS.MODULE_TYPE.$(s)))" >>$@;)
	@$(foreach s,$(STATS.SOONG_MODULE_TYPE),echo "modules_type_soong,$(s),$(STATS.SOONG_MODULE_TYPE.$(s))" >>$@;)
$(call declare-1p-target,$(BUILD_SYSTEM_STATS),build)
$(call dist-for-goals,droidcore-unbundled,$(BUILD_SYSTEM_STATS))

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

$(call declare-1p-target,$(SOONG_CONV_DATA),build)

SOONG_TO_CONVERT_SCRIPT := build/make/tools/soong_to_convert.py
SOONG_TO_CONVERT := $(PRODUCT_OUT)/soong_to_convert.txt
$(SOONG_TO_CONVERT): $(SOONG_CONV_DATA) $(SOONG_TO_CONVERT_SCRIPT)
	@rm -f $@
	$(hide) $(SOONG_TO_CONVERT_SCRIPT) $< >$@
$(call declare-1p-target,$(SOONG_TO_CONVERT),build)
$(call dist-for-goals,droidcore-unbundled,$(SOONG_TO_CONVERT))

$(PRODUCT_OUT)/product_packages.txt:
	@rm -f $@
	echo "" > $@
	$(foreach x,$(PRODUCT_PACKAGES),echo $(x) >> $@$(newline))

MK2BP_CATALOG_SCRIPT := build/make/tools/mk2bp_catalog.py
PRODUCT_PACKAGES_TXT := $(PRODUCT_OUT)/product_packages.txt
MK2BP_REMAINING_HTML := $(PRODUCT_OUT)/mk2bp_remaining.html
$(MK2BP_REMAINING_HTML): PRIVATE_CODE_SEARCH_BASE_URL := "https://cs.android.com/android/platform/superproject/+/master:"
$(MK2BP_REMAINING_HTML): $(SOONG_CONV_DATA) $(MK2BP_CATALOG_SCRIPT) $(PRODUCT_PACKAGES_TXT)
	@rm -f $@
	$(hide) $(MK2BP_CATALOG_SCRIPT) \
		--device=$(TARGET_DEVICE) \
		--product-packages=$(PRODUCT_PACKAGES_TXT) \
		--title="Remaining Android.mk files for $(TARGET_DEVICE)-$(TARGET_BUILD_VARIANT)" \
		--codesearch=$(PRIVATE_CODE_SEARCH_BASE_URL) \
		--out-dir="$(OUT_DIR)" \
		--mode=html \
		> $@
$(call declare-1p-target,$(MK2BP_REMAINING_HTML),build)
$(call dist-for-goals,droidcore-unbundled,$(MK2BP_REMAINING_HTML))

MK2BP_REMAINING_CSV := $(PRODUCT_OUT)/mk2bp_remaining.csv
$(MK2BP_REMAINING_CSV): $(SOONG_CONV_DATA) $(MK2BP_CATALOG_SCRIPT) $(PRODUCT_PACKAGES_TXT)
	@rm -f $@
	$(hide) $(MK2BP_CATALOG_SCRIPT) \
		--device=$(TARGET_DEVICE) \
		--product-packages=$(PRODUCT_PACKAGES_TXT) \
		--out-dir="$(OUT_DIR)" \
		--mode=csv \
		> $@
$(call declare-1p-target,$(MK2BP_REMAINING_CSV))
$(call dist-for-goals,droidcore-unbundled,$(MK2BP_REMAINING_CSV))

.PHONY: mk2bp_remaining
mk2bp_remaining: $(MK2BP_REMAINING_HTML) $(MK2BP_REMAINING_CSV)

# -----------------------------------------------------------------
# Modules use -Wno-error, or added default -Wall -Werror
WALL_WERROR := $(PRODUCT_OUT)/wall_werror.txt
$(WALL_WERROR):
	@rm -f $@
	echo "# Modules using -Wno-error" >> $@
	for m in $(sort $(SOONG_MODULES_USING_WNO_ERROR) $(MODULES_USING_WNO_ERROR)); do echo $$m >> $@; done
	echo "# Modules that allow warnings" >> $@
	for m in $(sort $(SOONG_MODULES_WARNINGS_ALLOWED) $(MODULES_WARNINGS_ALLOWED)); do echo $$m >> $@; done

$(call declare-0p-target,$(WALL_WERROR))

$(call dist-for-goals,droidcore-unbundled,$(WALL_WERROR))

# -----------------------------------------------------------------
# Modules missing profile files
PGO_PROFILE_MISSING := $(PRODUCT_OUT)/pgo_profile_file_missing.txt
$(PGO_PROFILE_MISSING):
	@rm -f $@
	echo "# Modules missing PGO profile files" >> $@
	for m in $(SOONG_MODULES_MISSING_PGO_PROFILE_FILE); do echo $$m >> $@; done

$(call declare-0p-target,$(PGO_PROFILE_MISSING))

$(call dist-for-goals,droidcore,$(PGO_PROFILE_MISSING))

CERTIFICATE_VIOLATION_MODULES_FILENAME := $(PRODUCT_OUT)/certificate_violation_modules.txt
$(CERTIFICATE_VIOLATION_MODULES_FILENAME):
	rm -f $@
	$(foreach m,$(sort $(CERTIFICATE_VIOLATION_MODULES)), echo $(m) >> $@;)
$(call declare-0p-target,$(CERTIFICATE_VIOLATION_MODULES_FILENAME))
$(call dist-for-goals,droidcore,$(CERTIFICATE_VIOLATION_MODULES_FILENAME))

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

$(call declare-0p-target,$(all_event_log_tags_file))

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

$(eval $(call declare-0p-target,$(event_log_tags_file)))

event-log-tags: $(event_log_tags_file)

ALL_DEFAULT_INSTALLED_MODULES += $(event_log_tags_file)

# Initialize INSTALLED_FILES_OUTSIDE_IMAGES with the list of all device files,
# files installed in images will be filtered out later.
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out \
  $(PRODUCT_OUT)/apex/% \
  $(PRODUCT_OUT)/fake_packages/% \
  $(PRODUCT_OUT)/testcases/%, \
  $(filter $(PRODUCT_OUT)/%,$(ALL_DEFAULT_INSTALLED_MODULES)))

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
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_ROOT_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
INTERNAL_ROOT_FILES := $(filter $(TARGET_ROOT_OUT)/%, \
	$(ALL_DEFAULT_INSTALLED_MODULES))


INSTALLED_FILES_FILE_ROOT := $(PRODUCT_OUT)/installed-files-root.txt
INSTALLED_FILES_JSON_ROOT := $(INSTALLED_FILES_FILE_ROOT:.txt=.json)
$(INSTALLED_FILES_FILE_ROOT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ROOT)
$(INSTALLED_FILES_FILE_ROOT) : $(INTERNAL_ROOT_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(TARGET_ROOT_OUT)
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_ROOT_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_ROOT))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_ROOT))

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
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_RAMDISK_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_RAMDISK_IMAGE
INTERNAL_RAMDISK_FILES := $(filter $(TARGET_RAMDISK_OUT)/%, \
	$(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_RAMDISK := $(PRODUCT_OUT)/installed-files-ramdisk.txt
INSTALLED_FILES_JSON_RAMDISK := $(INSTALLED_FILES_FILE_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_RAMDISK)
$(INSTALLED_FILES_FILE_RAMDISK) : $(INTERNAL_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(TARGET_RAMDISK_OUT)
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_RAMDISK_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE_RAMDISK)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON_RAMDISK)))

BUILT_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk.img


ifneq ($(BOARD_KERNEL_MODULES_16K),)

TARGET_OUT_RAMDISK_16K := $(PRODUCT_OUT)/ramdisk_16k
BUILT_RAMDISK_16K_TARGET := $(PRODUCT_OUT)/ramdisk_16k.img
RAMDISK_16K_STAGING_DIR := $(call intermediates-dir-for,PACKAGING,depmod_ramdisk_16k)

ifneq ($(BOARD_SYSTEM_KERNEL_MODULES),)
SYSTEM_DLKM_MODULE_PATTERNS := $(foreach path,$(BOARD_SYSTEM_KERNEL_MODULES),%/$(notdir $(path)))

endif

# BOARD_KERNEL_MODULES_16K might contain duplicate modules under different path.
# for example, foo/bar/wifi.ko and foo/wifi.ko . To avoid build issues, de-dup
# module list on basename first.
BOARD_KERNEL_MODULES_16K := $(foreach \
  pattern,\
  $(sort $(foreach \
    path,\
    $(BOARD_KERNEL_MODULES_16K),\
    %/$(notdir $(path)))\
  ),\
  $(firstword $(filter $(pattern),$(BOARD_KERNEL_MODULES_16K))) \
)
# For non-GKI modules, strip them before install. As debug symbols take up
# significant space.
$(foreach \
  file,\
  $(filter-out $(SYSTEM_DLKM_MODULE_PATTERNS),$(BOARD_KERNEL_MODULES_16K)),\
  $(eval \
    $(call copy-and-strip-kernel-module,\
      $(file),\
      $(RAMDISK_16K_STAGING_DIR)/lib/modules/0.0/$(notdir $(file)) \
    ) \
  ) \
)

# For GKI modules, copy as-is without stripping, because stripping would
# remove the signature of kernel modules, and GKI modules must be signed
# for kernel to load them.
$(foreach \
  file,\
  $(filter $(SYSTEM_DLKM_MODULE_PATTERNS),$(BOARD_KERNEL_MODULES_16K)),\
  $(eval \
    $(call copy-one-file,\
      $(file),\
      $(RAMDISK_16K_STAGING_DIR)/lib/modules/0.0/$(notdir $(file)) \
    ) \
  ) \
)

BOARD_VENDOR_RAMDISK_FRAGMENT.16K.PREBUILT := $(BUILT_RAMDISK_16K_TARGET)

$(BUILT_RAMDISK_16K_TARGET): $(DEPMOD) $(MKBOOTFS) $(EXTRACT_KERNEL) $(COMPRESSION_COMMAND_DEPS)
$(BUILT_RAMDISK_16K_TARGET): $(foreach file,$(BOARD_KERNEL_MODULES_16K),$(RAMDISK_16K_STAGING_DIR)/lib/modules/0.0/$(notdir $(file)))
	$(DEPMOD) -b $(RAMDISK_16K_STAGING_DIR) 0.0
	for MODULE in $(BOARD_KERNEL_MODULES_16K); do \
		basename $$MODULE >> $(RAMDISK_16K_STAGING_DIR)/lib/modules/0.0/modules.load ; \
	done;
	rm -rf $(TARGET_OUT_RAMDISK_16K)/lib/modules
	mkdir -p $(TARGET_OUT_RAMDISK_16K)/lib/modules
	KERNEL_RELEASE=`$(EXTRACT_KERNEL) --tools lz4:$(LZ4) --input $(BOARD_KERNEL_PATH_16K) --output-release` ;\
	IS_16K_KERNEL=`$(EXTRACT_KERNEL) --tools lz4:$(LZ4) --input $(BOARD_KERNEL_PATH_16K) --output-config` ;\
	if [[ "$$IS_16K_KERNEL" == *"CONFIG_ARM64_16K_PAGES=y"* ]]; then SUFFIX=_16k; fi ;\
	cp -r $(RAMDISK_16K_STAGING_DIR)/lib/modules/0.0 $(TARGET_OUT_RAMDISK_16K)/lib/modules/$$KERNEL_RELEASE$$SUFFIX
	$(MKBOOTFS) $(TARGET_OUT_RAMDISK_16K) | $(COMPRESSION_COMMAND) > $@

# Builds a ramdisk using modules defined in BOARD_KERNEL_MODULES_16K
ramdisk_16k: $(BUILT_RAMDISK_16K_TARGET)
.PHONY: ramdisk_16k

endif

ifneq ($(BOARD_KERNEL_PATH_16K),)
BUILT_KERNEL_16K_TARGET := $(PRODUCT_OUT)/kernel_16k

$(eval $(call copy-one-file,$(BOARD_KERNEL_PATH_16K),$(BUILT_KERNEL_16K_TARGET)))

# Copies BOARD_KERNEL_PATH_16K to output directory as is
kernel_16k: $(BUILT_KERNEL_16K_TARGET)
.PHONY: kernel_16k

BUILT_BOOTIMAGE_16K_TARGET := $(PRODUCT_OUT)/boot_16k.img

BOARD_KERNEL_16K_BOOTIMAGE_PARTITION_SIZE := $(BOARD_BOOTIMAGE_PARTITION_SIZE)

$(BUILT_BOOTIMAGE_16K_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH) $(BUILT_KERNEL_16K_TARGET)
	$(call pretty,"Target boot 16k image: $@")
	$(call build_boot_from_kernel_avb_enabled,$@,$(BUILT_KERNEL_16K_TARGET))


bootimage_16k: $(BUILT_BOOTIMAGE_16K_TARGET)
.PHONY: bootimage_16k

BUILT_BOOT_OTA_PACKAGE_16K := $(PRODUCT_OUT)/boot_ota_16k.zip
$(BUILT_BOOT_OTA_PACKAGE_16K): $(OTA_FROM_RAW_IMG) $(BUILT_BOOTIMAGE_16K_TARGET) $(INSTALLED_BOOTIMAGE_TARGET) $(DEFAULT_SYSTEM_DEV_CERTIFICATE).pk8
	$(OTA_FROM_RAW_IMG) --package_key $(DEFAULT_SYSTEM_DEV_CERTIFICATE) \
                      --max_timestamp `cat $(BUILD_DATETIME_FILE)` \
                      --path $(HOST_OUT) \
                      --partition_name boot \
                      --output $@ \
                      $(if $(BOARD_16K_OTA_USE_INCREMENTAL),\
                        $(INSTALLED_BOOTIMAGE_TARGET):$(BUILT_BOOTIMAGE_16K_TARGET),\
                        $(BUILT_BOOTIMAGE_16K_TARGET)\
                      )

boototapackage_16k: $(BUILT_BOOT_OTA_PACKAGE_16K)
.PHONY: boototapackage_16k

endif


ifeq ($(BOARD_RAMDISK_USE_LZ4),true)
# -l enables the legacy format used by the Linux kernel
COMPRESSION_COMMAND_DEPS := $(LZ4)
COMPRESSION_COMMAND := $(LZ4) -l -12 --favor-decSpeed
RAMDISK_EXT := .lz4
else
COMPRESSION_COMMAND_DEPS := $(GZIP)
COMPRESSION_COMMAND := $(GZIP)
RAMDISK_EXT := .gz
endif

# This file contains /dev nodes description added to the generic ramdisk
RAMDISK_NODE_LIST := $(PRODUCT_OUT)/ramdisk_node_list

# We just build this directly to the install location.
INSTALLED_RAMDISK_TARGET := $(BUILT_RAMDISK_TARGET)
$(INSTALLED_RAMDISK_TARGET): PRIVATE_DIRS := debug_ramdisk dev metadata mnt proc second_stage_resources sys
$(INSTALLED_RAMDISK_TARGET): $(MKBOOTFS) $(RAMDISK_NODE_LIST) $(INTERNAL_RAMDISK_FILES) $(INSTALLED_FILES_FILE_RAMDISK) | $(COMPRESSION_COMMAND_DEPS)
	$(call pretty,"Target ramdisk: $@")
	$(hide) mkdir -p $(addprefix $(TARGET_RAMDISK_OUT)/,$(PRIVATE_DIRS))
ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
	$(hide) mkdir -p $(addprefix $(TARGET_RAMDISK_OUT)/first_stage_ramdisk/,$(PRIVATE_DIRS))
endif
	$(hide) $(MKBOOTFS) -n $(RAMDISK_NODE_LIST) -d $(TARGET_OUT) $(TARGET_RAMDISK_OUT) | $(COMPRESSION_COMMAND) > $@

$(call declare-1p-container,$(INSTALLED_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_RAMDISK_TARGET),$(INTERNAL_RAMDISK_FILE),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_RAMDISK_TARGET)

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

INTERNAL_PREBUILT_BOOTIMAGE :=

my_installed_prebuilt_gki_apex := $(strip $(foreach package,$(PRODUCT_PACKAGES),$(if $(ALL_MODULES.$(package).EXTRACTED_BOOT_IMAGE),$(package))))
ifdef my_installed_prebuilt_gki_apex
  ifneq (1,$(words $(my_installed_prebuilt_gki_apex))) # len(my_installed_prebuilt_gki_apex) > 1
    $(error More than one prebuilt GKI APEXes are installed: $(my_installed_prebuilt_gki_apex))
  endif # len(my_installed_prebuilt_gki_apex) > 1

  ifdef BOARD_PREBUILT_BOOTIMAGE
    $(error Must not define BOARD_PREBUILT_BOOTIMAGE because a prebuilt GKI APEX is installed: $(my_installed_prebuilt_gki_apex))
  endif # BOARD_PREBUILT_BOOTIMAGE defined

  my_apex_extracted_boot_image := $(ALL_MODULES.$(my_installed_prebuilt_gki_apex).EXTRACTED_BOOT_IMAGE)
  INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img
  $(eval $(call copy-one-file,$(my_apex_extracted_boot_image),$(INSTALLED_BOOTIMAGE_TARGET)))
  $(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",boot)

  INTERNAL_PREBUILT_BOOTIMAGE := $(my_apex_extracted_boot_image)

else # my_installed_prebuilt_gki_apex not defined

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
# $2: boot image variant (boot, boot-debug, boot-test-harness)
define get-bootimage-partition-size
$(BOARD_$(call to-upper,$(subst .img,,$(subst $(2),kernel,$(notdir $(1)))))_BOOTIMAGE_PARTITION_SIZE)
endef

# $1: partition size
define get-partition-size-argument
  $(if $(1),--partition_size $(1),--dynamic_partition_size)
endef

# $1: output boot image target
# $2: input path to kernel binary
define build_boot_from_kernel_avb_enabled
  $(eval kernel := $(2))
  $(MKBOOTIMG) --kernel $(kernel) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1)
  $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$(1),boot)))
  $(AVBTOOL) add_hash_footer \
          --image $(1) \
          $(call get-partition-size-argument,$(call get-bootimage-partition-size,$(1),boot)) \
          --salt `sha256sum "$(kernel)" | cut -d " " -f 1` \
          --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
          $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
endef


ifndef BOARD_PREBUILT_BOOTIMAGE

ifneq ($(strip $(TARGET_NO_KERNEL)),true)
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET))

ifneq ($(BUILDING_INIT_BOOT_IMAGE),true)
  INTERNAL_BOOTIMAGE_ARGS += --ramdisk $(INSTALLED_RAMDISK_TARGET)
endif

ifndef BUILDING_VENDOR_BOOT_IMAGE
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  INTERNAL_BOOTIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
endif
endif

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

# kernel cmdline/base/pagesize in boot.
# - If using GKI, use GENERIC_KERNEL_CMDLINE. Remove kernel base and pagesize because they are
#   device-specific.
# - If not using GKI:
#   - If building vendor_boot, INTERNAL_KERNEL_CMDLINE, base and pagesize goes in vendor_boot.
#   - Otherwise, put them in boot.
ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
  ifdef GENERIC_KERNEL_CMDLINE
    INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(GENERIC_KERNEL_CMDLINE)"
  endif
else ifndef BUILDING_VENDOR_BOOT_IMAGE # && BOARD_USES_GENERIC_KERNEL_IMAGE != true
  ifdef INTERNAL_KERNEL_CMDLINE
    INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
  endif
  ifdef BOARD_KERNEL_BASE
    INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
  endif
  ifdef BOARD_KERNEL_PAGESIZE
    INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
  endif
endif # BUILDING_VENDOR_BOOT_IMAGE == "" && BOARD_USES_GENERIC_KERNEL_IMAGE != true

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
  $(eval kernel := $(call bootimage-to-kernel,$(1)))
  $(call build_boot_from_kernel_avb_enabled,$(1),$(kernel))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_board_avb_enabled,$@)

$(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",boot)
$(call declare-container-license-deps,$(INSTALLED_BOOTIMAGE_TARGET),$(INTERNAL_BOOTIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_BOOTIMAGE_TARGET)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_board_avb_enabled,$(b)))

else ifeq (true,$(PRODUCT_SUPPORTS_VBOOT)) # BOARD_AVB_ENABLE != true

# $1: boot image target
define build_boot_supports_vboot
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1).unsigned
  $(VBOOT_SIGNER) $(FUTILITY) $(1).unsigned $(PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(1).keyblock $(1)
  $(call assert-max-image-size,$(1),$(call get-bootimage-partition-size,$(1),boot))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES) $(VBOOT_SIGNER) $(FUTILITY)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_supports_vboot,$@)

$(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",boot)
$(call declare-container-license-deps,$(INSTALLED_BOOTIMAGE_TARGET),$(INTERNAL_BOOTIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_BOOTIMAGE_TARGET)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG) $(VBOOT_SIGNER) $(FUTILITY)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_supports_vboot,$(b)))

else # PRODUCT_SUPPORTS_VBOOT != true

# $1: boot image target
define build_boot_novboot
  $(MKBOOTIMG) --kernel $(call bootimage-to-kernel,$(1)) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $(1)
  $(call assert-max-image-size,$1,$(call get-bootimage-partition-size,$(1),boot))
endef

$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_FILES)
	$(call pretty,"Target boot image: $@")
	$(call build_boot_novboot,$@)

$(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",boot)
$(call declare-container-license-deps,$(INSTALLED_BOOTIMAGE_TARGET),$(INTERNAL_BOOTIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_BOOTIMAGE_TARGET)

.PHONY: bootimage-nodeps
bootimage-nodeps: $(MKBOOTIMG)
	@echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_BOOTIMAGE_TARGET),$(call build_boot_novboot,$(b)))

endif # BOARD_AVB_ENABLE
endif # BUILDING_BOOT_IMAGE

else # TARGET_NO_KERNEL == "true"
INSTALLED_BOOTIMAGE_TARGET :=
endif # TARGET_NO_KERNEL

else # BOARD_PREBUILT_BOOTIMAGE defined
INTERNAL_PREBUILT_BOOTIMAGE := $(BOARD_PREBUILT_BOOTIMAGE)
INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img

ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_BOOTIMAGE_TARGET): PRIVATE_WORKING_DIR := $(call intermediates-dir-for,PACKAGING,prebuilt_bootimg)
$(INSTALLED_BOOTIMAGE_TARGET): $(INTERNAL_PREBUILT_BOOTIMAGE) $(AVBTOOL) $(BOARD_AVB_BOOT_KEY_PATH) $(UNPACK_BOOTIMG)
	cp $(INTERNAL_PREBUILT_BOOTIMAGE) $@
	$(UNPACK_BOOTIMG) --boot_img $(INTERNAL_PREBUILT_BOOTIMAGE) --out $(PRIVATE_WORKING_DIR)
	chmod +w $@
	$(AVBTOOL) add_hash_footer \
	    --image $@ \
	    --salt `sha256sum $(PRIVATE_WORKING_DIR)/kernel | cut -d " " -f 1` \
	    $(call get-partition-size-argument,$(BOARD_BOOTIMAGE_PARTITION_SIZE)) \
	    --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
	    $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)


$(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",bool)
$(call declare-container-license-deps,$(INSTALLED_BOOTIMAGE_TARGET),$(INTERNAL_PREBUILT_BOOTIMAGE),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_BOOTIMAGE_TARGET)
else
$(INSTALLED_BOOTIMAGE_TARGET): $(INTERNAL_PREBUILT_BOOTIMAGE)
	cp $(INTERNAL_PREBUILT_BOOTIMAGE) $@
endif # BOARD_AVB_ENABLE

endif # BOARD_PREBUILT_BOOTIMAGE

endif # my_installed_prebuilt_gki_apex not defined

ifneq ($(BOARD_KERNEL_PATH_16K),)
BUILT_BOOT_OTA_PACKAGE_4K := $(PRODUCT_OUT)/boot_ota_4k.zip
$(BUILT_BOOT_OTA_PACKAGE_4K): $(OTA_FROM_RAW_IMG) $(INSTALLED_BOOTIMAGE_TARGET) $(BUILT_BOOTIMAGE_16K_TARGET) $(DEFAULT_SYSTEM_DEV_CERTIFICATE).pk8
	$(OTA_FROM_RAW_IMG) --package_key $(DEFAULT_SYSTEM_DEV_CERTIFICATE) \
                      --max_timestamp `cat $(BUILD_DATETIME_FILE)` \
                      --path $(HOST_OUT) \
                      --partition_name boot \
                      --output $@ \
                      $(if $(BOARD_16K_OTA_USE_INCREMENTAL),\
                        $(BUILT_BOOTIMAGE_16K_TARGET):$(INSTALLED_BOOTIMAGE_TARGET),\
                        $(INSTALLED_BOOTIMAGE_TARGET)\
                      )

boototapackage_4k: $(BUILT_BOOT_OTA_PACKAGE_4K)
.PHONY: boototapackage_4k

$(eval $(call copy-one-file,$(BUILT_BOOT_OTA_PACKAGE_4K),$(TARGET_OUT)/boot_otas/boot_ota_4k.zip))
$(eval $(call copy-one-file,$(BUILT_BOOT_OTA_PACKAGE_16K),$(TARGET_OUT)/boot_otas/boot_ota_16k.zip))

ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT)/boot_otas/boot_ota_4k.zip
ALL_DEFAULT_INSTALLED_MODULES += $(TARGET_OUT)/boot_otas/boot_ota_16k.zip


endif

my_apex_extracted_boot_image :=
my_installed_prebuilt_gki_apex :=

# -----------------------------------------------------------------
#  init boot image
ifeq ($(BUILDING_INIT_BOOT_IMAGE),true)

INSTALLED_INIT_BOOT_IMAGE_TARGET := $(PRODUCT_OUT)/init_boot.img
$(INSTALLED_INIT_BOOT_IMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_RAMDISK_TARGET)

INTERNAL_INIT_BOOT_IMAGE_ARGS := --ramdisk $(INSTALLED_RAMDISK_TARGET)

ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_INIT_BOOT_IMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_INIT_BOOT_IMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_INIT_BOOT_KEY_PATH)
	$(call pretty,"Target init_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_INIT_BOOT_IMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_INIT_ARGS) --output "$@"
	$(call assert-max-image-size,$@,$(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE))
	$(AVBTOOL) add_hash_footer \
           --image $@ \
	   $(call get-partition-size-argument,$(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE)) \
	   --partition_name init_boot $(INTERNAL_AVB_INIT_BOOT_SIGNING_ARGS) \
	   $(BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS)

$(call declare-1p-container,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),$(INTERNAL_GENERIC_RAMDISK_BOOT_SIGNATURE),$(PRODUCT_OUT)/:/)
else
$(INSTALLED_INIT_BOOT_IMAGE_TARGET):
	$(call pretty,"Target init_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_INIT_BOOT_IMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_INIT_ARGS) --output $@
	$(call assert-max-image-size,$@,$(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE))

$(call declare-1p-target,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
endif

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_INIT_BOOT_IMAGE_TARGET)

else # BUILDING_INIT_BOOT_IMAGE is not true

ifdef BOARD_PREBUILT_INIT_BOOT_IMAGE
INTERNAL_PREBUILT_INIT_BOOT_IMAGE := $(BOARD_PREBUILT_INIT_BOOT_IMAGE)
INSTALLED_INIT_BOOT_IMAGE_TARGET := $(PRODUCT_OUT)/init_boot.img

ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_INIT_BOOT_IMAGE_TARGET): $(INTERNAL_PREBUILT_INIT_BOOT_IMAGE) $(AVBTOOL) $(BOARD_AVB_INIT_BOOT_KEY_PATH)
	cp $(INTERNAL_PREBUILT_INIT_BOOT_IMAGE) $@
	chmod +w $@
	$(AVBTOOL) add_hash_footer \
	    --image $@ \
	    $(call get-partition-size-argument,$(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE)) \
	    --partition_name init_boot $(INTERNAL_AVB_INIT_BOOT_SIGNING_ARGS) \
	    $(BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS)

$(call declare-1p-container,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),$(INTERNAL_PREBUILT_INIT_BOOT_IMAGE),$(PRODUCT_OUT)/:/)
else
$(INSTALLED_INIT_BOOT_IMAGE_TARGET): $(INTERNAL_PREBUILT_INIT_BOOT_IMAGE)
	cp $(INTERNAL_PREBUILT_INIT_BOOT_IMAGE) $@

$(call declare-1p-target,$(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
endif # BOARD_AVB_ENABLE

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_INIT_BOOT_IMAGE_TARGET)

else # BOARD_PREBUILT_INIT_BOOT_IMAGE not defined
INSTALLED_INIT_BOOT_IMAGE_TARGET :=
endif # BOARD_PREBUILT_INIT_BOOT_IMAGE

endif # BUILDING_INIT_BOOT_IMAGE is not true

# -----------------------------------------------------------------
# vendor boot image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_VENDOR_RAMDISK_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifeq ($(BUILDING_VENDOR_BOOT_IMAGE),true)

INTERNAL_VENDOR_RAMDISK_FILES := $(filter $(TARGET_VENDOR_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

INTERNAL_VENDOR_RAMDISK_TARGET := $(call intermediates-dir-for,PACKAGING,vendor_boot)/vendor_ramdisk.cpio$(RAMDISK_EXT)

# Exclude recovery files in the default vendor ramdisk if including a standalone
# recovery ramdisk in vendor_boot.
ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
ifneq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
$(INTERNAL_VENDOR_RAMDISK_TARGET): $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
$(INTERNAL_VENDOR_RAMDISK_TARGET): PRIVATE_ADDITIONAL_DIR := $(TARGET_RECOVERY_ROOT_OUT)
endif
endif

$(INTERNAL_VENDOR_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_VENDOR_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_VENDOR_RAMDISK_OUT) $(PRIVATE_ADDITIONAL_DIR) | $(COMPRESSION_COMMAND) > $@

INSTALLED_VENDOR_RAMDISK_TARGET := $(PRODUCT_OUT)/vendor_ramdisk.img
$(INSTALLED_VENDOR_RAMDISK_TARGET): $(INTERNAL_VENDOR_RAMDISK_TARGET)
	@echo "Target vendor ramdisk: $@"
	$(copy-file-to-target)

$(call declare-1p-container,$(INSTALLED_VENDOR_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_RAMDISK_TARGET),$(INTERNAL_VENDOR_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_RAMDISK_TARGET)

INSTALLED_FILES_FILE_VENDOR_RAMDISK := $(PRODUCT_OUT)/installed-files-vendor-ramdisk.txt
INSTALLED_FILES_JSON_VENDOR_RAMDISK := $(INSTALLED_FILES_FILE_VENDOR_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_RAMDISK)
$(INSTALLED_FILES_FILE_VENDOR_RAMDISK): $(INTERNAL_VENDOR_RAMDISK_TARGET)
$(INSTALLED_FILES_FILE_VENDOR_RAMDISK): $(INTERNAL_VENDOR_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_VENDOR_RAMDISK_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE_VENDOR_RAMDISK)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON_VENDOR_RAMDISK)))

ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  ifneq ($(BUILDING_VENDOR_KERNEL_BOOT_IMAGE),true)
    # If we have vendor_kernel_boot partition, we migrate dtb image to that image
    # and allow dtb in vendor_boot to be empty.
    INTERNAL_VENDOR_BOOTIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
  endif
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

ifdef INTERNAL_BOOTCONFIG
  INTERNAL_VENDOR_BOOTCONFIG_TARGET := $(PRODUCT_OUT)/vendor-bootconfig.img
  $(INTERNAL_VENDOR_BOOTCONFIG_TARGET):
	rm -f $@
	$(foreach param,$(INTERNAL_BOOTCONFIG), \
	 printf "%s\n" $(param) >> $@;)
  INTERNAL_VENDOR_BOOTIMAGE_ARGS += --vendor_bootconfig $(INTERNAL_VENDOR_BOOTCONFIG_TARGET)
endif

# $(1): Build target name
# $(2): Staging dir to be compressed
# $(3): Build dependencies
define build-vendor-ramdisk-fragment-target
$(1): $(3) $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(2) | $(COMPRESSION_COMMAND) > $$@
endef

# $(1): Ramdisk name
define build-vendor-ramdisk-fragment
$(strip \
  $(eval build_target := $(call intermediates-dir-for,PACKAGING,vendor_ramdisk_fragments)/$(1).cpio$(RAMDISK_EXT)) \
  $(eval $(call build-vendor-ramdisk-fragment-target,$(build_target),$(VENDOR_RAMDISK_FRAGMENT.$(1).STAGING_DIR),$(VENDOR_RAMDISK_FRAGMENT.$(1).FILES))) \
  $(build_target) \
)
endef

# $(1): Ramdisk name
# $(2): Prebuilt file path
define build-prebuilt-vendor-ramdisk-fragment
$(strip \
  $(eval build_target := $(call intermediates-dir-for,PACKAGING,prebuilt_vendor_ramdisk_fragments)/$(1)) \
  $(eval $(call copy-one-file,$(2),$(build_target))) \
  $(build_target) \
)
endef

INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS :=
INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS :=

$(foreach vendor_ramdisk_fragment,$(INTERNAL_VENDOR_RAMDISK_FRAGMENTS), \
  $(eval prebuilt_vendor_ramdisk_fragment_file := $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).PREBUILT)) \
  $(if $(prebuilt_vendor_ramdisk_fragment_file), \
    $(eval vendor_ramdisk_fragment_target := $(call build-prebuilt-vendor-ramdisk-fragment,$(vendor_ramdisk_fragment),$(prebuilt_vendor_ramdisk_fragment_file))) \
    $(eval ### else ###), \
    $(eval vendor_ramdisk_fragment_target := $(call build-vendor-ramdisk-fragment,$(vendor_ramdisk_fragment)))) \
  $(eval INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS += $(vendor_ramdisk_fragment_target)) \
  $(eval INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS += $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS) --vendor_ramdisk_fragment $(vendor_ramdisk_fragment_target)) \
)

INSTALLED_VENDOR_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/vendor_boot.img
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_DTBIMAGE_TARGET)
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS) $(INTERNAL_VENDOR_BOOTCONFIG_TARGET)
ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_BOOTIMAGE_KEY_PATH)
	$(call pretty,"Target vendor_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
	$(AVBTOOL) add_hash_footer \
           --image $@ \
	   $(call get-partition-size-argument,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE)) \
	   --partition_name vendor_boot $(INTERNAL_AVB_VENDOR_BOOT_SIGNING_ARGS) \
	   $(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)
else
$(INSTALLED_VENDOR_BOOTIMAGE_TARGET):
	$(call pretty,"Target vendor_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
endif

$(call declare-1p-container,$(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_BOOTIMAGE_TARGET),$(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_DTB_IMAGE_TARGET) $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS) $(INTERNAL_VENDOR_BOOTCONDIG_TARGET),$(PRODUCT_OUT)/:/)
VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_BOOTIMAGE_TARGET)
endif # BUILDING_VENDOR_BOOT_IMAGE

# -----------------------------------------------------------------
# vendor kernel boot image
ifeq ($(BUILDING_VENDOR_KERNEL_BOOT_IMAGE),true)

INTERNAL_VENDOR_KERNEL_RAMDISK_FILES := $(filter $(TARGET_VENDOR_KERNEL_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET := $(call intermediates-dir-for,PACKAGING,vendor_kernel_boot)/vendor_kernel_ramdisk.cpio$(RAMDISK_EXT)

$(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET): $(MKBOOTFS) $(INTERNAL_VENDOR_KERNEL_RAMDISK_FILES) | $(COMPRESSION_COMMAND_DEPS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(TARGET_VENDOR_KERNEL_RAMDISK_OUT) | $(COMPRESSION_COMMAND) > $@

INSTALLED_VENDOR_KERNEL_RAMDISK_TARGET := $(PRODUCT_OUT)/vendor_kernel_ramdisk.img
$(INSTALLED_VENDOR_KERNEL_RAMDISK_TARGET): $(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET)
	@echo "Target vendor kernel ramdisk: $@"
	$(copy-file-to-target)

INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK := $(PRODUCT_OUT)/installed-files-vendor-kernel-ramdisk.txt
INSTALLED_FILES_JSON_VENDOR_KERNEL_RAMDISK := $(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_KERNEL_RAMDISK)
$(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK): $(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET)
$(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK): $(INTERNAL_VENDOR_KERNEL_RAMDISK_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_VENDOR_KERNEL_RAMDISK_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_VENDOR_KERNEL_RAMDISK))

INTERNAL_VENDOR_KERNEL_BOOTIMAGE_ARGS := --vendor_ramdisk $(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET)
INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/vendor_kernel_boot.img
$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET)

ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
  INTERNAL_VENDOR_KERNEL_BOOTIMAGE_ARGS += --dtb $(INSTALLED_DTBIMAGE_TARGET)
  $(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET): $(INSTALLED_DTBIMAGE_TARGET)
endif
ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_VENDOR_KERNEL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif


ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_KERNEL_BOOTIMAGE_KEY_PATH)
	$(call pretty,"Target vendor_kernel_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_KERNEL_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE))
	$(AVBTOOL) add_hash_footer \
	    --image $@ \
	   $(call get-partition-size-argument,$(BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE)) \
	   --partition_name vendor_kernel_boot $(INTERNAL_AVB_VENDOR_KERNEL_BOOT_SIGNING_ARGS) \
	   $(BOARD_AVB_VENDOR_KERNEL_BOOT_ADD_HASH_FOOTER_ARGS)
else
$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET):
	$(call pretty,"Target vendor_kernel_boot image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_KERNEL_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE))
endif
$(call declare-1p-container,$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET),)
ifdef BOARD_INCLUDE_DTB_IN_BOOTIMG
$(call declare-container-license-deps,$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET),\
    $(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET) $(INSTALLED_DTBIMAGE_TARGET),\
    $(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET):)
else
$(call declare-container-license-deps,$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET),$(INTERNAL_VENDOR_KERNEL_RAMDISK_TARGET),$(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET):)
endif
endif # BUILDING_VENDOR_KERNEL_BOOT_IMAGE

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

# Convert license metadata into xml notice file.
# $(1) - Output target notice filename
# $(2) - Product name
# $(3) - File title
# $(4) - License metadata file roots
# $(5) - Prefixes to strip
#
define xml-notice-rule
$(1): PRIVATE_PRODUCT := $(2)
$(1): PRIVATE_MESSAGE := $(3)
$(1): PRIVATE_DEPS := $(call corresponding-license-metadata,$(4))
$(1): $(call corresponding-license-metadata,$(4)) $(XMLNOTICE) $(BUILD_SYSTEM)/Makefile
	OUT_DIR=$(OUT_DIR) $(XMLNOTICE) -o $$@ -product=$$(PRIVATE_PRODUCT) -title=$$(PRIVATE_MESSAGE) $(foreach prefix, $(5), -strip_prefix=$(prefix)) $$(PRIVATE_DEPS)

notice_files: $(1)
endef

# Convert license metadata into text notice file.
# $(1) - Output target notice filename
# $(2) - Product name
# $(3) - File title
# $(4) - License metadata file roots
# $(5) - Prefixes to strip
#
define text-notice-rule
$(1): PRIVATE_PRODUCT := $(2)
$(1): PRIVATE_MESSAGE := $(3)
$(1): $(call corresponding-license-metadata,$(4)) $(TEXTNOTICE) $(BUILD_SYSTEM)/Makefile
	OUT_DIR=$(OUT_DIR) $(TEXTNOTICE) -o $$@ -product=$$(PRIVATE_PRODUCT) -title=$$(PRIVATE_MESSAGE) $(foreach prefix, $(5), -strip_prefix=$(prefix)) $(call corresponding-license-metadata,$(4))

notice_files: $(1)
endef

# Conversion license metadata into html notice file.
# $(1) - Output target notice filename
# $(2) - Product name
# $(3) - File title
# $(4) - License metadata file roots
# $(5) - Prefixes to strip
#
define html-notice-rule
$(1): PRIVATE_PRODUCT := $(2)
$(1): PRIVATE_MESSAGE := $(3)
$(1): $(call corresponding-license-metadata,$(4)) $(HTMLNOTICE) $(BUILD_SYSTEM)/Makefile
	OUT_DIR=$(OUT_DIR) $(HTMLNOTICE) -o $$@ -product=$$(PRIVATE_PRODUCT) -title=$$(PRIVATE_MESSAGE) $(foreach prefix, $(5), -strip_prefix=$(prefix)) $(call corresponding-license-metadata,$(4))

notice_files: $(1)
endef

$(KATI_obsolete_var combine-notice-files, To create notice files use xml-notice-rule, html-notice-rule, or text-notice-rule.)

# Notice file logic isn't relevant for TARGET_BUILD_APPS
ifndef TARGET_BUILD_APPS

# TODO These intermediate NOTICE.txt/NOTICE.html files should go into
# TARGET_OUT_NOTICE_FILES now that the notice files are gathered from
# the src subdirectory.
kernel_notice_file := $(TARGET_OUT_NOTICE_FILES)/src/kernel.txt

# Some targets get included under $(PRODUCT_OUT) for debug symbols or other
# reasons--not to be flashed onto any device. Targets under these directories
# need no associated notice file on the device UI.
exclude_target_dirs := apex

# TODO(b/69865032): Make PRODUCT_NOTICE_SPLIT the default behavior.
ifneq ($(PRODUCT_NOTICE_SPLIT),true)
#target_notice_file_html := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html
target_notice_file_html_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.html.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.html.gz

$(call declare-0p-target,$(target_notice_file_html_gz))
$(call declare-0p-target,$(installed_notice_html_or_xml_gz))
else
# target_notice_file_xml := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml
target_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE.xml.gz
installed_notice_html_or_xml_gz := $(TARGET_OUT)/etc/NOTICE.xml.gz

target_vendor_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.txt
target_vendor_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR.xml.gz
installed_vendor_notice_xml_gz := $(TARGET_OUT_VENDOR)/etc/NOTICE.xml.gz

target_product_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_PRODUCT.txt
target_product_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_PRODUCT.xml.gz
installed_product_notice_xml_gz := $(TARGET_OUT_PRODUCT)/etc/NOTICE.xml.gz

target_system_ext_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_EXT.txt
target_system_ext_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_EXT.xml.gz
installed_system_ext_notice_xml_gz := $(TARGET_OUT_SYSTEM_EXT)/etc/NOTICE.xml.gz

target_odm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM.txt
target_odm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM.xml.gz
installed_odm_notice_xml_gz := $(TARGET_OUT_ODM)/etc/NOTICE.xml.gz

target_vendor_dlkm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR_DLKM.txt
target_vendor_dlkm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_VENDOR_DLKM.xml.gz
installed_vendor_dlkm_notice_xml_gz := $(TARGET_OUT_VENDOR_DLKM)/etc/NOTICE.xml.gz

target_odm_dlkm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM_DLKM.txt
target_odm_dlkm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_ODM_DLKM.xml.gz
installed_odm_dlkm_notice_xml_gz := $(TARGET_OUT_ODM_DLKM)/etc/NOTICE.xml.gz

target_system_dlkm_notice_file_txt := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_DLKM.txt
target_system_dlkm_notice_file_xml_gz := $(TARGET_OUT_INTERMEDIATES)/NOTICE_SYSTEM_DLKM.xml.gz
installed_system_dlkm_notice_xml_gz := $(TARGET_OUT_SYSTEM_DLKM)/etc/NOTICE.xml.gz

ALL_INSTALLED_NOTICE_FILES := \
  $(installed_notice_html_or_xml_gz) \
  $(installed_vendor_notice_xml_gz) \
  $(installed_product_notice_xml_gz) \
  $(installed_system_ext_notice_xml_gz) \
  $(installed_odm_notice_xml_gz) \
  $(installed_vendor_dlkm_notice_xml_gz) \
  $(installed_odm_dlkm_notice_xml_gz) \
  $(installed_system_dlkm_notice_xml_gz) \

# $1 installed file path, e.g. out/target/product/vsoc_x86_64/system_ext/etc/NOTICE.xml.gz
define is-notice-file
$(if $(findstring $1,$(ALL_INSTALLED_NOTICE_FILES)),Y)
endef

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
license_modules_odm_dlkm := $(filter $(TARGET_OUT_SYSTEM_DLKM)/%,$(license_modules))
license_modules_agg := $(license_modules_system) \
                       $(license_modules_vendor) \
                       $(license_modules_product) \
                       $(license_modules_system_ext) \
                       $(license_modules_odm) \
                       $(license_modules_vendor_dlkm) \
                       $(license_modules_odm_dlkm) \
                       $(license_modules_system_dlkm)
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
license_modules_rehomed += $(filter $(PRODUCT_OUT)/vendor_ramdisk/%,$(license_modules_rest))
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

endif # PRODUCT_NOTICE_SPLIT

ALL_DEFAULT_INSTALLED_MODULES += $(installed_notice_html_or_xml_gz)

need_vendor_notice:=false
ifeq ($(BUILDING_VENDOR_BOOT_IMAGE),true)
   need_vendor_notice:=true
endif

ifdef BUILDING_DEBUG_VENDOR_BOOT_IMAGE
   need_vendor_notice:=true
endif

ifdef BUILDING_VENDOR_IMAGE
   need_vendor_notice:=true
endif

ifeq (true,$(need_vendor_notice))
ifneq (,$(installed_vendor_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_vendor_notice_xml_gz)
endif
endif

need_vendor_notice:=

ifdef BUILDING_ODM_IMAGE
ifneq (,$(installed_odm_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_odm_notice_xml_gz)
endif
endif

ifdef BUILDING_PRODUCT_IMAGE
ifneq (,$(installed_product_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_product_notice_xml_gz)
endif
endif

ifdef BUILDING_SYSTEM_EXT_IMAGE
ifneq (,$(installed_system_ext_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_system_ext_notice_xml_gz)
endif
endif

ifdef BUILDING_VENDOR_DLKM_IMAGE
ifneq (,$(installed_vendor_dlkm_notice_xml_gz)
ALL_DEFAULT_INSTALLED_MODULES += $(installed_vendor_dlkm_notice_xml_gz)
endif
endif

ifdef BUILDING_ODM_DLKM_IMAGE
ifneq (,$(installed_odm_dlkm_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_odm_dlkm_notice_xml_gz)
endif
endif

ifdef BUILDING_SYSTEM_DLKM_IMAGE
ifneq (,$(installed_system_dlkm_notice_xml_gz))
ALL_DEFAULT_INSTALLED_MODULES += $(installed_system_dlkm_notice_xml_gz)
endif
endif

endif  # TARGET_BUILD_APPS

# Presently none of the prebuilts etc. comply with policy to have a license text. Fake one here.
$(eval $(call copy-one-file,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,$(kernel_notice_file)))

ifneq (,$(strip $(INSTALLED_KERNEL_TARGET)))
$(call declare-license-metadata,$(INSTALLED_KERNEL_TARGET),SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,"Kernel",kernel)
endif

# No matter where it gets copied from, a copied linux kernel is licensed under "GPL 2.0 only"
$(eval $(call declare-copy-files-license-metadata,,:kernel,SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,kernel))


# #################################################################
# Targets for user images
# #################################################################

# These options tell the recovery updater/installer how to mount the partitions writebale.
# <fstype>=<fstype_opts>[|<fstype_opts>]...
# fstype_opts := <opt>[,<opt>]...
#         opt := <name>[=<value>]
# The following worked on Nexus devices with Kernel 3.1, 3.4, 3.10
DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS := ext4=max_batch_time=0,commit=1,data=ordered,barrier=1,errors=panic,nodelalloc

INTERNAL_USERIMAGES_DEPS := \
    $(BUILD_IMAGE) \
    $(MKE2FS_CONF) \
    $(MKEXTUSERIMG)

$(call declare-1p-target,$(MKE2FS_CONF),system/extras)

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
    $(BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE) \
  ,erofs),)
INTERNAL_USERIMAGES_DEPS += $(MKEROFS)
ifeq ($(BOARD_EROFS_USE_LEGACY_COMPRESSION),true)
BOARD_EROFS_COMPRESSOR ?= "lz4"
else
BOARD_EROFS_COMPRESSOR ?= "lz4hc,9"
endif
endif

ifneq ($(filter \
    $(BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_ODMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE) \
    $(BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE) \
  ,squashfs),)
INTERNAL_USERIMAGES_DEPS += $(MKSQUASHFSUSERIMG)
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

# $(1) the partition name (eg system)
# $(2) the image prop file
define add-common-flags-to-image-props
$(eval _var := $(call to-upper,$(1)))
$(hide) echo "$(1)_selinux_fc=$(SELINUX_FC)" >> $(2)
$(hide) echo "building_$(1)_image=$(BUILDING_$(_var)_IMAGE)" >> $(2)
endef

# $(1) the partition name (eg system)
# $(2) the image prop file
define add-common-ro-flags-to-image-props
$(eval _var := $(call to-upper,$(1)))
$(if $(BOARD_$(_var)IMAGE_EROFS_COMPRESSOR),$(hide) echo "$(1)_erofs_compressor=$(BOARD_$(_var)IMAGE_EROFS_COMPRESSOR)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_EROFS_COMPRESS_HINTS),$(hide) echo "$(1)_erofs_compress_hints=$(BOARD_$(_var)IMAGE_EROFS_COMPRESS_HINTS)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_EROFS_PCLUSTER_SIZE),$(hide) echo "$(1)_erofs_pcluster_size=$(BOARD_$(_var)IMAGE_EROFS_PCLUSTER_SIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_EROFS_BLOCKSIZE),$(hide) echo "$(1)_erofs_blocksize=$(BOARD_$(_var)IMAGE_EROFS_BLOCKSIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_EXTFS_INODE_COUNT),$(hide) echo "$(1)_extfs_inode_count=$(BOARD_$(_var)IMAGE_EXTFS_INODE_COUNT)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_EXTFS_RSV_PCT),$(hide) echo "$(1)_extfs_rsv_pct=$(BOARD_$(_var)IMAGE_EXTFS_RSV_PCT)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_F2FS_SLOAD_COMPRESS_FLAGS),$(hide) echo "$(1)_f2fs_sldc_flags=$(BOARD_$(_var)IMAGE_F2FS_SLOAD_COMPRESS_FLAGS)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_F2FS_BLOCKSIZE),$(hide) echo "$(1)_f2fs_blocksize=$(BOARD_$(_var)IMAGE_F2FS_BLOCKSIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_FILE_SYSTEM_COMPRESS),$(hide) echo "$(1)_f2fs_compress=$(BOARD_$(_var)IMAGE_FILE_SYSTEM_COMPRESS)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_FILE_SYSTEM_TYPE),$(hide) echo "$(1)_fs_type=$(BOARD_$(_var)IMAGE_FILE_SYSTEM_TYPE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_JOURNAL_SIZE),$(hide) echo "$(1)_journal_size=$(BOARD_$(_var)IMAGE_JOURNAL_SIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_PARTITION_RESERVED_SIZE),$(hide) echo "$(1)_reserved_size=$(BOARD_$(_var)IMAGE_PARTITION_RESERVED_SIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_PARTITION_SIZE),$(hide) echo "$(1)_size=$(BOARD_$(_var)IMAGE_PARTITION_SIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_SQUASHFS_BLOCK_SIZE),$(hide) echo "$(1)_squashfs_block_size=$(BOARD_$(_var)IMAGE_SQUASHFS_BLOCK_SIZE)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_SQUASHFS_COMPRESSOR),$(hide) echo "$(1)_squashfs_compressor=$(BOARD_$(_var)IMAGE_SQUASHFS_COMPRESSOR)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_SQUASHFS_COMPRESSOR_OPT),$(hide) echo "$(1)_squashfs_compressor_opt=$(BOARD_$(_var)IMAGE_SQUASHFS_COMPRESSOR_OPT)" >> $(2))
$(if $(BOARD_$(_var)IMAGE_SQUASHFS_DISABLE_4K_ALIGN),$(hide) echo "$(1)_squashfs_disable_4k_align=$(BOARD_$(_var)IMAGE_SQUASHFS_DISABLE_4K_ALIGN)" >> $(2))
$(if $(PRODUCT_$(_var)_BASE_FS_PATH),$(hide) echo "$(1)_base_fs_file=$(PRODUCT_$(_var)_BASE_FS_PATH)" >> $(2))
$(eval _size := $(BOARD_$(_var)IMAGE_PARTITION_SIZE))
$(eval _reserved := $(BOARD_$(_var)IMAGE_PARTITION_RESERVED_SIZE))
$(eval _headroom := $(PRODUCT_$(_var)_HEADROOM))
$(if $(or $(_size), $(_reserved), $(_headroom)),,
    $(hide) echo "$(1)_disable_sparse=true" >> $(2))
$(call add-common-flags-to-image-props,$(1),$(2))
endef

# $(1): the path of the output dictionary file
# $(2): a subset of "system vendor cache userdata product system_ext oem odm vendor_dlkm odm_dlkm system_dlkm"
# $(3): additional "key=value" pairs to append to the dictionary file.
define generate-image-prop-dictionary
$(if $(filter $(2),system),\
    $(if $(INTERNAL_SYSTEM_OTHER_PARTITION_SIZE),$(hide) echo "system_other_size=$(INTERNAL_SYSTEM_OTHER_PARTITION_SIZE)" >> $(1))
    $(if $(PRODUCT_SYSTEM_HEADROOM),$(hide) echo "system_headroom=$(PRODUCT_SYSTEM_HEADROOM)" >> $(1))
    $(call add-common-ro-flags-to-image-props,system,$(1))
)
$(if $(filter $(2),system_other),\
    $(hide) echo "building_system_other_image=$(BUILDING_SYSTEM_OTHER_IMAGE)" >> $(1)
    $(if $(INTERNAL_SYSTEM_OTHER_PARTITION_SIZE),,
        $(hide) echo "system_other_disable_sparse=true" >> $(1))
)
$(if $(filter $(2),userdata),\
    $(if $(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "userdata_fs_type=$(BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_USERDATAIMAGE_PARTITION_SIZE),$(hide) echo "userdata_size=$(BOARD_USERDATAIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(PRODUCT_FS_CASEFOLD),$(hide) echo "needs_casefold=$(PRODUCT_FS_CASEFOLD)" >> $(1))
    $(if $(PRODUCT_QUOTA_PROJID),$(hide) echo "needs_projid=$(PRODUCT_QUOTA_PROJID)" >> $(1))
    $(if $(PRODUCT_FS_COMPRESSION),$(hide) echo "needs_compress=$(PRODUCT_FS_COMPRESSION)" >> $(1))
    $(call add-common-flags-to-image-props,userdata,$(1))
)
$(if $(filter $(2),cache),\
    $(if $(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE),$(hide) echo "cache_fs_type=$(BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE)" >> $(1))
    $(if $(BOARD_CACHEIMAGE_PARTITION_SIZE),$(hide) echo "cache_size=$(BOARD_CACHEIMAGE_PARTITION_SIZE)" >> $(1))
    $(call add-common-flags-to-image-props,cache,$(1))
)
$(if $(filter $(2),vendor),\
    $(call add-common-ro-flags-to-image-props,vendor,$(1))
)
$(if $(filter $(2),product),\
    $(call add-common-ro-flags-to-image-props,product,$(1))
)
$(if $(filter $(2),system_ext),\
    $(call add-common-ro-flags-to-image-props,system_ext,$(1))
)
$(if $(filter $(2),odm),\
    $(call add-common-ro-flags-to-image-props,odm,$(1))
)
$(if $(filter $(2),vendor_dlkm),\
    $(call add-common-ro-flags-to-image-props,vendor_dlkm,$(1))
)
$(if $(filter $(2),odm_dlkm),\
    $(call add-common-ro-flags-to-image-props,odm_dlkm,$(1))
)
$(if $(filter $(2),system_dlkm),\
    $(call add-common-ro-flags-to-image-props,system_dlkm,$(1))
)
$(if $(filter $(2),oem),\
    $(if $(BOARD_OEMIMAGE_PARTITION_SIZE),$(hide) echo "oem_size=$(BOARD_OEMIMAGE_PARTITION_SIZE)" >> $(1))
    $(if $(BOARD_OEMIMAGE_JOURNAL_SIZE),$(hide) echo "oem_journal_size=$(BOARD_OEMIMAGE_JOURNAL_SIZE)" >> $(1))
    $(if $(BOARD_OEMIMAGE_EXTFS_INODE_COUNT),$(hide) echo "oem_extfs_inode_count=$(BOARD_OEMIMAGE_EXTFS_INODE_COUNT)" >> $(1))
    $(if $(BOARD_OEMIMAGE_EXTFS_RSV_PCT),$(hide) echo "oem_extfs_rsv_pct=$(BOARD_OEMIMAGE_EXTFS_RSV_PCT)" >> $(1))
    $(call add-common-flags-to-image-props,oem,$(1))
)
$(hide) echo "ext_mkuserimg=$(notdir $(MKEXTUSERIMG))" >> $(1)

$(if $(filter true,$(TARGET_USERIMAGES_USE_EXT2)),$(hide) echo "fs_type=ext2" >> $(1),
  $(if $(filter true,$(TARGET_USERIMAGES_USE_EXT3)),$(hide) echo "fs_type=ext3" >> $(1),
    $(if $(filter true,$(TARGET_USERIMAGES_USE_EXT4)),$(hide) echo "fs_type=ext4" >> $(1))))

$(if $(filter true,$(TARGET_USERIMAGES_SPARSE_EXT_DISABLED)),,$(hide) echo "extfs_sparse_flag=-s" >> $(1))
$(if $(filter true,$(TARGET_USERIMAGES_SPARSE_EROFS_DISABLED)),,$(hide) echo "erofs_sparse_flag=-s" >> $(1))
$(if $(filter true,$(TARGET_USERIMAGES_SPARSE_SQUASHFS_DISABLED)),,$(hide) echo "squashfs_sparse_flag=-s" >> $(1))
$(if $(filter true,$(TARGET_USERIMAGES_SPARSE_F2FS_DISABLED)),,$(hide) echo "f2fs_sparse_flag=-S" >> $(1))
$(if $(BOARD_EROFS_COMPRESSOR),$(hide) echo "erofs_default_compressor=$(BOARD_EROFS_COMPRESSOR)" >> $(1))
$(if $(BOARD_EROFS_COMPRESS_HINTS),$(hide) echo "erofs_default_compress_hints=$(BOARD_EROFS_COMPRESS_HINTS)" >> $(1))
$(if $(BOARD_EROFS_PCLUSTER_SIZE),$(hide) echo "erofs_pcluster_size=$(BOARD_EROFS_PCLUSTER_SIZE)" >> $(1))
$(if $(BOARD_EROFS_BLOCKSIZE),$(hide) echo "erofs_blocksize=$(BOARD_EROFS_BLOCKSIZE)" >> $(1))
$(if $(BOARD_EROFS_SHARE_DUP_BLOCKS),$(hide) echo "erofs_share_dup_blocks=$(BOARD_EROFS_SHARE_DUP_BLOCKS)" >> $(1))
$(if $(BOARD_EROFS_USE_LEGACY_COMPRESSION),$(hide) echo "erofs_use_legacy_compression=$(BOARD_EROFS_USE_LEGACY_COMPRESSION)" >> $(1))
$(if $(BOARD_EXT4_SHARE_DUP_BLOCKS),$(hide) echo "ext4_share_dup_blocks=$(BOARD_EXT4_SHARE_DUP_BLOCKS)" >> $(1))
$(if $(BOARD_F2FS_BLOCKSIZE),$(hide) echo "f2fs_blocksize=$(BOARD_F2FS_BLOCKSIZE)" >> $(1))
$(if $(BOARD_FLASH_LOGICAL_BLOCK_SIZE), $(hide) echo "flash_logical_block_size=$(BOARD_FLASH_LOGICAL_BLOCK_SIZE)" >> $(1))
$(if $(BOARD_FLASH_ERASE_BLOCK_SIZE), $(hide) echo "flash_erase_block_size=$(BOARD_FLASH_ERASE_BLOCK_SIZE)" >> $(1))
$(if $(filter eng, $(TARGET_BUILD_VARIANT)),$(hide) echo "verity_disable=true" >> $(1))
$(if $(PRODUCT_SYSTEM_VERITY_PARTITION),$(hide) echo "system_verity_block_device=$(PRODUCT_SYSTEM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_VENDOR_VERITY_PARTITION),$(hide) echo "vendor_verity_block_device=$(PRODUCT_VENDOR_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_PRODUCT_VERITY_PARTITION),$(hide) echo "product_verity_block_device=$(PRODUCT_PRODUCT_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_SYSTEM_EXT_VERITY_PARTITION),$(hide) echo "system_ext_verity_block_device=$(PRODUCT_SYSTEM_EXT_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_VENDOR_DLKM_VERITY_PARTITION),$(hide) echo "vendor_dlkm_verity_block_device=$(PRODUCT_VENDOR_DLKM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_ODM_DLKM_VERITY_PARTITION),$(hide) echo "odm_dlkm_verity_block_device=$(PRODUCT_ODM_DLKM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_SYSTEM_DLKM_VERITY_PARTITION),$(hide) echo "system_dlkm_verity_block_device=$(PRODUCT_SYSTEM_DLKM_VERITY_PARTITION)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot=$(PRODUCT_SUPPORTS_VBOOT)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_key=$(PRODUCT_VBOOT_SIGNING_KEY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_subkey=$(PRODUCT_VBOOT_SIGNING_SUBKEY)" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "futility=$(notdir $(FUTILITY))" >> $(1))
$(if $(PRODUCT_SUPPORTS_VBOOT),$(hide) echo "vboot_signer_cmd=$(VBOOT_SIGNER)" >> $(1))
$(if $(BOARD_AVB_ENABLE), \
  $(hide) echo "avb_avbtool=$(notdir $(AVBTOOL))" >> $(1)$(newline) \
  $(if $(filter $(2),system), \
    $(hide) echo "avb_system_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_system_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_SYSTEM_KEY_PATH), \
      $(hide) echo "avb_system_key_path=$(BOARD_AVB_SYSTEM_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_system_algorithm=$(BOARD_AVB_SYSTEM_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_system_rollback_index_location=$(BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),system_other), \
    $(hide) echo "avb_system_other_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_system_other_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_OTHER_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_SYSTEM_OTHER_KEY_PATH),\
      $(hide) echo "avb_system_other_key_path=$(BOARD_AVB_SYSTEM_OTHER_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_system_other_algorithm=$(BOARD_AVB_SYSTEM_OTHER_ALGORITHM)" >> $(1)$(newline))) \
  $(if $(filter $(2),vendor), \
    $(hide) echo "avb_vendor_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_vendor_add_hashtree_footer_args=$(BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_VENDOR_KEY_PATH),\
      $(hide) echo "avb_vendor_key_path=$(BOARD_AVB_VENDOR_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_vendor_algorithm=$(BOARD_AVB_VENDOR_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_vendor_rollback_index_location=$(BOARD_AVB_VENDOR_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),product), \
    $(hide) echo "avb_product_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_product_add_hashtree_footer_args=$(BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_PRODUCT_KEY_PATH),\
      $(hide) echo "avb_product_key_path=$(BOARD_AVB_PRODUCT_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_product_algorithm=$(BOARD_AVB_PRODUCT_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_product_rollback_index_location=$(BOARD_AVB_PRODUCT_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),system_ext), \
    $(hide) echo "avb_system_ext_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_system_ext_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_SYSTEM_EXT_KEY_PATH),\
      $(hide) echo "avb_system_ext_key_path=$(BOARD_AVB_SYSTEM_EXT_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_system_ext_algorithm=$(BOARD_AVB_SYSTEM_EXT_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_system_ext_rollback_index_location=$(BOARD_AVB_SYSTEM_EXT_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),odm), \
    $(hide) echo "avb_odm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_odm_add_hashtree_footer_args=$(BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_ODM_KEY_PATH),\
      $(hide) echo "avb_odm_key_path=$(BOARD_AVB_ODM_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_odm_algorithm=$(BOARD_AVB_ODM_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_odm_rollback_index_location=$(BOARD_AVB_ODM_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),vendor_dlkm), \
    $(hide) echo "avb_vendor_dlkm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_vendor_dlkm_add_hashtree_footer_args=$(BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_VENDOR_DLKM_KEY_PATH),\
      $(hide) echo "avb_vendor_dlkm_key_path=$(BOARD_AVB_VENDOR_DLKM_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_vendor_dlkm_algorithm=$(BOARD_AVB_VENDOR_DLKM_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_vendor_dlkm_rollback_index_location=$(BOARD_AVB_VENDOR_DLKM_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),odm_dlkm), \
    $(hide) echo "avb_odm_dlkm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_odm_dlkm_add_hashtree_footer_args=$(BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_ODM_DLKM_KEY_PATH),\
      $(hide) echo "avb_odm_dlkm_key_path=$(BOARD_AVB_ODM_DLKM_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_odm_dlkm_algorithm=$(BOARD_AVB_ODM_DLKM_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_odm_dlkm_rollback_index_location=$(BOARD_AVB_ODM_DLKM_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
  $(if $(filter $(2),system_dlkm), \
    $(hide) echo "avb_system_dlkm_hashtree_enable=$(BOARD_AVB_ENABLE)" >> $(1)$(newline) \
    $(hide) echo "avb_system_dlkm_add_hashtree_footer_args=$(BOARD_AVB_SYSTEM_DLKM_ADD_HASHTREE_FOOTER_ARGS)" >> $(1)$(newline) \
    $(if $(BOARD_AVB_SYSTEM_DLKM_KEY_PATH),\
      $(hide) echo "avb_system_dlkm_key_path=$(BOARD_AVB_SYSTEM_DLKM_KEY_PATH)" >> $(1)$(newline) \
      $(hide) echo "avb_system_dlkm_algorithm=$(BOARD_AVB_SYSTEM_DLKM_ALGORITHM)" >> $(1)$(newline) \
      $(hide) echo "avb_system_dlkm_rollback_index_location=$(BOARD_SYSTEM_SYSTEM_DLKM_ROLLBACK_INDEX_LOCATION)" >> $(1)$(newline))) \
)
$(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)),\
    $(hide) echo "recovery_as_boot=true" >> $(1))
$(hide) echo "root_dir=$(TARGET_ROOT_OUT)" >> $(1)
$(if $(filter true,$(PRODUCT_USE_DYNAMIC_PARTITION_SIZE)),\
    $(hide) echo "use_dynamic_partition_size=true" >> $(1))
$(if $(COPY_IMAGES_FOR_TARGET_FILES_ZIP),\
    $(hide) echo "use_fixed_timestamp=true" >> $(1))
$(if $(3),$(hide) $(foreach kv,$(3),echo "$(kv)" >> $(1);))
$(hide) sort -o $(1) $(1)
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
ifdef BUILDING_SYSTEM_DLKM_IMAGE
  PROP_DICTIONARY_IMAGES += system_dlkm
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
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_RECOVERY_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_RECOVERY_IMAGE

INTERNAL_RECOVERYIMAGE_FILES := $(filter $(TARGET_RECOVERY_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_RECOVERY := $(PRODUCT_OUT)/installed-files-recovery.txt
INSTALLED_FILES_JSON_RECOVERY := $(INSTALLED_FILES_FILE_RECOVERY:.txt=.json)

ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
INSTALLED_BOOTIMAGE_TARGET := $(BUILT_BOOTIMAGE_TARGET)
endif

# TODO(b/30414428): Can't depend on INTERNAL_RECOVERYIMAGE_FILES alone like other
# INSTALLED_FILES_FILE_* rules. Because currently there're cp/rsync/rm commands in
# build-recoveryimage-target, which would touch the files under TARGET_RECOVERY_OUT and race with
# the call to FILELIST.
$(INSTALLED_FILES_FILE_RECOVERY): $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)

$(INSTALLED_FILES_FILE_RECOVERY): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_RECOVERY)
$(INSTALLED_FILES_FILE_RECOVERY): $(INTERNAL_RECOVERYIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_RECOVERY_ROOT_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE_RECOVERY)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON_RECOVERY)))

recovery_sepolicy := \
    $(TARGET_RECOVERY_ROOT_OUT)/sepolicy \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_service_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/plat_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/system_ext_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/system_ext_service_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/system_ext_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_service_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/vendor_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/odm_property_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/product_file_contexts \
    $(TARGET_RECOVERY_ROOT_OUT)/product_service_contexts \
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
else ifdef TARGET_RECOVERY_FSTAB_GENRULE
# Specifies a soong genrule module that generates an fstab.
recovery_fstab := $(call intermediates-dir-for,ETC,$(TARGET_RECOVERY_FSTAB_GENRULE))/$(TARGET_RECOVERY_FSTAB_GENRULE)
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
#   c) We include the recovery DTBO image within recovery - not needing the resource file as we
#      do bsdiff because boot and recovery will contain different number of entries
#      (BOARD_INCLUDE_RECOVERY_DTBO = true).
#   d) We include the recovery ACPIO image within recovery - not needing the resource file as we
#      do bsdiff because boot and recovery will contain different number of entries
#      (BOARD_INCLUDE_RECOVERY_ACPIO = true).
#   e) We build a single image that contains vendor_boot and recovery both - no recovery image to
#      install
#      (BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT = true).

ifeq (,$(filter true, $(BOARD_USES_FULL_RECOVERY_IMAGE) $(BOARD_USES_RECOVERY_AS_BOOT) \
  $(BOARD_INCLUDE_RECOVERY_DTBO) $(BOARD_INCLUDE_RECOVERY_ACPIO) \
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
    TARGET_RECOVERY_UI_VR_STEREO_OFFSET:vr_stereo_offset \
    TARGET_RECOVERY_UI_BRIGHTNESS_FILE:brightness_file \
    TARGET_RECOVERY_UI_MAX_BRIGHTNESS_FILE:max_brightness_file \
    TARGET_RECOVERY_UI_BRIGHTNESS_NORMAL:brightness_normal_percent \
    TARGET_RECOVERY_UI_BRIGHTNESS_DIMMED:brightness_dimmed_percent

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

$(call declare-1p-target,$(INSTALLED_RECOVERY_BUILD_PROP_TARGET),build)
$(call declare-license-deps,$(INSTALLED_RECOVERY_BUILD_PROP_TARGET),\
    $(INSTALLED_BUILD_PROP_TARGET) $(INSTALLED_VENDOR_BUILD_PROP_TARGET) $(INSTALLED_ODM_BUILD_PROP_TARGET) \
    $(INSTALLED_PRODUCT_BUILD_PROP_TARGET) $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET))

# Only install boot/etc/build.prop to recovery image on recovery_as_boot.
# On device with dedicated recovery partition, the file should come from the boot
# ramdisk.
ifeq (true,$(BOARD_USES_RECOVERY_AS_BOOT))
INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET := $(TARGET_RECOVERY_ROOT_OUT)/$(RAMDISK_BUILD_PROP_REL_PATH)
$(INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET): $(INSTALLED_RAMDISK_BUILD_PROP_TARGET)
	$(copy-file-to-target)

$(call declare-1p-target,$(INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET),build)
$(call declare-license-deps,$(INSTALLED_RECOVERY_RAMDISK_BUILD_PROP_TARGET),$(INSTALLED_RAMDISK_BUILD_PROP_TARGET))
endif

INTERNAL_RECOVERYIMAGE_ARGS := --ramdisk $(recovery_ramdisk)

ifneq (truetrue,$(strip $(BUILDING_VENDOR_BOOT_IMAGE))$(strip $(BOARD_USES_RECOVERY_AS_BOOT)))
INTERNAL_RECOVERYIMAGE_ARGS += $(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET))
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
endif # (BUILDING_VENDOR_BOOT_IMAGE and BOARD_USES_RECOVERY_AS_BOOT)
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
	ln -sf /system/bin/init $(TARGET_RECOVERY_ROOT_OUT)/init
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
                 $(INTERNAL_MKBOOTIMG_VERSION_ARGS) \
                 $(BOARD_RECOVERY_MKBOOTIMG_ARGS) --output $(1))
  $(if $(filter true,$(PRODUCT_SUPPORTS_VBOOT)), \
    $(VBOOT_SIGNER) $(FUTILITY) $(1).unsigned $(PRODUCT_VBOOT_SIGNING_KEY).vbpubk $(PRODUCT_VBOOT_SIGNING_KEY).vbprivk $(PRODUCT_VBOOT_SIGNING_SUBKEY).vbprivk $(1).keyblock $(1))
  $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
    $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$(1),boot))), \
    $(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE))))
  $(if $(filter true,$(BOARD_AVB_ENABLE)), \
    $(if $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)), \
      $(AVBTOOL) add_hash_footer --image $(1) $(call get-partition-size-argument,$(call get-bootimage-partition-size,$(1),boot)) --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS),\
      $(AVBTOOL) add_hash_footer --image $(1) $(call get-partition-size-argument,$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)) --partition_name recovery $(INTERNAL_AVB_RECOVERY_SIGNING_ARGS) $(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)))
endef

recoveryimage-deps := $(MKBOOTIMG) $(recovery_ramdisk) $(recovery_kernel)
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

$(call declare-container-license-metadata,$(INSTALLED_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",bool)
$(call declare-container-license-deps,$(INSTALLED_BOOTIMAGE_TARGET),$(recoveryimage-deps),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_BOOTIMAGE_TARGET)
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


$(call declare-1p-container,$(INSTALLED_RECOVERYIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_RECOVERYIMAGE_TARGET),$(recoveryimage-deps),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_RECOVERYIMAGE_TARGET)

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


# -----------------------------------------------------------------
# Build debug ramdisk and debug boot image.
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_DEBUG_RAMDISK_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifneq ($(BUILDING_DEBUG_BOOT_IMAGE)$(BUILDING_DEBUG_VENDOR_BOOT_IMAGE),)

INTERNAL_DEBUG_RAMDISK_FILES := $(filter $(TARGET_DEBUG_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# Directories to be picked into the debug ramdisk.
# As these directories are all merged into one single cpio archive, the order
# matters. If there are multiple files with the same pathname, then the last one
# wins.
#
# ramdisk-debug.img will merge the content from either ramdisk.img or
# ramdisk-recovery.img, depending on whether BOARD_USES_RECOVERY_AS_BOOT
# is set or not.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
  INTERNAL_DEBUG_RAMDISK_SRC_DIRS := $(TARGET_RECOVERY_ROOT_OUT)
  INTERNAL_DEBUG_RAMDISK_SRC_RAMDISK_TARGET := $(recovery_ramdisk)
else  # BOARD_USES_RECOVERY_AS_BOOT == true
  INTERNAL_DEBUG_RAMDISK_SRC_DIRS := $(TARGET_RAMDISK_OUT)
  INTERNAL_DEBUG_RAMDISK_SRC_RAMDISK_TARGET := $(INSTALLED_RAMDISK_TARGET)
endif # BOARD_USES_RECOVERY_AS_BOOT != true

INTERNAL_DEBUG_RAMDISK_SRC_DIRS += $(TARGET_DEBUG_RAMDISK_OUT)
INTERNAL_DEBUG_RAMDISK_SRC_DEPS := $(INTERNAL_DEBUG_RAMDISK_SRC_RAMDISK_TARGET) $(INTERNAL_DEBUG_RAMDISK_FILES)

# INSTALLED_FILES_FILE_DEBUG_RAMDISK would ensure TARGET_DEBUG_RAMDISK_OUT is created.
INSTALLED_FILES_FILE_DEBUG_RAMDISK := $(PRODUCT_OUT)/installed-files-ramdisk-debug.txt
INSTALLED_FILES_JSON_DEBUG_RAMDISK := $(INSTALLED_FILES_FILE_DEBUG_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_DEBUG_RAMDISK)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK): $(INTERNAL_DEBUG_RAMDISK_SRC_DEPS)
$(INSTALLED_FILES_FILE_DEBUG_RAMDISK): $(FILESLIST) $(FILESLIST_UTIL)
	@echo "Installed file list: $@"
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@) $(TARGET_DEBUG_RAMDISK_OUT)
	touch $(TARGET_DEBUG_RAMDISK_OUT)/force_debuggable
	$(FILESLIST) $(INTERNAL_DEBUG_RAMDISK_SRC_DIRS) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE_DEBUG_RAMDISK)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON_DEBUG_RAMDISK)))

ifdef BUILDING_DEBUG_BOOT_IMAGE

# -----------------------------------------------------------------
# the debug ramdisk, which is the original ramdisk plus additional
# files: force_debuggable, adb_debug.prop and userdebug sepolicy.
# When /force_debuggable is present, /init will load userdebug sepolicy
# and property files to allow adb root, if the device is unlocked.
INSTALLED_DEBUG_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk-debug.img

$(INSTALLED_DEBUG_RAMDISK_TARGET): $(INSTALLED_FILES_FILE_DEBUG_RAMDISK)
$(INSTALLED_DEBUG_RAMDISK_TARGET): $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	@echo "Target debug ramdisk: $@"
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_DEBUG_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $@

$(call declare-1p-container,$(INSTALLED_DEBUG_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_DEBUG_RAMDISK_TARGET),$(INSTALLED_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_DEBUG_RAMDISK_TARGET)

.PHONY: ramdisk_debug-nodeps
ramdisk_debug-nodeps: $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	@echo "make $@: ignoring dependencies"
	$(hide) rm -f $(INSTALLED_DEBUG_RAMDISK_TARGET)
	$(hide) mkdir -p $(dir $(INSTALLED_DEBUG_RAMDISK_TARGET)) $(INTERNAL_DEBUG_RAMDISK_SRC_DIRS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_DEBUG_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $(INSTALLED_DEBUG_RAMDISK_TARGET)

# -----------------------------------------------------------------
# the boot-debug.img, which is the kernel plus ramdisk-debug.img
#
# Note: it's intentional to skip signing for boot-debug.img, because it
# can only be used if the device is unlocked with verification error.
ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
  INSTALLED_DEBUG_BOOTIMAGE_TARGET := $(foreach k,$(subst kernel,boot-debug,$(BOARD_KERNEL_BINARIES)), \
         $(PRODUCT_OUT)/$(k).img)
else
  INSTALLED_DEBUG_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot-debug.img
endif

# Replace ramdisk.img in $(MKBOOTIMG) ARGS with ramdisk-debug.img to build boot-debug.img
$(INSTALLED_DEBUG_BOOTIMAGE_TARGET): $(INSTALLED_DEBUG_RAMDISK_TARGET)
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
  INTERNAL_DEBUG_BOOTIMAGE_ARGS := $(subst $(INTERNAL_DEBUG_RAMDISK_SRC_RAMDISK_TARGET),$(INSTALLED_DEBUG_RAMDISK_TARGET),$(INTERNAL_RECOVERYIMAGE_ARGS))
else
  INTERNAL_DEBUG_BOOTIMAGE_ARGS := $(subst $(INTERNAL_DEBUG_RAMDISK_SRC_RAMDISK_TARGET),$(INSTALLED_DEBUG_RAMDISK_TARGET),$(INTERNAL_BOOTIMAGE_ARGS))
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
# $(2): boot image variant (boot, boot-debug, boot-test-harness)
define test-key-sign-bootimage
$(call assert-max-image-size,$(1),$(call get-hash-image-max-size,$(call get-bootimage-partition-size,$(1),$(2))))
$(AVBTOOL) add_hash_footer \
  --image $(1) \
  $(call get-partition-size-argument,$(call get-bootimage-partition-size,$(1),$(2)))\
  --partition_name boot $(INTERNAL_AVB_BOOT_TEST_SIGNING_ARGS) \
  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
$(call assert-max-image-size,$(1),$(call get-bootimage-partition-size,$(1),$(2)))
endef

# $(1): output file
define build-debug-bootimage-target
  $(MKBOOTIMG) --kernel $(PRODUCT_OUT)/$(subst .img,,$(subst boot-debug,kernel,$(notdir $(1)))) \
    $(INTERNAL_DEBUG_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) \
    $(BOARD_MKBOOTIMG_ARGS) --output $1
  $(if $(BOARD_AVB_BOOT_KEY_PATH),$(call test-key-sign-bootimage,$1,boot-debug))
endef

# Depends on original boot.img and ramdisk-debug.img, to build the new boot-debug.img
$(INSTALLED_DEBUG_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_BOOTIMAGE_TARGET) $(AVBTOOL)
	$(call pretty,"Target boot debug image: $@")
	$(call build-debug-bootimage-target, $@)

$(call declare-container-license-metadata,$(INSTALLED_DEBUG_BOOTIMAGE_TARGET),SPDX-license-identifier-GPL-2.0-only SPDX-license-identifier-Apache-2.0,restricted notice,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING build/soong/licenses/LICENSE,"Boot Image",boot)
$(call declare-container-license-deps,$(INSTALLED_DEBUG_BOOTIMAGE_TARGET),$(INSTALLED_BOOTIMAGE_TARGET),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_DEBUG_BOOTIMAGE_TARGET)

.PHONY: bootimage_debug-nodeps
bootimage_debug-nodeps: $(MKBOOTIMG) $(AVBTOOL)
	echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_DEBUG_BOOTIMAGE_TARGET),$(call build-debug-bootimage-target,$b))

endif # BUILDING_DEBUG_BOOT_IMAGE

# -----------------------------------------------------------------
# vendor debug ramdisk
# Combines vendor ramdisk files and debug ramdisk files to build the vendor debug ramdisk.
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_DEBUG_VENDOR_BOOT_IMAGE

INTERNAL_VENDOR_DEBUG_RAMDISK_FILES := $(filter $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# The debug vendor ramdisk combines vendor ramdisk and debug ramdisk.
INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS := $(TARGET_VENDOR_RAMDISK_OUT)
INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DEPS := $(INTERNAL_VENDOR_RAMDISK_TARGET)

# Exclude recovery files in the default vendor ramdisk if including a standalone
# recovery ramdisk in vendor_boot.
ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
  ifneq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
    INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS += $(TARGET_RECOVERY_ROOT_OUT)
    INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DEPS += $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
  endif # BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT != true
endif # BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT == true

INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS += $(TARGET_VENDOR_DEBUG_RAMDISK_OUT) $(TARGET_DEBUG_RAMDISK_OUT)
INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DEPS += $(INTERNAL_VENDOR_DEBUG_RAMDISK_FILES) $(INSTALLED_FILES_FILE_DEBUG_RAMDISK)

# INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK would ensure TARGET_VENDOR_DEBUG_RAMDISK_OUT is created.
INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK := $(PRODUCT_OUT)/installed-files-vendor-ramdisk-debug.txt
INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK := $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): $(INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DEPS)
$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK): $(FILESLIST) $(FILESLIST_UTIL)
	@echo "Installed file list: $@"
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@) $(TARGET_VENDOR_DEBUG_RAMDISK_OUT)
	$(FILESLIST) $(INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK))

INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET := $(call intermediates-dir-for,PACKAGING,vendor_boot-debug)/vendor_ramdisk-debug.cpio$(RAMDISK_EXT)

$(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET): $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK)
$(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET): $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $@

INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET := $(PRODUCT_OUT)/vendor_ramdisk-debug.img
$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET): $(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET)
	@echo "Target debug vendor ramdisk: $@"
	$(copy-file-to-target)

$(call declare-1p-container,$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET),$(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET)

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
  $(call get-partition-size-argument,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE)) \
  --partition_name vendor_boot $(INTERNAL_AVB_VENDOR_BOOT_TEST_SIGNING_ARGS) \
  $(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)
$(call assert-max-image-size,$(1),$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
endef

ifneq ($(BOARD_AVB_VENDOR_BOOT_KEY_PATH),)
$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_BOOT_TEST_KEY_PATH)
endif

# Depends on vendor_boot.img and vendor-ramdisk-debug.cpio.gz to build the new vendor_boot-debug.img
$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_VENDOR_BOOTIMAGE_TARGET) $(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET)
$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET): $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS)
	$(call pretty,"Target vendor_boot debug image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
	$(if $(BOARD_AVB_VENDOR_BOOT_KEY_PATH),$(call test-key-sign-vendor-bootimage,$@))

$(call declare-1p-container,$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET),$(INTERNAL_VENDOR_DEBUG_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET)

endif # BUILDING_DEBUG_VENDOR_BOOT_IMAGE

# Appends a few test harness specific properties into the adb_debug.prop.
ADDITIONAL_TEST_HARNESS_PROPERTIES := ro.audio.silent=1
ADDITIONAL_TEST_HARNESS_PROPERTIES += ro.test_harness=1

INTERNAL_DEBUG_RAMDISK_ADB_DEBUG_PROP_TARGET := $(strip $(filter $(TARGET_DEBUG_RAMDISK_OUT)/adb_debug.prop,$(INTERNAL_DEBUG_RAMDISK_FILES)))
INTERNAL_TEST_HARNESS_RAMDISK_ADB_DEBUG_PROP_TARGET := $(TARGET_TEST_HARNESS_RAMDISK_OUT)/adb_debug.prop
$(INTERNAL_TEST_HARNESS_RAMDISK_ADB_DEBUG_PROP_TARGET): $(INTERNAL_DEBUG_RAMDISK_ADB_DEBUG_PROP_TARGET)
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
ifdef INTERNAL_DEBUG_RAMDISK_ADB_DEBUG_PROP_TARGET
	$(hide) cp $(INTERNAL_DEBUG_RAMDISK_ADB_DEBUG_PROP_TARGET) $@
endif
	$(hide) echo "" >> $@
	$(hide) echo "#" >> $@
	$(hide) echo "# ADDITIONAL TEST HARNESS PROPERTIES" >> $@
	$(hide) echo "#" >> $@
	$(hide) $(foreach line,$(ADDITIONAL_TEST_HARNESS_PROPERTIES), \
	          echo "$(line)" >> $@;)

$(call declare-1p-target,$(INTERNAL_TEST_HARNESS_RAMDISK_ADB_DEBUG_PROP_TARGET))

INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_TEST_HARNESS_RAMDISK_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
INTERNAL_TEST_HARNESS_RAMDISK_FILES := $(filter $(TARGET_TEST_HARNESS_RAMDISK_OUT)/%, \
    $(INTERNAL_TEST_HARNESS_RAMDISK_ADB_DEBUG_PROP_TARGET) \
    $(ALL_DEFAULT_INSTALLED_MODULES))

# The order is important here. The test harness ramdisk staging directory has to
# come last so that it can override the adb_debug.prop in the debug ramdisk
# staging directory.
INTERNAL_TEST_HARNESS_RAMDISK_SRC_DIRS := $(INTERNAL_DEBUG_RAMDISK_SRC_DIRS) $(TARGET_TEST_HARNESS_RAMDISK_OUT)
INTERNAL_TEST_HARNESS_RAMDISK_SRC_DEPS := $(INSTALLED_FILES_FILE_DEBUG_RAMDISK) $(INTERNAL_TEST_HARNESS_RAMDISK_FILES)

ifdef BUILDING_DEBUG_BOOT_IMAGE

# -----------------------------------------------------------------
# The test harness ramdisk, which is based off debug_ramdisk, plus a
# few additional test-harness-specific properties in adb_debug.prop.
INSTALLED_TEST_HARNESS_RAMDISK_TARGET := $(PRODUCT_OUT)/ramdisk-test-harness.img

$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET): $(INTERNAL_TEST_HARNESS_RAMDISK_SRC_DEPS)
$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET): $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	@echo "Target test harness ramdisk: $@"
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_TEST_HARNESS_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $@

$(call declare-1p-container,$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_TEST_HARNESS_RAMDISK_TARGET),$(INTERNAL_TEST_HARNESS_RAMDISK_SRC_DEPS),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)

.PHONY: ramdisk_test_harness-nodeps
ramdisk_test_harness-nodeps: $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	@echo "make $@: ignoring dependencies"
	$(hide) rm -f $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)
	$(hide) mkdir -p $(dir $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)) $(INTERNAL_TEST_HARNESS_RAMDISK_SRC_DIRS)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_TEST_HARNESS_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)

# -----------------------------------------------------------------
# the boot-test-harness.img, which is the kernel plus ramdisk-test-harness.img
#
# Note: it's intentional to skip signing for boot-test-harness.img, because it
# can only be used if the device is unlocked with verification error.
ifneq ($(strip $(BOARD_KERNEL_BINARIES)),)
  INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET := $(foreach k,$(subst kernel,boot-test-harness,$(BOARD_KERNEL_BINARIES)), \
    $(PRODUCT_OUT)/$(k).img)
else
  INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot-test-harness.img
endif

# Replace ramdisk-debug.img in $(MKBOOTIMG) ARGS with ramdisk-test-harness.img to build boot-test-harness.img
$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET): $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)
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
    $(INTERNAL_TEST_HARNESS_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) \
    $(BOARD_MKBOOTIMG_ARGS) --output $@
  $(if $(BOARD_AVB_BOOT_KEY_PATH),$(call test-key-sign-bootimage,$@,boot-test-harness))
endef

# Build the new boot-test-harness.img, based on boot-debug.img and ramdisk-test-harness.img.
$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_DEBUG_BOOTIMAGE_TARGET) $(AVBTOOL)
	$(call pretty,"Target boot test harness image: $@")
	$(call build-boot-test-harness-target,$@)

$(call declare-1p-container,$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET),$(INSTALLED_DEBUG_BOOTIMAGE_TARGET),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET)

.PHONY: bootimage_test_harness-nodeps
bootimage_test_harness-nodeps: $(MKBOOTIMG) $(AVBTOOL)
	echo "make $@: ignoring dependencies"
	$(foreach b,$(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET),$(call build-boot-test-harness-target,$b))

endif # BUILDING_DEBUG_BOOT_IMAGE

# -----------------------------------------------------------------
# vendor test harness ramdisk, which is a vendor ramdisk combined with
# a test harness ramdisk.
ifdef BUILDING_DEBUG_VENDOR_BOOT_IMAGE

INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET := $(call intermediates-dir-for,PACKAGING,vendor_boot-test-harness)/vendor_ramdisk-test-harness.cpio$(RAMDISK_EXT)

# The order is important here. The test harness ramdisk staging directory has to
# come last so that it can override the adb_debug.prop in the debug ramdisk
# staging directory.
INTERNAL_TEST_HARNESS_VENDOR_RAMDISK_SRC_DIRS := $(INTERNAL_DEBUG_VENDOR_RAMDISK_SRC_DIRS) $(TARGET_TEST_HARNESS_RAMDISK_OUT)
INTERNAL_TEST_HARNESS_VENDOR_RAMDISK_SRC_DEPS := $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK) $(INTERNAL_TEST_HARNESS_RAMDISK_FILES)

$(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET): $(INTERNAL_TEST_HARNESS_VENDOR_RAMDISK_SRC_DEPS)
$(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET): $(MKBOOTFS) | $(COMPRESSION_COMMAND_DEPS)
	$(hide) rm -f $@
	$(hide) mkdir -p $(dir $@)
	$(MKBOOTFS) -d $(TARGET_OUT) $(INTERNAL_TEST_HARNESS_VENDOR_RAMDISK_SRC_DIRS) | $(COMPRESSION_COMMAND) > $@

INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET := $(PRODUCT_OUT)/vendor_ramdisk-test-harness.img
$(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET): $(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET)
	@echo "Target test harness vendor ramdisk: $@"
	$(copy-file-to-target)

$(call declare-1p-container,$(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET),$(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET)

# -----------------------------------------------------------------
# vendor_boot-test-harness.img.
INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/vendor_boot-test-harness.img

ifneq ($(BOARD_AVB_VENDOR_BOOT_KEY_PATH),)
$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET): $(AVBTOOL) $(BOARD_AVB_VENDOR_BOOT_TEST_KEY_PATH)
endif

# Depends on vendor_boot.img and vendor_ramdisk-test-harness.cpio$(RAMDISK_EXT) to build the new vendor_boot-test-harness.img
$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(INSTALLED_VENDOR_BOOTIMAGE_TARGET)
$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET): $(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET)
$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET): $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS)
	$(call pretty,"Target vendor_boot test harness image: $@")
	$(MKBOOTIMG) $(INTERNAL_VENDOR_BOOTIMAGE_ARGS) $(BOARD_MKBOOTIMG_ARGS) --vendor_ramdisk $(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_ARGS) --vendor_boot $@
	$(call assert-max-image-size,$@,$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE))
	$(if $(BOARD_AVB_VENDOR_BOOT_KEY_PATH),$(call test-key-sign-vendor-bootimage,$@))

$(call declare-1p-container,$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET),$(INTERNAL_VENDOR_TEST_HARNESS_RAMDISK_TARGET),$(PRODUCT_OUT)/:/)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET)

endif # BUILDING_DEBUG_VENDOR_BOOT_IMAGE

endif # BUILDING_DEBUG_BOOT_IMAGE || BUILDING_DEBUG_VENDOR_BOOT_IMAGE

PARTITION_COMPAT_SYMLINKS :=
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
$(eval PARTITION_COMPAT_SYMLINKS += $1)
$1
endef


# FSVerity metadata generation
# Generate fsverity metadata files (.fsv_meta) and build manifest
# (<partition>/etc/security/fsverity/BuildManifest<suffix>.apk) BEFORE filtering systemimage,
# vendorimage, odmimage, productimage files below.
ifeq ($(PRODUCT_FSVERITY_GENERATE_METADATA),true)

fsverity-metadata-targets-patterns := \
  $(TARGET_OUT)/framework/% \
  $(TARGET_OUT)/etc/boot-image.prof \
  $(TARGET_OUT)/etc/dirty-image-objects \
  $(TARGET_OUT)/etc/preloaded-classes \
  $(TARGET_OUT)/etc/classpaths/%.pb \

ifdef BUILDING_SYSTEM_EXT_IMAGE
fsverity-metadata-targets-patterns += $(TARGET_OUT_SYSTEM_EXT)/framework/%
endif

# Generate fsv_meta
fsverity-metadata-targets := $(sort $(filter \
  $(fsverity-metadata-targets-patterns), \
  $(ALL_DEFAULT_INSTALLED_MODULES)))

define fsverity-generate-metadata
$(call declare-0p-target,$(1).fsv_meta)

$(1).fsv_meta: PRIVATE_SRC := $(1)
$(1).fsv_meta: PRIVATE_FSVERITY := $(HOST_OUT_EXECUTABLES)/fsverity
$(1).fsv_meta: $(HOST_OUT_EXECUTABLES)/fsverity_metadata_generator $(HOST_OUT_EXECUTABLES)/fsverity $(1)
	$$< --fsverity-path $$(PRIVATE_FSVERITY) --signature none \
	    --hash-alg sha256 --output $$@ $$(PRIVATE_SRC)
endef

$(foreach f,$(fsverity-metadata-targets),$(eval $(call fsverity-generate-metadata,$(f))))
ALL_DEFAULT_INSTALLED_MODULES += $(addsuffix .fsv_meta,$(fsverity-metadata-targets))

FSVERITY_APK_KEY_PATH := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
FSVERITY_APK_MANIFEST_TEMPLATE_PATH := system/security/fsverity/AndroidManifest.xml

# Generate and install BuildManifest<suffix>.apk for the given partition
# $(1): path of the output APK
# $(2): partition name
define fsverity-generate-and-install-manifest-apk
fsverity-metadata-targets-$(2) := $(filter $(PRODUCT_OUT)/$(2)/%,\
      $(fsverity-metadata-targets))
$(1): PRIVATE_FSVERITY := $(HOST_OUT_EXECUTABLES)/fsverity
$(1): PRIVATE_AAPT2 := $(HOST_OUT_EXECUTABLES)/aapt2
$(1): PRIVATE_MIN_SDK_VERSION := $(DEFAULT_APP_TARGET_SDK)
$(1): PRIVATE_VERSION_CODE := $(PLATFORM_SDK_VERSION)
$(1): PRIVATE_VERSION_NAME := $(APPS_DEFAULT_VERSION_NAME)
$(1): PRIVATE_APKSIGNER := $(HOST_OUT_EXECUTABLES)/apksigner
$(1): PRIVATE_MANIFEST := $(FSVERITY_APK_MANIFEST_TEMPLATE_PATH)
$(1): PRIVATE_FRAMEWORK_RES := $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
$(1): PRIVATE_KEY := $(FSVERITY_APK_KEY_PATH)
$(1): PRIVATE_INPUTS := $$(fsverity-metadata-targets-$(2))
$(1): PRIVATE_ASSETS := $(call intermediates-dir-for,ETC,build_manifest-$(2))/assets
$(1): $(HOST_OUT_EXECUTABLES)/fsverity_manifest_generator \
    $(HOST_OUT_EXECUTABLES)/fsverity $(HOST_OUT_EXECUTABLES)/aapt2 \
    $(HOST_OUT_EXECUTABLES)/apksigner $(FSVERITY_APK_MANIFEST_TEMPLATE_PATH) \
    $(FSVERITY_APK_KEY_PATH).x509.pem $(FSVERITY_APK_KEY_PATH).pk8 \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk \
    $$(fsverity-metadata-targets-$(2))
	rm -rf $$(PRIVATE_ASSETS)
	mkdir -p $$(PRIVATE_ASSETS)
	$$< --fsverity-path $$(PRIVATE_FSVERITY) \
	    --base-dir $$(PRODUCT_OUT) \
	    --output $$(PRIVATE_ASSETS)/build_manifest.pb \
	    $$(PRIVATE_INPUTS)
	$$(PRIVATE_AAPT2) link -o $$@ \
	    -A $$(PRIVATE_ASSETS) \
	    -I $$(PRIVATE_FRAMEWORK_RES) \
	    --min-sdk-version $$(PRIVATE_MIN_SDK_VERSION) \
	    --version-code $$(PRIVATE_VERSION_CODE) \
	    --version-name $$(PRIVATE_VERSION_NAME) \
	    --manifest $$(PRIVATE_MANIFEST) \
            --rename-manifest-package com.android.security.fsverity_metadata.$(2)
	$$(PRIVATE_APKSIGNER) sign --in $$@ \
	    --cert $$(PRIVATE_KEY).x509.pem \
	    --key $$(PRIVATE_KEY).pk8

$(1).idsig: $(1)

ALL_DEFAULT_INSTALLED_MODULES += $(1) $(1).idsig

endef  # fsverity-generate-and-install-manifest-apk

$(eval $(call fsverity-generate-and-install-manifest-apk, \
  $(TARGET_OUT)/etc/security/fsverity/BuildManifest.apk,system))
ALL_FSVERITY_BUILD_MANIFEST_APK += $(TARGET_OUT)/etc/security/fsverity/BuildManifest.apk $(TARGET_OUT)/etc/security/fsverity/BuildManifest.apk.idsig
ifdef BUILDING_SYSTEM_EXT_IMAGE
  $(eval $(call fsverity-generate-and-install-manifest-apk, \
    $(TARGET_OUT_SYSTEM_EXT)/etc/security/fsverity/BuildManifestSystemExt.apk,system_ext))
  ALL_FSVERITY_BUILD_MANIFEST_APK += $(TARGET_OUT_SYSTEM_EXT)/etc/security/fsverity/BuildManifestSystemExt.apk $(TARGET_OUT_SYSTEM_EXT)/etc/security/fsverity/BuildManifestSystemExt.apk.idsig
endif

endif  # PRODUCT_FSVERITY_GENERATE_METADATA


# -----------------------------------------------------------------
# system image

INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
INTERNAL_SYSTEMIMAGE_FILES := $(sort $(filter $(TARGET_OUT)/%, \
    $(ALL_DEFAULT_INSTALLED_MODULES)))

# Create symlink /system/vendor to /vendor if necessary.
ifdef BOARD_USES_VENDORIMAGE
  _vendor_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT)/vendor,/vendor,vendor.img)
  INTERNAL_SYSTEMIMAGE_FILES += $(_vendor_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_vendor_symlink)
endif

# Create symlink /system/product to /product if necessary.
ifdef BOARD_USES_PRODUCTIMAGE
  _product_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT)/product,/product,product.img)
  INTERNAL_SYSTEMIMAGE_FILES += $(_product_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_product_symlink)
endif

# Create symlink /system/system_ext to /system_ext if necessary.
ifdef BOARD_USES_SYSTEM_EXTIMAGE
  _systemext_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT)/system_ext,/system_ext,system_ext.img)
  INTERNAL_SYSTEMIMAGE_FILES += $(_systemext_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_systemext_symlink)
endif

# -----------------------------------------------------------------
# system_dlkm partition image

# Create symlinks for system_dlkm on devices with a system_dlkm partition:
# /system/lib/modules -> /system_dlkm/lib/modules
#
# On devices with a system_dlkm partition,
# - /system/lib/modules is a symlink to a directory that stores system DLKMs.
# - The system_dlkm partition is mounted at /system_dlkm at runtime.
ifdef BOARD_USES_SYSTEM_DLKMIMAGE
  _system_dlkm_lib_modules_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT)/lib/modules,/system_dlkm/lib/modules,system_dlkm.img)
  INTERNAL_SYSTEMIMAGE_FILES += $(_system_dlkm_lib_modules_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_system_dlkm_lib_modules_symlink)
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

# Install system linker configuration
# Collect all available stub libraries installed in system and install with predefined linker configuration
# Also append LLNDK libraries in the APEX as required libs
SYSTEM_LINKER_CONFIG := $(TARGET_OUT)/etc/linker.config.pb
SYSTEM_LINKER_CONFIG_SOURCE := $(call intermediates-dir-for,ETC,system_linker_config)/system_linker_config
$(SYSTEM_LINKER_CONFIG): PRIVATE_SYSTEM_LINKER_CONFIG_SOURCE := $(SYSTEM_LINKER_CONFIG_SOURCE)
$(SYSTEM_LINKER_CONFIG): $(INTERNAL_SYSTEMIMAGE_FILES) $(SYSTEM_LINKER_CONFIG_SOURCE) | conv_linker_config
	@echo Creating linker config: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(HOST_OUT_EXECUTABLES)/conv_linker_config systemprovide --source $(PRIVATE_SYSTEM_LINKER_CONFIG_SOURCE) \
		--output $@ --value "$(STUB_LIBRARIES)" --system "$(TARGET_OUT)"
	$(HOST_OUT_EXECUTABLES)/conv_linker_config append --source $@ --output $@ --key requireLibs \
		--value "$(foreach lib,$(LLNDK_MOVED_TO_APEX_LIBRARIES), $(lib).so)"

$(call declare-1p-target,$(SYSTEM_LINKER_CONFIG),)
$(call declare-license-deps,$(SYSTEM_LINKER_CONFIG),$(INTERNAL_SYSTEMIMAGE_FILES) $(SYSTEM_LINKER_CONFIG_SOURCE))

FULL_SYSTEMIMAGE_DEPS += $(SYSTEM_LINKER_CONFIG)
ALL_DEFAULT_INSTALLED_MODULES += $(SYSTEM_LINKER_CONFIG)

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
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON)))

.PHONY: installed-file-list
installed-file-list: $(INSTALLED_FILES_FILE)

systemimage_intermediates :=$= $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE :=$= $(systemimage_intermediates)/system.img


# Used by the bazel sandwich to request the staging dir be built
$(systemimage_intermediates)/staging_dir.stamp: $(FULL_SYSTEMIMAGE_DEPS)
	touch $@

define write-file-lines
$(1):
	@echo Writing $$@
	rm -f $$@
	echo -n > $$@
	$$(foreach f,$(2),echo "$$(f)" >> $$@$$(newline))
endef

# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-image-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt,system, \
      skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(systemimage_intermediates)/file_list.txt) \
          $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1) $(TARGET_OUT) \
          || ( mkdir -p $${DIST_DIR}; \
               cp $(INSTALLED_FILES_FILE) $${DIST_DIR}/installed-files-rescued.txt; \
               exit 1 )
endef

$(eval $(call write-file-lines,$(systemimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT)/,,$(filter $(TARGET_OUT)/%,$(FULL_SYSTEMIMAGE_DEPS)))))

ifeq ($(BOARD_AVB_ENABLE),true)
$(BUILT_SYSTEMIMAGE): $(BOARD_AVB_SYSTEM_KEY_PATH)
endif
$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE) $(systemimage_intermediates)/file_list.txt
	$(call build-systemimage-target,$@)

$(call declare-1p-container,$(BUILT_SYSTEMIMAGE),system/extras)
$(call declare-container-license-deps,$(BUILT_SYSTEMIMAGE),$(FULL_SYSTEMIMAGE_DEPS),$(PRODUCT_OUT)/:/)

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
ifneq (,$(filter true,$(BOARD_INCLUDE_RECOVERY_DTBO) $(BOARD_INCLUDE_RECOVERY_ACPIO)))
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

$(call declare-1p-container,$(INSTALLED_SYSTEMIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_SYSTEMIMAGE_TARGET),$(BUILT_SYSTEMIMAGE),$(BUILT_SYSTEMIMAGE):/)

systemimage: $(INSTALLED_SYSTEMIMAGE_TARGET)

SYSTEM_NOTICE_DEPS += $(INSTALLED_SYSTEMIMAGE_TARGET)

.PHONY: systemimage-nodeps snod
systemimage-nodeps snod: $(filter-out systemimage-nodeps snod,$(MAKECMDGOALS)) \
	            | $(INTERNAL_USERIMAGES_DEPS) $(systemimage_intermediates)/file_list.txt
	@echo "make $@: ignoring dependencies"
	$(call build-systemimage-target,$(INSTALLED_SYSTEMIMAGE_TARGET))
	$(hide) $(call assert-max-image-size,$(INSTALLED_SYSTEMIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
ifeq (true,$(WITH_DEXPREOPT))
	$(warning Warning: with dexpreopt enabled, you may need a full rebuild.)
endif

endif # BUILDING_SYSTEM_IMAGE

.PHONY: sync syncsys sync_system
sync syncsys sync_system: $(INTERNAL_SYSTEMIMAGE_FILES)

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
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_DATA)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(userdataimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_DATA) $(userdataimage_intermediates)/userdata_image_info.txt \
          $(INSTALLED_USERDATAIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_USERDATAIMAGE_TARGET),$(BOARD_USERDATAIMAGE_PARTITION_SIZE))
endef

# We just build this directly to the install location.
INSTALLED_USERDATAIMAGE_TARGET := $(BUILT_USERDATAIMAGE_TARGET)
INSTALLED_USERDATAIMAGE_TARGET_DEPS := \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_USERDATAIMAGE_FILES)

$(eval $(call write-file-lines,$(userdataimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_DATA)/,,$(filter $(TARGET_OUT_DATA)/%,$(INSTALLED_USERDATAIMAGE_TARGET_DEPS)))))

$(INSTALLED_USERDATAIMAGE_TARGET): $(INSTALLED_USERDATAIMAGE_TARGET_DEPS) $(userdataimage_intermediates)/file_list.txt
	$(build-userdataimage-target)

$(call declare-1p-container,$(INSTALLED_USERDATAIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_USERDATAIMAGE_TARGET),$(INSTALLED_USERDATAIMAGE_TARGET_DEPS),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_USERDATAIMAGE_TARGET)

.PHONY: userdataimage-nodeps
userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS) $(userdataimage_intermediates)/file_list.txt
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
# cache partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_CACHE)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(cacheimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_CACHE) $(cacheimage_intermediates)/cache_image_info.txt \
          $(INSTALLED_CACHEIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_CACHEIMAGE_TARGET),$(BOARD_CACHEIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(cacheimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_CACHE)/,,$(filter $(TARGET_OUT_CACHE)/%,$(INTERNAL_CACHEIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_CACHEIMAGE_TARGET := $(BUILT_CACHEIMAGE_TARGET)
$(INSTALLED_CACHEIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES) $(cacheimage_intermediates)/file_list.txt
	$(build-cacheimage-target)

$(call declare-1p-container,$(INSTALLED_CACHEIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_CACHEIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_CACHEIMAGE_TARGET)

.PHONY: cacheimage-nodeps
cacheimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS) $(cacheimage_intermediates)/file_list.txt
	$(build-cacheimage-target)

else # BUILDING_CACHE_IMAGE
# we need to ignore the broken cache link when doing the rsync
IGNORE_CACHE_LINK := --exclude=cache
endif # BUILDING_CACHE_IMAGE

# -----------------------------------------------------------------
# system_other partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_SYSTEM_OTHER)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_SYSTEM_OTHER_IMAGE
ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
# Marker file to identify that odex files are installed
INSTALLED_SYSTEM_OTHER_ODEX_MARKER := $(TARGET_OUT_SYSTEM_OTHER)/system-other-odex-marker
ALL_DEFAULT_INSTALLED_MODULES += $(INSTALLED_SYSTEM_OTHER_ODEX_MARKER)
$(INSTALLED_SYSTEM_OTHER_ODEX_MARKER):
	$(hide) touch $@

$(call declare-0p-target,$(INSTALLED_SYSTEM_OTHER_ODEX_MARKER))
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
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_SYSTEM_OTHER) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(eval $(call declare-0p-target,$(INSTALLED_FILES_FILE_SYSTEMOTHER)))
$(eval $(call declare-0p-target,$(INSTALLED_FILES_JSON_SYSTEMOTHER)))

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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(systemotherimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_SYSTEM_OTHER) $(systemotherimage_intermediates)/system_other_image_info.txt \
          $(INSTALLED_SYSTEMOTHERIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(systemotherimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_SYSTEM_OTHER)/,,$(filter $(TARGET_OUT_SYSTEM_OTHER)/%,$(INTERNAL_SYSTEMOTHERIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_SYSTEMOTHERIMAGE_TARGET := $(BUILT_SYSTEMOTHERIMAGE_TARGET)
ifneq (true,$(SANITIZE_LITE))
# Only create system_other when not building the second stage of a SANITIZE_LITE build.
$(INSTALLED_SYSTEMOTHERIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEMOTHER) $(systemotherimage_intermediates)/file_list.txt
	$(build-systemotherimage-target)

$(call declare-1p-container,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEMOTHERIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_DEPS += $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)
endif

.PHONY: systemotherimage-nodeps
systemotherimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS) $(systemotherimage_intermediates)/file_list.txt
	$(build-systemotherimage-target)

endif # BUILDING_SYSTEM_OTHER_IMAGE


# -----------------------------------------------------------------
# vendor partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_VENDOR)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_VENDOR_IMAGE
INTERNAL_VENDORIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))


# Create symlink /vendor/odm to /odm if necessary.
ifdef BOARD_USES_ODMIMAGE
  _odm_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT_VENDOR)/odm,/odm,odm.img)
  INTERNAL_VENDORIMAGE_FILES += $(_odm_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_odm_symlink)
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
  _vendor_dlkm_lib_modules_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT_VENDOR)/lib/modules,/vendor_dlkm/lib/modules,vendor_dlkm.img)
  INTERNAL_VENDORIMAGE_FILES += $(_vendor_dlkm_lib_modules_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_vendor_dlkm_lib_modules_symlink)
endif

# Install vendor/etc/linker.config.pb with PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS and SOONG_STUB_VENDOR_LIBRARIES
vendor_linker_config_file := $(TARGET_OUT_VENDOR)/etc/linker.config.pb
$(vendor_linker_config_file): private_linker_config_fragments := $(PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS)
$(vendor_linker_config_file): $(INTERNAL_VENDORIMAGE_FILES) $(PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS) | $(HOST_OUT_EXECUTABLES)/conv_linker_config
	@echo Creating linker config: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(HOST_OUT_EXECUTABLES)/conv_linker_config proto \
		--source $(call normalize-path-list,$(private_linker_config_fragments)) \
		--output $@
	$(HOST_OUT_EXECUTABLES)/conv_linker_config systemprovide --source $@ \
		--output $@ --value "$(SOONG_STUB_VENDOR_LIBRARIES)" --system "$(TARGET_OUT_VENDOR)"
$(call define declare-0p-target,$(vendor_linker_config_file),)
INTERNAL_VENDORIMAGE_FILES += $(vendor_linker_config_file)
ALL_DEFAULT_INSTALLED_MODULES += $(vendor_linker_config_file)

INSTALLED_FILES_FILE_VENDOR := $(PRODUCT_OUT)/installed-files-vendor.txt
INSTALLED_FILES_JSON_VENDOR := $(INSTALLED_FILES_FILE_VENDOR:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR)
$(INSTALLED_FILES_FILE_VENDOR) : $(INTERNAL_VENDORIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_VENDOR) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_VENDOR))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_VENDOR))

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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(vendorimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_VENDOR) $(vendorimage_intermediates)/vendor_image_info.txt \
          $(INSTALLED_VENDORIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_VENDORIMAGE_TARGET) $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_VENDORIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(vendorimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_VENDOR)/,,$(filter $(TARGET_OUT_VENDOR)/%,$(INTERNAL_VENDORIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_VENDORIMAGE_TARGET := $(BUILT_VENDORIMAGE_TARGET)
$(INSTALLED_VENDORIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_VENDORIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_VENDOR) \
    $(RECOVERY_FROM_BOOT_PATCH) \
    $(vendorimage_intermediates)/file_list.txt
	$(build-vendorimage-target)

VENDOR_NOTICE_DEPS += $(INSTALLED_VENDORIMAGE_TARGET)

$(call declare-container-license-metadata,$(INSTALLED_VENDORIMAGE_TARGET),legacy_proprietary,proprietary,,"Vendor Image",vendor)
$(call declare-container-license-deps,$(INSTALLED_VENDORIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDORIMAGE_FILES) $(RECOVERY_FROM_BOOT_PATH),$(PRODUCT_OUT)/:/)

.PHONY: vendorimage-nodeps vnod
vendorimage-nodeps vnod: | $(INTERNAL_USERIMAGES_DEPS) $(vendorimage_intermediates)/file_list.txt
	$(build-vendorimage-target)

.PHONY: sync_vendor
sync sync_vendor: $(INTERNAL_VENDORIMAGE_FILES)

else ifdef BOARD_PREBUILT_VENDORIMAGE
INSTALLED_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDORIMAGE),$(INSTALLED_VENDORIMAGE_TARGET)))
$(if $(strip $(ALL_TARGETS.$(INSTALLED_VENDORIMAGE_TARGET).META_LIC)),,\
    $(if $(strip $(ALL_TARGETS.$(BOARD_PREBUILT_VENDORIMAGE).META_LIC)),\
        $(call declare-copy-target-license-metadata,$(INSTALLED_VENDORIMAGE_TARGET),$(BOARD_PREBUILT_VENDORIMAGE)),\
        $(call declare-license-metadata,$(INSTALLED_VENDORIMAGE_TARGET),legacy_proprietary,proprietary,,"Vendor Image",vendor)))
endif

# -----------------------------------------------------------------
# product partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_PRODUCT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_PRODUCT_IMAGE
INTERNAL_PRODUCTIMAGE_FILES := \
    $(filter $(TARGET_OUT_PRODUCT)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_PRODUCT := $(PRODUCT_OUT)/installed-files-product.txt
INSTALLED_FILES_JSON_PRODUCT := $(INSTALLED_FILES_FILE_PRODUCT:.txt=.json)
$(INSTALLED_FILES_FILE_PRODUCT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_PRODUCT)
$(INSTALLED_FILES_FILE_PRODUCT) : $(INTERNAL_PRODUCTIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_PRODUCT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_PRODUCT))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_PRODUCT))

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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(productimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_PRODUCT) $(productimage_intermediates)/product_image_info.txt \
          $(INSTALLED_PRODUCTIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_PRODUCTIMAGE_TARGET),$(BOARD_PRODUCTIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(productimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_PRODUCT)/,,$(filter $(TARGET_OUT_PRODUCT)/%,$(INTERNAL_PRODUCTIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_PRODUCTIMAGE_TARGET := $(BUILT_PRODUCTIMAGE_TARGET)
$(INSTALLED_PRODUCTIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_PRODUCTIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_PRODUCT) \
    $(productimage_intermediates)/file_list.txt
	$(build-productimage-target)

PRODUCT_NOTICE_DEPS += $(INSTALLED_PRODUCTIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_PRODUCTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_PRODUCTIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_PRODUCTIMAGE_FILES) $(INSTALLED_FILES_FILE_PRODUCT),$(PRODUCT_OUT)/:/)

.PHONY: productimage-nodeps pnod
productimage-nodeps pnod: | $(INTERNAL_USERIMAGES_DEPS) $(productimage_intermediates)/file_list.txt
	$(build-productimage-target)

.PHONY: sync_product
sync sync_product: $(INTERNAL_PRODUCTIMAGE_FILES)

else ifdef BOARD_PREBUILT_PRODUCTIMAGE
INSTALLED_PRODUCTIMAGE_TARGET := $(PRODUCT_OUT)/product.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_PRODUCTIMAGE),$(INSTALLED_PRODUCTIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# system_ext partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_SYSTEM_EXT)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_SYSTEM_EXT_IMAGE
INTERNAL_SYSTEM_EXTIMAGE_FILES := \
    $(filter $(TARGET_OUT_SYSTEM_EXT)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_SYSTEM_EXT := $(PRODUCT_OUT)/installed-files-system_ext.txt
INSTALLED_FILES_JSON_SYSTEM_EXT := $(INSTALLED_FILES_FILE_SYSTEM_EXT:.txt=.json)
$(INSTALLED_FILES_FILE_SYSTEM_EXT): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_SYSTEM_EXT)
$(INSTALLED_FILES_FILE_SYSTEM_EXT) : $(INTERNAL_SYSTEM_EXTIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_SYSTEM_EXT) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_SYSTEM_EXT))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_SYSTEM_EXT))

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
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(system_extimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_SYSTEM_EXT) \
          $(system_extimage_intermediates)/system_ext_image_info.txt \
          $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
          $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_PRODUCT_SERVICESIMAGE_TARGET),$(BOARD_PRODUCT_SERVICESIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(system_extimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_SYSTEM_EXT)/,,$(filter $(TARGET_OUT_SYSTEM_EXT)/%,$(INTERNAL_SYSTEM_EXTIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_SYSTEM_EXTIMAGE_TARGET := $(BUILT_SYSTEM_EXTIMAGE_TARGET)
$(INSTALLED_SYSTEM_EXTIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_SYSTEM_EXT) \
    $(system_extimage_intermediates)/file_list.txt
	$(build-system_extimage-target)

SYSTEM_EXT_NOTICE_DEPS += $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_SYSTEM_EXTIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_SYSTEM_EXTIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEM_EXTIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEM_EXT),$(PRODUCT_OUT)/:/)

.PHONY: systemextimage-nodeps senod
systemextimage-nodeps senod: | $(INTERNAL_USERIMAGES_DEPS) $(system_extimage_intermediates)/file_list.txt
	$(build-system_extimage-target)

.PHONY: sync_system_ext
sync sync_system_ext: $(INTERNAL_SYSTEM_EXTIMAGE_FILES)

else ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
INSTALLED_SYSTEM_EXTIMAGE_TARGET := $(PRODUCT_OUT)/system_ext.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_SYSTEM_EXTIMAGE),$(INSTALLED_SYSTEM_EXTIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# odm partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_ODM)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
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
  _odm_dlkm_lib_modules_symlink := $(call create-partition-compat-symlink,$(TARGET_OUT_ODM)/lib/modules,/odm_dlkm/lib/modules,odm_dlkm.img)
  INTERNAL_ODMIMAGE_FILES += $(_odm_dlkm_lib_modules_symlink)
  ALL_DEFAULT_INSTALLED_MODULES += $(_odm_dlkm_lib_modules_symlink)
endif

INSTALLED_FILES_FILE_ODM := $(PRODUCT_OUT)/installed-files-odm.txt
INSTALLED_FILES_JSON_ODM := $(INSTALLED_FILES_FILE_ODM:.txt=.json)
$(INSTALLED_FILES_FILE_ODM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ODM)
$(INSTALLED_FILES_FILE_ODM) : $(INTERNAL_ODMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_ODM) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_ODM))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_ODM))

odmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,odm)
BUILT_ODMIMAGE_TARGET := $(PRODUCT_OUT)/odm.img
define build-odmimage-target
  $(call pretty,"Target odm fs image: $(INSTALLED_ODMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_ODM)
  @mkdir -p $(odmimage_intermediates) && rm -rf $(odmimage_intermediates)/odm_image_info.txt
  $(call generate-image-prop-dictionary, $(odmimage_intermediates)/odm_image_info.txt, odm, \
	  skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(odmimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_ODM) $(odmimage_intermediates)/odm_image_info.txt \
          $(INSTALLED_ODMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_ODMIMAGE_TARGET),$(BOARD_ODMIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(odmimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_ODM)/,,$(filter $(TARGET_OUT_ODM)/%,$(INTERNAL_ODMIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_ODMIMAGE_TARGET := $(BUILT_ODMIMAGE_TARGET)
$(INSTALLED_ODMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_ODMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_ODM) \
    $(odmimage_intermediates)/file_list.txt
	$(build-odmimage-target)

ODM_NOTICE_DEPS += $(INSTALLED_ODMIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_ODMIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_ODMIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_ODMIMAGE_FILES) $(INSTALLED_FILES_FILE_ODM),$(PRODUCT_OUT)/:/)

.PHONY: odmimage-nodeps onod
odmimage-nodeps onod: | $(INTERNAL_USERIMAGES_DEPS) $(odmimage_intermediates)/file_list.txt
	$(build-odmimage-target)

.PHONY: sync_odm
sync sync_odm: $(INTERNAL_ODMIMAGE_FILES)

else ifdef BOARD_PREBUILT_ODMIMAGE
INSTALLED_ODMIMAGE_TARGET := $(PRODUCT_OUT)/odm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_ODMIMAGE),$(INSTALLED_ODMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# vendor_dlkm partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_VENDOR_DLKM)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_VENDOR_DLKM_IMAGE
INTERNAL_VENDOR_DLKMIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR_DLKM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_VENDOR_DLKM := $(PRODUCT_OUT)/installed-files-vendor_dlkm.txt
INSTALLED_FILES_JSON_VENDOR_DLKM := $(INSTALLED_FILES_FILE_VENDOR_DLKM:.txt=.json)
$(INSTALLED_FILES_FILE_VENDOR_DLKM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_VENDOR_DLKM)
$(INSTALLED_FILES_FILE_VENDOR_DLKM) : $(INTERNAL_VENDOR_DLKMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_VENDOR_DLKM) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_VENDOR_DLKM))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_VENDOR_DLKM))

vendor_dlkmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor_dlkm)
BUILT_VENDOR_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/vendor_dlkm.img
define build-vendor_dlkmimage-target
  $(call pretty,"Target vendor_dlkm fs image: $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR_DLKM)
  @mkdir -p $(vendor_dlkmimage_intermediates) && rm -rf $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt
  $(call generate-image-prop-dictionary, $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt, \
	  vendor_dlkm, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(vendor_dlkmimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_VENDOR_DLKM) $(vendor_dlkmimage_intermediates)/vendor_dlkm_image_info.txt \
          $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_VENDOR_DLKMIMAGE_TARGET),$(BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(vendor_dlkmimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_VENDOR_DLKM)/,,$(filter $(TARGET_OUT_VENDOR_DLKM)/%,$(INTERNAL_VENDOR_DLKMIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_VENDOR_DLKMIMAGE_TARGET := $(BUILT_VENDOR_DLKMIMAGE_TARGET)
$(INSTALLED_VENDOR_DLKMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_VENDOR_DLKM) \
    $(vendor_dlkmimage_intermediates)/file_list.txt
	$(build-vendor_dlkmimage-target)

VENDOR_DLKM_NOTICE_DEPS += $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_VENDOR_DLKMIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_VENDOR_DLKMIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDOR_DLKMIMAGE_FILES) $(INSTALLED_FILES_FILE_VENDOR_DLKM),$(PRODUCT_OUT)/:/)

.PHONY: vendor_dlkmimage-nodeps vdnod
vendor_dlkmimage-nodeps vdnod: | $(INTERNAL_USERIMAGES_DEPS) $(vendor_dlkmimage_intermediates)/file_list.txt
	$(build-vendor_dlkmimage-target)

.PHONY: sync_vendor_dlkm
sync sync_vendor_dlkm: $(INTERNAL_VENDOR_DLKMIMAGE_FILES)

else ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
INSTALLED_VENDOR_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/vendor_dlkm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_VENDOR_DLKMIMAGE),$(INSTALLED_VENDOR_DLKMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# odm_dlkm partition image
INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_ODM_DLKM)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_ODM_DLKM_IMAGE
INTERNAL_ODM_DLKMIMAGE_FILES := \
    $(filter $(TARGET_OUT_ODM_DLKM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_ODM_DLKM := $(PRODUCT_OUT)/installed-files-odm_dlkm.txt
INSTALLED_FILES_JSON_ODM_DLKM := $(INSTALLED_FILES_FILE_ODM_DLKM:.txt=.json)
$(INSTALLED_FILES_FILE_ODM_DLKM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_ODM_DLKM)
$(INSTALLED_FILES_FILE_ODM_DLKM) : $(INTERNAL_ODM_DLKMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_ODM_DLKM) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_ODM_DLKM))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_ODM_DLKM))

odm_dlkmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,odm_dlkm)
BUILT_ODM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/odm_dlkm.img
define build-odm_dlkmimage-target
  $(call pretty,"Target odm_dlkm fs image: $(INSTALLED_ODM_DLKMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_ODM_DLKM)
  @mkdir -p $(odm_dlkmimage_intermediates) && rm -rf $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt
  $(call generate-image-prop-dictionary, $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt, \
	  odm_dlkm, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(odm_dlkmimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_ODM_DLKM) $(odm_dlkmimage_intermediates)/odm_dlkm_image_info.txt \
          $(INSTALLED_ODM_DLKMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_ODM_DLKMIMAGE_TARGET),$(BOARD_ODM_DLKMIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(odm_dlkmimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_ODM_DLKM)/,,$(filter $(TARGET_OUT_ODM_DLKM)/%,$(INTERNAL_ODM_DLKMIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_ODM_DLKMIMAGE_TARGET := $(BUILT_ODM_DLKMIMAGE_TARGET)
$(INSTALLED_ODM_DLKMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_ODM_DLKMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_ODM_DLKM) \
    $(odm_dlkmimage_intermediates)/file_list.txt
	$(build-odm_dlkmimage-target)

ODM_DLKM_NOTICE_DEPS += $(INSTALLED_ODM_DLKMIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_ODM_DLKMIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_ODM_DLKMIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_ODM_DLKMIMAGE_FILES) $(INSTALLED_FILES_FILE_ODM_DLKM),$(PRODUCT_OUT)/:/)

.PHONY: odm_dlkmimage-nodeps odnod
odm_dlkmimage-nodeps odnod: | $(INTERNAL_USERIMAGES_DEPS) $(odm_dlkmimage_intermediates)/file_list.txt
	$(build-odm_dlkmimage-target)

.PHONY: sync_odm_dlkm
sync sync_odm_dlkm: $(INTERNAL_ODM_DLKMIMAGE_FILES)

else ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
INSTALLED_ODM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/odm_dlkm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_ODM_DLKMIMAGE),$(INSTALLED_ODM_DLKMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# system_dlkm partition image

INSTALLED_FILES_OUTSIDE_IMAGES := $(filter-out $(TARGET_OUT_SYSTEM_DLKM)/%, $(INSTALLED_FILES_OUTSIDE_IMAGES))
ifdef BUILDING_SYSTEM_DLKM_IMAGE

INTERNAL_SYSTEM_DLKMIMAGE_FILES := \
    $(filter $(TARGET_OUT_SYSTEM_DLKM)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES))

INSTALLED_FILES_FILE_SYSTEM_DLKM := $(PRODUCT_OUT)/installed-files-system_dlkm.txt
INSTALLED_FILES_JSON_SYSTEM_DLKM := $(INSTALLED_FILES_FILE_SYSTEM_DLKM:.txt=.json)
$(INSTALLED_FILES_FILE_SYSTEM_DLKM): .KATI_IMPLICIT_OUTPUTS := $(INSTALLED_FILES_JSON_SYSTEM_DLKM)
$(INSTALLED_FILES_FILE_SYSTEM_DLKM): $(INTERNAL_SYSTEM_DLKMIMAGE_FILES) $(FILESLIST) $(FILESLIST_UTIL)
	@echo Installed file list: $@
	mkdir -p $(dir $@)
	rm -f $@
	$(FILESLIST) $(TARGET_OUT_SYSTEM_DLKM) > $(@:.txt=.json)
	$(FILESLIST_UTIL) -c $(@:.txt=.json) > $@

$(call declare-0p-target,$(INSTALLED_FILES_FILE_SYSTEM_DLKM))
$(call declare-0p-target,$(INSTALLED_FILES_JSON_SYSTEM_DLKM))

system_dlkmimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,system_dlkm)
BUILT_SYSTEM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/system_dlkm.img
define build-system_dlkmimage-target
  $(call pretty,"Target system_dlkm fs image: $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_SYSTEM_DLKM)
  @mkdir -p $(system_dlkmimage_intermediates) && rm -rf $(system_dlkmimage_intermediates)/system_dlkm_image_info.txt
  $(call generate-image-prop-dictionary, $(system_dlkmimage_intermediates)/system_dlkm_image_info.txt, \
	  system_dlkm, skip_fsck=true)
  PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$$PATH \
      $(BUILD_IMAGE) \
          $(if $(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES),,--input-directory-filter-file $(system_dlkmimage_intermediates)/file_list.txt) \
          $(TARGET_OUT_SYSTEM_DLKM) $(system_dlkmimage_intermediates)/system_dlkm_image_info.txt \
          $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) $(TARGET_OUT)
  $(call assert-max-image-size,$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET),$(BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE))
endef

$(eval $(call write-file-lines,$(system_dlkmimage_intermediates)/file_list.txt,$(subst $(TARGET_OUT_SYSTEM_DLKM)/,,$(filter $(TARGET_OUT_SYSTEM_DLKM)/%,$(INTERNAL_SYSTEM_DLKMIMAGE_FILES)))))

# We just build this directly to the install location.
INSTALLED_SYSTEM_DLKMIMAGE_TARGET := $(BUILT_SYSTEM_DLKMIMAGE_TARGET)
$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET): \
    $(INTERNAL_USERIMAGES_DEPS) \
    $(INTERNAL_SYSTEM_DLKMIMAGE_FILES) \
    $(INSTALLED_FILES_FILE_SYSTEM_DLKM) \
    $(system_dlkmimage_intermediates)/file_list.txt
	$(build-system_dlkmimage-target)

SYSTEM_DLKM_NOTICE_DEPS += $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)

$(call declare-1p-container,$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET),$(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEM_DLKMIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEM_DLKM),$(PRODUCT_OUT)/:/)

.PHONY: system_dlkmimage-nodeps sdnod
system_dlkmimage-nodeps sdnod: | $(INTERNAL_USERIMAGES_DEPS) $(system_dlkmimage_intermediates)/file_list.txt
	$(build-system_dlkmimage-target)

.PHONY: sync_system_dlkm
sync sync_system_dlkm: $(INTERNAL_SYSTEM_DLKMIMAGE_FILES)

else ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
INSTALLED_SYSTEM_DLKMIMAGE_TARGET := $(PRODUCT_OUT)/system_dlkm.img
$(eval $(call copy-one-file,$(BOARD_PREBUILT_SYSTEM_DLKMIMAGE),$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)))
endif

# -----------------------------------------------------------------
# dtbo image
ifdef BOARD_PREBUILT_DTBOIMAGE
INSTALLED_DTBOIMAGE_TARGET := $(PRODUCT_OUT)/dtbo.img

ifeq ($(BOARD_AVB_ENABLE),true)
$(INSTALLED_DTBOIMAGE_TARGET): $(BOARD_PREBUILT_DTBOIMAGE) $(AVBTOOL) $(BOARD_AVB_DTBO_KEY_PATH)
	cp $(BOARD_PREBUILT_DTBOIMAGE) $@
	chmod +w $@
	$(AVBTOOL) add_hash_footer \
	    --image $@ \
	    $(call get-partition-size-argument,$(BOARD_DTBOIMG_PARTITION_SIZE)) \
	    --partition_name dtbo $(INTERNAL_AVB_DTBO_SIGNING_ARGS) \
	    $(BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS)

$(call declare-1p-container,$(INSTALLED_DTBOIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_DTBOIMAGE_TARGET),$(BOARD_PREBUILT_DTBOIMAGE),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS+= $(INSTALLED_DTBOIMAGE_TARGET)
else
$(INSTALLED_DTBOIMAGE_TARGET): $(BOARD_PREBUILT_DTBOIMAGE)
	cp $(BOARD_PREBUILT_DTBOIMAGE) $@
endif

endif # BOARD_PREBUILT_DTBOIMAGE

# -----------------------------------------------------------------
# Protected VM firmware image
ifeq ($(BOARD_USES_PVMFWIMAGE),true)

.PHONY: pvmfwimage
pvmfwimage: $(INSTALLED_PVMFWIMAGE_TARGET)

INSTALLED_PVMFWIMAGE_TARGET := $(PRODUCT_OUT)/pvmfw.img
INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET := $(PRODUCT_OUT)/pvmfw_embedded.avbpubkey
INSTALLED_PVMFW_BINARY_TARGET := $(call module-target-built-files,pvmfw_bin)
INTERNAL_PVMFWIMAGE_FILES := $(call module-target-built-files,pvmfw_img)
INTERNAL_PVMFW_EMBEDDED_AVBKEY := $(call module-target-built-files,pvmfw_embedded_key)
INTERNAL_PVMFW_SYMBOL := $(TARGET_OUT_EXECUTABLES_UNSTRIPPED)/pvmfw

$(call declare-1p-container,$(INSTALLED_PVMFWIMAGE_TARGET),)
$(call declare-container-license-deps,$(INSTALLED_PVMFWIMAGE_TARGET),$(INTERNAL_PVMFWIMAGE_FILES),$(PRODUCT_OUT)/:/)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_PVMFWIMAGE_TARGET)

# Place the unstripped pvmfw image to the symbols directory
$(INTERNAL_PVMFWIMAGE_FILES): |$(INTERNAL_PVMFW_SYMBOL)

$(eval $(call copy-one-file,$(INTERNAL_PVMFWIMAGE_FILES),$(INSTALLED_PVMFWIMAGE_TARGET)))

$(INSTALLED_PVMFWIMAGE_TARGET): $(INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET)

$(eval $(call copy-one-file,$(INTERNAL_PVMFW_EMBEDDED_AVBKEY),$(INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET)))

endif # BOARD_USES_PVMFWIMAGE

# Returns a list of image targets corresponding to the given list of partitions. For example, it
# returns "$(INSTALLED_PRODUCTIMAGE_TARGET)" for "product", or "$(INSTALLED_SYSTEMIMAGE_TARGET)
# $(INSTALLED_VENDORIMAGE_TARGET)" for "system vendor".
# (1): list of partitions like "system", "vendor" or "system product system_ext".
define images-for-partitions
$(strip $(foreach item,$(1),\
  $(if $(filter $(item),system_other),$(INSTALLED_SYSTEMOTHERIMAGE_TARGET),\
    $(if $(filter $(item),init_boot),$(INSTALLED_INIT_BOOT_IMAGE_TARGET),\
      $(INSTALLED_$(call to-upper,$(item))IMAGE_TARGET)))))
endef

# -----------------------------------------------------------------
# custom images
INSTALLED_CUSTOMIMAGES_TARGET :=

ifneq ($(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)),)
INTERNAL_AVB_CUSTOMIMAGES_SIGNING_ARGS :=
BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST :=
# If BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH is set, the image will be included in
# BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST, otherwise the image won't be AVB signed.
$(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
	$(if $(BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH), \
	$(eval BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST += $(partition)) \
	$(eval BOARD_$(call to-upper,$(partition))_IMAGE_LIST := $(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST))))

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
          $(call get-partition-size-argument,$(BOARD_AVB_$(call to-upper,$(2))_PARTITION_SIZE)) \
          --partition_name $(2) \
          $(INTERNAL_AVB_CUSTOMIMAGES_SIGNING_ARGS) \
          $(BOARD_AVB_$(call to-upper,$(2))_ADD_HASHTREE_FOOTER_ARGS)
endif
INSTALLED_CUSTOMIMAGES_TARGET += $(3)
endef

# Copy unsigned custom image.
# $(1): the prebuilt custom image.
# $(2): the signed custom image target.
define copy_custom_image
$(2): $(1) $(INTERNAL_USERIMAGES_DEPS)
	@echo Target custom image: $(2)
	mkdir -p $(dir $(2))
	cp $(1) $(2)
INSTALLED_CUSTOMIMAGES_TARGET += $(2)
endef

# Add AVB custom image to droid target
$(foreach partition,$(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), \
  $(foreach image,$(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST), \
     $(eval $(call sign_custom_image,$(image),$(partition),$(PRODUCT_OUT)/$(notdir $(image))))))

# Add unsigned custom image to droid target
$(foreach partition,$(filter-out $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), $(BOARD_CUSTOMIMAGES_PARTITION_LIST)), \
  $(foreach image,$(BOARD_$(call to-upper,$(partition))_IMAGE_LIST), \
     $(eval $(call copy_custom_image,$(image),$(PRODUCT_OUT)/$(notdir $(image))))))
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

$(eval $(call declare-0p-target,$(INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET),))

ifndef BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX
BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
endif

BOARD_AVB_SYSTEM_OTHER_ADD_HASHTREE_FOOTER_ARGS += --rollback_index $(BOARD_AVB_SYSTEM_OTHER_ROLLBACK_INDEX)
endif # end of AVB for BUILDING_SYSTEM_OTHER_IMAGE

INTERNAL_AVB_PARTITIONS_IN_CHAINED_VBMETA_IMAGES := \
    $(BOARD_AVB_VBMETA_SYSTEM) \
    $(BOARD_AVB_VBMETA_VENDOR) \
    $(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS),$(BOARD_AVB_VBMETA_$(call to-upper,$(partition))))

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

# Appends os version as a AVB property descriptor.
SYSTEM_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system.os_version:$(SYSTEM_OS_VERSION)

PRODUCT_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.product.os_version:$(PRODUCT_OS_VERSION)

SYSTEM_EXT_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_ext.os_version:$(SYSTEM_EXT_OS_VERSION)

INIT_BOOT_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.init_boot.os_version:$(INIT_BOOT_OS_VERSION)

BOOT_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.boot.os_version:$(BOOT_OS_VERSION)

VENDOR_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor.os_version:$(VENDOR_OS_VERSION)

ODM_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm.os_version:$(ODM_OS_VERSION)

VENDOR_DLKM_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor_dlkm.os_version:$(VENDOR_DLKM_OS_VERSION)

ODM_DLKM_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm_dlkm.os_version:$(ODM_DLKM_OS_VERSION)

SYSTEM_DLKM_OS_VERSION ?= $(PLATFORM_VERSION_LAST_STABLE)
BOARD_AVB_SYSTEM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_dlkm.os_version:$(SYSTEM_DLKM_OS_VERSION)

# Appends fingerprint and security patch level as a AVB property descriptor.
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.system.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.product.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.product.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_ext.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \
    --prop com.android.build.system_ext.security_patch:$(PLATFORM_SECURITY_PATCH)

BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.init_boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.vendor_boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \

BOARD_AVB_VENDOR_KERNEL_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.vendor_kernel_boot.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE) \

BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.recovery.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.vendor_dlkm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.odm_dlkm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_SYSTEM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_dlkm.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.dtbo.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

BOARD_AVB_PVMFW_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.pvmfw.fingerprint:$(BUILD_FINGERPRINT_FROM_FILE)

# The following vendor- and odm-specific images needs explicit SPL set per board.
# TODO(b/210875415) Is this security_patch property used? Should it be removed from
# boot.img when there is no platform ramdisk included in it?
ifdef BOOT_SECURITY_PATCH
BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.boot.security_patch:$(BOOT_SECURITY_PATCH)
endif

ifdef INIT_BOOT_SECURITY_PATCH
BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.init_boot.security_patch:$(INIT_BOOT_SECURITY_PATCH)
else ifdef BOOT_SECURITY_PATCH
BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.init_boot.security_patch:$(BOOT_SECURITY_PATCH)
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

ifdef SYSTEM_DLKM_SECURITY_PATCH
BOARD_AVB_SYSTEM_DLKM_ADD_HASHTREE_FOOTER_ARGS += \
    --prop com.android.build.system_dlkm.security_patch:$(SYSTEM_DLKM_SECURITY_PATCH)
endif

ifdef PVMFW_SECURITY_PATCH
BOARD_AVB_PVMFW_ADD_HASH_FOOTER_ARGS += \
    --prop com.android.build.pvmfw.security_patch:$(PVMFW_SECURITY_PATCH)
endif

# Append avbpubkey of microdroid-vendor partition into vendor_boot partition.
ifdef MICRODROID_VENDOR_AVBKEY
BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS += \
    --prop_from_file com.android.build.microdroid-vendor.avbpubkey:$(MICRODROID_VENDOR_AVBKEY)
endif

BOOT_FOOTER_ARGS := BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS
INIT_BOOT_FOOTER_ARGS := BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS
VENDOR_BOOT_FOOTER_ARGS := BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS
VENDOR_KERNEL_BOOT_FOOTER_ARGS := BOARD_AVB_VENDOR_KERNEL_BOOT_ADD_HASH_FOOTER_ARGS
DTBO_FOOTER_ARGS := BOARD_AVB_DTBO_ADD_HASH_FOOTER_ARGS
PVMFW_FOOTER_ARGS := BOARD_AVB_PVMFW_ADD_HASH_FOOTER_ARGS
SYSTEM_FOOTER_ARGS := BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS
VENDOR_FOOTER_ARGS := BOARD_AVB_VENDOR_ADD_HASHTREE_FOOTER_ARGS
RECOVERY_FOOTER_ARGS := BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS
PRODUCT_FOOTER_ARGS := BOARD_AVB_PRODUCT_ADD_HASHTREE_FOOTER_ARGS
SYSTEM_EXT_FOOTER_ARGS := BOARD_AVB_SYSTEM_EXT_ADD_HASHTREE_FOOTER_ARGS
ODM_FOOTER_ARGS := BOARD_AVB_ODM_ADD_HASHTREE_FOOTER_ARGS
VENDOR_DLKM_FOOTER_ARGS := BOARD_AVB_VENDOR_DLKM_ADD_HASHTREE_FOOTER_ARGS
ODM_DLKM_FOOTER_ARGS := BOARD_AVB_ODM_DLKM_ADD_HASHTREE_FOOTER_ARGS
SYSTEM_DLKM_FOOTER_ARGS := BOARD_AVB_SYSTEM_DLKM_ADD_HASHTREE_FOOTER_ARGS

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
$(eval _key_path := BOARD_AVB_$(PART)_KEY_PATH)
$(if $($(_rollback_index_location)),,$(error $(_rollback_index_location) is not defined))
$(if $($(_key_path)),,$(error $(_key_path) is not defined))

INTERNAL_AVB_MAKE_VBMETA_IMAGE_ARGS += \
    --chain_partition $(part):$($(_rollback_index_location)):$(AVB_CHAIN_KEY_DIR)/$(part).avbpubkey
endef

ifdef INSTALLED_BOOTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,boot))
endif

ifdef INSTALLED_INIT_BOOT_IMAGE_TARGET
$(eval $(call check-and-set-avb-args,init_boot))
endif

ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,vendor_boot))
endif

ifdef INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET
$(eval $(call check-and-set-avb-args,vendor_kernel_boot))
endif

ifdef INSTALLED_SYSTEMIMAGE_TARGET
$(eval $(call check-and-set-avb-args,system))
endif

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

ifdef INSTALLED_SYSTEM_DLKMIMAGE_TARGET
$(eval $(call check-and-set-avb-args,system_dlkm))
endif

ifdef INSTALLED_DTBOIMAGE_TARGET
$(eval $(call check-and-set-avb-args,dtbo))
endif

ifdef INSTALLED_PVMFWIMAGE_TARGET
$(eval $(call check-and-set-avb-args,pvmfw))
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

ifdef BOARD_AVB_VBMETA_CUSTOM_PARTITIONS
$(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS),$(eval $(call check-and-set-avb-args,vbmeta_$(partition))))
$(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS),$(eval BOARD_AVB_MAKE_VBMETA_$(call to-upper,$(partition))_IMAGE_ARGS += --padding_size 4096))
endif

ifneq ($(strip $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST)),)
$(foreach partition,$(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), \
    $(eval $(call check-and-set-custom-avb-chain-args,$(partition))))
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

ifdef BOARD_AVB_VBMETA_CUSTOM_PARTITIONS
  $(foreach partition,$(call to-upper,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)), \
      $(if $(BOARD_AVB_VBMETA_$(partition)_ROLLBACK_INDEX),$(eval \
        BOARD_AVB_MAKE_VBMETA_$(partition)_IMAGE_ARGS += \
          --rollback_index $(BOARD_AVB_VBMETA_$(partition)_ROLLBACK_INDEX))))
endif

# $(1): the directory to extract public keys to
define extract-avb-chain-public-keys
  $(if $(BOARD_AVB_BOOT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_BOOT_KEY_PATH) \
      --output $(1)/boot.avbpubkey)
  $(if $(BOARD_AVB_INIT_BOOT_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_INIT_BOOT_KEY_PATH) \
      --output $(1)/init_boot.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_BOOT_KEY_PATH),\
    $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_BOOT_KEY_PATH) \
      --output $(1)/vendor_boot.avbpubkey)
  $(if $(BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH),\
    $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH) \
      --output $(1)/vendor_kernel_boot.avbpubkey)
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
  $(if $(BOARD_AVB_SYSTEM_DLKM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_SYSTEM_DLKM_KEY_PATH) \
      --output $(1)/system_dlkm.avbpubkey)
  $(if $(BOARD_AVB_DTBO_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_DTBO_KEY_PATH) \
      --output $(1)/dtbo.avbpubkey)
  $(if $(BOARD_AVB_PVMFW_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_PVMFW_KEY_PATH) \
      --output $(1)/pvmfw.avbpubkey)
  $(if $(BOARD_AVB_RECOVERY_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_RECOVERY_KEY_PATH) \
      --output $(1)/recovery.avbpubkey)
  $(if $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH) \
        --output $(1)/vbmeta_system.avbpubkey)
  $(if $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH),\
    $(hide) $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH) \
        --output $(1)/vbmeta_vendor.avbpubkey)
  $(if $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST),\
    $(hide) $(foreach partition,$(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), \
        $(AVBTOOL) extract_public_key --key $(BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH) \
            --output $(1)/$(partition).avbpubkey;)) \
  $(if $(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS),\
    $(hide) $(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS), \
        $(AVBTOOL) extract_public_key --key $(BOARD_AVB_VBMETA_$(call to-upper,$(partition))_KEY_PATH) \
            --output $(1)/vbmeta_$(partition).avbpubkey;))
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

$(call declare-1p-container,$(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET),)

SYSTEM_NOTICE_DEPS += $(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET)
endif
endif # BUILDING_SYSTEM_IMAGE

ifdef BOARD_AVB_VBMETA_VENDOR
INSTALLED_VBMETA_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vbmeta_vendor.img
$(INSTALLED_VBMETA_VENDORIMAGE_TARGET): \
	    $(AVBTOOL) \
	    $(call images-for-partitions,$(BOARD_AVB_VBMETA_VENDOR)) \
	    $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH)
	$(call build-chained-vbmeta-image,vbmeta_vendor)

$(call declare-1p-container,$(INSTALLED_VBMETA_VENDORIMAGE_TARGET),)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_VBMETA_VENDORIMAGE_TARGET)
endif

ifdef BOARD_AVB_VBMETA_CUSTOM_PARTITIONS
define declare-custom-vbmeta-target
INSTALLED_VBMETA_$(call to-upper,$(1))IMAGE_TARGET := $(PRODUCT_OUT)/vbmeta_$(call to-lower,$(1)).img
$$(INSTALLED_VBMETA_$(call to-upper,$(1))IMAGE_TARGET): \
	    $(AVBTOOL) \
	    $(call images-for-partitions,$(BOARD_AVB_VBMETA_$(call to-upper,$(1)))) \
	    $(BOARD_AVB_VBMETA_$(call to-upper,$(1))_KEY_PATH)
	$$(call build-chained-vbmeta-image,vbmeta_$(call to-lower,$(1)))

$(call declare-1p-container,$(INSTALLED_VBMETA_$(call to-upper,$(1))IMAGE_TARGET),)

UNMOUNTED_NOTICE_VENDOR_DEPS += $(INSTALLED_VBMETA_$(call to-upper,$(1))IMAGE_TARGET)
endef

$(foreach partition,\
          $(call to-upper,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)),\
          $(eval $(call declare-custom-vbmeta-target,$(partition))))
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
	    $(INSTALLED_INIT_BOOT_IMAGE_TARGET) \
	    $(INSTALLED_VENDOR_BOOTIMAGE_TARGET) \
	    $(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET) \
	    $(INSTALLED_SYSTEMIMAGE_TARGET) \
	    $(INSTALLED_VENDORIMAGE_TARGET) \
	    $(INSTALLED_PRODUCTIMAGE_TARGET) \
	    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
	    $(INSTALLED_ODMIMAGE_TARGET) \
	    $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) \
	    $(INSTALLED_ODM_DLKMIMAGE_TARGET) \
	    $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) \
	    $(INSTALLED_DTBOIMAGE_TARGET) \
	    $(INSTALLED_PVMFWIMAGE_TARGET) \
	    $(INSTALLED_CUSTOMIMAGES_TARGET) \
	    $(INSTALLED_RECOVERYIMAGE_TARGET) \
	    $(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET) \
	    $(INSTALLED_VBMETA_VENDORIMAGE_TARGET) \
      $(foreach partition,$(call to-upper,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)),$(INSTALLED_VBMETA_$(partition)IMAGE_TARGET)) \
	    $(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH) \
	    $(BOARD_AVB_VBMETA_VENDOR_KEY_PATH) \
      $(foreach partition,$(call to-upper,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)),$(BOARD_AVB_VBMETA_$(partition)_KEY_PATH)) \
	    $(BOARD_AVB_KEY_PATH)
	$(build-vbmetaimage-target)

$(call declare-1p-container,$(INSTALLED_VBMETAIMAGE_TARGET),)

UNMOUNTED_NOTICE_DEPS += $(INSTALLED_VBMETAIMAGE_TARGET)

.PHONY: vbmetaimage-nodeps
vbmetaimage-nodeps: PRIVATE_AVB_VBMETA_SIGNING_ARGS := \
    --algorithm $(BOARD_AVB_ALGORITHM) --key $(BOARD_AVB_KEY_PATH)
vbmetaimage-nodeps:
	$(build-vbmetaimage-target)
endif # BUILDING_VBMETA_IMAGE

endif # BOARD_AVB_ENABLE

# List of files from all images
INTERNAL_ALLIMAGES_FILES := \
    $(FULL_SYSTEMIMAGE_DEPS) \
    $(INTERNAL_RAMDISK_FILES) \
    $(INTERNAL_USERDATAIMAGE_FILES) \
    $(INTERNAL_VENDORIMAGE_FILES) \
    $(INTERNAL_PRODUCTIMAGE_FILES) \
    $(INTERNAL_SYSTEM_EXTIMAGE_FILES) \
    $(INTERNAL_ODMIMAGE_FILES) \
    $(INTERNAL_VENDOR_DLKMIMAGE_FILES) \
    $(INTERNAL_ODM_DLKMIMAGE_FILES) \
    $(INTERNAL_SYSTEM_DLKMIMAGE_FILES) \
    $(INTERNAL_PVMFWIMAGE_FILES) \

# -----------------------------------------------------------------
# Run apex_sepolicy_tests for all installed APEXes

ifeq (,$(TARGET_BUILD_UNBUNDLED))
intermediate := $(call intermediates-dir-for,PACKAGING,apex_sepolicy_tests)
apex_dirs := \
  $(TARGET_OUT)/apex/% \
  $(TARGET_OUT_SYSTEM_EXT)/apex/% \
  $(TARGET_OUT_VENDOR)/apex/% \
  $(TARGET_OUT_PRODUCT)/apex/% \

apex_files := $(sort $(filter $(apex_dirs), $(INTERNAL_ALLIMAGES_FILES)))
apex_dirs :=

# $1: apex file
# $2: output file
define _run_apex_sepolicy_tests
$2: $1 \
    $(HOST_OUT_EXECUTABLES)/apex_sepolicy_tests \
    $(HOST_OUT_EXECUTABLES)/deapexer \
    $(HOST_OUT_EXECUTABLES)/debugfs_static
	@rm -rf $$@
	@mkdir -p $(dir $$@)
	$(HOST_OUT_EXECUTABLES)/apex_sepolicy_tests --all -f <($(HOST_OUT_EXECUTABLES)/deapexer --debugfs_path $(HOST_OUT_EXECUTABLES)/debugfs_static list -Z $$<)
	@touch $$@
endef

# $1: apex file list
define run_apex_sepolicy_tests
$(foreach apex_file,$1, \
  $(eval passfile := $(patsubst $(PRODUCT_OUT)/%,$(intermediate)/%.pass,$(apex_file))) \
  $(eval $(call _run_apex_sepolicy_tests,$(apex_file),$(passfile))) \
  $(passfile))
endef

.PHONY: run_apex_sepolicy_tests
run_apex_sepolicy_tests: $(call run_apex_sepolicy_tests,$(apex_files))

droid_targets: run_apex_sepolicy_tests

apex_files :=
intermediate :=
endif # TARGET_BUILD_UNBUNDLED

# -----------------------------------------------------------------
# Check VINTF of build

# Note: vendor_dlkm, odm_dlkm, and system_dlkm does not have VINTF files.
ifeq (,$(TARGET_BUILD_UNBUNDLED))

intermediates := $(call intermediates-dir-for,PACKAGING,check_vintf_all)
check_vintf_all_deps :=

# -----------------------------------------------------------------
# Activate vendor APEXes for checkvintf

apex_dirs := \
  $(TARGET_OUT_VENDOR)/apex/% \

apex_files := $(sort $(filter $(apex_dirs), $(INTERNAL_ALLIMAGES_FILES)))

APEX_OUT := $(intermediates)/apex
APEX_INFO_FILE := $(APEX_OUT)/apex-info-list.xml

# apexd_host scans/activates APEX files and writes /apex/apex-info-list.xml
# Note that `@echo $(PRIVATE_APEX_FILES)` line is added to trigger the rule when the APEX list is changed.
$(APEX_INFO_FILE): PRIVATE_APEX_FILES := $(apex_files)
$(APEX_INFO_FILE): $(HOST_OUT_EXECUTABLES)/apexd_host $(apex_files)
	@echo "Extracting apexes..."
	@echo $(PRIVATE_APEX_FILES) > /dev/null
	@rm -rf $(APEX_OUT)
	@mkdir -p $(APEX_OUT)
	$< --vendor_path $(TARGET_OUT_VENDOR) \
	   --apex_path $(APEX_OUT)

apex_files :=
apex_dirs :=

# The build system only writes VINTF metadata to */etc/vintf paths. Legacy paths aren't needed here
# because they are only used for prebuilt images.
# APEX files in /vendor/apex can have VINTF fragments as well.
check_vintf_common_srcs_patterns := \
  $(TARGET_OUT)/etc/vintf/% \
  $(TARGET_OUT_VENDOR)/etc/vintf/% \
  $(TARGET_OUT_ODM)/etc/vintf/% \
  $(TARGET_OUT_PRODUCT)/etc/vintf/% \
  $(TARGET_OUT_SYSTEM_EXT)/etc/vintf/% \
  $(TARGET_OUT_VENDOR)/apex/% \

check_vintf_common_srcs := $(sort $(filter $(check_vintf_common_srcs_patterns),$(INTERNAL_ALLIMAGES_FILES)))
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

check_vintf_system_log := $(intermediates)/check_vintf_system.log
check_vintf_all_deps += $(check_vintf_system_log)
$(check_vintf_system_log): $(HOST_OUT_EXECUTABLES)/checkvintf $(check_vintf_system_deps)
	@( $< --check-one --dirmap /system:$(TARGET_OUT) > $@ 2>&1 ) || ( cat $@ && exit 1 )
$(call declare-1p-target,$(check_vintf_system_log))
check_vintf_system_log :=

# -- Check framework manifest against frozen manifests for GSI targets. They need to be compatible.
ifneq (true, $(BUILDING_VENDOR_IMAGE))
    vintffm_log := $(intermediates)/vintffm.log
endif
check_vintf_all_deps += $(vintffm_log)
$(vintffm_log): $(HOST_OUT_EXECUTABLES)/vintffm $(check_vintf_system_deps)
	@( $< --check --dirmap /system:$(TARGET_OUT) \
	  --dirmap /system_ext:$(TARGET_OUT_SYSTEM_EXT) \
	  --dirmap /product:$(TARGET_OUT_PRODUCT) \
	  $(VINTF_FRAMEWORK_MANIFEST_FROZEN_DIR) > $@ 2>&1 ) || ( cat $@ && exit 1 )

$(call declare-1p-target,$(vintffm_log))

endif # check_vintf_system_deps
check_vintf_system_deps :=

# -- Check vendor manifest / matrix including fragments (excluding other device manifests / matrices)
check_vintf_vendor_deps := $(filter $(TARGET_OUT_VENDOR)/etc/vintf/%, $(check_vintf_common_srcs))
check_vintf_vendor_deps += $(filter $(TARGET_OUT_VENDOR)/apex/%, $(check_vintf_common_srcs))
ifneq ($(strip $(check_vintf_vendor_deps)),)
check_vintf_has_vendor := true
check_vintf_vendor_log := $(intermediates)/check_vintf_vendor.log
check_vintf_all_deps += $(check_vintf_vendor_log)
# Check vendor SKU=(empty) case when:
# - DEVICE_MANIFEST_FILE is not empty; OR
# - DEVICE_MANIFEST_FILE is empty AND DEVICE_MANIFEST_SKUS is empty (only vendor manifest fragments are used)
$(check_vintf_vendor_log): PRIVATE_VENDOR_SKUS := \
  $(if $(DEVICE_MANIFEST_FILE),EMPTY_VENDOR_SKU_PLACEHOLDER,\
    $(if $(DEVICE_MANIFEST_SKUS),,EMPTY_VENDOR_SKU_PLACEHOLDER)) \
  $(DEVICE_MANIFEST_SKUS)
$(check_vintf_vendor_log): $(HOST_OUT_EXECUTABLES)/checkvintf $(check_vintf_vendor_deps) $(APEX_INFO_FILE)
	$(foreach vendor_sku,$(PRIVATE_VENDOR_SKUS), \
	  ( $< --check-one --dirmap /vendor:$(TARGET_OUT_VENDOR) --dirmap /apex:$(APEX_OUT) \
	       --property ro.boot.product.vendor.sku=$(filter-out EMPTY_VENDOR_SKU_PLACEHOLDER,$(vendor_sku)) \
	       > $@ 2>&1 ) || ( cat $@ && exit 1 ); )
$(call declare-1p-target,$(check_vintf_vendor_log))
check_vintf_vendor_log :=
endif # check_vintf_vendor_deps
check_vintf_vendor_deps :=

# -- Kernel version and configurations.
ifeq ($(PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS),true)

BUILT_KERNEL_CONFIGS_FILE := $(intermediates)/kernel_configs.txt
BUILT_KERNEL_VERSION_FILE := $(intermediates)/kernel_version.txt

my_board_extracted_kernel :=

# Tools for decompression that is not in PATH.
# Check $(EXTRACT_KERNEL) for decompression algorithms supported by the script.
# Algorithms that are in the script but not in this list will be found in PATH.
my_decompress_tools := \
    lz4:$(HOST_OUT_EXECUTABLES)/lz4 \


# BOARD_KERNEL_CONFIG_FILE and BOARD_KERNEL_VERSION can be used to override the values extracted
# from INSTALLED_KERNEL_TARGET.
ifdef BOARD_KERNEL_VERSION
$(BUILT_KERNEL_VERSION_FILE): PRIVATE_DECOMPRESS_TOOLS := $(my_decompress_tools)
$(BUILT_KERNEL_VERSION_FILE): $(foreach pair,$(my_decompress_tools),$(call word-colon,2,$(pair)))
$(BUILT_KERNEL_VERSION_FILE): $(EXTRACT_KERNEL) $(firstword $(INSTALLED_KERNEL_TARGET))
	KERNEL_RELEASE=`$(EXTRACT_KERNEL) --tools $(PRIVATE_DECOMPRESS_TOOLS) --input $(firstword $(INSTALLED_KERNEL_TARGET)) \
	  --output-release` ;\
  if [ "$$KERNEL_RELEASE" != '$(BOARD_KERNEL_VERSION)' ]; then \
    echo "Specified kernel version '$(BOARD_KERNEL_VERSION)' does not match actual kernel version '$$KERNEL_RELEASE' " ; exit 1; fi;
	echo '$(BOARD_KERNEL_VERSION)' > $@

ifdef BOARD_KERNEL_CONFIG_FILE
$(BUILT_KERNEL_CONFIGS_FILE): $(BOARD_KERNEL_CONFIG_FILE)
	cp $< $@

$(call declare-license-metadata,$(BUILT_KERNEL_CONFIGS_FILE),SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,"Kernel",kernel)
$(call declare-license-metadata,$(BUILT_KERNEL_VERSION_FILE),SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,"Kernel",kernel)

my_board_extracted_kernel := true
endif # BOARD_KERNEL_CONFIG_FILE
endif # BOARD_KERNEL_VERSION


ifneq ($(my_board_extracted_kernel),true)
ifdef INSTALLED_KERNEL_TARGET
ifndef BOARD_KERNEL_VERSION
$(BUILT_KERNEL_CONFIGS_FILE): .KATI_IMPLICIT_OUTPUTS := $(BUILT_KERNEL_VERSION_FILE)
endif
$(BUILT_KERNEL_CONFIGS_FILE): PRIVATE_DECOMPRESS_TOOLS := $(my_decompress_tools)
$(BUILT_KERNEL_CONFIGS_FILE): $(foreach pair,$(my_decompress_tools),$(call word-colon,2,$(pair)))
$(BUILT_KERNEL_CONFIGS_FILE): $(EXTRACT_KERNEL) $(firstword $(INSTALLED_KERNEL_TARGET))
	$< --tools $(PRIVATE_DECOMPRESS_TOOLS) --input $(firstword $(INSTALLED_KERNEL_TARGET)) \
	  --output-configs $@ \
	  $(if $(BOARD_KERNEL_VERSION),,--output-release $(BUILT_KERNEL_VERSION_FILE))

$(call declare-license-metadata,$(BUILT_KERNEL_CONFIGS_FILE),SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,"Kernel",kernel)

my_board_extracted_kernel := true
endif # INSTALLED_KERNEL_TARGET
endif # my_board_extracted_kernel

ifneq ($(my_board_extracted_kernel),true)
ifdef INSTALLED_BOOTIMAGE_TARGET
$(BUILT_KERNEL_CONFIGS_FILE): .KATI_IMPLICIT_OUTPUTS := $(BUILT_KERNEL_VERSION_FILE)
$(BUILT_KERNEL_CONFIGS_FILE): PRIVATE_DECOMPRESS_TOOLS := $(my_decompress_tools)
$(BUILT_KERNEL_CONFIGS_FILE): $(foreach pair,$(my_decompress_tools),$(call word-colon,2,$(pair)))
$(BUILT_KERNEL_CONFIGS_FILE): PRIVATE_UNPACKED_BOOTIMG := $(intermediates)/unpacked_bootimage
$(BUILT_KERNEL_CONFIGS_FILE): \
        $(HOST_OUT_EXECUTABLES)/unpack_bootimg \
        $(EXTRACT_KERNEL) \
        $(INSTALLED_BOOTIMAGE_TARGET)
	$(HOST_OUT_EXECUTABLES)/unpack_bootimg --boot_img $(INSTALLED_BOOTIMAGE_TARGET) --out $(PRIVATE_UNPACKED_BOOTIMG)
	$(EXTRACT_KERNEL) --tools $(PRIVATE_DECOMPRESS_TOOLS) --input $(PRIVATE_UNPACKED_BOOTIMG)/kernel \
	  --output-configs $@ \
	  --output-release $(BUILT_KERNEL_VERSION_FILE)

$(call declare-license-metadata,$(BUILT_KERNEL_CONFIGS_FILE),SPDX-license-identifier-GPL-2.0-only,restricted,$(BUILD_SYSTEM)/LINUX_KERNEL_COPYING,"Kernel",kernel)

my_board_extracted_kernel := true
endif # INSTALLED_BOOTIMAGE_TARGET
endif # my_board_extracted_kernel

ifeq ($(my_board_extracted_kernel),true)
$(call dist-for-goals, droid_targets, $(BUILT_KERNEL_VERSION_FILE))
else
$(warning Neither INSTALLED_KERNEL_TARGET nor INSTALLED_BOOTIMAGE_TARGET is defined when \
    PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS  is true. Information about the updated kernel \
    cannot be built into OTA update package. You can fix this by: \
    (1) setting TARGET_NO_KERNEL to false and installing the built kernel to $(PRODUCT_OUT)/kernel,\
        so that kernel information will be extracted from the built kernel; or \
    (2) Add a prebuilt boot image and specify it in BOARD_PREBUILT_BOOTIMAGE; or \
    (3) extracting kernel configuration and defining BOARD_KERNEL_CONFIG_FILE and \
        BOARD_KERNEL_VERSION manually; or \
    (4) unsetting PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS manually.)
# Clear their values to indicate that these two files does not exist.
BUILT_KERNEL_CONFIGS_FILE :=
BUILT_KERNEL_VERSION_FILE :=
endif

my_decompress_tools :=
my_board_extracted_kernel :=

endif # PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS

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

check_vintf_compatible_log := $(intermediates)/check_vintf_compatible.log
check_vintf_all_deps += $(check_vintf_compatible_log)

check_vintf_compatible_args :=
check_vintf_compatible_deps := $(check_vintf_common_srcs) $(APEX_INFO_FILE)

ifeq ($(PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS),true)
ifneq (,$(BUILT_KERNEL_VERSION_FILE)$(BUILT_KERNEL_CONFIGS_FILE))
check_vintf_compatible_args += --kernel $(BUILT_KERNEL_VERSION_FILE):$(BUILT_KERNEL_CONFIGS_FILE)
check_vintf_compatible_deps += $(BUILT_KERNEL_CONFIGS_FILE) $(BUILT_KERNEL_VERSION_FILE)
endif # BUILT_KERNEL_VERSION_FILE != "" || BUILT_KERNEL_CONFIGS_FILE != ""
endif # PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS

check_vintf_compatible_args += \
  --dirmap /system:$(TARGET_OUT) \
  --dirmap /vendor:$(TARGET_OUT_VENDOR) \
  --dirmap /odm:$(TARGET_OUT_ODM) \
  --dirmap /product:$(TARGET_OUT_PRODUCT) \
  --dirmap /system_ext:$(TARGET_OUT_SYSTEM_EXT) \
  --dirmap /apex:$(APEX_OUT) \

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
	@echo "PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS=$(PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS)" > $@
	@echo -n -e 'Deps: \n  ' >> $@
	@sed 's/ /\n  /g' <<< "$(PRIVATE_CHECK_VINTF_DEPS)" >> $@
	@echo -n -e 'Args: \n  ' >> $@
	@cat <<< "$(PRIVATE_CHECK_VINTF_ARGS)" >> $@
	$(foreach odm_sku,$(PRIVATE_ODM_SKUS), $(foreach vendor_sku,$(PRIVATE_VENDOR_SKUS), \
	  echo "For ODM SKU = $(odm_sku), vendor SKU = $(vendor_sku)" >> $@; \
	  ( $< --check-compat $(PRIVATE_CHECK_VINTF_ARGS) \
	       --property ro.boot.product.hardware.sku=$(filter-out EMPTY_ODM_SKU_PLACEHOLDER,$(odm_sku)) \
	       --property ro.boot.product.vendor.sku=$(filter-out EMPTY_VENDOR_SKU_PLACEHOLDER,$(vendor_sku)) \
	       >> $@ 2>&1 ) || (cat $@ && exit 1); ))

$(call declare-1p-target,$(check_vintf_compatible_log))

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

PARTITIONS_AND_OTHER_IN_SUPER := $(BOARD_SUPER_PARTITION_PARTITION_LIST)

# Add the system other image to the misc_info. Because factory ota may install system_other to the super partition.
ifdef BUILDING_SYSTEM_OTHER_IMAGE
PARTITIONS_AND_OTHER_IN_SUPER += system_other
endif # BUILDING_SYSTEM_OTHER_IMAGE

# $(1): misc_info.txt
# #(2): optional log file
define check-all-partition-sizes-target
  mkdir -p $(dir $(1))
  rm -f $(1)
  $(call dump-super-image-info, $(1))
  $(foreach partition,$(PARTITIONS_AND_OTHER_IN_SUPER), \
    echo "$(partition)_image="$(call images-for-partitions,$(partition)) >> $(1);)
  $(CHECK_PARTITION_SIZES) $(if $(2),--logfile $(2),-v) $(1)
endef

check_all_partition_sizes_log := $(call intermediates-dir-for,PACKAGING,check-all-partition-sizes)/check_all_partition_sizes.log
droid_targets: $(check_all_partition_sizes_log)
$(call dist-for-goals, droid_targets, $(check_all_partition_sizes_log))

$(check_all_partition_sizes_log): \
    $(CHECK_PARTITION_SIZES) \
    $(call images-for-partitions,$(PARTITIONS_AND_OTHER_IN_SUPER))
	$(call check-all-partition-sizes-target, \
	  $(call intermediates-dir-for,PACKAGING,check-all-partition-sizes)/misc_info.txt, \
	  $@)

$(call declare-1p-target,$(check_all_partition_sizes_log))

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
  # A target without a kernel may be one of the following:
  # - A generic target. In this case, the OTA package usually isn't built.
  #   PRODUCT_BUILD_GENERIC_OTA_PACKAGE may be set to true to force OTA package
  #   generation.
  # - A real device target, with TARGET_NO_KERNEL set to true and
  #   BOARD_PREBUILT_BOOTIMAGE set. In this case, it is valid to generate
  #   an OTA package.
  ifneq ($(PRODUCT_BUILD_GENERIC_OTA_PACKAGE),true)
    ifneq ($(filter generic%,$(TARGET_DEVICE)),)
      build_ota_package := false
    endif
    ifeq ($(INSTALLED_BOOTIMAGE_TARGET),)
      ifeq ($(TARGET_NO_KERNEL),true)
        build_ota_package := false
      endif
    endif # INSTALLED_BOOTIMAGE_TARGET == ""
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
  create_brick_ota \
  delta_generator \
  e2fsck \
  e2fsdroid \
  fc_sort \
  fec \
  fsck.erofs \
  fsck.f2fs \
  fs_config \
  generate_verity_key \
  host_init_verifier \
  img2simg \
  img_from_target_files \
  imgdiff \
  initrd_bootconfig \
  libconscrypt_openjdk_jni \
  lpmake \
  lpunpack \
  lz4 \
  make_f2fs \
  make_f2fs_casefold \
  merge_ota \
  merge_target_files \
  mk_combined_img \
  mkbootfs \
  mkbootimg \
  mke2fs \
  mke2fs.conf \
  mkfs.erofs \
  mkf2fsuserimg \
  mksquashfs \
  mksquashfsimage \
  mkuserimg_mke2fs \
  ota_extractor \
  ota_from_target_files \
  repack_bootimg \
  secilc \
  sefcontext_compile \
  sgdisk \
  shflags \
  sign_apex \
  sign_target_files_apks \
  sign_virt_apex \
  signapk \
  simg2img \
  sload_f2fs \
  toybox \
  tune2fs \
  unpack_bootimg \
  update_device \
  update_host_simulator \
  validate_target_files \
  verity_signer \
  verity_verifier \
  zipalign \
  zucchini \
  zip2zip \


# Additional tools to unpack and repack the apex file.
INTERNAL_OTATOOLS_MODULES += \
  apexd_host \
  apexer \
  apex_compression_tool \
  deapexer \
  debugfs_static \
  fsck.erofs \
  make_erofs \
  merge_zips \
  resize2fs \
  soong_zip \

ifeq (true,$(PRODUCT_SUPPORTS_VBOOT))
INTERNAL_OTATOOLS_MODULES += \
  futility-host \
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
      -name "*.pk8"))

ifneq (,$(wildcard packages/modules))
INTERNAL_OTATOOLS_PACKAGE_FILES += \
  $(sort $(shell find packages/modules -type f -name "*.x509.pem" -o -name "*.pk8" -o -name \
      "key.pem"))
endif

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
  $(shell find build/make/tools/releasetools -name "*.pyc" -prune -o \
      \( -type f -o -type l \) -print | sort)

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

$(call declare-1p-container,$(BUILT_OTATOOLS_PACKAGE),build)
$(call declare-container-license-deps,$(INTERNAL_OTATOOLS_PACKAGE_FILES) $(INTERNAL_OTATOOLS_RELEASETOOLS),$(BUILT_OTATOOLS_PACKAGE):)

.PHONY: otatools-package
otatools-package: $(BUILT_OTATOOLS_PACKAGE)

$(call dist-for-goals, otatools-package, \
  $(BUILT_OTATOOLS_PACKAGE) \
)

endif # build_otatools_package

# -----------------------------------------------------------------
#  fastboot-info.txt
FASTBOOT_INFO_VERSION = 1

INSTALLED_FASTBOOT_INFO_TARGET := $(PRODUCT_OUT)/fastboot-info.txt

$(INSTALLED_FASTBOOT_INFO_TARGET):
	rm -f $@
	$(call pretty,"Target fastboot-info.txt: $@")
	$(hide) echo "# fastboot-info for $(TARGET_PRODUCT)" >> $@
	$(hide) echo "version $(FASTBOOT_INFO_VERSION)" >> $@
ifneq ($(INSTALLED_BOOTIMAGE_TARGET),)
	$(hide) echo "flash boot" >> $@
endif
ifneq ($(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
	$(hide) echo "flash init_boot" >> $@
endif
ifdef BOARD_PREBUILT_DTBOIMAGE
	$(hide) echo "flash dtbo" >> $@
endif
ifneq ($(INSTALLED_DTIMAGE_TARGET),)
	$(hide) echo "flash dts dt.img" >> $@
endif
ifneq ($(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET),)
	$(hide) echo "flash vendor_kernel_boot" >> $@
endif
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) echo "flash recovery" >> $@
endif
ifeq ($(BOARD_USES_PVMFWIMAGE),true)
	$(hide) echo "flash pvmfw" >> $@
endif
ifneq ($(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
	$(hide) echo "flash vendor_boot" >> $@
endif
ifeq ($(BOARD_AVB_ENABLE),true)
ifeq ($(BUILDING_VBMETA_IMAGE),true)
	$(hide) echo "flash --apply-vbmeta vbmeta" >> $@
endif
ifneq (,$(strip $(BOARD_AVB_VBMETA_SYSTEM)))
	$(hide) echo "flash vbmeta_system" >> $@
endif
ifneq (,$(strip $(BOARD_AVB_VBMETA_VENDOR)))
	$(hide) echo "flash vbmeta_vendor" >> $@
endif
ifneq (,$(strip $(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)))
	$(hide) $(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS), \
	  echo "flash vbmeta_$(partition)" >> $@;)
endif
endif # BOARD_AVB_ENABLE
	$(hide) echo "reboot fastboot" >> $@
	$(hide) echo "update-super" >> $@
	$(hide) $(foreach partition,$(BOARD_SUPER_PARTITION_PARTITION_LIST), \
	  echo "flash $(partition)" >> $@;)
ifdef BUILDING_SYSTEM_OTHER_IMAGE
	$(hide) echo "flash --slot-other system system_other.img" >> $@
endif
ifdef BUILDING_CACHE_IMAGE
	$(hide) echo "if-wipe erase cache" >> $@
endif
	$(hide) echo "if-wipe erase userdata" >> $@
ifeq ($(BOARD_USES_METADATA_PARTITION),true)
	$(hide) echo "if-wipe erase metadata" >> $@
endif

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
ifneq ($(INSTALLED_INIT_BOOT_IMAGE_TARGET),)
	$(hide) echo "init_boot=true" >> $@
	$(hide) echo "init_boot_size=$(BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE)" >> $@
endif
ifeq ($(BOARD_RAMDISK_USE_LZ4),true)
	echo "lz4_ramdisks=true" >> $@
endif
ifneq ($(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
	echo "vendor_boot=true" >> $@
	echo "vendor_boot_size=$(BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE)" >> $@
endif
ifneq ($(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET),)
	echo "vendor_kernel_boot=true" >> $@
	echo "vendor_kernel_boot_size=$(BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE)" >> $@
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
ifdef PRODUCT_EXTRA_OTA_KEYS
	$(hide) echo "extra_ota_keys=$(PRODUCT_EXTRA_OTA_KEYS)" >> $@
endif
ifdef PRODUCT_EXTRA_RECOVERY_KEYS
	$(hide) echo "extra_recovery_keys=$(PRODUCT_EXTRA_RECOVERY_KEYS)" >> $@
endif
	$(hide) echo 'mkbootimg_args=$(BOARD_MKBOOTIMG_ARGS)' >> $@
	$(hide) echo 'recovery_mkbootimg_args=$(BOARD_RECOVERY_MKBOOTIMG_ARGS)' >> $@
	$(hide) echo 'mkbootimg_version_args=$(INTERNAL_MKBOOTIMG_VERSION_ARGS)' >> $@
	$(hide) echo 'mkbootimg_init_args=$(BOARD_MKBOOTIMG_INIT_ARGS)' >> $@
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
ifeq ($(BUILDING_VBMETA_IMAGE),true)
	$(hide) echo "avb_building_vbmeta_image=true" >> $@
endif # BUILDING_VBMETA_IMAGE
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
	$(hide) echo "avb_init_boot_add_hash_footer_args=$(BOARD_AVB_INIT_BOOT_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_INIT_BOOT_KEY_PATH
	$(hide) echo "avb_init_boot_key_path=$(BOARD_AVB_INIT_BOOT_KEY_PATH)" >> $@
	$(hide) echo "avb_init_boot_algorithm=$(BOARD_AVB_INIT_BOOT_ALGORITHM)" >> $@
	$(hide) echo "avb_init_boot_rollback_index_location=$(BOARD_AVB_INIT_BOOT_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_INIT_BOOT_KEY_PATH
	echo "avb_vendor_boot_add_hash_footer_args=$(BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_VENDOR_BOOT_KEY_PATH
	echo "avb_vendor_boot_key_path=$(BOARD_AVB_VENDOR_BOOT_KEY_PATH)" >> $@
	echo "avb_vendor_boot_algorithm=$(BOARD_AVB_VENDOR_BOOT_ALGORITHM)" >> $@
	echo "avb_vendor_boot_rollback_index_location=$(BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VENDOR_BOOT_KEY_PATH
	echo "avb_vendor_kernel_boot_add_hash_footer_args=$(BOARD_AVB_VENDOR_KERNEL_BOOT_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH
	echo "avb_vendor_kernel_boot_key_path=$(BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH)" >> $@
	echo "avb_vendor_kernel_boot_algorithm=$(BOARD_AVB_VENDOR_KERNEL_BOOT_ALGORITHM)" >> $@
	echo "avb_vendor_kernel_boot_rollback_index_location=$(BOARD_AVB_VENDOR_KERNEL_BOOT_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH
	$(hide) echo "avb_recovery_add_hash_footer_args=$(BOARD_AVB_RECOVERY_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_RECOVERY_KEY_PATH
	$(hide) echo "avb_recovery_key_path=$(BOARD_AVB_RECOVERY_KEY_PATH)" >> $@
	$(hide) echo "avb_recovery_algorithm=$(BOARD_AVB_RECOVERY_ALGORITHM)" >> $@
	$(hide) echo "avb_recovery_rollback_index_location=$(BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_RECOVERY_KEY_PATH
ifneq (,$(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)))
	$(hide) echo "custom_images_partition_list=$(filter-out $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), $(BOARD_CUSTOMIMAGES_PARTITION_LIST))" >> $@
	$(hide) $(foreach partition,$(filter-out $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), $(BOARD_CUSTOMIMAGES_PARTITION_LIST)), \
	    echo "$(partition)_image_list=$(foreach image,$(BOARD_$(call to-upper,$(partition))_IMAGE_LIST),$(notdir $(image)))" >> $@;)
endif # BOARD_CUSTOMIMAGES_PARTITION_LIST
ifneq (,$(strip $(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST)))
	$(hide) echo "avb_custom_images_partition_list=$(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST)" >> $@
	$(hide) $(foreach partition,$(BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST), \
	    echo "avb_$(partition)_key_path=$(BOARD_AVB_$(call to-upper,$(partition))_KEY_PATH)"  >> $@; \
	    echo "avb_$(partition)_algorithm=$(BOARD_AVB_$(call to-upper,$(partition))_ALGORITHM)"  >> $@; \
	    echo "avb_$(partition)_add_hashtree_footer_args=$(BOARD_AVB_$(call to-upper,$(partition))_ADD_HASHTREE_FOOTER_ARGS)"  >> $@; \
	    echo "avb_$(partition)_rollback_index_location=$(BOARD_AVB_$(call to-upper,$(partition))_ROLLBACK_INDEX_LOCATION)"  >> $@; \
	    echo "avb_$(partition)_partition_size=$(BOARD_AVB_$(call to-upper,$(partition))_PARTITION_SIZE)"  >> $@; \
	    echo "avb_$(partition)_image_list=$(foreach image,$(BOARD_AVB_$(call to-upper,$(partition))_IMAGE_LIST),$(notdir $(image)))" >> $@;)
endif # BOARD_AVB_CUSTOMIMAGES_PARTITION_LIST
ifneq (,$(strip $(BOARD_AVB_VBMETA_SYSTEM)))
	$(hide) echo "avb_vbmeta_system=$(BOARD_AVB_VBMETA_SYSTEM)" >> $@
	$(hide) echo "avb_vbmeta_system_args=$(BOARD_AVB_MAKE_VBMETA_SYSTEM_IMAGE_ARGS)" >> $@
	$(hide) echo "avb_vbmeta_system_key_path=$(BOARD_AVB_VBMETA_SYSTEM_KEY_PATH)" >> $@
	$(hide) echo "avb_vbmeta_system_algorithm=$(BOARD_AVB_VBMETA_SYSTEM_ALGORITHM)" >> $@
	$(hide) echo "avb_vbmeta_system_rollback_index_location=$(BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VBMETA_SYSTEM
ifneq (,$(strip $(BOARD_AVB_VBMETA_VENDOR)))
	$(hide) echo "avb_vbmeta_vendor=$(BOARD_AVB_VBMETA_VENDOR)" >> $@
	$(hide) echo "avb_vbmeta_vendor_args=$(BOARD_AVB_MAKE_VBMETA_VENDOR_IMAGE_ARGS)" >> $@
	$(hide) echo "avb_vbmeta_vendor_key_path=$(BOARD_AVB_VBMETA_VENDOR_KEY_PATH)" >> $@
	$(hide) echo "avb_vbmeta_vendor_algorithm=$(BOARD_AVB_VBMETA_VENDOR_ALGORITHM)" >> $@
	$(hide) echo "avb_vbmeta_vendor_rollback_index_location=$(BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_VBMETA_VENDOR_KEY_PATH
ifneq (,$(strip $(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)))
	$(hide) echo "avb_custom_vbmeta_images_partition_list=$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)" >> $@
	$(hide) $(foreach partition,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS),\
	echo "avb_vbmeta_$(partition)=$(BOARD_AVB_VBMETA_$(call to-upper,$(partition)))" >> $@ ;\
	echo "avb_vbmeta_$(partition)_args=$(BOARD_AVB_MAKE_VBMETA_$(call to-upper,$(partition))_IMAGE_ARGS)" >> $@ ;\
	echo "avb_vbmeta_$(partition)_key_path=$(BOARD_AVB_VBMETA_$(call to-upper,$(partition))_KEY_PATH)" >> $@ ;\
	echo "avb_vbmeta_$(partition)_algorithm=$(BOARD_AVB_VBMETA_$(call to-upper,$(partition))_ALGORITHM)" >> $@ ;\
	echo "avb_vbmeta_$(partition)_rollback_index_location=$(BOARD_AVB_VBMETA_$(call to-upper,$(partition))_ROLLBACK_INDEX_LOCATION)" >> $@ ;)
endif # BOARD_AVB_VBMETA_CUSTOM_PARTITIONS
endif # BOARD_AVB_ENABLE
	$(call generate-userimage-prop-dictionary, $@)
ifeq ($(AB_OTA_UPDATER),true)
	@# Include the build type in META/misc_info.txt so the server can easily differentiate production builds.
	$(hide) echo "build_type=$(TARGET_BUILD_VARIANT)" >> $@
	$(hide) echo "ab_update=true" >> $@
endif
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
	$(hide) echo "allow_non_ab=true" >> $@
endif
ifeq ($(BOARD_NON_AB_OTA_DISABLE_COMPRESSION),true)
	$(hide) echo "board_non_ab_ota_disable_compression=true" >> $@
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
ifeq ($(BOARD_USES_PVMFWIMAGE),true)
	$(hide) echo "has_pvmfw=true" >> $@
ifeq ($(BOARD_AVB_ENABLE),true)
	$(hide) echo "pvmfw_size=$(BOARD_PVMFWIMAGE_PARTITION_SIZE)" >> $@
	$(hide) echo "avb_pvmfw_add_hash_footer_args=$(BOARD_AVB_PVMFW_ADD_HASH_FOOTER_ARGS)" >> $@
ifdef BOARD_AVB_PVMFW_KEY_PATH
	$(hide) echo "avb_pvmfw_key_path=$(BOARD_AVB_PVMFW_KEY_PATH)" >> $@
	$(hide) echo "avb_pvmfw_algorithm=$(BOARD_AVB_PVMFW_ALGORITHM)" >> $@
	$(hide) echo "avb_pvmfw_rollback_index_location=$(BOARD_AVB_PVMFW_ROLLBACK_INDEX_LOCATION)" >> $@
endif # BOARD_AVB_PVMFW_KEY_PATH
endif # BOARD_AVB_ENABLE
endif # BOARD_USES_PVMFWIMAGE
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
ifneq ($(BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST),)
	$(hide) echo "partial_ota_update_partitions_list=$(BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST)" >> $@
endif
ifeq ($(BUILDING_WITH_VSDK),true)
	$(hide) echo "building_with_vsdk=true" >> $@
endif

$(call declare-0p-target,$(INSTALLED_FASTBOOT_INFO_TARGET))

.PHONY: fastboot_info
fastboot_info: $(INSTALLED_FASTBOOT_INFO_TARGET)

droidcore-unbundled: $(INSTALLED_FASTBOOT_INFO_TARGET)

$(call declare-0p-target,$(INSTALLED_MISC_INFO_TARGET))

.PHONY: misc_info
misc_info: $(INSTALLED_MISC_INFO_TARGET)

droidcore-unbundled: $(INSTALLED_MISC_INFO_TARGET)

# -----------------------------------------------------------------
# A zip of the directories that map to the target filesystem.
# This zip can be used to create an OTA package or filesystem image
# as a post-build step.
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-target_files

intermediates := $(call intermediates-dir-for,PACKAGING,target_files)
BUILT_TARGET_FILES_DIR := $(intermediates)/$(name).zip.list
BUILT_TARGET_FILES_PACKAGE := $(intermediates)/$(name).zip
$(BUILT_TARGET_FILES_PACKAGE): zip_root := $(intermediates)/$(name)
$(BUILT_TARGET_FILES_DIR): zip_root := $(intermediates)/$(name)
$(BUILT_TARGET_FILES_DIR): intermediates := $(intermediates)


# $(1): Directory to copy
# $(2): Location to copy it to
# The "ls -A" is to skip if $(1) is empty.
define package_files-copy-root
  if [ -d "$(strip $(1))" -a "$$(ls -A $(1))" ]; then \
    mkdir -p $(2) && \
    $(ACP) -rd $(strip $(1))/. $(strip $(2))/; \
  fi
endef

built_ota_tools :=

# We can't build static executables when SANITIZE_TARGET=address
ifeq (,$(filter address, $(SANITIZE_TARGET)))
built_ota_tools += \
    $(call intermediates-dir-for,EXECUTABLES,updater)/updater
endif

$(BUILT_TARGET_FILES_DIR): PRIVATE_OTA_TOOLS := $(built_ota_tools)

tool_extension := $(wildcard $(tool_extensions)/releasetools.py)
$(BUILT_TARGET_FILES_DIR): PRIVATE_TOOL_EXTENSION := $(tool_extension)

updater_dep :=
ifeq ($(AB_OTA_UPDATER),true)
updater_dep += system/update_engine/update_engine.conf
$(call declare-1p-target,system/update_engine/update_engine.conf,system/update_engine)
updater_dep += external/zucchini/version_info.h
$(call declare-license-metadata,external/zucchini/version_info.h,legacy_notice,notice,external/zucchini/LICENSE,external/zucchini)
updater_dep += $(HOST_OUT_SHARED_LIBRARIES)/liblz4.so
endif

# Build OTA tools if non-A/B is allowed
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
updater_dep += $(built_ota_tools)
endif

$(BUILT_TARGET_FILES_DIR): $(updater_dep)

# If we are using recovery as boot, output recovery files to BOOT/.
# If we are moving recovery resources to vendor_boot, output recovery files to VENDOR_BOOT/.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(BUILT_TARGET_FILES_DIR): PRIVATE_RECOVERY_OUT := BOOT
else ifeq ($(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT),true)
$(BUILT_TARGET_FILES_DIR): PRIVATE_RECOVERY_OUT := VENDOR_BOOT
else
$(BUILT_TARGET_FILES_DIR): PRIVATE_RECOVERY_OUT := RECOVERY
endif

ifeq ($(AB_OTA_UPDATER),true)
  ifdef OSRELEASED_DIRECTORY
    $(BUILT_TARGET_FILES_DIR): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id
    $(BUILT_TARGET_FILES_DIR): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version
    $(BUILT_TARGET_FILES_DIR): $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version
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

define filter-out-missing-vendor
$(if $(INSTALLED_VENDORIMAGE_TARGET),$(1),$(filter-out vendor,$(1)))
endef
define filter-out-missing-vendor_dlkm
$(if $(INSTALLED_VENDOR_DLKMIMAGE_TARGET),$(1),$(filter-out vendor_dlkm,$(1)))
endef
define filter-out-missing-odm
$(if $(INSTALLED_ODMIMAGE_TARGET),$(1),$(filter-out odm,$(1)))
endef
define filter-out-missing-odm_dlkm
$(if $(INSTALLED_ODM_DLKMIMAGE_TARGET),$(1),$(filter-out odm_dlkm,$(1)))
endef
define filter-out-missing-system_dlkm
$(if $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET),$(1),$(filter-out system_dlkm,$(1)))
endef
# Filter out vendor,vendor_dlkm,odm,odm_dlkm,system_dlkm from the list for AOSP targets.
# $(1): list
define filter-out-missing-partitions
$(call filter-out-missing-vendor,\
  $(call filter-out-missing-vendor_dlkm,\
    $(call filter-out-missing-odm,\
      $(call filter-out-missing-odm_dlkm,\
        $(call filter-out-missing-system_dlkm,$(1))))))
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
  $(if $(BUILDING_SUPER_EMPTY_IMAGE), \
    echo "build_super_empty_partition=true" >> $(1))
  $(if $(filter true,$(BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE)), \
    echo "build_retrofit_dynamic_partitions_ota_package=true" >> $(1))
  echo "super_metadata_device=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)" >> $(1)
  $(if $(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
    echo "super_block_devices=$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)" >> $(1))
  $(foreach device,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES), \
    echo "super_$(device)_device_size=$(BOARD_SUPER_PARTITION_$(call to-upper,$(device))_DEVICE_SIZE)" >> $(1);)
  $(if $(BOARD_SUPER_PARTITION_PARTITION_LIST), \
    echo "dynamic_partition_list=$(call filter-out-missing-partitions,$(BOARD_SUPER_PARTITION_PARTITION_LIST))" >> $(1))
  $(if $(BOARD_SUPER_PARTITION_GROUPS),
    echo "super_partition_groups=$(BOARD_SUPER_PARTITION_GROUPS)" >> $(1))
  $(foreach group,$(BOARD_SUPER_PARTITION_GROUPS), \
    echo "super_$(group)_group_size=$(BOARD_$(call to-upper,$(group))_SIZE)" >> $(1); \
    $(if $(BOARD_$(call to-upper,$(group))_PARTITION_LIST), \
      echo "super_$(group)_partition_list=$(call filter-out-missing-partitions,$(BOARD_$(call to-upper,$(group))_PARTITION_LIST))" >> $(1);))
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
  $(if $(filter true,$(PRODUCT_VIRTUAL_AB_COMPRESSION)), \
    echo "virtual_ab_compression=true" >> $(1))
# This value controls the compression algorithm used for VABC
# valid options are defined in system/core/fs_mgr/libsnapshot/cow_writer.cpp
# e.g. "none", "gz", "brotli"
  $(if $(PRODUCT_VIRTUAL_AB_COMPRESSION_METHOD), \
    echo "virtual_ab_compression_method=$(PRODUCT_VIRTUAL_AB_COMPRESSION_METHOD)" >> $(1))
  $(if $(filter true,$(PRODUCT_VIRTUAL_AB_OTA_RETROFIT)), \
    echo "virtual_ab_retrofit=true" >> $(1))
  $(if $(PRODUCT_VIRTUAL_AB_COW_VERSION), \
    echo "virtual_ab_cow_version=$(PRODUCT_VIRTUAL_AB_COW_VERSION)" >> $(1))
endef

# Copy an image file to a directory and generate a block list map file from the image,
# only if the map_file_generator supports the file system.
# Otherwise, skip generating map files as well as copying images. The image will be
# generated from the $(ADD_IMG_TO_TARGET_FILES) to generate the map file with it.
# $(1): path of the image file
# $(2): target out directory
# $(3): image name to generate a map file. skip generating map file if empty
define copy-image-and-generate-map
  $(if $(COPY_IMAGES_FOR_TARGET_FILES_ZIP), \
    $(eval _supported_fs_for_map_file_generator := erofs ext%) \
    $(eval _img := $(call to-upper,$(3))) \
    $(if $(3),$(eval _map_fs_type := $(BOARD_$(_img)IMAGE_FILE_SYSTEM_TYPE)),\
      $(eval _no_map_file := "true")) \
    $(if $(filter $(_supported_fs_for_map_file_generator),$(_map_fs_type))$(_no_map_file),\
      mkdir -p $(2); \
      cp $(1) $(2); \
      $(if $(3),$(HOST_OUT_EXECUTABLES)/map_file_generator $(1) $(2)/$(3).map)) \
    $(eval _img :=) \
    $(eval _map_fs_type :=) \
    $(eval _no_map_file :=) \
  )
endef

# By conditionally including the dependency of the target files package on the
# full system image deps, we speed up builds that do not build the system
# image.
ifdef BUILDING_SYSTEM_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(FULL_SYSTEMIMAGE_DEPS)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_SYSTEMIMAGE)
  endif
else
  # releasetools may need the system build.prop even when building a
  # system-image-less product.
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_BUILD_PROP_TARGET)
endif

ifdef BUILDING_USERDATA_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_USERDATAIMAGE_FILES)
endif

ifdef BUILDING_SYSTEM_OTHER_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_SYSTEMOTHERIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_SYSTEMOTHERIMAGE_TARGET)
  endif
endif

ifdef BUILDING_VENDOR_BOOT_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_VENDOR_RAMDISK_FILES)
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_VENDOR_RAMDISK_FRAGMENT_TARGETS)
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_VENDOR_BOOTCONFIG_TARGET)
  # The vendor ramdisk may be built from the recovery ramdisk.
  ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
    $(BUILT_TARGET_FILES_DIR): $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP)
  endif
endif

ifdef BUILDING_RECOVERY_IMAGE
  # TODO(b/30414428): Can't depend on INTERNAL_RECOVERYIMAGE_FILES alone like other
  # BUILT_TARGET_FILES_PACKAGE dependencies because currently there're cp/rsync/rm
  # commands in build-recoveryimage-target, which would touch the files under
  # TARGET_RECOVERY_OUT and race with packaging target-files.zip.
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    $(BUILT_TARGET_FILES_DIR): $(INSTALLED_BOOTIMAGE_TARGET)
  else
    $(BUILT_TARGET_FILES_DIR): $(INSTALLED_RECOVERYIMAGE_TARGET)
  endif
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_RECOVERYIMAGE_FILES)
endif

# Conditionally depend on the image files if the image is being built so the
# target-files.zip rule doesn't wait on the image creation rule, or the image
# if it is coming from a prebuilt.

ifdef BUILDING_VENDOR_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_VENDORIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_VENDORIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_VENDORIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_VENDORIMAGE_TARGET)
endif

ifdef BUILDING_PRODUCT_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_PRODUCTIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_PRODUCTIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_PRODUCTIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_PRODUCTIMAGE_TARGET)
endif

ifdef BUILDING_SYSTEM_EXT_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_SYSTEM_EXTIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_SYSTEM_EXTIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)
endif

ifneq (,$(BUILDING_BOOT_IMAGE)$(BUILDING_INIT_BOOT_IMAGE))
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_RAMDISK_FILES)
endif  # BUILDING_BOOT_IMAGE != "" || BUILDING_INIT_BOOT_IMAGE != ""

ifneq (,$(INTERNAL_PREBUILT_BOOTIMAGE) $(filter true,$(BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES)))
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_BOOTIMAGE_TARGET)
endif

ifdef BUILDING_ODM_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_ODMIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_ODMIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_ODMIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_ODMIMAGE_TARGET)
endif

ifdef BUILDING_VENDOR_DLKM_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_VENDOR_DLKMIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_VENDOR_DLKMIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)
endif

ifdef BUILDING_ODM_DLKM_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_ODM_DLKMIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_ODM_DLKMIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_ODM_DLKMIMAGE_TARGET)
endif

ifdef BUILDING_SYSTEM_DLKM_IMAGE
  $(BUILT_TARGET_FILES_DIR): $(INTERNAL_SYSTEM_DLKMIMAGE_FILES)
  ifdef COPY_IMAGES_FOR_TARGET_FILES_ZIP
    $(BUILT_TARGET_FILES_DIR): $(BUILT_SYSTEM_DLKMIMAGE_TARGET)
  endif
else ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
  $(BUILT_TARGET_FILES_DIR): $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)
endif

ifeq ($(BUILD_QEMU_IMAGES),true)
  MK_VBMETA_BOOT_KERNEL_CMDLINE_SH := device/generic/goldfish/tools/mk_vbmeta_boot_params.sh
  $(BUILT_TARGET_FILES_DIR): $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH)
endif

ifdef BOARD_PREBUILT_BOOTLOADER
$(BUILT_TARGET_FILES_DIR): $(INSTALLED_BOOTLOADER_MODULE)
droidcore-unbundled: $(INSTALLED_BOOTLOADER_MODULE)
endif

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_DIR): \
	    $(INSTALLED_RADIOIMAGE_TARGET) \
	    $(INSTALLED_RECOVERYIMAGE_TARGET) \
	    $(INSTALLED_CACHEIMAGE_TARGET) \
	    $(INSTALLED_DTBOIMAGE_TARGET) \
	    $(INSTALLED_PVMFWIMAGE_TARGET) \
	    $(INSTALLED_PVMFW_BINARY_TARGET) \
	    $(INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET) \
	    $(INSTALLED_CUSTOMIMAGES_TARGET) \
	    $(INSTALLED_ANDROID_INFO_TXT_TARGET) \
	    $(INSTALLED_KERNEL_TARGET) \
	    $(INSTALLED_RAMDISK_TARGET) \
	    $(INSTALLED_DTBIMAGE_TARGET) \
	    $(INSTALLED_2NDBOOTLOADER_TARGET) \
	    $(BUILT_RAMDISK_16K_TARGET) \
	    $(BUILT_KERNEL_16K_TARGET) \
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
	    $(PRODUCT_SYSTEM_DLKM_BASE_FS_PATH) \
	    $(LPMAKE) \
	    $(SELINUX_FC) \
	    $(INSTALLED_MISC_INFO_TARGET) \
	    $(INSTALLED_FASTBOOT_INFO_TARGET) \
	    $(APKCERTS_FILE) \
	    $(APEX_KEYS_FILE) \
	    $(SOONG_ZIP) \
	    $(HOST_OUT_EXECUTABLES)/fs_config \
	    $(HOST_OUT_EXECUTABLES)/map_file_generator \
	    $(ADD_IMG_TO_TARGET_FILES) \
	    $(MAKE_RECOVERY_PATCH) \
	    $(BUILT_KERNEL_CONFIGS_FILE) \
	    $(BUILT_KERNEL_VERSION_FILE) \
	    | $(ACP)
	@echo "Building target files: $@"
	$(hide) rm -rf $@ $@.list $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT))$(filter true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)))
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/$(PRIVATE_RECOVERY_OUT)
# Exclude recovery files in the default vendor ramdisk if including a standalone
# recovery ramdisk in vendor_boot.
ifneq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/$(PRIVATE_RECOVERY_OUT)/RAMDISK)
endif
ifdef INSTALLED_KERNEL_TARGET
ifneq (,$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))
	cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/
else ifneq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
	cp $(firstword $(INSTALLED_KERNEL_TARGET)) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/kernel
endif
endif
ifneq (truetrue,$(strip $(BUILDING_VENDOR_BOOT_IMAGE))$(strip $(BOARD_USES_RECOVERY_AS_BOOT)))
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
endif # not (BUILDING_VENDOR_BOOT_IMAGE and BOARD_USES_RECOVERY_AS_BOOT)
endif # INSTALLED_RECOVERYIMAGE_TARGET defined or BOARD_USES_RECOVERY_AS_BOOT is true
	@# Components of the boot image
	$(hide) mkdir -p $(zip_root)/BOOT
	$(hide) mkdir -p $(zip_root)/ROOT
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_ROOT_OUT),$(zip_root)/ROOT)
	@# If we are using recovery as boot, this is already done when processing recovery.
ifneq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_RAMDISK_OUT),$(zip_root)/BOOT/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/BOOT/
endif
ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
	echo "$(GENERIC_KERNEL_CMDLINE)" > $(zip_root)/BOOT/cmdline
else ifndef INSTALLED_VENDOR_BOOTIMAGE_TARGET # && BOARD_USES_GENERIC_KERNEL_IMAGE != true
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
ifneq ($(BUILDING_VENDOR_KERNEL_BOOT_IMAGE),true)
	cp $(INSTALLED_DTBIMAGE_TARGET) $(zip_root)/VENDOR_BOOT/dtb
endif
endif # end of INSTALLED_DTBIMAGE_TARGET
ifdef INTERNAL_VENDOR_BOOTCONFIG_TARGET
	cp $(INTERNAL_VENDOR_BOOTCONFIG_TARGET) $(zip_root)/VENDOR_BOOT/vendor_bootconfig
endif
ifdef BOARD_KERNEL_BASE
	echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/VENDOR_BOOT/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/VENDOR_BOOT/pagesize
endif
	echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/VENDOR_BOOT/vendor_cmdline
ifdef INTERNAL_VENDOR_RAMDISK_FRAGMENTS
	echo "$(INTERNAL_VENDOR_RAMDISK_FRAGMENTS)" > "$(zip_root)/VENDOR_BOOT/vendor_ramdisk_fragments"
	$(foreach vendor_ramdisk_fragment,$(INTERNAL_VENDOR_RAMDISK_FRAGMENTS), \
	  mkdir -p $(zip_root)/VENDOR_BOOT/RAMDISK_FRAGMENTS/$(vendor_ramdisk_fragment); \
	  echo "$(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).MKBOOTIMG_ARGS)" > "$(zip_root)/VENDOR_BOOT/RAMDISK_FRAGMENTS/$(vendor_ramdisk_fragment)/mkbootimg_args"; \
	  $(eval prebuilt_ramdisk := $(BOARD_VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).PREBUILT)) \
	  $(if $(prebuilt_ramdisk), \
	    cp "$(prebuilt_ramdisk)" "$(zip_root)/VENDOR_BOOT/RAMDISK_FRAGMENTS/$(vendor_ramdisk_fragment)/prebuilt_ramdisk";, \
	    $(call package_files-copy-root, \
	      $(VENDOR_RAMDISK_FRAGMENT.$(vendor_ramdisk_fragment).STAGING_DIR), \
	      $(zip_root)/VENDOR_BOOT/RAMDISK_FRAGMENTS/$(vendor_ramdisk_fragment)/RAMDISK); \
	  ))
endif # INTERNAL_VENDOR_RAMDISK_FRAGMENTS != ""
endif # INSTALLED_VENDOR_BOOTIMAGE_TARGET
ifdef INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET
	mkdir -p $(zip_root)/VENDOR_KERNEL_BOOT
	$(call package_files-copy-root, \
	    $(TARGET_VENDOR_KERNEL_RAMDISK_OUT),$(zip_root)/VENDOR_KERNEL_BOOT/RAMDISK)
ifdef INSTALLED_DTBIMAGE_TARGET
	cp $(INSTALLED_DTBIMAGE_TARGET) $(zip_root)/VENDOR_KERNEL_BOOT/dtb
endif
ifdef BOARD_KERNEL_PAGESIZE
	echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/VENDOR_KERNEL_BOOT/pagesize
endif
endif # INSTALLED_VENDOR_BOOTIMAGE_TARGET
ifdef BUILDING_SYSTEM_IMAGE
	@# Contents of the system image
	$(hide) $(call package_files-copy-root, \
	    $(SYSTEMIMAGE_SOURCE_DIR),$(zip_root)/SYSTEM)
else ifdef INSTALLED_BUILD_PROP_TARGET
	@# Copy the system build.prop even if not building a system image
	@# because add_img_to_target_files may need it to build other partition
	@# images.
	$(hide) mkdir -p "$(zip_root)/SYSTEM"
	$(hide) cp "$(INSTALLED_BUILD_PROP_TARGET)" "$(patsubst $(TARGET_OUT)/%,$(zip_root)/SYSTEM/%,$(INSTALLED_BUILD_PROP_TARGET))"
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
ifdef BUILDING_SYSTEM_DLKM_IMAGE
	@# Contents of the system_dlkm image
	$(hide) $(call package_files-copy-root, \
	    $(TARGET_OUT_SYSTEM_DLKM),$(zip_root)/SYSTEM_DLKM)
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
	$(hide) cp $(APEX_KEYS_FILE) $(zip_root)/META/apexkeys.txt
ifneq ($(tool_extension),)
	$(hide) cp $(PRIVATE_TOOL_EXTENSION) $(zip_root)/META/
endif
	$(hide) echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) cp $(SELINUX_FC) $(zip_root)/META/file_contexts.bin
	$(hide) cp $(INSTALLED_MISC_INFO_TARGET) $(zip_root)/META/misc_info.txt
ifneq ($(INSTALLED_FASTBOOT_INFO_TARGET),)
	$(hide) cp $(INSTALLED_FASTBOOT_INFO_TARGET) $(zip_root)/META/fastboot-info.txt
endif
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
ifneq ($(PRODUCT_SYSTEM_DLKM_BASE_FS_PATH),)
	$(hide) cp $(PRODUCT_SYSTEM_DLKM_BASE_FS_PATH) \
	  $(zip_root)/META/$(notdir $(PRODUCT_SYSTEM_DLKM_BASE_FS_PATH))
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
	$(hide) cp $(TOPDIR)external/zucchini/version_info.h $(zip_root)/META/zucchini_config.txt
	$(hide) cp $(HOST_OUT_SHARED_LIBRARIES)/liblz4.so $(zip_root)/META/liblz4.so
	$(hide) for part in $(sort $(AB_OTA_PARTITIONS)); do \
	  echo "$${part}" >> $(zip_root)/META/ab_partitions.txt; \
	done
	$(hide) for conf in $(strip $(AB_OTA_POSTINSTALL_CONFIG)); do \
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
ifdef BOARD_PREBUILT_INIT_BOOT_IMAGE
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_INIT_BOOT_IMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif

ifndef BOARD_PREBUILT_BOOTIMAGE
ifneq (,$(strip $(INTERNAL_PREBUILT_BOOTIMAGE) $(filter true,$(BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES))))
ifdef INSTALLED_BOOTIMAGE_TARGET
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_BOOTIMAGE_TARGET) $(zip_root)/IMAGES/
endif # INSTALLED_BOOTIMAGE_TARGET
endif # INTERNAL_PREBUILT_BOOTIMAGE != "" || BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES == true
else # BOARD_PREBUILT_BOOTIMAGE is defined
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_BOOTIMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif # BOARD_PREBUILT_BOOTIMAGE
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
ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) $(zip_root)/IMAGES/
endif
ifdef BOARD_PREBUILT_DTBOIMAGE
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_DTBOIMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif # BOARD_PREBUILT_DTBOIMAGE
ifdef BUILT_KERNEL_16K_TARGET
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(BUILT_KERNEL_16K_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif # BUILT_KERNEL_16K_TARGET
ifdef BUILT_RAMDISK_16K_TARGET
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(BUILT_RAMDISK_16K_TARGET) $(zip_root)/PREBUILT_IMAGES/
endif # BUILT_RAMDISK_16K_TARGET
ifeq ($(BOARD_USES_PVMFWIMAGE),true)
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) cp $(INSTALLED_PVMFWIMAGE_TARGET) $(zip_root)/PREBUILT_IMAGES/
	$(hide) cp $(INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET) $(zip_root)/PREBUILT_IMAGES/
	$(hide) mkdir -p $(zip_root)/PVMFW
	$(hide) cp $(INSTALLED_PVMFW_BINARY_TARGET) $(zip_root)/PVMFW/
endif
ifdef BOARD_PREBUILT_BOOTLOADER
	$(hide) mkdir -p $(zip_root)/IMAGES
	$(hide) cp $(INSTALLED_BOOTLOADER_MODULE) $(zip_root)/IMAGES/
endif
ifneq ($(strip $(BOARD_CUSTOMIMAGES_PARTITION_LIST)),)
	$(hide) mkdir -p $(zip_root)/PREBUILT_IMAGES
	$(hide) $(foreach partition,$(BOARD_CUSTOMIMAGES_PARTITION_LIST), \
	    $(foreach image,$(BOARD_$(call to-upper,$(partition))_IMAGE_LIST),cp $(image) $(zip_root)/PREBUILT_IMAGES/;))
endif # BOARD_CUSTOMIMAGES_PARTITION_LIST
	@# The radio images in BOARD_PACK_RADIOIMAGES will be additionally copied from RADIO/ into
	@# IMAGES/, which then will be added into <product>-img.zip. Such images must be listed in
	@# INSTALLED_RADIOIMAGE_TARGET.
	$(hide) $(foreach part,$(BOARD_PACK_RADIOIMAGES), \
	    echo $(part) >> $(zip_root)/META/pack_radioimages.txt;)
	@# Run fs_config on all the system, vendor, boot ramdisk,
	@# and recovery ramdisk files in the zip, and save the output
ifdef BUILDING_SYSTEM_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_SYSTEMIMAGE),$(zip_root)/IMAGES,system)
	$(hide) $(call fs_config,$(zip_root)/SYSTEM,system/) > $(zip_root)/META/filesystem_config.txt
endif
ifdef BUILDING_VENDOR_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_VENDORIMAGE_TARGET),$(zip_root)/IMAGES,vendor)
	$(hide) $(call fs_config,$(zip_root)/VENDOR,vendor/) > $(zip_root)/META/vendor_filesystem_config.txt
endif
ifdef BUILDING_PRODUCT_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_PRODUCTIMAGE_TARGET),$(zip_root)/IMAGES,product)
	$(hide) $(call fs_config,$(zip_root)/PRODUCT,product/) > $(zip_root)/META/product_filesystem_config.txt
endif
ifdef BUILDING_SYSTEM_EXT_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_SYSTEM_EXTIMAGE_TARGET),$(zip_root)/IMAGES,system_ext)
	$(hide) $(call fs_config,$(zip_root)/SYSTEM_EXT,system_ext/) > $(zip_root)/META/system_ext_filesystem_config.txt
endif
ifdef BUILDING_ODM_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_ODMIMAGE_TARGET),$(zip_root)/IMAGES,odm)
	$(hide) $(call fs_config,$(zip_root)/ODM,odm/) > $(zip_root)/META/odm_filesystem_config.txt
endif
ifdef BUILDING_VENDOR_DLKM_IMAGE
	$(hide)$(call copy-image-and-generate-map,$(BUILT_VENDOR_DLKMIMAGE_TARGET),$(zip_root)/IMAGES,vendor_dlkm)
	$(hide) $(call fs_config,$(zip_root)/VENDOR_DLKM,vendor_dlkm/) > $(zip_root)/META/vendor_dlkm_filesystem_config.txt
endif
ifdef BUILDING_ODM_DLKM_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_ODM_DLKMIMAGE_TARGET),$(zip_root)/IMAGES,odm_dlkm)
	$(hide) $(call fs_config,$(zip_root)/ODM_DLKM,odm_dlkm/) > $(zip_root)/META/odm_dlkm_filesystem_config.txt
endif
ifdef BUILDING_SYSTEM_DLKM_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_SYSTEM_DLKMIMAGE_TARGET),$(zip_root)/IMAGES,system_dlkm)
	$(hide) $(call fs_config,$(zip_root)/SYSTEM_DLKM,system_dlkm/) > $(zip_root)/META/system_dlkm_filesystem_config.txt
endif
	@# ROOT always contains the files for the root under normal boot.
	$(hide) $(call fs_config,$(zip_root)/ROOT,) > $(zip_root)/META/root_filesystem_config.txt
	@# BOOT/RAMDISK contains the first stage and recovery ramdisk.
	$(hide) $(call fs_config,$(zip_root)/BOOT/RAMDISK,) > $(zip_root)/META/boot_filesystem_config.txt
ifdef BUILDING_INIT_BOOT_IMAGE
	$(hide) $(call package_files-copy-root, $(TARGET_RAMDISK_OUT),$(zip_root)/INIT_BOOT/RAMDISK)
	$(hide) $(call fs_config,$(zip_root)/INIT_BOOT/RAMDISK,) > $(zip_root)/META/init_boot_filesystem_config.txt
	$(hide) cp $(RAMDISK_NODE_LIST) $(zip_root)/META/ramdisk_node_list
ifdef BOARD_KERNEL_PAGESIZE
	$(hide) echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/INIT_BOOT/pagesize
endif # BOARD_KERNEL_PAGESIZE
endif # BUILDING_INIT_BOOT_IMAGE
ifneq ($(INSTALLED_VENDOR_BOOTIMAGE_TARGET),)
	$(call fs_config,$(zip_root)/VENDOR_BOOT/RAMDISK,) > $(zip_root)/META/vendor_boot_filesystem_config.txt
endif
ifneq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) $(call fs_config,$(zip_root)/RECOVERY/RAMDISK,) > $(zip_root)/META/recovery_filesystem_config.txt
endif
ifdef BUILDING_SYSTEM_OTHER_IMAGE
	$(hide) $(call copy-image-and-generate-map,$(BUILT_SYSTEMOTHERIMAGE_TARGET),$(zip_root)/IMAGES)
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
	$(hide) find $(zip_root)/META | sort >$@
	$(hide) find $(zip_root) -path $(zip_root)/META -prune -o -print | sort >>$@

$(BUILT_TARGET_FILES_PACKAGE): $(BUILT_TARGET_FILES_DIR)
	@echo "Packaging target files: $@"
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(zip_root) -r $@.list

.PHONY: target-files-package
target-files-package: $(BUILT_TARGET_FILES_PACKAGE)

.PHONY: target-files-dir
target-files-dir: $(BUILT_TARGET_FILES_DIR)

$(call declare-1p-container,$(BUILT_TARGET_FILES_PACKAGE),)
$(call declare-container-license-deps,$(BUILT_TARGET_FILES_PACKAGE), $(INSTALLED_RADIOIMAGE_TARGET) \
            $(INSTALLED_RECOVERYIMAGE_TARGET) \
            $(INSTALLED_CACHEIMAGE_TARGET) \
            $(INSTALLED_DTBOIMAGE_TARGET) \
            $(INSTALLED_PVMFWIMAGE_TARGET) \
            $(INSTALLED_PVMFW_EMBEDDED_AVBKEY_TARGET) \
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
            $(PRODUCT_SYSTEM_DLKM_BASE_FS_PATH) \
            $(LPMAKE) \
            $(SELINUX_FC) \
            $(INSTALLED_MISC_INFO_TARGET) \
            $(INSTALLED_FASTBOOT_INFO_TARGET) \
            $(APKCERTS_FILE) \
            $(APEX_KEYS_FILE) \
            $(HOST_OUT_EXECUTABLES)/fs_config \
            $(HOST_OUT_EXECUTABLES)/map_file_generator \
            $(ADD_IMG_TO_TARGET_FILES) \
            $(MAKE_RECOVERY_PATCH) \
            $(BUILT_KERNEL_CONFIGS_FILE) \
            $(BUILT_KERNEL_VERSION_FILE),$(BUILT_TARGET_FILES_PACKAGE):)

$(call dist-for-goals-with-filenametag, target-files-package, $(BUILT_TARGET_FILES_PACKAGE))

# -----------------------------------------------------------------
# NDK Sysroot Package
NDK_SYSROOT_TARGET := $(PRODUCT_OUT)/ndk_sysroot.tar.bz2
.PHONY: ndk_sysroot
ndk_sysroot: $(NDK_SYSROOT_TARGET)
$(NDK_SYSROOT_TARGET): $(SOONG_OUT_DIR)/ndk.timestamp
	@echo Package NDK sysroot...
	$(hide) tar cjf $@ -C $(SOONG_OUT_DIR) ndk

ifeq ($(HOST_OS),linux)
$(call dist-for-goals,sdk ndk_sysroot,$(NDK_SYSROOT_TARGET))
endif

ifeq ($(build_ota_package),true)
# -----------------------------------------------------------------
# OTA update package

# $(1): output file
# $(2): additional args
define build-ota-package-target
PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$(dir $(ZIP2ZIP)):$$PATH \
    $(OTA_FROM_TARGET_FILES) \
        --verbose \
        --path $(HOST_OUT) \
        $(if $(OEM_OTA_CONFIG), --oem_settings $(OEM_OTA_CONFIG)) \
        $(2) \
        $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) $(1)
endef

product_name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  product_name := $(product_name)_debug
endif
name := $(product_name)-ota

INTERNAL_OTA_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip
INTERNAL_OTA_METADATA := $(PRODUCT_OUT)/ota_metadata

$(call declare-0p-target,$(INTERNAL_OTA_METADATA))

$(INTERNAL_OTA_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(INTERNAL_OTA_PACKAGE_TARGET): .KATI_IMPLICIT_OUTPUTS := $(INTERNAL_OTA_METADATA)
$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_DIR) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES)
	@echo "Package OTA: $@"
	$(call build-ota-package-target,$@,-k $(KEY_CERT_PAIR) --output_metadata_path $(INTERNAL_OTA_METADATA))

$(call declare-1p-container,$(INTERNAL_OTA_PACKAGE_TARGET),)
$(call declare-container-license-deps,$(INTERNAL_OTA_PACKAGE_TARGET),$(BUILT_TARGET_FILES_PACKAGE) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES),$(PRODUCT_OUT)/:/)

.PHONY: otapackage
otapackage: $(INTERNAL_OTA_PACKAGE_TARGET)

ifeq ($(BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE),true)
name := $(product_name)-ota-retrofit

INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip
$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET): \
    $(BUILT_TARGET_FILES_PACKAGE) \
    $(OTA_FROM_TARGET_FILES) \
    $(INTERNAL_OTATOOLS_FILES)
	@echo "Package OTA (retrofit dynamic partitions): $@"
	$(call build-ota-package-target,$@,-k $(KEY_CERT_PAIR) --retrofit_dynamic_partitions)

$(call declare-1p-container,$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET),)
$(call declare-container-license-deps,$(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET),$(BUILT_TARGET_FILES_PACKAGE) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES),$(PRODUCT_OUT)/:/)

.PHONY: otardppackage

otapackage otardppackage: $(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET)

endif # BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE

ifneq ($(BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST),)
name := $(product_name)-partial-ota

INTERNAL_OTA_PARTIAL_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip
$(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET): KEY_CERT_PAIR := $(DEFAULT_KEY_CERT_PAIR)
$(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET): $(BUILT_TARGET_FILES_DIR) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES)
	@echo "Package partial OTA: $@"
	$(call build-ota-package-target,$@,-k $(KEY_CERT_PAIR) --partial "$(BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST)")

$(call declare-1p-container,$(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET),)
$(call declare-container-license-deps,$(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET),$(BUILT_TARGET_FILES_PACKAGE) $(OTA_FROM_TARGET_FILES) $(INTERNAL_OTATOOLS_FILES),$(PRODUCT_OUT)/:/)


.PHONY: partialotapackage
partialotapackage: $(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET)

endif # BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST

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

# The mac build doesn't build dex2oat, so create the zip file only if the build OS is linux.
ifeq ($(BUILD_OS),linux)
ifneq ($(DEX2OAT),)
dexpreopt_tools_deps := $(DEXPREOPT_GEN_DEPS) $(DEXPREOPT_GEN)
dexpreopt_tools_deps += $(HOST_OUT_EXECUTABLES)/dexdump
dexpreopt_tools_deps += $(HOST_OUT_EXECUTABLES)/oatdump
DEXPREOPT_TOOLS_ZIP := $(PRODUCT_OUT)/dexpreopt_tools.zip
$(DEXPREOPT_TOOLS_ZIP): $(dexpreopt_tools_deps)
$(DEXPREOPT_TOOLS_ZIP): PRIVATE_DEXPREOPT_TOOLS_DEPS := $(dexpreopt_tools_deps)
$(DEXPREOPT_TOOLS_ZIP): $(SOONG_ZIP)
	$(hide) mkdir -p $(dir $@)
	$(hide) $(SOONG_ZIP) -d -o $@ -j $(addprefix -f ,$(PRIVATE_DEXPREOPT_TOOLS_DEPS)) -f $$(realpath $(DEX2OAT))
$(call declare-1p-target,$(DEXPREOPT_TOOLS_ZIP),)
endif # DEX2OAT is set
endif # BUILD_OS == linux

DEXPREOPT_CONFIG_ZIP := $(PRODUCT_OUT)/dexpreopt_config.zip

$(DEXPREOPT_CONFIG_ZIP): $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_ODMIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \

ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(DEXPREOPT_CONFIG_ZIP): $(DEX_PREOPT_CONFIG_FOR_MAKE) \
	  $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE) \

endif

$(DEXPREOPT_CONFIG_ZIP): $(SOONG_ZIP)
	$(hide) mkdir -p $(dir $@) $(PRODUCT_OUT)/dexpreopt_config

ifeq (,$(TARGET_BUILD_UNBUNDLED))
ifneq (,$(DEX_PREOPT_CONFIG_FOR_MAKE))
	$(hide) cp $(DEX_PREOPT_CONFIG_FOR_MAKE) $(PRODUCT_OUT)/dexpreopt_config
endif
ifneq (,$(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE))
	$(hide) cp $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE) $(PRODUCT_OUT)/dexpreopt_config
endif
endif #!TARGET_BUILD_UNBUNDLED
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(PRODUCT_OUT)/dexpreopt_config -D $(PRODUCT_OUT)/dexpreopt_config

.PHONY: dexpreopt_config_zip
dexpreopt_config_zip: $(DEXPREOPT_CONFIG_ZIP)

$(call declare-1p-target,$(DEXPREOPT_CONFIG_ZIP),)

# -----------------------------------------------------------------
# A zip of the symbols directory.  Keep the full paths to make it
# more obvious where these files came from.
# Also produces a textproto containing mappings from elf IDs to symbols
# filename, which will allow finding the appropriate symbols to deobfuscate
# a stack trace frame.
#

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif

# The path to the zip file containing binaries with symbols.
SYMBOLS_ZIP := $(PRODUCT_OUT)/$(name)-symbols.zip
# The path to a file containing mappings from elf IDs to filenames.
SYMBOLS_MAPPING := $(PRODUCT_OUT)/$(name)-symbols-mapping.textproto
.KATI_READONLY := SYMBOLS_ZIP SYMBOLS_MAPPING
# For apps_only build we'll establish the dependency later in build/make/core/main.mk.
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(SYMBOLS_ZIP): $(INTERNAL_ALLIMAGES_FILES) $(updater_dep)
endif
$(SYMBOLS_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,symbols)/filelist
$(SYMBOLS_ZIP): PRIVATE_MAPPING_PACKAGING_DIR := $(call intermediates-dir-for,PACKAGING,elf_symbol_mapping)
$(SYMBOLS_ZIP): $(SOONG_ZIP) $(SYMBOLS_MAP)
	@echo "Package symbols: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(TARGET_OUT_UNSTRIPPED) $(dir $(PRIVATE_LIST_FILE)) $(PRIVATE_MAPPING_PACKAGING_DIR)
	# Find all of the files in the symbols directory and zip them into the symbols zip.
	$(hide) find -L $(TARGET_OUT_UNSTRIPPED) -type f | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) --ignore_missing_files -d -o $@ -C $(OUT_DIR)/.. -l $(PRIVATE_LIST_FILE)
	# Find all of the files in the symbols mapping directory and merge them into the symbols mapping textproto.
	$(hide) find -L $(PRIVATE_MAPPING_PACKAGING_DIR) -type f | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SYMBOLS_MAP) -merge $(SYMBOLS_MAPPING) -ignore_missing_files @$(PRIVATE_LIST_FILE)
$(SYMBOLS_ZIP): .KATI_IMPLICIT_OUTPUTS := $(SYMBOLS_MAPPING)

$(call declare-1p-container,$(SYMBOLS_ZIP),)
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(call declare-container-license-deps,$(SYMBOLS_ZIP),$(INTERNAL_ALLIMAGES_FILES) $(updater_dep),$(PRODUCT_OUT)/:/)
endif

# -----------------------------------------------------------------
# A zip of the coverage directory.
#
name := gcov-report-files-all
ifeq ($(TARGET_BUILD_TYPE),debug)
name := $(name)_debug
endif
COVERAGE_ZIP := $(PRODUCT_OUT)/$(name).zip
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(COVERAGE_ZIP): $(INTERNAL_ALLIMAGES_FILES)
endif
$(COVERAGE_ZIP): PRIVATE_LIST_FILE := $(call intermediates-dir-for,PACKAGING,coverage)/filelist
$(COVERAGE_ZIP): $(SOONG_ZIP)
	@echo "Package coverage: $@"
	$(hide) rm -rf $@ $(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $(dir $@) $(TARGET_OUT_COVERAGE) $(dir $(PRIVATE_LIST_FILE))
	$(hide) find $(TARGET_OUT_COVERAGE) | sort >$(PRIVATE_LIST_FILE)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(TARGET_OUT_COVERAGE) -l $(PRIVATE_LIST_FILE)

$(call declare-1p-container,$(COVERAGE_ZIP),)
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(call declare-container-license-deps,$(COVERAGE_ZIP),$(INTERNAL_ALLIMAGE_FILES),$(PRODUCT_OUT)/:/)
endif

SYSTEM_NOTICE_DEPS += $(COVERAGE_ZIP)

#------------------------------------------------------------------
# Export the LLVM profile data tool and dependencies for Clang coverage processing
#
ifeq (true,$(CLANG_COVERAGE))
  LLVM_PROFDATA := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/bin/llvm-profdata
  LLVM_COV := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/bin/llvm-cov
  LIBCXX := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/lib/x86_64-unknown-linux-gnu/libc++.so
  # Use llvm-profdata.zip for backwards compatibility with tradefed code.
  LLVM_COVERAGE_TOOLS_ZIP := $(PRODUCT_OUT)/llvm-profdata.zip

  $(LLVM_COVERAGE_TOOLS_ZIP): $(SOONG_ZIP)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION) -f $(LLVM_PROFDATA) -f $(LIBCXX) -f $(LLVM_COV)

  $(call dist-for-goals,droidcore-unbundled apps_only,$(LLVM_COVERAGE_TOOLS_ZIP))
endif

# -----------------------------------------------------------------
# A zip of the Android Apps. Not keeping full path so that we don't
# include product names when distributing
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-apps

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
$(JACOCO_REPORT_CLASSES_ALL): PRIVATE_TARGET_JACOCO_DIR := $(call intermediates-dir-for,PACKAGING,jacoco)
$(JACOCO_REPORT_CLASSES_ALL): PRIVATE_HOST_JACOCO_DIR := $(call intermediates-dir-for,PACKAGING,jacoco,HOST)
$(JACOCO_REPORT_CLASSES_ALL): PRIVATE_TARGET_PROGUARD_USAGE_DIR := $(call intermediates-dir-for,PACKAGING,proguard_usage)
$(JACOCO_REPORT_CLASSES_ALL): PRIVATE_HOST_PROGUARD_USAGE_DIR := $(call intermediates-dir-for,PACKAGING,proguard_usage,HOST)
$(JACOCO_REPORT_CLASSES_ALL) :
	@echo "Collecting uninstrumented classes"
	mkdir -p $(PRIVATE_TARGET_JACOCO_DIR) $(PRIVATE_HOST_JACOCO_DIR) $(PRIVATE_TARGET_PROGUARD_USAGE_DIR) $(PRIVATE_HOST_PROGUARD_USAGE_DIR)
	$(SOONG_ZIP) -o $@ -L 0 \
	  -C $(PRIVATE_TARGET_JACOCO_DIR) -P out/target/common/obj -D $(PRIVATE_TARGET_JACOCO_DIR) \
	  -C $(PRIVATE_HOST_JACOCO_DIR) -P out/target/common/obj -D $(PRIVATE_HOST_JACOCO_DIR) \
	  -C $(PRIVATE_TARGET_PROGUARD_USAGE_DIR) -P out/target/common/obj -D $(PRIVATE_TARGET_PROGUARD_USAGE_DIR) \
	  -C $(PRIVATE_HOST_PROGUARD_USAGE_DIR) -P out/target/common/obj -D $(PRIVATE_HOST_PROGUARD_USAGE_DIR)

ifeq (,$(TARGET_BUILD_UNBUNDLED))
  $(JACOCO_REPORT_CLASSES_ALL): $(INTERNAL_ALLIMAGES_FILES)
endif

# This is not ideal, but it is difficult to correctly figure out the actual jacoco report
# jars we need to add here as dependencies, so we add the device-tests as a dependency when
# the env variable is set and this should guarantee thaat all the jacoco report jars are ready
# when we package the final report jar here.
ifeq ($(JACOCO_PACKAGING_INCLUDE_DEVICE_TESTS),true)
  $(JACOCO_REPORT_CLASSES_ALL): $(COMPATIBILITY.device-tests.FILES)
endif
endif # EMMA_INSTRUMENT=true


#------------------------------------------------------------------
# A zip of Proguard obfuscation dictionary files.
# Also produces a textproto containing mappings from the hashes of the
# dictionary contents (which are also stored in the dex files on the
# devices) to the filename of the proguard dictionary, which will allow
# finding the appropriate dictionary to deobfuscate a stack trace frame.
#

ifeq (,$(TARGET_BUILD_UNBUNDLED))
  _proguard_dict_zip_modules := $(call product-installed-modules,$(INTERNAL_PRODUCT))
else
  _proguard_dict_zip_modules := $(unbundled_build_modules)
endif

# The path to the zip file containing proguard dictionaries.
PROGUARD_DICT_ZIP :=$= $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-dict.zip
$(PROGUARD_DICT_ZIP): PRIVATE_SOONG_ZIP_ARGUMENTS := $(foreach m,$(_proguard_dict_zip_modules),$(ALL_MODULES.$(m).PROGUARD_DICTIONARY_SOONG_ZIP_ARGUMENTS))
$(PROGUARD_DICT_ZIP): $(SOONG_ZIP) $(foreach m,$(_proguard_dict_zip_modules),$(ALL_MODULES.$(m).PROGUARD_DICTIONARY_FILES))
	@echo "Packaging Proguard obfuscation dictionary files."
	# Zip all of the files in PROGUARD_DICTIONARY_FILES.
	echo -n > $@.tmparglist
	$(foreach arg,$(PRIVATE_SOONG_ZIP_ARGUMENTS),printf "%s\n" "$(arg)" >> $@.tmparglist$(newline))
	$(SOONG_ZIP) -d -o $@ @$@.tmparglist
	rm -f $@.tmparglist

# The path to the zip file containing mappings from dictionary hashes to filenames.
PROGUARD_DICT_MAPPING :=$= $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-dict-mapping.textproto
_proguard_dict_mapping_files := $(foreach m,$(_proguard_dict_zip_modules),$(ALL_MODULES.$(m).PROGUARD_DICTIONARY_MAPPING))
$(PROGUARD_DICT_MAPPING): PRIVATE_MAPPING_FILES := $(_proguard_dict_mapping_files)
$(PROGUARD_DICT_MAPPING): $(SYMBOLS_MAP) $(_proguard_dict_mapping_files)
	@echo "Packaging Proguard obfuscation dictionary mapping files."
	# Merge all the mapping files together
	echo -n > $@.tmparglist
	$(foreach mf,$(PRIVATE_MAPPING_FILES),echo "$(mf)" >> $@.tmparglist$(newline))
	$(SYMBOLS_MAP) -merge $(PROGUARD_DICT_MAPPING) @$@.tmparglist
	rm -f $@.tmparglist

$(call declare-1p-container,$(PROGUARD_DICT_ZIP),)
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(call declare-container-license-deps,$(PROGUARD_DICT_ZIP),$(INTERNAL_ALLIMAGES_FILES) $(updater_dep),$(PRODUCT_OUT)/:/)
endif

#------------------------------------------------------------------
# A zip of Proguard usage files.
#
PROGUARD_USAGE_ZIP :=$= $(PRODUCT_OUT)/$(TARGET_PRODUCT)-proguard-usage.zip
_proguard_usage_zips := $(foreach m,$(_proguard_dict_zip_modules),$(ALL_MODULES.$(m).PROGUARD_USAGE_ZIP))
$(PROGUARD_USAGE_ZIP): PRIVATE_ZIPS := $(_proguard_usage_zips)
$(PROGUARD_USAGE_ZIP): $(MERGE_ZIPS) $(_proguard_usage_zips)
	@echo "Packaging Proguard usage files."
	echo -n > $@.tmparglist
	$(foreach z,$(PRIVATE_ZIPS),echo "$(z)" >> $@.tmparglist$(newline))
	$(MERGE_ZIPS) $@ @$@.tmparglist
	rm -rf $@.tmparglist

_proguard_dict_mapping_files :=
_proguard_usage_zips :=
_proguard_dict_zip_modules :=

$(call declare-1p-container,$(PROGUARD_USAGE_ZIP),)
ifeq (,$(TARGET_BUILD_UNBUNDLED))
$(call declare-container-license-deps,$(PROGUARD_USAGE_ZIP),$(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(INSTALLED_BOOTIMAGE_TARGET) \
    $(INSTALLED_INIT_BOOT_IMAGE_TARGET) \
    $(INSTALLED_USERDATAIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) \
    $(INSTALLED_ODMIMAGE_TARGET) \
    $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) \
    $(INSTALLED_ODM_DLKMIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) \
    $(updater_dep),$(PROGUARD_USAGE_ZIP):/)
endif

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
$(INTERNAL_SUPERIMAGE_DIST_TARGET): $(LPMAKE) $(BUILT_TARGET_FILES_DIR) $(BUILD_SUPER_IMAGE)
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

$(INSTALLED_SUPERIMAGE_TARGET): $(INSTALLED_SUPERIMAGE_DEPENDENCIES)
	$(call pretty,"Target super fs image for debug: $@")
	$(call build-superimage-target,$(INSTALLED_SUPERIMAGE_TARGET),\
          $(call intermediates-dir-for,PACKAGING,superimage_debug)/misc_info.txt)

# For devices that uses super image directly, the superimage target points to the file in $(PRODUCT_OUT).
.PHONY: superimage
superimage: $(INSTALLED_SUPERIMAGE_TARGET)

# If BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT is set, super.img is built from images in the
# $(PRODUCT_OUT) directory, and is built to $(PRODUCT_OUT)/super.img. Also, it will
# be built for non-dist builds. This is useful for devices that uses super.img directly, e.g.
# virtual devices.
ifeq (true,$(BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT))
droidcore-unbundled: $(INSTALLED_SUPERIMAGE_TARGET)

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
ifdef BUILDING_SUPER_EMPTY_IMAGE

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

$(call declare-0p-target,$(INSTALLED_SUPERIMAGE_EMPTY_TARGET))

endif # BUILDING_SUPER_EMPTY_IMAGE


# -----------------------------------------------------------------
# The update package

name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-img

INTERNAL_UPDATE_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_UPDATE_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) $(IMG_FROM_TARGET_FILES)
	$(call pretty,"Package: $@")
	PATH=$(INTERNAL_USERIMAGES_BINARY_PATHS):$(dir $(ZIP2ZIP)):$$PATH \
	    $(IMG_FROM_TARGET_FILES) \
	        --additional IMAGES/VerifiedBootParams.textproto:VerifiedBootParams.textproto \
	        --build_super_image $(BUILD_SUPER_IMAGE) \
	        $(BUILT_TARGET_FILES_PACKAGE) $@

$(call declare-1p-container,$(INTERNAL_UPDATE_PACKAGE_TARGET),)
$(call declare-container-license-deps,$(INTERNAL_UPDATE_PACKAGE_TARGET),$(BUILT_TARGET_FILES_PACKAGE) $(IMG_FROM_TARGET_FILES),$(PRODUCT_OUT)/:/)

.PHONY: updatepackage
updatepackage: $(INTERNAL_UPDATE_PACKAGE_TARGET)
$(call dist-for-goals-with-filenametag,updatepackage,$(INTERNAL_UPDATE_PACKAGE_TARGET))


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
droidcore-unbundled: $(INSTALLED_QEMU_SYSTEMIMAGE)
endif
ifdef INSTALLED_VENDORIMAGE_TARGET
INSTALLED_QEMU_VENDORIMAGE := $(PRODUCT_OUT)/vendor-qemu.img
$(INSTALLED_QEMU_VENDORIMAGE): $(INSTALLED_VENDORIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create vendor-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_VENDORIMAGE_TARGET))

vendorimage: $(INSTALLED_QEMU_VENDORIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_VENDORIMAGE)
endif

ifdef INSTALLED_RAMDISK_TARGET
ifdef INSTALLED_VENDOR_BOOTIMAGE_TARGET
ifdef INTERNAL_VENDOR_RAMDISK_TARGET
INSTALLED_QEMU_RAMDISKIMAGE := $(PRODUCT_OUT)/ramdisk-qemu.img
$(INSTALLED_QEMU_RAMDISKIMAGE): $(INTERNAL_VENDOR_RAMDISK_TARGET) $(INSTALLED_RAMDISK_TARGET)
	@echo Create ramdisk-qemu.img
	(cat $(INSTALLED_RAMDISK_TARGET) $(INTERNAL_VENDOR_RAMDISK_TARGET) > $(INSTALLED_QEMU_RAMDISKIMAGE))

droidcore-unbundled: $(INSTALLED_QEMU_RAMDISKIMAGE)
endif
endif
endif

ifdef INSTALLED_PRODUCTIMAGE_TARGET
INSTALLED_QEMU_PRODUCTIMAGE := $(PRODUCT_OUT)/product-qemu.img
$(INSTALLED_QEMU_PRODUCTIMAGE): $(INSTALLED_PRODUCTIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create product-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_PRODUCTIMAGE_TARGET))

productimage: $(INSTALLED_QEMU_PRODUCTIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_PRODUCTIMAGE)
endif
ifdef INSTALLED_SYSTEM_EXTIMAGE_TARGET
INSTALLED_QEMU_SYSTEM_EXTIMAGE := $(PRODUCT_OUT)/system_ext-qemu.img
$(INSTALLED_QEMU_SYSTEM_EXTIMAGE): $(INSTALLED_SYSTEM_EXTIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST) $(SIMG2IMG)
	@echo Create system_ext-qemu.img
	(export SGDISK=$(SGDISK_HOST) SIMG2IMG=$(SIMG2IMG); $(MK_QEMU_IMAGE_SH) $(INSTALLED_SYSTEM_EXTIMAGE_TARGET))

systemextimage: $(INSTALLED_QEMU_SYSTEM_EXTIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_SYSTEM_EXTIMAGE)
endif
ifdef INSTALLED_ODMIMAGE_TARGET
INSTALLED_QEMU_ODMIMAGE := $(PRODUCT_OUT)/odm-qemu.img
$(INSTALLED_QEMU_ODMIMAGE): $(INSTALLED_ODMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create odm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_ODMIMAGE_TARGET))

odmimage: $(INSTALLED_QEMU_ODMIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_ODMIMAGE)
endif

ifdef INSTALLED_VENDOR_DLKMIMAGE_TARGET
INSTALLED_QEMU_VENDOR_DLKMIMAGE := $(PRODUCT_OUT)/vendor_dlkm-qemu.img
$(INSTALLED_QEMU_VENDOR_DLKMIMAGE): $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create vendor_dlkm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_VENDOR_DLKMIMAGE_TARGET))

vendor_dlkmimage: $(INSTALLED_QEMU_VENDOR_DLKMIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_VENDOR_DLKMIMAGE)
endif

ifdef INSTALLED_ODM_DLKMIMAGE_TARGET
INSTALLED_QEMU_ODM_DLKMIMAGE := $(PRODUCT_OUT)/odm_dlkm-qemu.img
$(INSTALLED_QEMU_ODM_DLKMIMAGE): $(INSTALLED_ODM_DLKMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create odm_dlkm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_ODM_DLKMIMAGE_TARGET))

odm_dlkmimage: $(INSTALLED_QEMU_ODM_DLKMIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_ODM_DLKMIMAGE)
endif

ifdef INSTALLED_SYSTEM_DLKMIMAGE_TARGET
INSTALLED_QEMU_SYSTEM_DLKMIMAGE := $(PRODUCT_OUT)/system_dlkm-qemu.img
$(INSTALLED_QEMU_SYSTEM_DLKMIMAGE): $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) $(MK_QEMU_IMAGE_SH) $(SGDISK_HOST)
	@echo Create system_dlkm-qemu.img
	(export SGDISK=$(SGDISK_HOST); $(MK_QEMU_IMAGE_SH) $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET))

system_dlkmimage: $(INSTALLED_QEMU_SYSTEM_DLKMIMAGE)
droidcore-unbundled: $(INSTALLED_QEMU_SYSTEM_DLKMIMAGE)
endif

QEMU_VERIFIED_BOOT_PARAMS := $(PRODUCT_OUT)/VerifiedBootParams.textproto
$(QEMU_VERIFIED_BOOT_PARAMS): $(INSTALLED_VBMETAIMAGE_TARGET) $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH) $(AVBTOOL)
	@echo Creating $@
	(export AVBTOOL=$(AVBTOOL); $(MK_VBMETA_BOOT_KERNEL_CMDLINE_SH) $(INSTALLED_VBMETAIMAGE_TARGET) \
    $(INSTALLED_SYSTEMIMAGE_TARGET) $(QEMU_VERIFIED_BOOT_PARAMS))

systemimage: $(QEMU_VERIFIED_BOOT_PARAMS)
droidcore-unbundled: $(QEMU_VERIFIED_BOOT_PARAMS)

endif
# -----------------------------------------------------------------
# The emulator package
ifeq ($(BUILD_EMULATOR),true)
INTERNAL_EMULATOR_PACKAGE_FILES += \
        $(HOST_OUT_EXECUTABLES)/emulator$(HOST_EXECUTABLE_SUFFIX) \
        $(INSTALLED_RAMDISK_TARGET) \
        $(INSTALLED_SYSTEMIMAGE_TARGET) \
        $(INSTALLED_USERDATAIMAGE_TARGET)

name := $(TARGET_PRODUCT)-emulator

INTERNAL_EMULATOR_PACKAGE_TARGET := $(PRODUCT_OUT)/$(name).zip

$(INTERNAL_EMULATOR_PACKAGE_TARGET): $(INTERNAL_EMULATOR_PACKAGE_FILES)
	@echo "Package: $@"
	$(hide) zip -qjX $@ $(INTERNAL_EMULATOR_PACKAGE_FILES)

endif


# -----------------------------------------------------------------
# The SDK

ifneq ($(filter sdk,$(MAKECMDGOALS)),)

# The SDK includes host-specific components, so it belongs under HOST_OUT.
sdk_dir := $(HOST_OUT)/sdk/$(TARGET_PRODUCT)

# Build a name that looks like:
#
#     linux-x86   --> android-sdk_12345_linux-x86
#     darwin-x86  --> android-sdk_12345_mac-x86
#     windows-x86 --> android-sdk_12345_windows
#
ifneq ($(HOST_OS),linux)
  $(error Building the monolithic SDK is only supported on Linux)
endif
sdk_name := android-sdk
INTERNAL_SDK_HOST_OS_NAME := linux-$(SDK_HOST_ARCH)
sdk_name := $(sdk_name)_$(INTERNAL_SDK_HOST_OS_NAME)

sdk_dep_file := $(sdk_dir)/sdk_deps.mk

ATREE_FILES :=
-include $(sdk_dep_file)

# if we don't have a real list, then use "everything"
ifeq ($(strip $(ATREE_FILES)),)
ATREE_FILES := \
	$(ALL_DOCS) \
	$(ALL_SDK_FILES)
endif

atree_dir := development/build


sdk_atree_files := $(atree_dir)/sdk.exclude.atree

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

deps := \
	$(OUT_DOCS)/offline-sdk-timestamp \
	$(SDK_METADATA_FILES) \
  $(INSTALLED_SDK_BUILD_PROP_TARGET) \
	$(ATREE_FILES) \
	$(sdk_atree_files) \
	$(HOST_OUT_EXECUTABLES)/atree \
	$(HOST_OUT_EXECUTABLES)/line_endings

# The name of the subdir within the platforms dir of the sdk. One of:
# - android-<SDK_INT> (stable base dessert SDKs)
# - android-<CODENAME> (stable extension SDKs)
# - android-<SDK_INT>-ext<EXT_INT> (codename SDKs)
sdk_platform_dir_name := $(strip \
  $(if $(filter REL,$(PLATFORM_VERSION_CODENAME)), \
    $(if $(filter $(PLATFORM_SDK_EXTENSION_VERSION),$(PLATFORM_BASE_SDK_EXTENSION_VERSION)), \
      android-$(PLATFORM_SDK_VERSION), \
      android-$(PLATFORM_SDK_VERSION)-ext$(PLATFORM_SDK_EXTENSION_VERSION) \
    ), \
    android-$(PLATFORM_VERSION_CODENAME) \
  ) \
)

INTERNAL_SDK_TARGET := $(sdk_dir)/$(sdk_name).zip
$(INTERNAL_SDK_TARGET): PRIVATE_NAME := $(sdk_name)
$(INTERNAL_SDK_TARGET): PRIVATE_DIR := $(sdk_dir)/$(sdk_name)
$(INTERNAL_SDK_TARGET): PRIVATE_DEP_FILE := $(sdk_dep_file)
$(INTERNAL_SDK_TARGET): PRIVATE_INPUT_FILES := $(sdk_atree_files)
$(INTERNAL_SDK_TARGET): PRIVATE_PLATFORM_NAME := $(sdk_platform_dir_name)
# Set SDK_GNU_ERROR to non-empty to fail when a GNU target is built.
#
#SDK_GNU_ERROR := true

$(INTERNAL_SDK_TARGET): $(deps)
	@echo "Package SDK: $@"
	$(hide) rm -rf $(PRIVATE_DIR) $@
	$(hide) for f in $(strip $(target_gnu_MODULES)); do \
	  if [ -f $$f ]; then \
	    echo SDK: $(if $(SDK_GNU_ERROR),ERROR:,warning:) \
	        including GNU target $$f >&2; \
	    FAIL=$(SDK_GNU_ERROR); \
	  fi; \
	done; \
	if [ $$FAIL ]; then exit 1; fi
	$(hide) ( \
	    ATREE_STRIP="$(HOST_STRIP) -x" \
	    $(HOST_OUT_EXECUTABLES)/atree \
	    $(addprefix -f ,$(PRIVATE_INPUT_FILES)) \
	        -m $(PRIVATE_DEP_FILE) \
	        -I . \
	        -I $(PRODUCT_OUT) \
	        -I $(HOST_OUT) \
	        -I $(TARGET_COMMON_OUT_ROOT) \
	        -v "PLATFORM_NAME=$(PRIVATE_PLATFORM_NAME)" \
	        -v "OUT_DIR=$(OUT_DIR)" \
	        -v "HOST_OUT=$(HOST_OUT)" \
	        -v "TARGET_ARCH=$(TARGET_ARCH)" \
	        -v "TARGET_CPU_ABI=$(TARGET_CPU_ABI)" \
	        -v "DLL_EXTENSION=$(HOST_SHLIB_SUFFIX)" \
	        -o $(PRIVATE_DIR) && \
	    HOST_OUT_EXECUTABLES=$(HOST_OUT_EXECUTABLES) HOST_OS=$(HOST_OS) \
	        development/build/tools/sdk_clean.sh $(PRIVATE_DIR) && \
	    chmod -R ug+rwX $(PRIVATE_DIR) && \
	    cd $(dir $@) && zip -rqX $(notdir $@) $(PRIVATE_NAME) \
	) || ( rm -rf $(PRIVATE_DIR) $@ && exit 44 )

MAIN_SDK_DIR  := $(sdk_dir)
MAIN_SDK_ZIP  := $(INTERNAL_SDK_TARGET)

endif # sdk in MAKECMDGOALS

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
# The rule to build all fuzz targets for C++ and Rust, and package them.
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
$(call dist-for-goals,haiku,$(PRODUCT_OUT)/module-info.json)
.PHONY: haiku-java
haiku-java: $(SOONG_JAVA_FUZZ_PACKAGING_ARCH_MODULES) $(ALL_JAVA_FUZZ_TARGETS)
$(call dist-for-goals,haiku-java,$(SOONG_JAVA_FUZZ_PACKAGING_ARCH_MODULES))
.PHONY: haiku-rust
haiku-rust: $(SOONG_RUST_FUZZ_PACKAGING_ARCH_MODULES) $(ALL_RUST_FUZZ_TARGETS)
$(call dist-for-goals,haiku-rust,$(SOONG_RUST_FUZZ_PACKAGING_ARCH_MODULES))
$(call dist-for-goals,haiku-rust,$(PRODUCT_OUT)/module-info.json)
.PHONY: haiku-presubmit
haiku-presubmit: $(SOONG_PRESUBMIT_FUZZ_PACKAGING_ARCH_MODULES) $(ALL_PRESUBMIT_FUZZ_TARGETS)
$(call dist-for-goals,haiku-presubmit,$(SOONG_PRESUBMIT_FUZZ_PACKAGING_ARCH_MODULES))

# -----------------------------------------------------------------
# Extract platform fonts used in Layoutlib
include $(BUILD_SYSTEM)/layoutlib_data.mk


# -----------------------------------------------------------------
# OS Licensing

include $(BUILD_SYSTEM)/os_licensing.mk

# When appending new code to this file, please insert above OS Licensing
