SOONG_OUT_DIR := $(OUT_DIR)/soong

# This needs to exist before the realpath checks below
$(shell mkdir -p $(SOONG_OUT_DIR))

ifeq (,$(filter /%,$(SOONG_OUT_DIR)))
SOONG_TOP_RELPATH := $(shell python -c "import os; print os.path.relpath('$(TOP)', '$(SOONG_OUT_DIR)')")
# Protect against out being a symlink and relative paths not working
ifneq ($(realpath $(SOONG_OUT_DIR)/$(SOONG_TOP_RELPATH)),$(realpath $(TOP)))
SOONG_OUT_DIR := $(abspath $(SOONG_OUT_DIR))
SOONG_TOP_RELPATH := $(abspath $(TOP))
endif
else
SOONG_TOP_RELPATH := $(abspath $(TOP))
endif

SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables
SOONG_IN_MAKE := $(SOONG_OUT_DIR)/.soong.in_make

# Only include the Soong-generated Android.mk if we're merging the
# Soong-defined binaries with Kati-defined binaries.
ifeq ($(USE_SOONG),true)
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android.mk
endif

# Bootstrap soong.  Run only the first time for clean builds
$(SOONG):
	$(hide) mkdir -p $(dir $@)
	$(hide) cd $(dir $@) && $(SOONG_TOP_RELPATH)/bootstrap.bash

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
SOONG_VARIABLES_TMP := $(SOONG_VARIABLES).$$$$
$(SOONG_VARIABLES): FORCE
	$(hide) mkdir -p $(dir $@)
	$(hide) (\
	echo '{'; \
	echo '    "Platform_sdk_version": $(PLATFORM_SDK_VERSION),'; \
	echo '    "Unbundled_build": $(if $(TARGET_BUILD_APPS),true,false),'; \
	echo '    "Brillo": $(if $(BRILLO),true,false),'; \
	echo '    "Malloc_not_svelte": $(if $(filter true,$(MALLOC_SVELTE)),false,true),'; \
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
run_soong: $(SOONG) $(SOONG_VARIABLES) $(SOONG_IN_MAKE) FORCE
	$(hide) $(SOONG) $(SOONG_BUILD_NINJA) $(NINJA_ARGS)
