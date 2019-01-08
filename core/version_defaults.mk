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
#     BUILD_DATETIME
#     PLATFORM_SECURITY_PATCH
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

DEFAULT_PLATFORM_VERSION := OPM1
MIN_PLATFORM_VERSION := OPM1
MAX_PLATFORM_VERSION := OPM1

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

# Default versions for each TARGET_PLATFORM_VERSION
# TODO: PLATFORM_VERSION, PLATFORM_SDK_VERSION, etc. should be conditional
# on this

# This is the canonical definition of the platform version,
# which is the version that we reveal to the end user.
# Update this value when the platform version changes (rather
# than overriding it somewhere else).  Can be an arbitrary string.

# When you add a new PLATFORM_VERSION which will result in a new
# PLATFORM_SDK_VERSION please ensure you add a corresponding isAtLeast*
# method in the following java file:
# frameworks/support/compat/gingerbread/android/support/v4/os/BuildCompat.java

# When you change PLATFORM_VERSION for a given PLATFORM_SDK_VERSION
# please add that PLATFORM_VERSION as well as clean up obsolete PLATFORM_VERSION's
# in the following text file:
# cts/tests/tests/os/assets/platform_versions.txt
PLATFORM_VERSION.OPM1 := 8.1.0

# These are the current development codenames, if the build is not a final
# release build.  If this is a final release build, it is simply "REL".
PLATFORM_VERSION_CODENAME.OPM1 := REL

ifndef PLATFORM_VERSION
  PLATFORM_VERSION := $(PLATFORM_VERSION.$(TARGET_PLATFORM_VERSION))
  ifndef PLATFORM_VERSION
    # PLATFORM_VERSION falls back to TARGET_PLATFORM_VERSION
    PLATFORM_VERSION := $(TARGET_PLATFORM_VERSION)
  endif
endif

ifndef PLATFORM_SDK_VERSION
  # This is the canonical definition of the SDK version, which defines
  # the set of APIs and functionality available in the platform.  It
  # is a single integer that increases monotonically as updates to
  # the SDK are released.  It should only be incremented when the APIs for
  # the new release are frozen (so that developers don't write apps against
  # intermediate builds).  During development, this number remains at the
  # SDK version the branch is based on and PLATFORM_VERSION_CODENAME holds
  # the code-name of the new development work.

  # When you change PLATFORM_SDK_VERSION please ensure you also update the
  # corresponding methods for isAtLeast* in the following java file:
  # frameworks/support/compat/gingerbread/android/support/v4/os/BuildCompat.java

  # When you increment the PLATFORM_SDK_VERSION please ensure you also
  # clear out the following text file of all older PLATFORM_VERSION's:
  # cts/tests/tests/os/assets/platform_versions.txt
  PLATFORM_SDK_VERSION := 27
endif

ifndef PLATFORM_JACK_MIN_SDK_VERSION
  # This is definition of the min SDK version given to Jack for the current
  # platform. For released version it should be the same as
  # PLATFORM_SDK_VERSION. During development, this number may be incremented
  # before PLATFORM_SDK_VERSION if the platform starts to add new java
  # language supports.
  PLATFORM_JACK_MIN_SDK_VERSION := o-b1
endif

ifndef PLATFORM_VERSION_CODENAME
  PLATFORM_VERSION_CODENAME := $(PLATFORM_VERSION_CODENAME.$(TARGET_PLATFORM_VERSION))
  ifndef PLATFORM_VERSION_CODENAME
    # PLATFORM_VERSION_CODENAME falls back to TARGET_PLATFORM_VERSION
    PLATFORM_VERSION_CODENAME := $(TARGET_PLATFORM_VERSION)
  endif

  # This is all of the development codenames that are active.  Should be either
  # the same as PLATFORM_VERSION_CODENAME or a comma-separated list of additional
  # codenames after PLATFORM_VERSION_CODENAME.
  PLATFORM_VERSION_ALL_CODENAMES :=

  # Build a list of all possible code names. Avoid duplicates, and stop when we
  # reach a codename that matches PLATFORM_VERSION_CODENAME (anything beyond
  # that is not included in our build.
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
    # This value will always be 0 for release builds.
    PLATFORM_PREVIEW_SDK_VERSION := 0
  endif
endif

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

ifndef PLATFORM_SECURITY_PATCH
    #  Used to indicate the security patch that has been applied to the device.
    #  It must signify that the build includes all security patches issued up through the designated Android Public Security Bulletin.
    #  It must be of the form "YYYY-MM-DD" on production devices.
    #  It must match one of the Android Security Patch Level strings of the Public Security Bulletins.
    #  If there is no $PLATFORM_SECURITY_PATCH set, keep it empty.
      PLATFORM_SECURITY_PATCH := 2019-03-05
endif

ifndef PLATFORM_BASE_OS
  # Used to indicate the base os applied to the device.
  # Can be an arbitrary string, but must be a single word.
  #
  # If there is no $PLATFORM_BASE_OS set, keep it empty.
  PLATFORM_BASE_OS :=
endif

ifndef BUILD_ID
  # Used to signify special builds.  E.g., branches and/or releases,
  # like "M5-RC7".  Can be an arbitrary string, but must be a single
  # word and a valid file name.
  #
  # If there is no BUILD_ID set, make it obvious.
  BUILD_ID := UNKNOWN
endif

ifndef BUILD_DATETIME
  # Used to reproduce builds by setting the same time. Must be the number
  # of seconds since the Epoch.
  BUILD_DATETIME := $(shell date +%s)
endif

ifneq (,$(findstring Darwin,$(shell uname -sm)))
DATE := date -r $(BUILD_DATETIME)
else
DATE := date -d @$(BUILD_DATETIME)
endif

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
  BUILD_NUMBER := eng.$(shell echo $${USER:0:6}).$(shell $(DATE) +%Y%m%d.%H%M%S)
endif
