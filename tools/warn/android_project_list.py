#
# Copyright (C) 2019 The Android Open Source Project
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

"""Define a project list to sort warnings by project directory path."""


def project_name_and_pattern(name, pattern):
  return [name, '(^|.*/)' + pattern + '/.*: warning:']


def simple_project_pattern(pattern):
  return project_name_and_pattern(pattern, pattern)


# A list of [project_name, file_path_pattern].
# project_name should not contain comma, to be used in CSV output.
project_list = [
    simple_project_pattern('art'),
    simple_project_pattern('bionic'),
    simple_project_pattern('bootable'),
    simple_project_pattern('build'),
    simple_project_pattern('cts'),
    simple_project_pattern('dalvik'),
    simple_project_pattern('developers'),
    simple_project_pattern('development'),
    simple_project_pattern('device'),
    simple_project_pattern('doc'),
    # match external/google* before external/
    project_name_and_pattern('external/google', 'external/google.*'),
    project_name_and_pattern('external/non-google', 'external'),
    simple_project_pattern('frameworks/av/camera'),
    simple_project_pattern('frameworks/av/cmds'),
    simple_project_pattern('frameworks/av/drm'),
    simple_project_pattern('frameworks/av/include'),
    simple_project_pattern('frameworks/av/media/img_utils'),
    simple_project_pattern('frameworks/av/media/libcpustats'),
    simple_project_pattern('frameworks/av/media/libeffects'),
    simple_project_pattern('frameworks/av/media/libmediaplayerservice'),
    simple_project_pattern('frameworks/av/media/libmedia'),
    simple_project_pattern('frameworks/av/media/libstagefright'),
    simple_project_pattern('frameworks/av/media/mtp'),
    simple_project_pattern('frameworks/av/media/ndk'),
    simple_project_pattern('frameworks/av/media/utils'),
    project_name_and_pattern('frameworks/av/media/Other',
                             'frameworks/av/media'),
    simple_project_pattern('frameworks/av/radio'),
    simple_project_pattern('frameworks/av/services'),
    simple_project_pattern('frameworks/av/soundtrigger'),
    project_name_and_pattern('frameworks/av/Other', 'frameworks/av'),
    simple_project_pattern('frameworks/base/cmds'),
    simple_project_pattern('frameworks/base/core'),
    simple_project_pattern('frameworks/base/drm'),
    simple_project_pattern('frameworks/base/media'),
    simple_project_pattern('frameworks/base/libs'),
    simple_project_pattern('frameworks/base/native'),
    simple_project_pattern('frameworks/base/packages'),
    simple_project_pattern('frameworks/base/rs'),
    simple_project_pattern('frameworks/base/services'),
    simple_project_pattern('frameworks/base/tests'),
    simple_project_pattern('frameworks/base/tools'),
    project_name_and_pattern('frameworks/base/Other', 'frameworks/base'),
    simple_project_pattern('frameworks/compile/libbcc'),
    simple_project_pattern('frameworks/compile/mclinker'),
    simple_project_pattern('frameworks/compile/slang'),
    project_name_and_pattern('frameworks/compile/Other', 'frameworks/compile'),
    simple_project_pattern('frameworks/minikin'),
    simple_project_pattern('frameworks/ml'),
    simple_project_pattern('frameworks/native/cmds'),
    simple_project_pattern('frameworks/native/include'),
    simple_project_pattern('frameworks/native/libs'),
    simple_project_pattern('frameworks/native/opengl'),
    simple_project_pattern('frameworks/native/services'),
    simple_project_pattern('frameworks/native/vulkan'),
    project_name_and_pattern('frameworks/native/Other', 'frameworks/native'),
    simple_project_pattern('frameworks/opt'),
    simple_project_pattern('frameworks/rs'),
    simple_project_pattern('frameworks/webview'),
    simple_project_pattern('frameworks/wilhelm'),
    project_name_and_pattern('frameworks/Other', 'frameworks'),
    simple_project_pattern('hardware/akm'),
    simple_project_pattern('hardware/broadcom'),
    simple_project_pattern('hardware/google'),
    simple_project_pattern('hardware/intel'),
    simple_project_pattern('hardware/interfaces'),
    simple_project_pattern('hardware/libhardware'),
    simple_project_pattern('hardware/libhardware_legacy'),
    simple_project_pattern('hardware/qcom'),
    simple_project_pattern('hardware/ril'),
    project_name_and_pattern('hardware/Other', 'hardware'),
    simple_project_pattern('kernel'),
    simple_project_pattern('libcore'),
    simple_project_pattern('libnativehelper'),
    simple_project_pattern('ndk'),
    # match vendor/unbungled_google/packages before other packages
    simple_project_pattern('unbundled_google'),
    simple_project_pattern('packages'),
    simple_project_pattern('pdk'),
    simple_project_pattern('prebuilts'),
    simple_project_pattern('system/bt'),
    simple_project_pattern('system/connectivity'),
    simple_project_pattern('system/core/adb'),
    simple_project_pattern('system/core/base'),
    simple_project_pattern('system/core/debuggerd'),
    simple_project_pattern('system/core/fastboot'),
    simple_project_pattern('system/core/fingerprintd'),
    simple_project_pattern('system/core/fs_mgr'),
    simple_project_pattern('system/core/gatekeeperd'),
    simple_project_pattern('system/core/healthd'),
    simple_project_pattern('system/core/include'),
    simple_project_pattern('system/core/init'),
    simple_project_pattern('system/core/libbacktrace'),
    simple_project_pattern('system/core/liblog'),
    simple_project_pattern('system/core/libpixelflinger'),
    simple_project_pattern('system/core/libprocessgroup'),
    simple_project_pattern('system/core/libsysutils'),
    simple_project_pattern('system/core/logcat'),
    simple_project_pattern('system/core/logd'),
    simple_project_pattern('system/core/run-as'),
    simple_project_pattern('system/core/sdcard'),
    simple_project_pattern('system/core/toolbox'),
    project_name_and_pattern('system/core/Other', 'system/core'),
    simple_project_pattern('system/extras/ANRdaemon'),
    simple_project_pattern('system/extras/cpustats'),
    simple_project_pattern('system/extras/crypto-perf'),
    simple_project_pattern('system/extras/ext4_utils'),
    simple_project_pattern('system/extras/f2fs_utils'),
    simple_project_pattern('system/extras/iotop'),
    simple_project_pattern('system/extras/libfec'),
    simple_project_pattern('system/extras/memory_replay'),
    simple_project_pattern('system/extras/mmap-perf'),
    simple_project_pattern('system/extras/multinetwork'),
    simple_project_pattern('system/extras/procrank'),
    simple_project_pattern('system/extras/runconuid'),
    simple_project_pattern('system/extras/showmap'),
    simple_project_pattern('system/extras/simpleperf'),
    simple_project_pattern('system/extras/su'),
    simple_project_pattern('system/extras/tests'),
    simple_project_pattern('system/extras/verity'),
    project_name_and_pattern('system/extras/Other', 'system/extras'),
    simple_project_pattern('system/gatekeeper'),
    simple_project_pattern('system/keymaster'),
    simple_project_pattern('system/libhidl'),
    simple_project_pattern('system/libhwbinder'),
    simple_project_pattern('system/media'),
    simple_project_pattern('system/netd'),
    simple_project_pattern('system/nvram'),
    simple_project_pattern('system/security'),
    simple_project_pattern('system/sepolicy'),
    simple_project_pattern('system/tools'),
    simple_project_pattern('system/update_engine'),
    simple_project_pattern('system/vold'),
    project_name_and_pattern('system/Other', 'system'),
    simple_project_pattern('toolchain'),
    simple_project_pattern('test'),
    simple_project_pattern('tools'),
    # match vendor/google* before vendor/
    project_name_and_pattern('vendor/google', 'vendor/google.*'),
    project_name_and_pattern('vendor/non-google', 'vendor'),
    # keep out/obj and other patterns at the end.
    ['out/obj',
     '.*/(gen|obj[^/]*)/(include|EXECUTABLES|SHARED_LIBRARIES|'
     'STATIC_LIBRARIES|NATIVE_TESTS)/.*: warning:'],
    ['other', '.*']  # all other unrecognized patterns
]
