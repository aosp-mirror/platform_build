LOCAL_PATH:= $(call my-dir)

#####################################################################
# Check the generate list against the latest list stored in the
# source tree
.PHONY: check-abi-dump-list

# Check if vndk list is changed
droidcore: check-abi-dump-list

check-abi-dump-list-timestamp := $(call intermediates-dir-for,PACKAGING,vndk)/check-abi-dump-list-timestamp

# The ABI tool does not support sanitizer and coverage builds.
ifeq (,$(filter true,$(SKIP_ABI_CHECKS) $(CLANG_COVERAGE)))
ifeq (,$(SANITIZE_TARGET))
check-abi-dump-list: $(check-abi-dump-list-timestamp)
endif
endif

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
.PHONY: findlsdumps_APEX
findlsdumps_APEX: $(LSDUMP_PATHS_FILE) $(call filter-abi-dump-paths,APEX,$(LSDUMP_PATHS))

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
# APEX/LLNDK/PLATFORM libraries.

# $(1): The directory containing ABI dumps.
# Return a list of ABI dump paths ending with .so.lsdump.
define find-abi-dump-paths
$(if $(wildcard $(1)), \
  $(addprefix $(1)/, \
    $(call find-files-in-subdirs,$(1),"*.so.lsdump" -and -type f,.)))
endef

# $(1): A list of tags.
# $(2): A list of tag:path.
# Return the file names of the ABI dumps that match the tags, and replace the
# file name extensions with .so.lsdump.
define filter-abi-dump-names
$(patsubst %.so.llndk.lsdump,%.so.lsdump, \
  $(patsubst %.so.apex.lsdump,%.so.lsdump, \
    $(notdir $(call filter-abi-dump-paths,$(1),$(2)))))
endef

VNDK_ABI_DUMP_DIR := prebuilts/abi-dumps/vndk/$(RELEASE_BOARD_API_LEVEL)
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
    PLATFORM_ABI_DUMP_DIR := prebuilts/abi-dumps/platform/$(PLATFORM_SDK_VERSION)
else
    PLATFORM_ABI_DUMP_DIR := prebuilts/abi-dumps/platform/current
endif
VNDK_ABI_DUMPS := $(call find-abi-dump-paths,$(VNDK_ABI_DUMP_DIR))
PLATFORM_ABI_DUMPS := $(call find-abi-dump-paths,$(PLATFORM_ABI_DUMP_DIR))

# Check for superfluous lsdump files. Since LSDUMP_PATHS only covers the
# libraries that can be built from source in the current build, and prebuilts of
# Mainline modules may be in use, we also allow the libs in STUB_LIBRARIES for
# platform ABIs.
# In addition, libRS is allowed because it's disabled for RISC-V.

$(check-abi-dump-list-timestamp): PRIVATE_LSDUMP_PATHS := $(LSDUMP_PATHS)
$(check-abi-dump-list-timestamp): PRIVATE_STUB_LIBRARIES := $(STUB_LIBRARIES)
$(check-abi-dump-list-timestamp):
	$(eval added_vndk_abi_dumps := $(strip $(sort $(filter-out \
	  $(call filter-abi-dump-names,LLNDK,$(PRIVATE_LSDUMP_PATHS)) libRS.so.lsdump, \
	  $(notdir $(VNDK_ABI_DUMPS))))))
	$(if $(added_vndk_abi_dumps), \
	  echo -e "Found unexpected ABI reference dump files under $(VNDK_ABI_DUMP_DIR). It is caused by mismatch between Android.bp and the dump files. Run \`find \$${ANDROID_BUILD_TOP}/$(VNDK_ABI_DUMP_DIR) '(' -name $(subst $(space), -or -name ,$(added_vndk_abi_dumps)) ')' -delete\` to delete the dump files.")

	# TODO(b/314010764): Remove LLNDK tag after PLATFORM_SDK_VERSION is upgraded to 35.
	$(eval added_platform_abi_dumps := $(strip $(sort $(filter-out \
	  $(call filter-abi-dump-names,APEX LLNDK PLATFORM,$(PRIVATE_LSDUMP_PATHS)) \
	  $(addsuffix .lsdump,$(PRIVATE_STUB_LIBRARIES)) libRS.so.lsdump, \
	  $(notdir $(PLATFORM_ABI_DUMPS))))))
	$(if $(added_platform_abi_dumps), \
	  echo -e "Found unexpected ABI reference dump files under $(PLATFORM_ABI_DUMP_DIR). It is caused by mismatch between Android.bp and the dump files. Run \`find \$${ANDROID_BUILD_TOP}/$(PLATFORM_ABI_DUMP_DIR) '(' -name $(subst $(space), -or -name ,$(added_platform_abi_dumps)) ')' -delete\` to delete the dump files.")

	$(if $(added_vndk_abi_dumps)$(added_platform_abi_dumps),exit 1)
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

#####################################################################
# VNDK package and snapshot.

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
