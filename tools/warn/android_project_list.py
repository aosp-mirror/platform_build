# python3
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


def create_pattern(name, pattern=None):
  if pattern is not None:
    return [name, '(^|.*/)' + pattern + '/.*: warning:']
  return [name, '(^|.*/)' + name + '/.*: warning:']


# A list of [project_name, file_path_pattern].
# project_name should not contain comma, to be used in CSV output.
project_list = [
    create_pattern('art'),
    create_pattern('bionic'),
    create_pattern('bootable'),
    create_pattern('build'),
    create_pattern('cts'),
    create_pattern('dalvik'),
    create_pattern('developers'),
    create_pattern('development'),
    create_pattern('device'),
    create_pattern('doc'),
    # match external/google* before external/
    create_pattern('external/google', 'external/google.*'),
    create_pattern('external/non-google', 'external'),
    create_pattern('frameworks/av/camera'),
    create_pattern('frameworks/av/cmds'),
    create_pattern('frameworks/av/drm'),
    create_pattern('frameworks/av/include'),
    create_pattern('frameworks/av/media/img_utils'),
    create_pattern('frameworks/av/media/libcpustats'),
    create_pattern('frameworks/av/media/libeffects'),
    create_pattern('frameworks/av/media/libmediaplayerservice'),
    create_pattern('frameworks/av/media/libmedia'),
    create_pattern('frameworks/av/media/libstagefright'),
    create_pattern('frameworks/av/media/mtp'),
    create_pattern('frameworks/av/media/ndk'),
    create_pattern('frameworks/av/media/utils'),
    create_pattern('frameworks/av/media/Other', 'frameworks/av/media'),
    create_pattern('frameworks/av/radio'),
    create_pattern('frameworks/av/services'),
    create_pattern('frameworks/av/soundtrigger'),
    create_pattern('frameworks/av/Other', 'frameworks/av'),
    create_pattern('frameworks/base/cmds'),
    create_pattern('frameworks/base/core'),
    create_pattern('frameworks/base/drm'),
    create_pattern('frameworks/base/media'),
    create_pattern('frameworks/base/libs'),
    create_pattern('frameworks/base/native'),
    create_pattern('frameworks/base/packages'),
    create_pattern('frameworks/base/rs'),
    create_pattern('frameworks/base/services'),
    create_pattern('frameworks/base/tests'),
    create_pattern('frameworks/base/tools'),
    create_pattern('frameworks/base/Other', 'frameworks/base'),
    create_pattern('frameworks/compile/libbcc'),
    create_pattern('frameworks/compile/mclinker'),
    create_pattern('frameworks/compile/slang'),
    create_pattern('frameworks/compile/Other', 'frameworks/compile'),
    create_pattern('frameworks/minikin'),
    create_pattern('frameworks/ml'),
    create_pattern('frameworks/native/cmds'),
    create_pattern('frameworks/native/include'),
    create_pattern('frameworks/native/libs'),
    create_pattern('frameworks/native/opengl'),
    create_pattern('frameworks/native/services'),
    create_pattern('frameworks/native/vulkan'),
    create_pattern('frameworks/native/Other', 'frameworks/native'),
    create_pattern('frameworks/opt'),
    create_pattern('frameworks/rs'),
    create_pattern('frameworks/webview'),
    create_pattern('frameworks/wilhelm'),
    create_pattern('frameworks/Other', 'frameworks'),
    create_pattern('hardware/akm'),
    create_pattern('hardware/broadcom'),
    create_pattern('hardware/google'),
    create_pattern('hardware/intel'),
    create_pattern('hardware/interfaces'),
    create_pattern('hardware/libhardware'),
    create_pattern('hardware/libhardware_legacy'),
    create_pattern('hardware/qcom'),
    create_pattern('hardware/ril'),
    create_pattern('hardware/Other', 'hardware'),
    create_pattern('kernel'),
    create_pattern('libcore'),
    create_pattern('libnativehelper'),
    create_pattern('ndk'),
    # match vendor/unbungled_google/packages before other packages
    create_pattern('unbundled_google'),
    create_pattern('packages/providers/MediaProvider'),
    create_pattern('packages'),
    create_pattern('pdk'),
    create_pattern('prebuilts'),
    create_pattern('system/bt'),
    create_pattern('system/connectivity'),
    create_pattern('system/core/adb'),
    create_pattern('system/core/base'),
    create_pattern('system/core/debuggerd'),
    create_pattern('system/core/fastboot'),
    create_pattern('system/core/fingerprintd'),
    create_pattern('system/core/fs_mgr'),
    create_pattern('system/core/gatekeeperd'),
    create_pattern('system/core/healthd'),
    create_pattern('system/core/include'),
    create_pattern('system/core/init'),
    create_pattern('system/core/libbacktrace'),
    create_pattern('system/core/liblog'),
    create_pattern('system/core/libpixelflinger'),
    create_pattern('system/core/libprocessgroup'),
    create_pattern('system/core/libsysutils'),
    create_pattern('system/core/logcat'),
    create_pattern('system/core/logd'),
    create_pattern('system/core/run-as'),
    create_pattern('system/core/sdcard'),
    create_pattern('system/core/toolbox'),
    create_pattern('system/core/Other', 'system/core'),
    create_pattern('system/extras/ANRdaemon'),
    create_pattern('system/extras/cpustats'),
    create_pattern('system/extras/crypto-perf'),
    create_pattern('system/extras/ext4_utils'),
    create_pattern('system/extras/f2fs_utils'),
    create_pattern('system/extras/iotop'),
    create_pattern('system/extras/libfec'),
    create_pattern('system/extras/memory_replay'),
    create_pattern('system/extras/mmap-perf'),
    create_pattern('system/extras/multinetwork'),
    create_pattern('system/extras/perfprofd'),
    create_pattern('system/extras/procrank'),
    create_pattern('system/extras/runconuid'),
    create_pattern('system/extras/showmap'),
    create_pattern('system/extras/simpleperf'),
    create_pattern('system/extras/su'),
    create_pattern('system/extras/tests'),
    create_pattern('system/extras/verity'),
    create_pattern('system/extras/Other', 'system/extras'),
    create_pattern('system/gatekeeper'),
    create_pattern('system/keymaster'),
    create_pattern('system/libhidl'),
    create_pattern('system/libhwbinder'),
    create_pattern('system/media'),
    create_pattern('system/netd'),
    create_pattern('system/nvram'),
    create_pattern('system/security'),
    create_pattern('system/sepolicy'),
    create_pattern('system/tools'),
    create_pattern('system/update_engine'),
    create_pattern('system/vold'),
    create_pattern('system/Other', 'system'),
    create_pattern('toolchain'),
    create_pattern('test'),
    create_pattern('tools'),
    # match vendor/google* before vendor/
    create_pattern('vendor/google', 'vendor/google.*'),
    create_pattern('vendor/non-google', 'vendor'),
    # keep out/obj and other patterns at the end.
    [
        'out/obj', '.*/(gen|obj[^/]*)/(include|EXECUTABLES|SHARED_LIBRARIES|'
        'STATIC_LIBRARIES|NATIVE_TESTS)/.*: warning:'
    ],
    ['other', '.*']  # all other unrecognized patterns
]
