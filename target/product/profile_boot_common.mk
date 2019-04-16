#
# Copyright 2018 The Android Open Source Project
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

# Use an empty profile to make non of the boot image be AOT compiled (for now).
# Note that we could use a previous profile but we will miss the opportunity to
# remove classes that are no longer in use.
# Ideally we would just generate an empty boot.art but we don't have the build
# support to separate the image from the compile code.
PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION := build/make/target/product/empty-profile
PRODUCT_DEX_PREOPT_BOOT_FLAGS := --count-hotness-in-compiled-code
DEX_PREOPT_DEFAULT := nostripping

# Disable uncompressing priv apps so that there is enough space to build the system partition.
DONT_UNCOMPRESS_PRIV_APPS_DEXS := true

# Use an empty preloaded-classes list.
PRODUCT_COPY_FILES += \
    build/make/target/product/empty-preloaded-classes:system/etc/preloaded-classes

# Boot image property overrides.
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.jitinitialsize=32m \
    dalvik.vm.jitmaxsize=32m \
    dalvik.vm.usejitprofiles=true \
    dalvik.vm.hot-startup-method-samples=256 \
    dalvik.vm.profilesystemserver=true \
    dalvik.vm.profilebootimage=true

# Use speed compiler filter since system server doesn't have JIT.
PRODUCT_DEX_PREOPT_BOOT_FLAGS += --compiler-filter=speed
# System server is speed compiled and doesn't have a separate preopt flag,
# so we enable hotness in compiled code for everything.
PRODUCT_DEX_PREOPT_DEFAULT_FLAGS := --count-hotness-in-compiled-code

PRODUCT_DIST_BOOT_AND_SYSTEM_JARS := true
