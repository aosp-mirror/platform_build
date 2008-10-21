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
    bluez-libs:external/bluez/libs/include \
    bluez-utils:external/bluez/utils \
    bootloader:bootloader/legacy/include \
    corecg:external/skia/include/corecg \
    dbus:external/dbus \
    frameworks-base:frameworks/base/include \
    graphics:external/skia/include/graphics \
    libc:bionic/libc/include \
    libdrm1:frameworks/base/media/libdrm/mobile1/include \
    libdrm2:frameworks/base/media/libdrm/mobile2/include \
    libhardware:hardware/libhardware/include \
    libhost:build/libs/host/include \
    libm:bionic/libm/include \
    libnativehelper:dalvik/libnativehelper/include \
    libpagemap:system/extras/libpagemap/include \
    libril:hardware/ril/include \
    libstdc++:bionic/libstdc++/include \
    libthread_db:bionic/libthread_db/include \
    mkbootimg:system/core/mkbootimg \
    recovery:recovery \
    system-core:system/core/include

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

FRAMEWORKS_BASE_SUBDIRS := \
	core \
	graphics \
	location \
	media \
	opengl \
	sax \
	services \
	telephony \
	wifi

FRAMEWORKS_BASE_JAVA_SRC_DIRS := \
	$(patsubst %,frameworks/base/%/java,$(FRAMEWORKS_BASE_SUBDIRS))
