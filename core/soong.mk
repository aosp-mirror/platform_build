SOONG_OUT_DIR := $(OUT_DIR)/soong
SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BOOTSTRAP := $(SOONG_OUT_DIR)/.soong.bootstrap
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_IN_MAKE := $(SOONG_OUT_DIR)/.soong.in_make
SOONG_MAKEVARS_MK := $(SOONG_OUT_DIR)/make_vars-$(TARGET_PRODUCT).mk
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables

# Only include the Soong-generated Android.mk if we're merging the
# Soong-defined binaries with Kati-defined binaries.
ifeq ($(USE_SOONG),true)
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android-$(TARGET_PRODUCT).mk
endif

# We need to rebootstrap soong if SOONG_OUT_DIR or the reverse path from
# SOONG_OUT_DIR to TOP changes
SOONG_NEEDS_REBOOTSTRAP :=
ifneq ($(wildcard $(SOONG_BOOTSTRAP)),)
  ifneq ($(SOONG_OUT_DIR),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$BUILDDIR)))
    SOONG_NEEDS_REBOOTSTRAP := FORCE
    $(warning soong_out_dir changed)
  endif
  ifneq ($(strip $(shell build/soong/scripts/reverse_path.py $(SOONG_OUT_DIR))),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$SRCDIR_FROM_BUILDDIR)))
    SOONG_NEEDS_REBOOTSTRAP := FORCE
    $(warning reverse path changed)
  endif
endif

# Bootstrap soong.
$(SOONG_BOOTSTRAP): bootstrap.bash $(SOONG_NEEDS_REBOOTSTRAP)
	$(hide) mkdir -p $(dir $@)
	$(hide) BUILDDIR=$(SOONG_OUT_DIR) ./bootstrap.bash

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
SOONG_VARIABLES_TMP := $(SOONG_VARIABLES).$$$$
$(SOONG_VARIABLES): FORCE
	$(hide) mkdir -p $(dir $@)
	$(hide) (\
	echo '{'; \
	echo '    "Make_suffix": "-$(TARGET_PRODUCT)",'; \
	echo ''; \
	echo '    "Platform_sdk_version": $(PLATFORM_SDK_VERSION),'; \
	echo '    "Unbundled_build": $(if $(TARGET_BUILD_APPS),true,false),'; \
	echo '    "Brillo": $(if $(BRILLO),true,false),'; \
	echo '    "Malloc_not_svelte": $(if $(filter true,$(MALLOC_SVELTE)),false,true),'; \
	echo '    "Allow_missing_dependencies": $(if $(TARGET_BUILD_APPS)$(filter true,$(SOONG_ALLOW_MISSING_DEPENDENCIES)),true,false),'; \
	echo '    "SanitizeHost": [$(if $(SANITIZE_HOST),"$(subst $(comma),"$(comma)",$(SANITIZE_HOST))")],'; \
	echo '    "SanitizeDevice": [$(if $(SANITIZE_TARGET),"$(subst $(comma),"$(comma)",$(SANITIZE_TARGET))")],'; \
	echo ''; \
	echo '    "DeviceName": "$(TARGET_DEVICE)",'; \
	echo '    "DeviceArch": "$(TARGET_ARCH)",'; \
	echo '    "DeviceArchVariant": "$(TARGET_ARCH_VARIANT)",'; \
	echo '    "DeviceCpuVariant": "$(TARGET_CPU_VARIANT)",'; \
	echo '    "DeviceAbi": ["$(TARGET_CPU_ABI)", "$(TARGET_CPU_ABI2)"],'; \
	echo '    "DeviceUsesClang": $(if $(USE_CLANG_PLATFORM_BUILD),$(USE_CLANG_PLATFORM_BUILD),false),'; \
	echo ''; \
	echo '    "DeviceSecondaryArch": "$(TARGET_2ND_ARCH)",'; \
	echo '    "DeviceSecondaryArchVariant": "$(TARGET_2ND_ARCH_VARIANT)",'; \
	echo '    "DeviceSecondaryCpuVariant": "$(TARGET_2ND_CPU_VARIANT)",'; \
	echo '    "DeviceSecondaryAbi": ["$(TARGET_2ND_CPU_ABI)", "$(TARGET_2ND_CPU_ABI2)"],'; \
	echo ''; \
	echo '    "HostArch": "$(HOST_ARCH)",'; \
	echo '    "HostSecondaryArch": "$(HOST_2ND_ARCH)",'; \
	echo ''; \
	echo '    "CrossHost": "$(HOST_CROSS_OS)",'; \
	echo '    "CrossHostArch": "$(HOST_CROSS_ARCH)",'; \
	echo '    "CrossHostSecondaryArch": "$(HOST_CROSS_2ND_ARCH)"'; \
	echo '}') > $(SOONG_VARIABLES_TMP); \
	if ! cmp -s $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES_TMP); \
	fi

# Tell soong that it is embedded in make
$(SOONG_IN_MAKE):
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

# Run Soong, this implicitly create an Android.mk listing all soong outputs as
# prebuilts.
.PHONY: run_soong
run_soong: $(SOONG_BOOTSTRAP) $(SOONG_VARIABLES) $(SOONG_IN_MAKE) FORCE
	$(hide) $(SOONG) $(SOONG_BUILD_NINJA) $(NINJA_EXTRA_ARGS)
