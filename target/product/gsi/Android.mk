LOCAL_PATH:= $(call my-dir)

#####################################################################
# list of vndk libraries from the source code.
INTERNAL_VNDK_LIB_LIST := $(SOONG_VNDK_LIBRARIES_FILE)

#####################################################################
# This is the up-to-date list of vndk libs.
LATEST_VNDK_LIB_LIST := $(LOCAL_PATH)/current.txt
ifeq ($(KEEP_VNDK),true)
UNFROZEN_VNDK := true
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
    # Use frozen vndk lib list only if "34 >= PLATFORM_VNDK_VERSION"
    ifeq ($(call math_gt_or_eq,34,$(PLATFORM_VNDK_VERSION)),true)
        LATEST_VNDK_LIB_LIST := $(LOCAL_PATH)/$(PLATFORM_VNDK_VERSION).txt
        ifeq ($(wildcard $(LATEST_VNDK_LIB_LIST)),)
            $(error $(LATEST_VNDK_LIB_LIST) file not found. Please copy "$(LOCAL_PATH)/current.txt" to "$(LATEST_VNDK_LIB_LIST)" and commit a CL for release branch)
        endif
        UNFROZEN_VNDK :=
    endif
endif
endif

#####################################################################
# Check the generate list against the latest list stored in the
# source tree
.PHONY: check-vndk-list

# Check if vndk list is changed
droidcore: check-vndk-list

check-vndk-list-timestamp := $(call intermediates-dir-for,PACKAGING,vndk)/check-list-timestamp
check-vndk-abi-dump-list-timestamp := $(call intermediates-dir-for,PACKAGING,vndk)/check-abi-dump-list-timestamp

ifeq ($(TARGET_IS_64_BIT)|$(TARGET_2ND_ARCH),true|)
# TODO(b/110429754) remove this condition when we support 64-bit-only device
check-vndk-list: ;
else ifeq ($(TARGET_SKIP_CURRENT_VNDK),true)
check-vndk-list: ;
else ifeq ($(BOARD_VNDK_VERSION),)
check-vndk-list: ;
else
check-vndk-list: $(check-vndk-list-timestamp)
ifneq ($(SKIP_ABI_CHECKS),true)
check-vndk-list: $(check-vndk-abi-dump-list-timestamp)
endif
endif

_vndk_check_failure_message := " error: VNDK library list has been changed.\n"
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
_vndk_check_failure_message += "       Changing the VNDK library list is not allowed in API locked branches."
else
_vndk_check_failure_message += "       Run \`update-vndk-list.sh\` to update $(LATEST_VNDK_LIB_LIST)"
endif

# The *-ndk_platform.so libraries no longer exist and are removed from the VNDK set. However, they
# can exist if NEED_AIDL_NDK_PLATFORM_BACKEND is set to true for legacy devices. Don't be bothered
# with the extraneous libraries.
ifeq ($(NEED_AIDL_NDK_PLATFORM_BACKEND),true)
	_READ_INTERNAL_VNDK_LIB_LIST := sed /ndk_platform.so/d $(INTERNAL_VNDK_LIB_LIST)
else
	_READ_INTERNAL_VNDK_LIB_LIST := cat $(INTERNAL_VNDK_LIB_LIST)
endif

$(check-vndk-list-timestamp): $(INTERNAL_VNDK_LIB_LIST) $(LATEST_VNDK_LIB_LIST) $(HOST_OUT_EXECUTABLES)/update-vndk-list.sh
	$(hide) ($(_READ_INTERNAL_VNDK_LIB_LIST) | sort | \
	diff --old-line-format="Removed %L" \
	  --new-line-format="Added %L" \
	  --unchanged-line-format="" \
	  <(cat $(LATEST_VNDK_LIB_LIST) | sort) - \
	  || ( echo -e $(_vndk_check_failure_message); exit 1 ))
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

