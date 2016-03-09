# Detect Mac OS X and SDK versions.
# Output variables:
#   build_mac_version
#   mac_sdk_version
#   mac_sdk_root
#   gcc_darwin_version

# You can no longer install older SDKs in newer xcode versions, so it appears
# to be expected to use the newer SDKs, but set command line flags in order to
# target older Mac OS X versions.
#
# We'll use the oldest SDK we can find, and then use the -mmacosx-version-min
# and MACOSX_DEPLOYMENT_TARGET flags to set our minimum version.

ifndef build_mac_version

build_mac_version := $(shell sw_vers -productVersion)

mac_sdk_versions_supported :=  10.8 10.9 10.10 10.11
ifneq ($(strip $(MAC_SDK_VERSION)),)
mac_sdk_version := $(MAC_SDK_VERSION)
ifeq ($(filter $(mac_sdk_version),$(mac_sdk_versions_supported)),)
$(warning ****************************************************************)
$(warning * MAC_SDK_VERSION $(MAC_SDK_VERSION) isn't one of the supported $(mac_sdk_versions_supported))
$(warning ****************************************************************)
$(error Stop.)
endif
else
mac_sdk_versions_installed := $(shell xcodebuild -showsdks | grep macosx | sed -e "s/.*macosx//g")
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
$(warning *****************************************************)
$(warning * Can not find SDK $(mac_sdk_version) at $(mac_sdk_root))
$(warning *****************************************************)
$(error Stop.)
endif

# Set to the minimum version of OS X that we want to run on.
mac_sdk_version := $(firstword $(mac_sdk_versions_supported))

endif  # ifndef build_mac_version
