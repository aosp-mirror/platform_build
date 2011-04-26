#
# Copyright (C) 2010 The Android Open Source Project
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

# This is the list of modules grandfathered to use ALL_PREBUILT

# DO NOT ADD ANY NEW MODULE TO THIS FILE
#
# ALL_PREBUILT modules are hard to control and audit and we don't want
# to add any new such module in the system

GRANDFATHERED_ALL_PREBUILT := \
	akmd2 \
	am \
	ap_gain.bin \
	audio.conf \
	auto_pairing.conf \
	AVRCP.kl \
	baseline11k.par \
	baseline8k.par \
	baseline.par \
	basic.ok \
	batch \
	bitmap_size.txt \
	blacklist.conf \
	bmgr \
	boolean.g2g \
	bp.img \
	brcm_guci_drv \
	bypassfactory \
	cdt.bin \
	chat-ril \
	cmu6plus.ok.zip \
	cpcap-key.kl \
	data \
	dbus.conf \
	dev \
	egl.cfg \
	enroll.ok \
	en-US-ttp.data \
	firmware_error.565 \
	firmware_install.565 \
	ftmipcd \
	generic11_f.swimdl \
	generic11.lda \
	generic11_m.swimdl \
	generic8_f.swimdl \
	generic8.lda \
	generic8_m.swimdl \
	generic.swiarb \
	gps.conf \
	gpsconfig.xml \
	gps.stingray.so \
	gralloc.omap3.so \
	gralloc.tegra.so \
	hosts \
	hwcomposer.tegra.so \
	ime \
	init.goldfish.rc \
	init.goldfish.sh \
	init.olympus.rc \
	init.rc \
	init.sholes.rc \
	init.stingray.rc \
	input \
	input.conf \
	kernel \
	lbl \
	libEGL_POWERVR_SGX530_121.so \
	libEGL_tegra.so \
	libGLESv1_CM_POWERVR_SGX530_121.so \
	libGLESv1_CM_tegra.so \
	libGLESv2_POWERVR_SGX530_121.so \
	libGLESv2_tegra.so \
	libmdmctrl.a \
	libmoto_ril.so \
	libpppd_plugin-ril.so \
	libril_rds.so \
	location \
	location.cfg \
	main.conf \
	mbm.bin \
	mbm_consumer.bin \
	mdm_panicd \
	monkey \
	network.conf \
	phone_type_choice.g2g \
	pm \
	pppd-ril \
	pppd-ril.options \
	proc \
	qwerty.kl \
	radio.img \
	rdl.bin \
	RFFspeed_501.bmd \
	RFFstd_501.bmd \
	savebpver \
	sbin \
	sholes-keypad.kl \
	suplcerts.bks \
	svc \
	sys \
	system \
	tcmd \
	ueventd.goldfish.rc \
	ueventd.olympus.rc \
	ueventd.rc \
	ueventd.stingray.rc \
	VoiceDialer.g2g \
	vold.fstab \
	wl1271.bin \
	zoneinfo.dat \
	zoneinfo.idx \
	zoneinfo.version
