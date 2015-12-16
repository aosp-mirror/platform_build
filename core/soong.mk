SOONG_OUT_DIR := $(OUT_DIR)/soong
SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android.mk
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables

ifeq (,$(filter /%,$(SOONG_OUT_DIR)))
SOONG_TOP_RELPATH := $(shell python -c "import os; print os.path.relpath('$(TOP)', '$(SOONG_OUT_DIR)')")
else
SOONG_TOP_RELPATH := $(realpath $(TOP))
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
	echo '    "Device_uses_jemalloc": $(if $(filter dlmalloc,$(MALLOC_IMPL)),false,true),'; \
	echo '    "Device_uses_dlmalloc": $(if $(filter dlmalloc,$(MALLOC_IMPL)),true,false),'; \
	echo '    $(if $(BOARD_MALLOC_ALIGNMENT),"Dlmalloc_alignment": $(BOARD_MALLOC_ALIGNMENT)$(comma),)'; \
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
	echo '    "HostSecondaryArch": "$(HOST_2ND_ARCH)"'; \
	echo '}') > $(SOONG_VARIABLES_TMP); \
	if ! cmp -s $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES_TMP); \
	fi

# Build an Android.mk listing all soong outputs as prebuilts
$(SOONG_ANDROID_MK): $(SOONG) $(SOONG_VARIABLES) FORCE
	$(hide) $(SOONG) $(SOONG_BUILD_NINJA) $(NINJA_ARGS)
