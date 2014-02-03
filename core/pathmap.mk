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
# them in Android.mk files.
#
# TODO: Allow each project to define stuff like this before the per-module
#       Android.mk files are included, so we don't need to have a big central
#       list.
#

#
# A mapping from shorthand names to include directories.
#
pathmap_INCL := \
    bootloader:bootable/bootloader/legacy/include \
    camera:system/media/camera/include \
    corecg:external/skia/include/core \
    frameworks-base:frameworks/base/include \
    frameworks-native:frameworks/native/include \
    graphics:external/skia/include/core \
    libc:bionic/libc/include \
    libhardware:hardware/libhardware/include \
    libhardware_legacy:hardware/libhardware_legacy/include \
    libhost:build/libs/host/include \
    libm:bionic/libm/include \
    libnativehelper:libnativehelper/include \
    libpagemap:system/extras/libpagemap/include \
    libril:hardware/ril/include \
    libstdc++:bionic/libstdc++/include \
    mkbootimg:system/core/mkbootimg \
    opengl-tests-includes:frameworks/native/opengl/tests/include \
    recovery:bootable/recovery \
    system-core:system/core/include \
    audio-effects:system/media/audio_effects/include \
    audio-utils:system/media/audio_utils/include \
    audio-route:system/media/audio_route/include \
    wilhelm:frameworks/wilhelm/include \
    wilhelm-ut:frameworks/wilhelm/src/ut \
    speex:external/speex/include

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
# Many modules expect to be able to say "#include <jni.h>",
# so make it easy for them to find the correct path.
#
JNI_H_INCLUDE := $(call include-path-for,libnativehelper)/nativehelper

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
	    telephony \
	    wifi \
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

#
# A list of all source roots under frameworks/support.
#
FRAMEWORKS_SUPPORT_SUBDIRS := \
        v4 \
        v7/gridlayout \
        v7/appcompat \
        v7/mediarouter \
        v8/renderscript \
        v13

#
# A version of FRAMEWORKS_SUPPORT_SUBDIRS that is expanded to full paths from
# the root of the tree.
#
FRAMEWORKS_SUPPORT_JAVA_SRC_DIRS := \
	$(addprefix frameworks/support/,$(FRAMEWORKS_SUPPORT_SUBDIRS))

#
# A list of support library modules.
#
FRAMEWORKS_SUPPORT_JAVA_LIBRARIES := \
    $(foreach dir,$(FRAMEWORKS_SUPPORT_SUBDIRS),android-support-$(subst /,-,$(dir)))

