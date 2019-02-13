LOCAL_PATH:= $(call my-dir)

#####################################################################
# Create the list of vndk libraries from the source code.
INTERNAL_VNDK_LIB_LIST := $(call intermediates-dir-for,PACKAGING,vndk)/libs.txt
$(INTERNAL_VNDK_LIB_LIST):
	@echo "Generate: $@"
	@mkdir -p $(dir $@)
	$(hide) echo -n > $@
	$(hide) $(foreach lib, $(filter-out libclang_rt.%,$(LLNDK_LIBRARIES)), \
	  echo LLNDK: $(lib).so >> $@;)
	$(hide) $(foreach lib, $(VNDK_SAMEPROCESS_LIBRARIES), \
	  echo VNDK-SP: $(lib).so >> $@;)
	$(hide) $(foreach lib, $(filter-out libclang_rt.%,$(VNDK_CORE_LIBRARIES)), \
	  echo VNDK-core: $(lib).so >> $@;)
	$(hide) $(foreach lib, $(VNDK_PRIVATE_LIBRARIES), \
	  echo VNDK-private: $(lib).so >> $@;)

#####################################################################
# This is the up-to-date list of vndk libs.
# TODO(b/62012285): the lib list should be stored somewhere under
# /prebuilts/vndk
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
LATEST_VNDK_LIB_LIST := $(LOCAL_PATH)/$(PLATFORM_VNDK_VERSION).txt
ifeq ($(wildcard $(LATEST_VNDK_LIB_LIST)),)
$(error $(LATEST_VNDK_LIB_LIST) file not found. Please copy "$(LOCAL_PATH)/current.txt" to "$(LATEST_VNDK_LIB_LIST)" and commit a CL for release branch)
endif
else
LATEST_VNDK_LIB_LIST := $(LOCAL_PATH)/current.txt
endif

#####################################################################
# Check the generate list against the latest list stored in the
# source tree
.PHONY: check-vndk-list

# Check if vndk list is changed
droidcore: check-vndk-list

check-vndk-list-timestamp := $(call intermediates-dir-for,PACKAGING,vndk)/check-list-timestamp

ifeq ($(TARGET_IS_64_BIT)|$(TARGET_2ND_ARCH),true|)
# TODO(b/110429754) remove this condition when we support 64-bit-only device
check-vndk-list: ;
else ifeq ($(TARGET_BUILD_PDK),true)
# b/118634643: don't check VNDK lib list when building PDK. Some libs (libandroid_net.so
# and some render-script related ones) can't be built in PDK due to missing frameworks/base.
check-vndk-list: ;
else
check-vndk-list: $(check-vndk-list-timestamp)
endif

_vndk_check_failure_message := " error: VNDK library list has been changed.\n"
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
_vndk_check_failure_message += "       Changing the VNDK library list is not allowed in API locked branches."
else
_vndk_check_failure_message += "       Run update-vndk-list.sh to update $(LATEST_VNDK_LIB_LIST)"
endif

$(check-vndk-list-timestamp): $(INTERNAL_VNDK_LIB_LIST) $(LATEST_VNDK_LIB_LIST) $(HOST_OUT_EXECUTABLES)/update-vndk-list.sh
	$(hide) ( diff --old-line-format="Removed %L" \
	  --new-line-format="Added %L" \
	  --unchanged-line-format="" \
	  $(LATEST_VNDK_LIB_LIST) $(INTERNAL_VNDK_LIB_LIST) \
	  || ( echo -e $(_vndk_check_failure_message); exit 1 ))
	$(hide) mkdir -p $(dir $@)
	$(hide) touch $@

#####################################################################
# Script to update the latest VNDK lib list
include $(CLEAR_VARS)
LOCAL_MODULE := update-vndk-list.sh
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
	        echo "cd \$${ANDROID_BUILD_TOP}" >> $@; \
	        echo "cp $(PRIVATE_INTERNAL_VNDK_LIB_LIST) $(PRIVATE_LATEST_VNDK_LIB_LIST)" >> $@; \
	        echo "echo $(PRIVATE_LATEST_VNDK_LIB_LIST) updated." >> $@
endif
	@chmod a+x $@

ifneq ($(BOARD_VNDK_VERSION),)

include $(CLEAR_VARS)
LOCAL_MODULE := vndk_package
LOCAL_REQUIRED_MODULES := \
    $(LLNDK_LIBRARIES) \
    llndk.libraries.txt \
    vndksp.libraries.txt
ifneq ($(TARGET_SKIP_CURRENT_VNDK),true)
LOCAL_REQUIRED_MODULES += \
    $(addsuffix .vendor,$(VNDK_CORE_LIBRARIES)) \
    $(addsuffix .vendor,$(VNDK_SAMEPROCESS_LIBRARIES))
endif
include $(BUILD_PHONY_PACKAGE)

include $(CLEAR_VARS)
LOCAL_MODULE := vndk_snapshot_package
_binder32 :=
ifneq ($(TARGET_USES_64_BIT_BINDER),true)
ifneq ($(TARGET_IS_64_BIT),true)
_binder32 := _binder32
endif
endif
LOCAL_REQUIRED_MODULES := \
    $(foreach vndk_ver,$(PRODUCT_EXTRA_VNDK_VERSIONS),vndk_v$(vndk_ver)_$(TARGET_ARCH)$(_binder32))
_binder32 :=
include $(BUILD_PHONY_PACKAGE)

endif # BOARD_VNDK_VERSION is set