#####################################################################
# Script to update the latest VNDK lib list
include $(CLEAR_VARS)
LOCAL_MODULE := update-vndk-list.sh
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_STEM := $(LOCAL_MODULE)
LOCAL_IS_HOST_MODULE := true
include $(BUILD_SYSTEM)/base_rules.mk
$(LOCAL_BUILT_MODULE): PRIVATE_INTERNAL_VNDK_LIB_LIST := $(INTERNAL_VNDK_LIB_LIST)
$(LOCAL_BUILT_MODULE): PRIVATE_LATEST_VNDK_LIB_LIST := $(LATEST_VNDK_LIB_LIST)
$(LOCAL_BUILT_MODULE):
	@echo "Generate: $@"
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) echo "#!/bin/bash" > $@
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
	$(hide) echo "echo Updating VNDK library list is NOT allowed in API locked branches." >> $@; \
	        echo "exit 1" >> $@
else
	$(hide) echo "if [ -z \"\$${ANDROID_BUILD_TOP}\" ]; then" >> $@; \
	        echo "  echo Run lunch or choosecombo first" >> $@; \
	        echo "  exit 1" >> $@; \
	        echo "fi" >> $@; \
	        echo "cd \$${ANDROID_BUILD_TOP}" >> $@
ifeq ($(NEED_AIDL_NDK_PLATFORM_BACKEND),true)
	$(hide) echo "sed /ndk_platform.so/d $(PRIVATE_INTERNAL_VNDK_LIB_LIST) > $(PRIVATE_LATEST_VNDK_LIB_LIST)" >> $@
else
	$(hide) echo "cp $(PRIVATE_INTERNAL_VNDK_LIB_LIST) $(PRIVATE_LATEST_VNDK_LIB_LIST)" >> $@
endif
	$(hide) echo "echo $(PRIVATE_LATEST_VNDK_LIB_LIST) updated." >> $@
endif
	@chmod a+x $@

#####################################################################
# ABI reference dumps.

# LSDUMP_PATHS is a list of tag:path. They are written to LSDUMP_PATHS_FILE.
LSDUMP_PATHS_FILE := $(PRODUCT_OUT)/lsdump_paths.txt

$(LSDUMP_PATHS_FILE): PRIVATE_LSDUMP_PATHS := $(LSDUMP_PATHS)
$(LSDUMP_PATHS_FILE):
	@echo "Generate $@"
	@rm -rf $@ && echo -e "$(subst :,:$(space),$(subst $(space),\n,$(PRIVATE_LSDUMP_PATHS)))" > $@

# $(1): A list of tags.
# $(2): A list of tag:path.
# Return the file paths of the ABI dumps that match the tags.
define filter-abi-dump-paths
$(eval tag_patterns := $(addsuffix :%,$(1)))
$(patsubst $(tag_patterns),%,$(filter $(tag_patterns),$(2)))
endef

# Subsets of LSDUMP_PATHS.
.PHONY: findlsdumps_LLNDK
findlsdumps_LLNDK: $(LSDUMP_PATHS_FILE) $(call filter-abi-dump-paths,LLNDK,$(LSDUMP_PATHS))

.PHONY: findlsdumps_NDK
findlsdumps_NDK: $(LSDUMP_PATHS_FILE) $(call filter-abi-dump-paths,NDK,$(LSDUMP_PATHS))

.PHONY: findlsdumps_PLATFORM
findlsdumps_PLATFORM: $(LSDUMP_PATHS_FILE) $(call filter-abi-dump-paths,PLATFORM,$(LSDUMP_PATHS))

.PHONY: findlsdumps
findlsdumps: $(LSDUMP_PATHS_FILE) $(foreach p,$(LSDUMP_PATHS),$(call word-colon,2,$(p)))

#####################################################################
# Check that all ABI reference dumps have corresponding
# NDK/VNDK/PLATFORM libraries.

