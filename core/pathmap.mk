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
# A central place to define mappings to paths, to avoid hard-coding
# them in Android.mk files. Not meant for header file include directories,
# despite the fact that it was historically used for that!
#
# If you want this for a library's header files, use LOCAL_EXPORT_C_INCLUDES
# instead. Then users of the library don't have to do anything --- they'll
# have the correct header files added to their include path automatically.
#

#
# TODO: Allow each project to define stuff like this before the per-module
#       Android.mk files are included, so we don't need to have a big central
#       list.
#

#
# A mapping from shorthand names to include directories.
#
pathmap_INCL := \
    camera:system/media/camera/include \
    frameworks-base:frameworks/base/include \
    frameworks-native:frameworks/native/include \
    libhardware:hardware/libhardware/include \
    libhardware_legacy:hardware/libhardware_legacy/include \
    libril:hardware/ril/include \
    recovery:bootable/recovery \
    system-core:system/core/include \
    audio:system/media/audio/include \
    audio-effects:system/media/audio_effects/include \
    audio-utils:system/media/audio_utils/include \
    audio-route:system/media/audio_route/include \
    wilhelm:frameworks/wilhelm/include \
    wilhelm-ut:frameworks/wilhelm/src/ut \
    mediandk:frameworks/av/media/ndk/

#
# Returns the path to the requested module's include directory,
# relative to the root of the source tree.  Does not handle external
# modules.
#
# $(1): a list of modules (or other named entities) to find the includes for
#
define include-path-for
$(foreach n,$(1),$(patsubst $(n):%,%,$(filter $(n):%,$(pathmap_INCL))))
endef

#
# A list of all source roots under frameworks/base, which will be
# built into the android.jar.
#
FRAMEWORKS_BASE_SUBDIRS := \
	$(addsuffix /java, \
	    core \
	    graphics \
	    location \
	    media \
	    media/mca/effect \
	    media/mca/filterfw \
	    media/mca/filterpacks \
	    drm \
	    opengl \
	    sax \
	    telecomm \
	    telephony \
	    wifi \
	    lowpan \
	    keystore \
	    rs \
	 )

#
# A version of FRAMEWORKS_BASE_SUBDIRS that is expanded to full paths from
# the root of the tree.  This currently needs to be here so that other libraries
# and apps can find the .aidl files in the framework, though we should really
# figure out a better way to do this.
#
FRAMEWORKS_BASE_JAVA_SRC_DIRS := \
	$(addprefix frameworks/base/,$(FRAMEWORKS_BASE_SUBDIRS))
