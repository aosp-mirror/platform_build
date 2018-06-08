#
# Copyright (C) 2013 The Android Open Source Project
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
# Tiny configuration for small devices such as wearables. Includes base and embedded.
# No telephony

PRODUCT_PACKAGES := \
    audio.primary.default \
    Bluetooth \
    CalendarProvider \
    CertInstaller \
    clatd \
    clatd.conf \
    ContactsProvider \
    DefaultContainerService \
    FusedLocation \
    InputDevices \
    local_time.default \
    power.default \
    pppd \

# The order here is the same order they end up on the classpath, so it matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    services \
    wifi-service

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    FusedLocation \
    InputDevices

# The set of packages we want to force 'speed' compilation on.
PRODUCT_DEXPREOPT_SPEED_APPS := \

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)
$(call inherit-product-if-exists, external/roboto-fonts/fonts.mk)

# Overrides
PRODUCT_BRAND := tiny
PRODUCT_DEVICE := tiny
PRODUCT_NAME := core_tiny