# $(1): The directory containing ABI dumps.
# Return a list of ABI dump paths ending with .so.lsdump.
define find-abi-dump-paths
$(if $(wildcard $(1)), \
  $(addprefix $(1)/, \
    $(call find-files-in-subdirs,$(1),"*.so.lsdump" -and -type f,.)))
endef

# $(1): A list of tags.
# $(2): A list of tag:path.
# Return the file names of the ABI dumps that match the tags.
define filter-abi-dump-names
$(notdir $(call filter-abi-dump-paths,$(1),$(2)))
endef

ifdef RELEASE_BOARD_API_LEVEL
    VNDK_ABI_DUMP_DIR := prebuilts/abi-dumps/vndk/$(RELEASE_BOARD_API_LEVEL)
else
    VNDK_ABI_DUMP_DIR := prebuilts/abi-dumps/vndk/$(PLATFORM_VNDK_VERSION)
endif
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
    NDK_ABI_DUMP_DIR := prebuilts/abi-dumps/ndk/$(PLATFORM_SDK_VERSION)
    PLATFORM_ABI_DUMP_DIR := prebuilts/abi-dumps/platform/$(PLATFORM_SDK_VERSION)
else
    NDK_ABI_DUMP_DIR := prebuilts/abi-dumps/ndk/current
    PLATFORM_ABI_DUMP_DIR := prebuilts/abi-dumps/platform/current
endif
VNDK_ABI_DUMPS := $(call find-abi-dump-paths,$(VNDK_ABI_DUMP_DIR))
NDK_ABI_DUMPS := $(call find-abi-dump-paths,$(NDK_ABI_DUMP_DIR))
PLATFORM_ABI_DUMPS := $(call find-abi-dump-paths,$(PLATFORM_ABI_DUMP_DIR))

# Check for superfluous lsdump files. Since LSDUMP_PATHS only covers the
# libraries that can be built from source in the current build, and prebuilts of
# Mainline modules may be in use, we also allow the libs in STUB_LIBRARIES for
# NDK and platform ABIs.

$(check-vndk-abi-dump-list-timestamp): PRIVATE_LSDUMP_PATHS := $(LSDUMP_PATHS)
$(check-vndk-abi-dump-list-timestamp): PRIVATE_STUB_LIBRARIES := $(STUB_LIBRARIES)
$(check-vndk-abi-dump-list-timestamp):
	$(eval added_vndk_abi_dumps := $(strip $(sort $(filter-out \
	  $(call filter-abi-dump-names,LLNDK VNDK-SP VNDK-core,$(PRIVATE_LSDUMP_PATHS)), \
	  $(notdir $(VNDK_ABI_DUMPS))))))
	$(if $(added_vndk_abi_dumps), \
	  echo -e "Found unexpected ABI reference dump files under $(VNDK_ABI_DUMP_DIR). It is caused by mismatch between Android.bp and the dump files. Run \`find \$${ANDROID_BUILD_TOP}/$(VNDK_ABI_DUMP_DIR) '(' -name $(subst $(space), -or -name ,$(added_vndk_abi_dumps)) ')' -delete\` to delete the dump files.")

	$(eval added_ndk_abi_dumps := $(strip $(sort $(filter-out \
	  $(call filter-abi-dump-names,NDK,$(PRIVATE_LSDUMP_PATHS)) \
	  $(addsuffix .lsdump,$(PRIVATE_STUB_LIBRARIES)), \
	  $(notdir $(NDK_ABI_DUMPS))))))
	$(if $(added_ndk_abi_dumps), \
	  echo -e "Found unexpected ABI reference dump files under $(NDK_ABI_DUMP_DIR). It is caused by mismatch between Android.bp and the dump files. Run \`find \$${ANDROID_BUILD_TOP}/$(NDK_ABI_DUMP_DIR) '(' -name $(subst $(space), -or -name ,$(added_ndk_abi_dumps)) ')' -delete\` to delete the dump files.")

	# TODO(b/314010764): Remove LLNDK tag after PLATFORM_SDK_VERSION is upgraded to 35.
	$(eval added_platform_abi_dumps := $(strip $(sort $(filter-out \
	  $(call filter-abi-dump-names,LLNDK PLATFORM,$(PRIVATE_LSDUMP_PATHS)) \
	  $(addsuffix .lsdump,$(PRIVATE_STUB_LIBRARIES)), \
	  $(notdir $(PLATFORM_ABI_DUMPS))))))
	$(if $(added_platform_abi_dumps), \
	  echo -e "Found unexpected ABI reference dump files under $(PLATFORM_ABI_DUMP_DIR). It is caused by mismatch between Android.bp and the dump files. Run \`find \$${ANDROID_BUILD_TOP}/$(PLATFORM_ABI_DUMP_DIR) '(' -name $(subst $(space), -or -name ,$(added_platform_abi_dumps)) ')' -delete\` to delete the dump files.")

	$(if $(added_vndk_abi_dumps)$(added_ndk_abi_dumps)$(added_platform_abi_dumps),exit 1)
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

