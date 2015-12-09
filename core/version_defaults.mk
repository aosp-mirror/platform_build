#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Handle various build version information.
#
# Guarantees that the following are defined:
#     PLATFORM_VERSION
#     PLATFORM_SDK_VERSION
#     PLATFORM_VERSION_CODENAME
#     DEFAULT_APP_TARGET_SDK
#     BUILD_ID
#     BUILD_NUMBER
#     SECURITY_PATCH
#

# Look for an optional file containing overrides of the defaults,
# but don't cry if we don't find it.  We could just use -include, but
# the build.prop target also wants INTERNAL_BUILD_ID_MAKEFILE to be set
# if the file exists.
#
INTERNAL_BUILD_ID_MAKEFILE := $(wildcard $(BUILD_SYSTEM)/build_id.mk)
ifneq "" "$(INTERNAL_BUILD_ID_MAKEFILE)"
  include $(INTERNAL_BUILD_ID_MAKEFILE)
endif

ifeq "" "$(PLATFORM_VERSION)"
  # This is the canonical definition of the platform version,
  # which is the version that we reveal to the end user.
  # Update this value when the platform version changes (rather
  # than overriding it somewhere else).  Can be an arbitrary string.
  PLATFORM_VERSION := 6.0.1
endif

ifeq "" "$(PLATFORM_SDK_VERSION)"
  # This is the canonical definition of the SDK version, which defines
  # the set of APIs and functionality available in the platform.  It
  # is a single integer that increases monotonically as updates to
  # the SDK are released.  It should only be incremented when the APIs for
  # the new release are frozen (so that developers don't write apps against
  # intermediate builds).  During development, this number remains at the
  # SDK version the branch is based on and PLATFORM_VERSION_CODENAME holds
  # the code-name of the new development work.
  PLATFORM_SDK_VERSION := 23
endif

ifeq "" "$(PLATFORM_VERSION_CODENAME)"
  # This is the current development code-name, if the build is not a final
  # release build.  If this is a final release build, it is simply "REL".
  PLATFORM_VERSION_CODENAME := REL

  # This is all of the development codenames that are active.  Should be either
  # the same as PLATFORM_VERSION_CODENAME or a comma-separated list of additional
  # codenames after PLATFORM_VERSION_CODENAME.
  PLATFORM_VERSION_ALL_CODENAMES := $(PLATFORM_VERSION_CODENAME)
endif

ifeq "REL" "$(PLATFORM_VERSION_CODENAME)"
  PLATFORM_PREVIEW_SDK_VERSION := 0
else
  ifeq "" "$(PLATFORM_PREVIEW_SDK_VERSION)"
    # This is the definition of a preview SDK version over and above the current
    # platform SDK version. Unlike the platform SDK version, a higher value
    # for preview SDK version does NOT mean that all prior preview APIs are
    # included. Packages reading this value to determine compatibility with
    # known APIs should check that this value is precisely equal to the preview
    # SDK version the package was built for, otherwise it should fall back to
    # assuming the device can only support APIs as of the previous official
    # public release.
    # This value will always be 0 for release builds.
    PLATFORM_PREVIEW_SDK_VERSION := 0
  endif
endif

ifeq "" "$(DEFAULT_APP_TARGET_SDK)"
  # This is the default minSdkVersion and targetSdkVersion to use for
  # all .apks created by the build system.  It can be overridden by explicitly
  # setting these in the .apk's AndroidManifest.xml.  It is either the code
  # name of the development build or, if this is a release build, the official
  # SDK version of this release.
  ifeq "REL" "$(PLATFORM_VERSION_CODENAME)"
    DEFAULT_APP_TARGET_SDK := $(PLATFORM_SDK_VERSION)
  else
    DEFAULT_APP_TARGET_SDK := $(PLATFORM_VERSION_CODENAME)
  endif
endif

ifeq "" "$(PLATFORM_SECURITY_PATCH)"
  # Used to indicate the security patch that has been applied to the device.
  # Can be an arbitrary string, but must be a single word.
  #
  # If there is no $PLATFORM_SECURITY_PATCH set, keep it empty.
  PLATFORM_SECURITY_PATCH := 2016-02-01
endif

ifeq "" "$(PLATFORM_BASE_OS)"
  # Used to indicate the base os applied to the device.
  # Can be an arbitrary string, but must be a single word.
  #
  # If there is no $PLATFORM_BASE_OS set, keep it empty.
  PLATFORM_BASE_OS :=
endif

ifeq "" "$(BUILD_ID)"
  # Used to signify special builds.  E.g., branches and/or releases,
  # like "M5-RC7".  Can be an arbitrary string, but must be a single
  # word and a valid file name.
  #
  # If there is no BUILD_ID set, make it obvious.
  BUILD_ID := UNKNOWN
endif

ifeq "" "$(BUILD_NUMBER)"
  # BUILD_NUMBER should be set to the source control value that
  # represents the current state of the source code.  E.g., a
  # perforce changelist number or a git hash.  Can be an arbitrary string
  # (to allow for source control that uses something other than numbers),
  # but must be a single word and a valid file name.
  #
  # If no BUILD_NUMBER is set, create a useful "I am an engineering build
  # from this date/time" value.  Make it start with a non-digit so that
  # anyone trying to parse it as an integer will probably get "0".
  BUILD_NUMBER := eng.$(USER).$(shell date +%Y%m%d.%H%M%S)
endif
