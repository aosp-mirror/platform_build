# Rules to build boot.art
# Input variables:
#   my_2nd_arch_prefix: indicates if this is to build for the 2nd arch.

# The image "location" is a symbolic path that with multiarchitecture
# support doesn't really exist on the device. Typically it is
# /system/framework/boot.art and should be the same for all supported
# architectures on the device. The concrete architecture specific
# content actually ends up in a "filename" that contains an
# architecture specific directory name such as arm, arm64, mips,
# mips64, x86, x86_64.
#
# Here are some example values for an x86_64 / x86 configuration:
#
# DEFAULT_DEX_PREOPT_BUILT_IMAGE_LOCATION=out/target/product/generic_x86_64/dex_bootjars/system/framework/boot.art
# DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME=out/target/product/generic_x86_64/dex_bootjars/system/framework/x86_64/boot.art
# LIBART_BOOT_IMAGE=/system/framework/x86_64/boot.art
#
# 2ND_DEFAULT_DEX_PREOPT_BUILT_IMAGE_LOCATION=out/target/product/generic_x86_64/dex_bootjars/system/framework/boot.art
# 2ND_DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME=out/target/product/generic_x86_64/dex_bootjars/system/framework/x86/boot.art
# 2ND_LIBART_BOOT_IMAGE=/system/framework/x86/boot.art

$(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_LOCATION := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/boot.art
$(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$($(my_2nd_arch_prefix)DEX2OAT_TARGET_ARCH)/boot.art
$(my_2nd_arch_prefix)LIBART_BOOT_IMAGE_FILENAME := /$(DEXPREOPT_BOOT_JAR_DIR)/$($(my_2nd_arch_prefix)DEX2OAT_TARGET_ARCH)/boot.art

# The .oat with symbols
$(my_2nd_arch_prefix)LIBART_TARGET_BOOT_OAT_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)$(patsubst %.art,%.oat,$($(my_2nd_arch_prefix)LIBART_BOOT_IMAGE_FILENAME))

$(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE := $(PRODUCT_OUT)$($(my_2nd_arch_prefix)LIBART_BOOT_IMAGE_FILENAME)
$(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_EXTRA_INSTALLED_FILES := $(addprefix $(dir $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)),\
    $(LIBART_TARGET_BOOT_ART_EXTRA_FILES))

# If we have a compiled-classes file, create a parameter.
COMPILED_CLASSES_FLAGS :=
ifneq ($(COMPILED_CLASSES),)
  COMPILED_CLASSES_FLAGS := --compiled-classes=$(COMPILED_CLASSES)
endif

# If we have a dirty-image-objects file, create a parameter.
DIRTY_IMAGE_OBJECTS_FLAGS :=
ifneq ($(DIRTY_IMAGE_OBJECTS),)
  DIRTY_IMAGE_OBJECTS_FLAGS := --dirty-image-objects=$(DIRTY_IMAGE_OBJECTS)
endif

# The rule to install boot.art
# Depends on installed boot.oat, boot-*.art, boot-*.oat
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE) : $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME) | $(ACP) $($(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_EXTRA_INSTALLED_FILES)
	@echo "Install: $@"
	$(copy-file-to-target)

# The rule to install boot.oat, boot-*.art, boot-*.oat
# Depends on built-but-not-installed boot.art
$($(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_EXTRA_INSTALLED_FILES) : $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME)  | $(ACP)
	@echo "Install: $@"
	@mkdir -p $(dir $@)
	$(hide) $(ACP) -fp $(dir $<)$(notdir $@) $@

ifeq (,$(my_out_boot_image_profile_location))
my_boot_image_flags := $(COMPILED_CLASSES_FLAGS)
my_boot_image_flags += --image-classes=$(PRELOADED_CLASSES)
my_boot_image_flags += $(DIRTY_IMAGE_OBJECTS_FLAGS)
else
my_boot_image_flags := --compiler-filter=speed-profile
my_boot_image_flags += --profile-file=$(my_out_boot_image_profile_location)
endif

$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME): PRIVATE_BOOT_IMAGE_FLAGS := $(my_boot_image_flags)
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME): PRIVATE_2ND_ARCH_VAR_PREFIX := $(my_2nd_arch_prefix)
# Use dex2oat debug version for better error reporting
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME) : $(LIBART_TARGET_BOOT_DEX_FILES) $(PRELOADED_CLASSES) $(COMPILED_CLASSES) $(DIRTY_IMAGE_OBJECTS) $(DEX2OAT_DEPENDENCY) $(my_out_boot_image_profile_location)
	@echo "target dex2oat: $@"
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))
	@rm -f $(dir $@)/*.art $(dir $@)/*.oat
	@rm -f $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))/*.art
	@rm -f $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))/*.oat
	$(DEX2OAT) --runtime-arg -Xms$(DEX2OAT_IMAGE_XMS) \
		--runtime-arg -Xmx$(DEX2OAT_IMAGE_XMX) \
		$(PRIVATE_BOOT_IMAGE_FLAGS) \
		$(addprefix --dex-file=,$(LIBART_TARGET_BOOT_DEX_FILES)) \
		$(addprefix --dex-location=,$(LIBART_TARGET_BOOT_DEX_LOCATIONS)) \
		--oat-symbols=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED) \
		--oat-file=$(patsubst %.art,%.oat,$@) \
		--oat-location=$(patsubst %.art,%.oat,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_BOOT_IMAGE_FILENAME)) \
		--image=$@ --base=$(LIBART_IMG_TARGET_BASE_ADDRESS) \
		--instruction-set=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH) \
		--instruction-set-variant=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT) \
		--instruction-set-features=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES) \
		--android-root=$(PRODUCT_OUT)/system \
		--runtime-arg -Xnorelocate --compile-pic \
		--no-generate-debug-info --generate-build-id \
		--multi-image --no-inline-from=core-oj.jar \
		$(PRODUCT_DEX_PREOPT_BOOT_FLAGS) $(GLOBAL_DEXPREOPT_FLAGS) $(ART_BOOT_IMAGE_EXTRA_ARGS)
