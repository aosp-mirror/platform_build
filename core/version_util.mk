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
#     PLATFORM_DISPLAY_VERSION
#     PLATFORM_SDK_VERSION
#     PLATFORM_SDK_EXTENSION_VERSION
#     PLATFORM_VERSION_CODENAME
#     DEFAULT_APP_TARGET_SDK
#     BUILD_ID
#     BUILD_NUMBER
#     PLATFORM_SECURITY_PATCH
#     PLATFORM_VNDK_VERSION
#     PLATFORM_SYSTEMSDK_VERSIONS
#     PLATFORM_VERSION_LAST_STABLE
#     PLATFORM_VERSION_KNOWN_CODENAMES
#

# Look for an optional file containing overrides of the defaults,
# but don't cry if we don't find it.  We could just use -include, but
# the build.prop target also wants INTERNAL_BUILD_ID_MAKEFILE to be set
# if the file exists.
#
INTERNAL_BUILD_ID_MAKEFILE := $(wildcard $(BUILD_SYSTEM)/build_id.mk)
ifdef INTERNAL_BUILD_ID_MAKEFILE
  include $(INTERNAL_BUILD_ID_MAKEFILE)
endif

ifdef TARGET_PLATFORM_VERSION
  $(error Do not set TARGET_PLATFORM_VERSION directly. Use RELEASE_PLATFORM_VERSION. value: $(TARGET_PLATFORM_VERSION))
endif
TARGET_PLATFORM_VERSION := $(RELEASE_PLATFORM_VERSION)
.KATI_READONLY := TARGET_PLATFORM_VERSION

ifdef PLATFORM_SECURITY_PATCH
  $(error Do not set PLATFORM_SECURITY_PATCH directly. Use RELEASE_PLATFORM_SECURITY_PATCH. value: $(PLATFORM_SECURITY_PATCH))
endif
PLATFORM_SECURITY_PATCH := $(RELEASE_PLATFORM_SECURITY_PATCH)
.KATI_READONLY := PLATFORM_SECURITY_PATCH

ifdef PLATFORM_SDK_VERSION
  $(error Do not set PLATFORM_SDK_VERSION directly. Use RELEASE_PLATFORM_SDK_VERSION. value: $(PLATFORM_SDK_VERSION))
endif
PLATFORM_SDK_VERSION := $(RELEASE_PLATFORM_SDK_VERSION)
.KATI_READONLY := PLATFORM_SDK_VERSION

ifdef PLATFORM_SDK_EXTENSION_VERSION
  $(error Do not set PLATFORM_SDK_EXTENSION_VERSION directly. Use RELEASE_PLATFORM_SDK_EXTENSION_VERSION. value: $(PLATFORM_SDK_EXTENSION_VERSION))
endif
PLATFORM_SDK_EXTENSION_VERSION := $(RELEASE_PLATFORM_SDK_EXTENSION_VERSION)
.KATI_READONLY := PLATFORM_SDK_EXTENSION_VERSION

# This is the sdk extension version that PLATFORM_SDK_VERSION ships with.
PLATFORM_BASE_SDK_EXTENSION_VERSION := $(PLATFORM_SDK_EXTENSION_VERSION)
.KATI_READONLY := PLATFORM_BASE_SDK_EXTENSION_VERSION

ifdef PLATFORM_VERSION_CODENAME
  $(error Do not set PLATFORM_VERSION_CODENAME directly. Use RELEASE_PLATFORM_VERSION. value: $(PLATFORM_VERSION_CODENAME))
endif
PLATFORM_VERSION_CODENAME := $(RELEASE_PLATFORM_VERSION_CODENAME)
.KATI_READONLY := PLATFORM_VERSION_CODENAME

ifdef PLATFORM_VERSION_ALL_CODENAMES
  $(error Do not set PLATFORM_VERSION_ALL_CODENAMES directly. Use RELEASE_PLATFORM_VERSION_ALL_CODENAMES. value: $(PLATFORM_VERSION_ALL_CODENAMES))
endif
PLATFORM_VERSION_ALL_CODENAMES := $(RELEASE_PLATFORM_VERSION_ALL_CODENAMES)
.KATI_READONLY := PLATFORM_VERSION_ALL_CODENAMES

