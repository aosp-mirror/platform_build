SOONG_OUT_DIR := $(OUT_DIR)/soong
SOONG_HOST_EXECUTABLES := $(SOONG_OUT_DIR)/host/$(HOST_PREBUILT_TAG)/bin
KATI := $(SOONG_HOST_EXECUTABLES)/ckati
MAKEPARALLEL := $(SOONG_HOST_EXECUTABLES)/makeparallel

SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BOOTSTRAP := $(SOONG_OUT_DIR)/.soong.bootstrap
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android.mk
SOONG_IN_MAKE := $(SOONG_OUT_DIR)/.soong.in_make
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables

# We need to rebootstrap soong if SOONG_OUT_DIR or the reverse path from
# SOONG_OUT_DIR to TOP changes
SOONG_NEEDS_REBOOTSTRAP :=
ifneq ($(wildcard $(SOONG_BOOTSTRAP)),)
  ifneq ($(SOONG_OUT_DIR),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$BUILDDIR)))
    SOONG_NEEDS_REBOOTSTRAP := FORCE
    $(warning soong_out_dir changed)
  endif
  ifneq ($(strip $(shell build/soong/reverse_path.py $(SOONG_OUT_DIR))),$(strip $(shell source $(SOONG_BOOTSTRAP); echo $$SRCDIR_FROM_BUILDDIR)))
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
	echo '    "Device_uses_jemalloc": $(if $(filter true,$(MALLOC_SVELTE)),false,true),'; \
	echo '    "Device_uses_dlmalloc": $(if $(filter true,$(MALLOC_SVELTE)),true,false),'; \
	echo '    "Platform_sdk_version": $(PLATFORM_SDK_VERSION),'; \
	echo '    "Unbundled_build": $(if $(TARGET_BUILD_APPS),true,false),'; \
	echo '    "Brillo": $(if $(BRILLO),true,false),'; \
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

# Build an Android.mk listing all soong outputs as prebuilts
$(SOONG_ANDROID_MK): $(SOONG_BOOTSTRAP) $(SOONG_VARIABLES) $(SOONG_IN_MAKE) FORCE
	$(hide) $(SOONG) $(KATI) $(MAKEPARALLEL) $(NINJA_ARGS)

$(KATI): $(SOONG_ANDROID_MK)
$(MAKEPARALLEL): $(SOONG_ANDROID_MK)
