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
#     PLATFORM_SECURITY_PATCH
#     PLATFORM_VNDK_VERSION
#     PLATFORM_SYSTEMSDK_VERSIONS
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

DEFAULT_PLATFORM_VERSION := SP2A
MIN_PLATFORM_VERSION := SP2A
MAX_PLATFORM_VERSION := SP2A

ALLOWED_VERSIONS := $(call allowed-platform-versions,\
  $(MIN_PLATFORM_VERSION),\
  $(MAX_PLATFORM_VERSION),\
  $(DEFAULT_PLATFORM_VERSION))

ifndef TARGET_PLATFORM_VERSION
  TARGET_PLATFORM_VERSION := $(DEFAULT_PLATFORM_VERSION)
endif

ifeq (,$(filter $(ALLOWED_VERSIONS), $(TARGET_PLATFORM_VERSION)))
  $(warning Invalid TARGET_PLATFORM_VERSION '$(TARGET_PLATFORM_VERSION)', must be one of)
  $(error $(ALLOWED_VERSIONS))
endif
ALLOWED_VERSIONS :=
MIN_PLATFORM_VERSION :=
MAX_PLATFORM_VERSION :=

.KATI_READONLY := \
  DEFAULT_PLATFORM_VERSION \
  TARGET_PLATFORM_VERSION

# Default versions for each TARGET_PLATFORM_VERSION
# TODO: PLATFORM_VERSION, PLATFORM_SDK_VERSION, etc. should be conditional
# on this

# This is the canonical definition of the platform version,
# which is the version that we reveal to the end user.
# Update this value when the platform version changes (rather
# than overriding it somewhere else).  Can be an arbitrary string.

# When you change PLATFORM_VERSION for a given PLATFORM_SDK_VERSION
# please add that PLATFORM_VERSION as well as clean up obsolete PLATFORM_VERSION's
# in the following text file:
# cts/tests/tests/os/assets/platform_versions.txt

# Note that there should be one PLATFORM_VERSION and PLATFORM_VERSION_CODENAME
# entry for each unreleased API level, regardless of
# MIN_PLATFORM_VERSION/MAX_PLATFORM_VERSION. PLATFORM_VERSION is used to
# generate the range of allowed SDK versions, so it must have an entry for every
# unreleased API level targetable by this branch, not just those that are valid
# lunch targets for this branch.

# The last stable version name of the platform that was released.  During
# development, this stays at that previous version, while the codename indicates
# further work based on the previous version.
PLATFORM_VERSION_LAST_STABLE := 12
.KATI_READONLY := PLATFORM_VERSION_LAST_STABLE

# These are the current development codenames, if the build is not a final
# release build.  If this is a final release build, it is simply "REL".
PLATFORM_VERSION_CODENAME.SP2A := REL

ifndef PLATFORM_VERSION_CODENAME
  PLATFORM_VERSION_CODENAME := $(PLATFORM_VERSION_CODENAME.$(TARGET_PLATFORM_VERSION))
  ifndef PLATFORM_VERSION_CODENAME
    # PLATFORM_VERSION_CODENAME falls back to TARGET_PLATFORM_VERSION
    PLATFORM_VERSION_CODENAME := $(TARGET_PLATFORM_VERSION)
  endif

  # This is all of the *active* development codenames.
  # This confusing name is needed because
  # all_codenames has been baked into build.prop for ages.
  #
  # Should be either the same as PLATFORM_VERSION_CODENAME or a comma-separated
  # list of additional codenames after PLATFORM_VERSION_CODENAME.
  PLATFORM_VERSION_ALL_CODENAMES :=

  # Build a list of all active code names. Avoid duplicates, and stop when we
  # reach a codename that matches PLATFORM_VERSION_CODENAME (anything beyond
  # that is not included in our build).
  _versions_in_target := \
    $(call find_and_earlier,$(ALL_VERSIONS),$(TARGET_PLATFORM_VERSION))
  $(foreach version,$(_versions_in_target),\
    $(eval _codename := $(PLATFORM_VERSION_CODENAME.$(version)))\
    $(if $(filter $(_codename),$(PLATFORM_VERSION_ALL_CODENAMES)),,\
      $(eval PLATFORM_VERSION_ALL_CODENAMES += $(_codename))))

  # And convert from space separated to comma separated.
  PLATFORM_VERSION_ALL_CODENAMES := \
    $(subst $(space),$(comma),$(strip $(PLATFORM_VERSION_ALL_CODENAMES)))

endif
.KATI_READONLY := \
  PLATFORM_VERSION_CODENAME \
  PLATFORM_VERSION_ALL_CODENAMES