ifdef PLATFORM_VERSION_ALL_PREVIEW_CODENAMES
  $(error Do not set PLATFORM_VERSION_ALL_PREVIEW_CODENAMES directly. Use RELEASE_PLATFORM_VERSION_ALL_PREVIEW_CODENAMES. value: $(PLATFORM_VERSION_ALL_PREVIEW_CODENAMES))
endif
PLATFORM_VERSION_ALL_PREVIEW_CODENAMES := $(RELEASE_PLATFORM_VERSION_ALL_PREVIEW_CODENAMES)
.KATI_READONLY := PLATFORM_VERSION_ALL_PREVIEW_CODENAMES

ifdef PLATFORM_VERSION_LAST_STABLE
  $(error Do not set PLATFORM_VERSION_LAST_STABLE directly. Use RELEASE_PLATFORM_VERSION_LAST_STABLE. value: $(PLATFORM_VERSION_CODENAME))
endif
PLATFORM_VERSION_LAST_STABLE := $(RELEASE_PLATFORM_VERSION_LAST_STABLE)
.KATI_READONLY := PLATFORM_VERSION_LAST_STABLE

ifdef PLATFORM_VERSION_KNOWN_CODENAMES
  $(error Do not set PLATFORM_VERSION_KNOWN_CODENAMES directly. Use RELEASE_PLATFORM_VERSION_KNOWN_CODENAMES. value: $(PLATFORM_VERSION_KNOWN_CODENAMES))
endif
PLATFORM_VERSION_KNOWN_CODENAMES := $(RELEASE_PLATFORM_VERSION_KNOWN_CODENAMES)
.KATI_READONLY := PLATFORM_VERSION_KNOWN_CODENAMES

ifndef PLATFORM_VERSION
  ifeq (REL,$(PLATFORM_VERSION_CODENAME))
      PLATFORM_VERSION := $(PLATFORM_VERSION_LAST_STABLE)
  else
      PLATFORM_VERSION := $(PLATFORM_VERSION_CODENAME)
  endif
endif
.KATI_READONLY := PLATFORM_VERSION

ifndef PLATFORM_DISPLAY_VERSION
  PLATFORM_DISPLAY_VERSION := $(PLATFORM_VERSION)
endif
.KATI_READONLY := PLATFORM_DISPLAY_VERSION

ifeq (REL,$(PLATFORM_VERSION_CODENAME))
  PLATFORM_PREVIEW_SDK_VERSION := 0
else
  ifndef PLATFORM_PREVIEW_SDK_VERSION
    # This is the definition of a preview SDK version over and above the current
    # platform SDK version. Unlike the platform SDK version, a higher value
    # for preview SDK version does NOT mean that all prior preview APIs are
    # included. Packages reading this value to determine compatibility with
    # known APIs should check that this value is precisely equal to the preview
    # SDK version the package was built for, otherwise it should fall back to
    # assuming the device can only support APIs as of the previous official
    # public release.
    # This value will always be forced to 0 for release builds by the logic
    # in the "ifeq" block above, so the value below will be used on any
    # non-release builds, and it should always be at least 1, to indicate that
    # APIs may have changed since the claimed PLATFORM_SDK_VERSION.
    PLATFORM_PREVIEW_SDK_VERSION := 1
  endif
endif
.KATI_READONLY := PLATFORM_PREVIEW_SDK_VERSION

ifndef DEFAULT_APP_TARGET_SDK
  # This is the default minSdkVersion and targetSdkVersion to use for
  # all .apks created by the build system.  It can be overridden by explicitly
  # setting these in the .apk's AndroidManifest.xml.  It is either the code
  # name of the development build or, if this is a release build, the official
  # SDK version of this release.
  ifeq (REL,$(PLATFORM_VERSION_CODENAME))
    DEFAULT_APP_TARGET_SDK := $(PLATFORM_SDK_VERSION)
  else
    DEFAULT_APP_TARGET_SDK := $(PLATFORM_VERSION_CODENAME)
  endif
endif
.KATI_READONLY := DEFAULT_APP_TARGET_SDK

ifeq ($(KEEP_VNDK),true)
  ifndef PLATFORM_VNDK_VERSION
    # This is the definition of the VNDK version for the current VNDK libraries.
    # With trunk stable, VNDK will not be frozen but deprecated.
    # This version will be removed with the VNDK deprecation.
    ifeq (REL,$(PLATFORM_VERSION_CODENAME))
      ifdef RELEASE_PLATFORM_VNDK_VERSION
        PLATFORM_VNDK_VERSION := $(RELEASE_PLATFORM_VNDK_VERSION)
      else
        PLATFORM_VNDK_VERSION := $(PLATFORM_SDK_VERSION)
      endif
    else
      PLATFORM_VNDK_VERSION := $(PLATFORM_VERSION_CODENAME)
    endif
  endif
  .KATI_READONLY := PLATFORM_VNDK_VERSION
