#
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

PRODUCT_POLICY := android.policy_phone
PRODUCT_PROPERTY_OVERRIDES :=

PRODUCT_PACKAGES := \
	AccountAndSyncSettings \
	Camera \
	Calculator \
	CarHome \
	DeskClock \
	Development \
	DrmProvider \
	Email \
	Fallback \
	Gallery \
	GPSEnable \
	Launcher2 \
	Protips \
	Music \
	Mms \
	Settings \
	SdkSetup \
	CustomLocale \
	gpstest \
	sqlite3 \
	LatinIME \
	PinyinIME \
	Phone \
	OpenWnn \
	libWnnEngDic \
	libWnnJpnDic \
	libwnndict \
	CertInstaller \
	LiveWallpapersPicker \
	ApiDemos \
	GestureBuilder \
	SoftKeyboard \
	CubeLiveWallpapers

PRODUCT_PACKAGE_OVERLAYS := development/sdk_overlay

PRODUCT_COPY_FILES := \
	system/core/rootdir/etc/vold.fstab:system/etc/vold.fstab \
	frameworks/base/data/sounds/effects/camera_click.ogg:system/media/audio/ui/camera_click.ogg \
	frameworks/base/data/sounds/effects/VideoRecord.ogg:system/media/audio/ui/VideoRecord.ogg \
	frameworks/base/data/etc/android.hardware.camera.autofocus.xml:system/etc/permissions/android.hardware.camera.autofocus.xml

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/locales_full.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_NAME := sdk
PRODUCT_DEVICE := generic
PRODUCT_LOCALES += ldpi hdpi mdpi

# include available languages for TTS in the system image
include external/svox/pico/lang/PicoLangDeDeInSystem.mk
include external/svox/pico/lang/PicoLangEnGBInSystem.mk
include external/svox/pico/lang/PicoLangEnUsInSystem.mk
include external/svox/pico/lang/PicoLangEsEsInSystem.mk
include external/svox/pico/lang/PicoLangFrFrInSystem.mk
include external/svox/pico/lang/PicoLangItItInSystem.mk
