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

$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libmediaplayerservice_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libmedia_jni_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libstagefright_omx_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/android-info.txt)
$(call add-clean-step, find $(PRODUCT_OUT) -name "*.apk" | xargs rm)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/*/LINKED)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib/*.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/symbols/system/lib/*.so)
$(call add-clean-step, rm -rf $(HOST_OUT_EXECUTABLES)/iself)
$(call add-clean-step, rm -rf $(HOST_OUT_EXECUTABLES)/lsd)
$(call add-clean-step, rm -rf $(HOST_OUT_EXECUTABLES)/apriori)
$(call add-clean-step, rm -rf $(HOST_OUT_EXECUTABLES)/isprelinked)
$(call add-clean-step, rm -rf $(HOST_OUT_EXECUTABLES)/soslim)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib/*.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/symbols/system/lib/*.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/YouTube*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libstagefright_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libstagefright_omx_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/librtp_jni_intermediates)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/android-info.txt)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/JAVA_LIBRARIES/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/framework/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libbcinfo_intermediates)

# ICS MR2!!!!!!!!!!!!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES/libbcinfo_intermediates)

# WAIT, I MEAN JELLY BEAN!!!!!!!!!!!!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Changing where ro.carrier value is instantiated for system/build.prop
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Now we switched to build against Mac OS X SDK 10.6
$(call add-clean-step, rm -rf $(OUT_DIR)/host/darwin-x86/obj)

$(call add-clean-step, rm -f $(OUT_DIR)/versions_checked.mk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.o)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.o)

# JB MR2!!!!!!!  AND *NO*, THIS WILL NOT BE K-WHATEVER.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Start of "K" development!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# GCC 4.7
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.o)

# Wait, back to some JB development!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# And on to KLP...
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# KLP now based off API 18.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# Clean up around the /system/app -> /system/priv-app migration
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)

# Clean up old location of generated Java files from aidl
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/framework_intermediates/src)

# Clean up ApplicationsProvider which is being removed.
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/ApplicationsProvider_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/priv-app/ApplicationsProvider.apk)

# Clean up Moto OMA DM client which isn't ready yet.
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.android.omadm.plugin.dev_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.android.omadm.plugin.diagmon_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.android.omadm.pluginhelper_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.android.omadm.plugin_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/JAVA_LIBRARIES/com.android.omadm.service.api_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/DMService_intermediates)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/SprintDM_intermediates)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/priv-app/DMService.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/SprintDM.apk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/omadm)

# GCC 4.8
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/STATIC_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/SHARED_LIBRARIES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/EXECUTABLES)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/lib/*.o)

# KLP I mean KitKat now API 19.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# 4.4.1
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# 4.4.2
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# "L" and beyond.
# Make libart the default runtime
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Rename persist.sys.dalvik.vm.lib to allow new default
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# KKWT development
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# L development
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# L development
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# Add ro.product.cpu.abilist{32,64} to build.prop.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Unset TARGET_PREFER_32_BIT_APPS for 64 bit targets.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Adding dalvik.vm.dex2oat-flags to eng builds
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Unset TARGET_PREFER_32_BIT_APPS for 64 bit targets.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Switching the x86 emulator over to a 64 bit primary zygote.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)

# Rename persist.sys.dalvik.vm.lib.1 to allow new default
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Switching PRODUCT_RUNTIMES default for some devices
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Switching to 32-bit-by-default host multilib build
$(call add-clean-step, rm -rf $(HOST_OUT_INTERMEDIATES))

# KKWT has become API 20
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# ims-common.jar added to BOOTCLASSPATH
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/ETC/init.environ.rc_intermediates)

# Change ro.zygote for core_64_bit.mk from zygote32_64 to zygote64_32
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# Adding dalvik.vm.dex2oat-Xms, dalvik.vm.dex2oat-Xmx
# dalvik.vm.image-dex2oat-Xms, and dalvik.vm.image-dex2oat-Xmx
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system)

# Switch host builds to Clang by default
$(call add-clean-step, rm -rf $(OUT_DIR)/host)

# Adding dalvik.vm.dex2oat-filter
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# API 21?
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# API 21!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# API 22!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# Move to libc++ as the default STL.
$(call add-clean-step, rm -rf $(OUT_DIR))

# dex2oat instruction-set changes
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# Make GNU++11 the default standard version. This requires a cleanspec because
# char16_t/char32_t will be real types now instead of typedefs, which means
# an ABI change since the names will mangle differently.
$(call add-clean-step, rm -rf $(OUT_DIR))

# 5.1!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# Remove ro.product.locale.language/country and add ro.product.locale
# instead.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# On to MNC
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# Adding dalvik.vm.usejit
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# Rename dalvik.vm.usejit to debug.dalvik.vm.usejit
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# Revert rename dalvik.vm.usejit to debug.dalvik.vm.usejit
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# Change from interpret-only to verify-at-runtime.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/default.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/default.prop)

# New York, New York!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# 23 is becoming alive!!!
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# Change PLATFORM_VERSION from NYC to N
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*)

# $(PRODUCT_OUT)/recovery/root/sdcard goes from symlink to folder.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/recovery/root/sdcard)

# Add BOARD_USES_SYSTEM_OTHER_ODEX
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/priv-app/*)

$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/previous_overlays.txt)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/current_packages.txt)

$(call add-clean-step, rm -rf $(HOST_OUT_INTERMEDIATES)/include)

$(call add-clean-step, rm -rf $(HOST_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/src)
$(call add-clean-step, rm -rf $(HOST_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/previous_gen_java_config.mk)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/current_gen_java_config.mk)

$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*/package-res.apk)
$(call add-clean-step, rm -rf $(TARGET_OUT_INTERMEDIATES)/APPS/*/package-res.apk)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*_intermediates/src)

$(call add-clean-step, rm -rf $(HOST_OUT_TESTCASES))
$(call add-clean-step, rm -rf $(TARGET_OUT_TESTCASES))

$(call add-clean-step, rm -rf $(TARGET_OUT_ETC)/init)

# Libraries are moved from {system|vendor}/lib to ./lib/framework, ./lib/vndk, etc.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/lib*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor/lib*)

# Revert that move
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/lib*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor/lib*)

# Sanitized libraries now live in a different location.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/lib*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/data/vendor/lib*)

# Soong module variant change, remove obsolete intermediates
$(call add-clean-step, rm -rf $(OUT_DIR)/soong/.intermediates)

# Version checking moving to Soong
$(call add-clean-step, rm -rf $(OUT_DIR)/versions_checked.mk)

# Vendor tests were being installed into /vendor/bin accidentally
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor/nativetest*)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/nativetest*)

# Jack is no longer the default compiler, remove the intermediates
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/*/*/classes*.jack)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/*/*/jack*)

# Move adbd from $(PRODUCT_OUT)/root/sbin to $(PRODUCT_OUT)/system/bin
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/root/sbin/adbd)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/symbols/sbin/adbd)

# Soong linux -> linux_glibc rename
$(call add-clean-step, find $(SOONG_OUT_DIR)/.intermediates -name 'linux_x86*' | xargs rm -rf)
$(call add-clean-step, find $(SOONG_OUT_DIR)/.intermediates -name 'linux_common*' | xargs rm -rf)

# Remove old aidl/logtags files that may be in the generated source directory
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/*/*_intermediates/src)
$(call add-clean-step, rm -f $(OUT_DIR)/target/common/obj/*/*_intermediates/java-source-list)
$(call add-clean-step, rm -rf $(OUT_DIR)/host/common/obj/*/*_intermediates/src)
$(call add-clean-step, rm -f $(OUT_DIR)/host/common/obj/*/*_intermediates/java-source-list)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/obj/APPS/*/flat-res)

# Remove old VNDK directories without version
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib/vndk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib/vndk-sp)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib64/vndk)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib64/vndk-sp)

# Remove old dex output directories
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/*/*_intermediates/with-local/)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/*/*_intermediates/no-local/)
$(call add-clean-step, rm -rf $(HOST_OUT_COMMON_INTERMEDIATES)/*/*_intermediates/with-local/)
$(call add-clean-step, rm -rf $(HOST_OUT_COMMON_INTERMEDIATES)/*/*_intermediates/no-local/)

# Remove legacy VINTF metadata files
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/manifest.xml)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor/manifest.xml)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/manifest.xml)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/vendor/compatibility_matrix.xml)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/compatibility_matrix.xml)

# Remove DisplayCutoutEmulation overlays
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/overlay/DisplayCutoutEmulationWide)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/overlay/DisplayCutoutEmulationNarrow)

# Remove obsolete intermedates src files
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/*/*_intermediates/src/RenderScript.stamp*)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/java-source-list)
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/JAVA_LIBRARIES/*_intermediates/java-source-list)
$(call add-clean-step, rm -rf $(OUT_DOCS)/*-timestamp)

$(call add-clean-step, rm -rf $(TARGET_COMMON_OUT_ROOT)/obj_asan/APPS/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_COMMON_OUT_ROOT)/obj_asan/JAVA_LIBRARIES/*_intermediates/src)
$(call add-clean-step, rm -rf $(TARGET_COMMON_OUT_ROOT)/obj_asan/APPS/*_intermediates/java-source-list)
$(call add-clean-step, rm -rf $(TARGET_COMMON_OUT_ROOT)/obj_asan/JAVA_LIBRARIES/*_intermediates/java-source-list)

# Remove stale init.noenforce.rc
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/init/gsi/init.noenforce.rc)

# Clean up Launcher3 which has been replaced with Launcher3QuickStep
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/Launcher3)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/priv-app/Launcher3)
$(call add-clean-step, rm -rf $(OUT_DIR)/target/common/obj/APPS/Launcher3_intermediates)

# Remove old merged AndroidManifest.xml location
$(call add-clean-step, rm -rf $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/*_intermediates/AndroidManifest.xml)

$(call add-clean-step, find $(PRODUCT_OUT) -type f -name "vr_hwc*" -print0 | xargs -0 rm -f)

$(call add-clean-step, rm -rf $(SOONG_OUT_DIR)/.intermediates/system/vold)

# Remove product-services related files / images
$(call add-clean-step, find $(PRODUCT_OUT) -type f -name "*product-services*" -print0 | xargs -0 rm -rf)
$(call add-clean-step, find $(PRODUCT_OUT) -type d -name "*product-services*" -print0 | xargs -0 rm -rf)
$(call add-clean-step, find $(PRODUCT_OUT) -type l -name "*product-services*" -print0 | xargs -0 rm -rf)

# Remove obsolete recovery etc files
$(call add-clean-step, rm -rf $(TARGET_RECOVERY_ROOT_OUT)/etc)

# Remove *_OUT_INTERMEDIATE_LIBRARIES
$(call add-clean-step, rm -rf $(addsuffix /lib,\
  $(HOST_OUT_INTERMEDIATES) $(2ND_HOST_OUT_INTERMEDIATES) \
  $(HOST_CROSS_OUT_INTERMEDIATES) $(2ND_HOST_CROSS_OUT_INTERMEDIATES) \
  $(TARGET_OUT_INTERMEDIATES) $(2ND_TARGET_OUT_INTERMEDIATES)))

# Remove strip.sh intermediates to save space
$(call add-clean-step, find $(OUT_DIR) \( -name "*.so.debug" -o -name "*.so.dynsyms" -o -name "*.so.funcsyms" -o -name "*.so.keep_symbols" -o -name "*.so.mini_debuginfo.xz" \) -print0 | xargs -0 rm -f)

# Clean up old ninja files
$(call add-clean-step, rm -f $(OUT_DIR)/build-*-dist*.ninja)

$(call add-clean-step, rm -f $(HOST_OUT)/*ts/host-libprotobuf-java-*.jar)

$(call add-clean-step, find $(OUT_DIR)/target/product/mainline_arm64/system -type f -name "*.*dex" -print0 | xargs -0 rm -f)

# Clean up aidegen
$(call add-clean-step, rm -f $(HOST_OUT)/bin/aidegen)

# Remove perfprofd
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/perfprofd)

# Remove incorrectly created directories in the source tree
$(call add-clean-step, find system/app system/priv-app system/framework system_other -depth -type d -print0 | xargs -0 rmdir)
$(call add-clean-step, rm -f .d)

# Remove obsolete apps
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/app/*)

# Remove corrupt generated rule due to using toybox's sed
$(call add-clean-step, rm -rf $(SOONG_OUT_DIR)/.intermediates/system/core/init/generated_stub_builtin_function_map)

# Clean up core JNI libraries moved to runtime apex
$(call add-clean-step, rm -f $(PRODUCT_OUT)/system/lib*/libjavacore.so)
$(call add-clean-step, rm -f $(PRODUCT_OUT)/system/lib*/libopenjdk.so)
$(call add-clean-step, rm -f $(PRODUCT_OUT)/system/lib*/libexpat.so)

# Merge product_services into product
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/product_services)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/product_services)

# Clean up old location of hiddenapi files
$(call add-clean-step, rm -f $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/hiddenapi*)

# Clean up previous default location of RROs
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/overlay)

# Remove ART artifacts installed only by modules `art-runtime` and
# `art-tools` in /system on target.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dalvikvm)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dalvikvm32)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dalvikvm64)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dex2oat)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dex2oatd)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dexdiag)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dexdump)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dexlist)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dexoptanalyzer)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/dexoptanalyzerd)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/oatdump)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/profman)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/profmand)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libadbconnection.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libadbconnectiond.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libart-compiler.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libartd-compiler.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libart-dexlayout.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libartd-dexlayout.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libart-disassembler.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libart.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libartd.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libartbase.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libartbased.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdexfile.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdexfiled.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdexfile_external.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdexfile_support.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdt_fd_forward.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libdt_socket.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libjdwp.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libnpt.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libopenjdkd.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libopenjdkjvm.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libopenjdkjvmd.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libopenjdkjvmti.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libopenjdkjvmtid.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libprofile.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libprofiled.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libtombstoned_client.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libvixl.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libvixld.so)

# Clean up old location of dexpreopted boot jars
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/dex_bootjars)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/dex_bootjars_input)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libnpt.so)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*)

# Clean up old testcase files
$(call add-clean-step, rm -rf $(TARGET_OUT_TESTCASES)/*)
$(call add-clean-step, rm -rf $(HOST_OUT_TESTCASES)/*)
$(call add-clean-step, rm -rf $(HOST_CROSS_OUT_TESTCASES)/*)
$(call add-clean-step, rm -rf $(TARGET_OUT_DATA)/*)
$(call add-clean-step, rm -rf $(HOST_OUT)/vts/*)
$(call add-clean-step, rm -rf $(HOST_OUT)/framework/vts-tradefed.jar)

# Clean up old location of system_other.avbpubkey
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/security/avb/)

# Clean up bufferhub files
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/bin/hw/android.frameworks.bufferhub@1.0-service)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/init/android.frameworks.bufferhub@1.0-service.rc)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/super.img)

$(call add-clean-step, find $(PRODUCT_OUT) -type f -name "generated_*_image_info.txt" -print0 | xargs -0 rm -f)

# Clean up libicuuc.so and libicui18n.so
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libicu*)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/target/common/obj/framework.aidl)

# Clean up adb_debug.propr
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/etc/adb_debug.prop)

$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libjavacrypto.so)

# Clean up old location of soft OMX plugins
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libstagefright_soft*)

# Move odm build.prop to /odm/etc/.
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/odm/build.prop)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/vendor/odm/build.prop)

# Remove libcameraservice and libcamera_client from base_system
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libcameraservice.so)
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/lib*/libcamera_client.so)

# ************************************************
# NEWER CLEAN STEPS MUST BE AT THE END OF THE LIST
# ************************************************