endif

ifndef PLATFORM_SYSTEMSDK_MIN_VERSION
  # This is the oldest version of system SDK that the platform supports. Contrary
  # to the public SDK where platform essentially supports all previous SDK versions,
  # platform supports only a few number of recent system SDK versions as some of
  # old system APIs are gradually deprecated, removed and then deleted.
  PLATFORM_SYSTEMSDK_MIN_VERSION := 29
endif
.KATI_READONLY := PLATFORM_SYSTEMSDK_MIN_VERSION

# This is the list of system SDK versions that the current platform supports.
PLATFORM_SYSTEMSDK_VERSIONS :=
ifneq (,$(PLATFORM_SYSTEMSDK_MIN_VERSION))
  $(if $(call math_is_number,$(PLATFORM_SYSTEMSDK_MIN_VERSION)),,\
    $(error PLATFORM_SYSTEMSDK_MIN_VERSION must be a number, but was $(PLATFORM_SYSTEMSDK_MIN_VERSION)))
  PLATFORM_SYSTEMSDK_VERSIONS := $(call int_range_list,$(PLATFORM_SYSTEMSDK_MIN_VERSION),$(PLATFORM_SDK_VERSION))
endif
# Platform always supports the current version
ifeq (REL,$(PLATFORM_VERSION_CODENAME))
  PLATFORM_SYSTEMSDK_VERSIONS += $(PLATFORM_SDK_VERSION)
else
  PLATFORM_SYSTEMSDK_VERSIONS += $(subst $(comma),$(space),$(PLATFORM_VERSION_ALL_CODENAMES))
endif
PLATFORM_SYSTEMSDK_VERSIONS := $(strip $(sort $(PLATFORM_SYSTEMSDK_VERSIONS)))
.KATI_READONLY := PLATFORM_SYSTEMSDK_VERSIONS

.KATI_READONLY := PLATFORM_SECURITY_PATCH

ifndef PLATFORM_SECURITY_PATCH_TIMESTAMP
  # Used to indicate the matching timestamp for the security patch string in PLATFORM_SECURITY_PATCH.
  PLATFORM_SECURITY_PATCH_TIMESTAMP := $(shell date -d 'TZ="GMT" $(PLATFORM_SECURITY_PATCH)' +%s)
endif
.KATI_READONLY := PLATFORM_SECURITY_PATCH_TIMESTAMP

ifndef PLATFORM_BASE_OS
  # Used to indicate the base os applied to the device.
  # Can be an arbitrary string, but must be a single word.
  #
  # If there is no $PLATFORM_BASE_OS set, keep it empty.
  PLATFORM_BASE_OS :=
endif
.KATI_READONLY := PLATFORM_BASE_OS

ifndef BUILD_ID
  # Used to signify special builds.  E.g., branches and/or releases,
  # like "M5-RC7".  Can be an arbitrary string, but must be a single
  # word and a valid file name.
  #
  # If there is no BUILD_ID set, make it obvious.
  BUILD_ID := UNKNOWN
endif
.KATI_READONLY := BUILD_ID

ifndef BUILD_DATETIME
  # Used to reproduce builds by setting the same time. Must be the number
  # of seconds since the Epoch.
  BUILD_DATETIME := $(shell date +%s)
endif

DATE := date -d @$(BUILD_DATETIME)
.KATI_READONLY := DATE

# Everything should be using BUILD_DATETIME_FROM_FILE instead.
# BUILD_DATETIME and DATE can be removed once BUILD_NUMBER moves
# to soong_ui.
$(KATI_obsolete_var BUILD_DATETIME,Use BUILD_DATETIME_FROM_FILE)

ifndef HAS_BUILD_NUMBER
  HAS_BUILD_NUMBER := false
endif
.KATI_READONLY := HAS_BUILD_NUMBER

ifndef PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION
  # Used to set minimum supported target sdk version. Apps targeting sdk
  # version lower than the set value will result in a warning being shown
  # when any activity from the app is started.
  PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION := 28
endif
.KATI_READONLY := PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION
