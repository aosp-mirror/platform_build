# Detect Mac OS X and SDK versions.
# Output variables:
#   build_mac_version
#   mac_sdk_version
#   mac_sdk_root
#   gcc_darwin_version

ifndef build_mac_version

build_mac_version := $(shell sw_vers -productVersion)

mac_sdk_versions_supported :=  10.6 10.7 10.8 10.9
ifneq ($(strip $(MAC_SDK_VERSION)),)
mac_sdk_version := $(MAC_SDK_VERSION)
ifeq ($(filter $(mac_sdk_version),$(mac_sdk_versions_supported)),)
$(warning ****************************************************************)
$(warning * MAC_SDK_VERSION $(MAC_SDK_VERSION) isn't one of the supported $(mac_sdk_versions_supported))
$(warning ****************************************************************)
$(error Stop.)
endif
else
mac_sdk_versions_installed := $(shell xcodebuild -showsdks | grep macosx | sort | sed -e "s/.*macosx//g")
mac_sdk_version := $(firstword $(filter $(mac_sdk_versions_installed), $(mac_sdk_versions_supported)))
ifeq ($(mac_sdk_version),)
mac_sdk_version := $(firstword $(mac_sdk_versions_supported))
endif
endif

mac_sdk_path := $(shell xcode-select -print-path)
# try /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.?.sdk
#  or /Volume/Xcode/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.?.sdk
mac_sdk_root := $(mac_sdk_path)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$(mac_sdk_version).sdk
ifeq ($(wildcard $(mac_sdk_root)),)
# try legacy /Developer/SDKs/MacOSX10.?.sdk
mac_sdk_root := /Developer/SDKs/MacOSX$(mac_sdk_version).sdk
endif
ifeq ($(wildcard $(mac_sdk_root)),)
$(warning *****************************************************)
$(warning * Can not find SDK $(mac_sdk_version) at $(mac_sdk_root))
$(warning *****************************************************)
$(error Stop.)
endif

ifeq ($(mac_sdk_version),10.6)
  gcc_darwin_version := 10
else
  gcc_darwin_version := 11
endif

endif  # ifndef build_mac_version
