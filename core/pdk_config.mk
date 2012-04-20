# This file defines the rule to fuse the platform.zip into the current PDK build.

.PHONY: pdk fusion
pdk fusion: $(DEFAULT_GOAL)

# What to build:
# pdk fusion if:
# 1) the platform.zip exists in the default location
# or
# 2) PDK_FUSION_PLATFORM_ZIP is passed in from the environment
# or
# 3) fusion is a command line build goal,
#    PDK_FUSION_PLATFORM_ZIP is needed anyway, then do we need the 'fusion' goal?
# otherwise pdk only if:
# 1) pdk is a command line build goal
# or
# 2) TARGET_BUILD_PDK is passed in from the environment

# TODO: what's the best default location?
_pdk_fusion_default_platform_zip := vendor/pdk/$(TARGET_DEVICE)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)/platform/platform.zip
ifneq (,$(wildcard $(_pdk_fusion_default_platform_zip)))
$(info $(_pdk_fusion_default_platform_zip) found, do a PDK fusion build.)
PDK_FUSION_PLATFORM_ZIP := $(_pdk_fusion_default_platform_zip)
TARGET_BUILD_PDK := true
endif

ifneq (,$(filter pdk fusion, $(MAKECMDGOALS)))
TARGET_BUILD_PDK := true
ifneq (,$(filter fusion, $(MAKECMDGOALS)))
ifndef PDK_FUSION_PLATFORM_ZIP
  $(error Specify PDK_FUSION_PLATFORM_ZIP to do a PDK fusion.)
endif
endif  # fusion
endif  # pdk or fusion

ifdef PDK_FUSION_PLATFORM_ZIP
TARGET_BUILD_PDK := true
ifeq (,$(wildcard $(PDK_FUSION_PLATFORM_ZIP)))
  $(error Cannot find file $(PDK_FUSION_PLATFORM_ZIP).)
endif

_pdk_fusion_intermediates := $(call intermediates-dir-for, PACKAGING, pdk_fusion)
_pdk_fusion_stamp := $(_pdk_fusion_intermediates)/pdk_fusion.stamp

$(_pdk_fusion_stamp) : $(PDK_FUSION_PLATFORM_ZIP)
	@echo "Unzip $(dir $@) <- $<"
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) unzip -qo $< -d $(dir $@)
	$(hide) touch $@

_pdk_fusion_file_list := $(shell unzip -Z -1 $(PDK_FUSION_PLATFORM_ZIP) '*[^/]' 2>/dev/null)
_pdk_fusion_files := $(addprefix $(_pdk_fusion_intermediates)/, $(_pdk_fusion_file_list))
$(_pdk_fusion_files) : $(_pdk_fusion_stamp)

# Implicit pattern rules to copy the fusion files to the system image directory.
# Note that if there is already explicit rule in the build system to generate a file,
# the pattern rule will be just ignored by make.
# That's desired by us: we want only absent files from the platform zip package.
# Copy with the last-modified time preserved, never follow symbolic links.
$(PRODUCT_OUT)/% : $(_pdk_fusion_intermediates)/%
	@mkdir -p $(dir $@)
	$(hide) cp -fpPR $< $@

ALL_PDK_FUSION_FILES := $(addprefix $(PRODUCT_OUT)/, $(_pdk_fusion_file_list))

endif
