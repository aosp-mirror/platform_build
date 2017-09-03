# This file defines the rule to fuse the platform.zip into the current PDK build.
PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR :=
PDK_PLATFORM_JAVA_ZIP_JAVA_HOST_LIB_DIR := \
	host/common/obj/JAVA_LIBRARIES/bouncycastle-host_intermediates \
	host/common/obj/JAVA_LIBRARIES/compatibility-host-util_intermediates \
	host/common/obj/JAVA_LIBRARIES/cts-tradefed-harness_intermediates \
	host/common/obj/JAVA_LIBRARIES/hosttestlib_intermediates
PDK_PLATFORM_JAVA_ZIP_CONTENTS :=

ifneq (,$(filter platform-java, $(MAKECMDGOALS))$(PDK_FUSION_PLATFORM_ZIP))
# additional items to add to platform.zip for platform-java build
# For these dirs, add classes.jar and javalib.jar from the dir to platform.zip
# all paths under out dir
PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR += \
  target/common/obj/JAVA_LIBRARIES/android.test.runner_intermediates \
  target/common/obj/JAVA_LIBRARIES/android-common_intermediates \
  target/common/obj/JAVA_LIBRARIES/android-ex-camera2_intermediates \
  target/common/obj/JAVA_LIBRARIES/android_stubs_current_intermediates \
  target/common/obj/JAVA_LIBRARIES/bouncycastle_intermediates \
  target/common/obj/JAVA_LIBRARIES/conscrypt_intermediates \
  target/common/obj/JAVA_LIBRARIES/core-oj_intermediates \
  target/common/obj/JAVA_LIBRARIES/core-libart_intermediates \
  target/common/obj/JAVA_LIBRARIES/legacy-test_intermediates \
  target/common/obj/JAVA_LIBRARIES/legacy-android-test_intermediates \
  target/common/obj/JAVA_LIBRARIES/ext_intermediates \
  target/common/obj/JAVA_LIBRARIES/framework_intermediates \
  target/common/obj/JAVA_LIBRARIES/ims-common_intermediates \
  target/common/obj/JAVA_LIBRARIES/okhttp_intermediates \
  target/common/obj/JAVA_LIBRARIES/telephony-common_intermediates \
  target/common/obj/JAVA_LIBRARIES/voip-common_intermediates \

# not java libraries
PDK_PLATFORM_JAVA_ZIP_CONTENTS += \
	target/common/obj/APPS/framework-res_intermediates/package-export.apk \
	target/common/obj/APPS/framework-res_intermediates/src/R.stamp
endif # platform-java or FUSION build

PDK_PLATFORM_JAVA_ZIP_JAVA_LIB_DIR := \
	$(PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR) \
	$(PDK_PLATFORM_JAVA_ZIP_JAVA_HOST_LIB_DIR)

PDK_PLATFORM_JAVA_ZIP_CONTENTS += $(foreach lib_dir,$(PDK_PLATFORM_JAVA_ZIP_JAVA_LIB_DIR),\
    $(lib_dir)/classes.jack $(lib_dir)/classes.jar $(lib_dir)/classes.jar.toc \
    $(lib_dir)/javalib.jar  $(lib_dir)/classes*.dex \
    $(lib_dir)/classes.dex.toc )

# check and override java support level
ifneq ($(TARGET_BUILD_PDK)$(PDK_FUSION_PLATFORM_ZIP),)
ifneq ($(wildcard external/proguard),)
TARGET_BUILD_JAVA_SUPPORT_LEVEL := sdk
else # no proguard
TARGET_BUILD_JAVA_SUPPORT_LEVEL :=
endif
# platform supprot is set after checking platform.zip
endif # PDK

ifdef PDK_FUSION_PLATFORM_ZIP
_pdk_fusion_intermediates := $(call intermediates-dir-for, PACKAGING, pdk_fusion)
_pdk_fusion_stamp := $(_pdk_fusion_intermediates)/pdk_fusion.stamp

_pdk_fusion_file_list := $(shell unzip -Z -1 $(PDK_FUSION_PLATFORM_ZIP) \
    '*[^/]' -x 'target/common/*' 2>/dev/null)
_pdk_fusion_java_file_list := \
	$(shell unzip -Z -1 $(PDK_FUSION_PLATFORM_ZIP) 'target/common/*' 2>/dev/null)
_pdk_fusion_files := $(addprefix $(_pdk_fusion_intermediates)/,\
    $(_pdk_fusion_file_list) $(_pdk_fusion_java_file_list))

ifneq ($(_pdk_fusion_java_file_list),)
# This represents whether java build can use platform API or not
# This should not be used in Android.mk
TARGET_BUILD_PDK_JAVA_PLATFORM := true
ifneq ($(TARGET_BUILD_JAVA_SUPPORT_LEVEL),)
TARGET_BUILD_JAVA_SUPPORT_LEVEL := platform
endif
endif