#####################################################################
# VNDK package and snapshot.

include $(CLEAR_VARS)
LOCAL_MODULE := vndk_package
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
# Filter LLNDK libs moved to APEX to avoid pulling them into /system/LIB
LOCAL_REQUIRED_MODULES := llndk_in_system

ifneq ($(TARGET_SKIP_CURRENT_VNDK),true)
LOCAL_REQUIRED_MODULES += \
    vndkcorevariant.libraries.txt \
    $(addsuffix .vendor,$(VNDK_CORE_LIBRARIES)) \
    $(addsuffix .vendor,$(VNDK_SAMEPROCESS_LIBRARIES)) \
    $(VNDK_USING_CORE_VARIANT_LIBRARIES) \
    com.android.vndk.current

# Install VNDK apex on vendor partition if VNDK is unfrozen
ifdef UNFROZEN_VNDK
LOCAL_REQUIRED_MODULES += com.android.vndk.current.on_vendor
endif

LOCAL_ADDITIONAL_DEPENDENCIES += $(call module-built-files,\
    $(addsuffix .vendor,$(VNDK_CORE_LIBRARIES) $(VNDK_SAMEPROCESS_LIBRARIES)))

endif
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)

LOCAL_MODULE := vndk_apex_snapshot_package
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_REQUIRED_MODULES := $(foreach vndk_ver,$(PRODUCT_EXTRA_VNDK_VERSIONS),com.android.vndk.v$(vndk_ver))
include $(BUILD_PHONY_PACKAGE)

#####################################################################
# Define Phony module to install LLNDK modules which are installed in
# the system image
include $(CLEAR_VARS)
LOCAL_MODULE := llndk_in_system
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE

# Filter LLNDK libs moved to APEX to avoid pulling them into /system/LIB
LOCAL_REQUIRED_MODULES := \
    $(filter-out $(LLNDK_MOVED_TO_APEX_LIBRARIES),$(LLNDK_LIBRARIES)) \
    llndk.libraries.txt


include $(BUILD_PHONY_PACKAGE)

#####################################################################
# init.gsi.rc, GSI-specific init script.

include $(CLEAR_VARS)
LOCAL_MODULE := init.gsi.rc
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_SRC_FILES := $(LOCAL_MODULE)
LOCAL_MODULE_CLASS := ETC
LOCAL_SYSTEM_EXT_MODULE := true
LOCAL_MODULE_RELATIVE_PATH := init

include $(BUILD_PREBUILT)


include $(CLEAR_VARS)
LOCAL_MODULE := init.vndk-nodef.rc
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
LOCAL_LICENSE_CONDITIONS := notice
LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
LOCAL_SRC_FILES := $(LOCAL_MODULE)
LOCAL_MODULE_CLASS := ETC
LOCAL_SYSTEM_EXT_MODULE := true
LOCAL_MODULE_RELATIVE_PATH := gsi

include $(BUILD_PREBUILT)
