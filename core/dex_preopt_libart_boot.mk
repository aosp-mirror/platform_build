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
$(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_FILES := $(addprefix $(dir $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)),\
    $(LIBART_TARGET_BOOT_ART_VDEX_FILES))

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
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE) : $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME) | $(ACP) $($(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_EXTRA_INSTALLED_FILES) $($(my_2nd_arch_prefix)LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_SHARED_FILES)
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

ifneq (addresstrue,$(SANITIZE_TARGET)$(SANITIZE_LITE))
# Skip recompiling the boot image for the second sanitization phase. We'll get separate paths
# and invalidate first-stage artifacts which are crucial to SANITIZE_LITE builds.
# Note: this is technically incorrect. Compiled code contains stack checks which may depend
#       on ASAN settings.

# Use ANDROID_LOG_TAGS to suppress most logging by default...
ifeq (,$(ART_BOOT_IMAGE_EXTRA_ARGS))
DEX2OAT_BOOT_IMAGE_LOG_TAGS := ANDROID_LOG_TAGS="*:e"
else
# ...unless the boot image is generated specifically for testing, then allow all logging.
DEX2OAT_BOOT_IMAGE_LOG_TAGS := ANDROID_LOG_TAGS="*:v"
endif

# An additional message to print on dex2oat failure.
DEX2OAT_FAILURE_MESSAGE := ERROR: Dex2oat failed to compile a boot image.
DEX2OAT_FAILURE_MESSAGE += It is likely that the boot classpath is inconsistent.
ifeq ($(ONE_SHOT_MAKEFILE),)
  DEX2OAT_FAILURE_MESSAGE += Rebuild with ART_BOOT_IMAGE_EXTRA_ARGS="--runtime-arg -verbose:verifier" to see verification errors.
else
  DEX2OAT_FAILURE_MESSAGE += Build with m, mma, or mmma instead of mm or mmm to remedy the situation.
endif

$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME): PRIVATE_BOOT_IMAGE_FLAGS := $(my_boot_image_flags)
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME): PRIVATE_2ND_ARCH_VAR_PREFIX := $(my_2nd_arch_prefix)
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME): PRIVATE_IMAGE_LOCATION := $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_LOCATION)
# Use dex2oat debug version for better error reporting
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME) : $(LIBART_TARGET_BOOT_DEX_FILES) $(PRELOADED_CLASSES) $(COMPILED_CLASSES) $(DIRTY_IMAGE_OBJECTS) $(DEX2OAT_DEPENDENCY) $(PATCHOAT_DEPENDENCY) $(my_out_boot_image_profile_location)
	@echo "target dex2oat: $@"
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))
	@rm -f $(dir $@)/*.art $(dir $@)/*.oat $(dir $@)/*.art.rel
	@rm -f $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))/*.art
	@rm -f $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))/*.oat
	@rm -f $(dir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)LIBART_TARGET_BOOT_OAT_UNSTRIPPED))/*.art.rel
	$(hide) $(DEX2OAT_BOOT_IMAGE_LOG_TAGS) $(DEX2OAT) --runtime-arg -Xms$(DEX2OAT_IMAGE_XMS) \
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
		--abort-on-hard-verifier-error \
		--abort-on-soft-verifier-error \
		$(PRODUCT_DEX_PREOPT_BOOT_FLAGS) $(GLOBAL_DEXPREOPT_FLAGS) $(ART_BOOT_IMAGE_EXTRA_ARGS) \
		|| ( echo "$(DEX2OAT_FAILURE_MESSAGE)" ; false ) && \
	$(DEX2OAT_BOOT_IMAGE_LOG_TAGS) ANDROID_ROOT=$(PRODUCT_OUT)/system ANDROID_DATA=$(dir $@) $(PATCHOAT) \
		--input-image-location=$(PRIVATE_IMAGE_LOCATION) \
		--output-image-relocation-directory=$(dir $@) \
		--instruction-set=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH) \
		--base-offset-delta=0x10000000

endif
