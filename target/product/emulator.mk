#
# Copyright (C) 2012 The Android Open Source Project
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
# This file is included by other product makefiles to add all the
# emulator-related modules to PRODUCT_PACKAGES.
#

# Device modules
PRODUCT_PACKAGES += \
    libGLES_android \
    vintf \
    CarrierConfig \

# need this for gles libraries to load properly
# after moving to /vendor/lib/
PRODUCT_PACKAGES += \
    vndk-sp

# WiFi: system side
PRODUCT_PACKAGES += \
	ip \
	iw \
	wificond \


PRODUCT_PACKAGE_OVERLAYS := device/generic/goldfish/overlay

PRODUCT_CHARACTERISTICS := emulator

PRODUCT_FULL_TREBLE_OVERRIDE := true

# goldfish vendor partition configurations
$(call inherit-product-if-exists, device/generic/goldfish/vendor.mk)

#watchdog tiggers reboot because location service is not
#responding, disble it for now.
#still keep it on internal master as it is still working
#once it is fixed in aosp, remove this block of comment.
#PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
#config.disable_location=true

# Enable Perfetto traced
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.traced.enable=1

# enable Google-specific location features,
# like NetworkLocationProvider and LocationCollector
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.com.google.locationfeatures=1

# disable setupwizard
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.setupwizard.mode=DISABLED
