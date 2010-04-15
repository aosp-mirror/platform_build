# Copyright (C) 2007 The Android Open Source Project
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

# Just bump this if you want to force a clean build.
# **********************************************************************
# WHEN DOING SO
# 1. DELETE ANY "add-clean-step" ENTRIES THAT HAVE PILED UP IN THIS FILE.
# 2. REMOVE ALL FILES NAMED CleanSpec.mk.
# 3. BUMP THE VERSION.
# IDEALLY, THOSE STEPS SHOULD BE DONE ATOMICALLY.
# **********************************************************************
#
INTERNAL_CLEAN_BUILD_VERSION := 3
#
# ***********************************************************************
# Do not touch INTERNAL_CLEAN_BUILD_VERSION if you've added a clean step!
# ***********************************************************************

# If you don't need to do a full clean build but would like to touch
# a file or delete some intermediate files, add a clean step to the end
# of the list.  These steps will only be run once, if they haven't been
# run before.
#
# E.g.:
#     $(call add-clean-step, touch -c external/sqlite/sqlite3.h)
#     $(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libz_intermediates)
#
# Always use "touch -c" and "rm -f" or "rm -rf" to gracefully deal with
# files that are missing or have been moved.
#
# Use $(PRODUCT_OUT) to get to the "out/target/product/blah/" directory.
# Use $(OUT_DIR) to refer to the "out" directory.
#
# If you need to re-do something that's already mentioned, just copy
# the command and add it to the bottom of the list.  E.g., if a change
# that you made last week required touching a file and a change you
# made today requires touching the same file, just copy the old
# touch step and add it to the end of the list.
#
# ************************************************
# NEWER CLEAN STEPS MUST BE AT THE END OF THE LIST
# ************************************************

# For example:
#$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/AndroidTests_intermediates)
#$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/core_intermediates)
#$(call add-clean-step, find $(OUT_DIR) -type f -name "IGTalkSession*" -print0 | xargs -0 rm -f)
#$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.google.android.datamessaging_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/sholes/obj/SHARED_LIBRARIES/libhardware_legacy_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/pvasflocal.cfg)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/sholes)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/media/audio/ringtones/Silence.ogg)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/media/audio/ringtones/notifications/Silence.ogg)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/passion/obj/SHARED_LIBRARIES/libhardware_legacy_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.google.android.datamessaging_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libcrypto_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libssl_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES/openssl_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/sholes/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/bugreport)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libdvm_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libandroid_runtime_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/obj/target/common/obj/APPS/VoiceSearch_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/VoiceSearch_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libgps-rpc_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/pdsm_atl_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libgps_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libhardware_legacy_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/*/system/app/Launcher.apk)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates/src/core/java/android/bluetooth/)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/product/sholes/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/com.amazon.mp3_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/com.amazon.mp3.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES/openssl_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libv8_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libwebcore_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libjs_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libv8_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates/src/core/java/com/android/internal/os/IDropBoxService.java)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/GoogleSubscribedFeedsProvider.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libhardware_legacy_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libmediaplayerservice_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libstagefright_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/GoogleServicesFramework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/VoiceSearchWithKeyboard.apk)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/Email_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/Email_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/vendor/google_voiceime)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/QuickSearchBox.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libdvm_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates/src/core/java/android/speech)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/Email_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/AndroidTests_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/EnhancedGoogleSearchProvider.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/GoogleCheckin.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libdvm*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libgtest_main_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES/libgtest_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/Music*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Music*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/Music*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Music*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Launcher.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/AlarmClock.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Calendar.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/DeskClock.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Email.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Facebook.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Gallery3D.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Maps.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/MyFaves.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/googlevoice.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/kickback.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/soundback.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/talkback.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/Launcher*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Launcher*.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/Music*)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/Music*)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/jsr305_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/guava_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/*)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/*)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)

# ************************************************
# NEWER CLEAN STEPS MUST BE AT THE END OF THE LIST
# ************************************************

subdir_cleanspecs := \
    $(shell build/tools/findleaves.py --prune=out --prune=.repo --prune=.git . CleanSpec.mk)
include $(subdir_cleanspecs)
subdir_cleanspecs :=