ifndef PLATFORM_VERSION
  ifeq (REL,$(PLATFORM_VERSION_CODENAME))
      PLATFORM_VERSION := $(PLATFORM_VERSION_LAST_STABLE)
  else
      PLATFORM_VERSION := $(PLATFORM_VERSION_CODENAME)
  endif
endif
.KATI_READONLY := PLATFORM_VERSION

ifndef PLATFORM_SDK_VERSION
  # This is the canonical definition of the SDK version, which defines
  # the set of APIs and functionality available in the platform.  It
  # is a single integer that increases monotonically as updates to
  # the SDK are released.  It should only be incremented when the APIs for
  # the new release are frozen (so that developers don't write apps against
  # intermediate builds).  During development, this number remains at the
  # SDK version the branch is based on and PLATFORM_VERSION_CODENAME holds
  # the code-name of the new development work.

  # When you increment the PLATFORM_SDK_VERSION please ensure you also
  # clear out the following text file of all older PLATFORM_VERSION's:
  # cts/tests/tests/os/assets/platform_versions.txt
  PLATFORM_SDK_VERSION := 32
endif
.KATI_READONLY := PLATFORM_SDK_VERSION

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

ifndef PLATFORM_VNDK_VERSION
  # This is the definition of the VNDK version for the current VNDK libraries.
  # The version is only available when PLATFORM_VERSION_CODENAME == REL.
  # Otherwise, it will be set to a CODENAME version. The ABI is allowed to be
  # changed only before the Android version is released. Once
  # PLATFORM_VNDK_VERSION is set to actual version, the ABI for this version
  # will be frozon and emit build errors if any ABI for the VNDK libs are
  # changed.
  # After that the snapshot of the VNDK with this version will be generated.
  #
  # The VNDK version follows PLATFORM_SDK_VERSION.
  ifeq (REL,$(PLATFORM_VERSION_CODENAME))
    PLATFORM_VNDK_VERSION := $(PLATFORM_SDK_VERSION)
  else
    PLATFORM_VNDK_VERSION := $(PLATFORM_VERSION_CODENAME)
  endif
endif
.KATI_READONLY := PLATFORM_VNDK_VERSION

ifndef PLATFORM_SYSTEMSDK_MIN_VERSION
  # This is the oldest version of system SDK that the platform supports. Contrary
  # to the public SDK where platform essentially supports all previous SDK versions,
  # platform supports only a few number of recent system SDK versions as some of
  # old system APIs are gradually deprecated, removed and then deleted.
  PLATFORM_SYSTEMSDK_MIN_VERSION := 28
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
  PLATFORM_SYSTEMSDK_VERSIONS += $(PLATFORM_VERSION_CODENAME)
endif
PLATFORM_SYSTEMSDK_VERSIONS := $(strip $(sort $(PLATFORM_SYSTEMSDK_VERSIONS)))
.KATI_READONLY := PLATFORM_SYSTEMSDK_VERSIONS

ifndef PLATFORM_SECURITY_PATCH
    #  Used to indicate the security patch that has been applied to the device.
    #  It must signify that the build includes all security patches issued up through the designated Android Public Security Bulletin.
    #  It must be of the form "YYYY-MM-DD" on production devices.
    #  It must match one of the Android Security Patch Level strings of the Public Security Bulletins.
    #  If there is no $PLATFORM_SECURITY_PATCH set, keep it empty.
    PLATFORM_SECURITY_PATCH := 2025-03-05
endif
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

HAS_BUILD_NUMBER := true
ifndef BUILD_NUMBER
  # BUILD_NUMBER should be set to the source control value that
  # represents the current state of the source code.  E.g., a
  # perforce changelist number or a git hash.  Can be an arbitrary string
  # (to allow for source control that uses something other than numbers),
  # but must be a single word and a valid file name.
  #
  # If no BUILD_NUMBER is set, create a useful "I am an engineering build
  # from this date/time" value.  Make it start with a non-digit so that
  # anyone trying to parse it as an integer will probably get "0".
  BUILD_NUMBER := eng.$(shell echo $${BUILD_USERNAME:0:6}).$(shell $(DATE) +%Y%m%d.%H%M%S)
  HAS_BUILD_NUMBER := false
endif
.KATI_READONLY := BUILD_NUMBER HAS_BUILD_NUMBER

ifndef PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION
  # Used to set minimum supported target sdk version. Apps targeting sdk
  # version lower than the set value will result in a warning being shown
  # when any activity from the app is started.
  PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION := 23
endif
.KATI_READONLY := PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION
