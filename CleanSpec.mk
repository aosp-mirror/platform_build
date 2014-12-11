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

# 5.0.1
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# 5.0.2
$(call add-clean-step, rm -rf $(PRODUCT_OUT)/system/build.prop)

# ************************************************
# NEWER CLEAN STEPS MUST BE AT THE END OF THE LIST
# ************************************************