$(_pdk_fusion_stamp) : $(PDK_FUSION_PLATFORM_ZIP)
	@echo "Unzip $(dir $@) <- $<"
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) unzip -qo $< -d $(dir $@)
	$(call split-long-arguments,-touch,$(_pdk_fusion_files))
	$(hide) touch $@


$(_pdk_fusion_files) : $(_pdk_fusion_stamp)


# Implicit pattern rules to copy the fusion files to the system image directory.
# Note that if there is already explicit rule in the build system to generate a file,
# the pattern rule will be just ignored by make.
# That's desired by us: we want only absent files from the platform zip package.
# Copy with the last-modified time preserved, never follow symbolic links.
$(PRODUCT_OUT)/% : $(_pdk_fusion_intermediates)/% $(_pdk_fusion_stamp)
	@mkdir -p $(dir $@)
	$(hide) rm -rf $@
	$(hide) cp -fpPR $< $@

# implicit rules for host java files
$(HOST_COMMON_OUT_ROOT)/% : $(_pdk_fusion_intermediates)/host/common/% $(_pdk_fusion_stamp)
	@mkdir -p $(dir $@)
	$(hide) cp -fpPR $< $@

ifeq (true,$(TARGET_BUILD_PDK_JAVA_PLATFORM))

PDK_FUSION_OUT_DIR := $(OUT_DIR)
ifeq (debug,$(TARGET_BUILD_TYPE))
PDK_FUSION_OUT_DIR := $(DEBUG_OUT_DIR)
endif

define JAVA_dependency_template
$(call add-dependency,$(PDK_FUSION_OUT_DIR)/$(strip $(1)),\
  $(foreach d,$(filter $(2),$(_pdk_fusion_java_file_list)),$(PDK_FUSION_OUT_DIR)/$(d)))
endef

# needs explicit dependency as package-export.apk is not explicitly pulled
$(eval $(call JAVA_dependency_template,\
target/common/obj/APPS/framework-res_intermediates/src/R.stamp,\
target/common/obj/APPS/framework-res_intermediates/package-export.apk))

# javalib.jar should pull classes.jar as classes.jar is not explicitly pulled.
$(foreach lib_dir,$(PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR),\
$(eval $(call JAVA_dependency_template,$(lib_dir)/javalib.jar,\
$(lib_dir)/classes.jar)))

# pull .jack and .dex files
$(foreach lib_dir,$(PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR),\
  $(eval $(call JAVA_dependency_template,$(lib_dir)/classes.jar.toc,\
    $(lib_dir)/classes.jar $(lib_dir)/classes.jack)))
$(foreach lib_dir,$(PDK_PLATFORM_JAVA_ZIP_JAVA_TARGET_LIB_DIR),\
  $(eval $(call JAVA_dependency_template,$(lib_dir)/classes.dex.toc,\
    $(lib_dir)/classes.jar $(lib_dir)/classes.jack $(lib_dir)/classes%.dex)))

# implicit rules for all other target files
$(TARGET_COMMON_OUT_ROOT)/% : $(_pdk_fusion_intermediates)/target/common/% $(_pdk_fusion_stamp)
	@mkdir -p $(dir $@)
	$(hide) cp -fpPR $< $@
endif

ALL_PDK_FUSION_FILES := $(addprefix $(PRODUCT_OUT)/, $(_pdk_fusion_file_list))

endif # PDK_FUSION_PLATFORM_ZIP

ifeq ($(TARGET_BUILD_PDK),true)
$(info PDK TARGET_BUILD_JAVA_SUPPORT_LEVEL $(TARGET_BUILD_JAVA_SUPPORT_LEVEL))
ifeq ($(TARGET_BUILD_PDK_JAVA_PLATFORM),)

# SDK used for Java build under PDK
PDK_BUILD_SDK_VERSION := $(lastword $(TARGET_AVAILABLE_SDK_VERSIONS))
$(info PDK Build uses SDK $(PDK_BUILD_SDK_VERSION))

else # PDK_JAVA

$(info PDK Build uses the current platform API)

endif # PDK_JAVA

endif # BUILD_PDK

ifneq (,$(filter platform platform-java, $(MAKECMDGOALS))$(filter true,$(TARGET_BUILD_PDK)))
# files under $(PRODUCT_OUT)/symbols to help debugging.
# Source not included to PDK due to dependency issue, so provide symbols instead.

# We may not be building all of them.
# The platform.zip just silently ignores the nonexistent ones.
PDK_SYMBOL_FILES_LIST := \
    system/bin/app_process32 \
    system/bin/app_process64

ifdef PDK_FUSION_PLATFORM_ZIP
# symbols should be explicitly pulled for fusion build
$(foreach f,$(filter $(PDK_SYMBOL_FILES_LIST), $(_pdk_fusion_file_list)),\
  $(eval $(call add-dependency,$(PRODUCT_OUT)/$(f),$(PRODUCT_OUT)/symbols/$(f))))
endif # PLATFORM_ZIP
endif # platform.zip build or PDK
