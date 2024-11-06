#
# Copyright (C) 2024 The Android Open Source Project
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

# ###############################################################
# This file adds wpa_supplicant_8 variables into soong config namespace (`wpa_supplicant_8`)
# ###############################################################

ifdef BOARD_HOSTAPD_DRIVER
$(call soong_config_set_bool,wpa_supplicant_8,wpa_build_hostapd,true)
ifneq ($(BOARD_HOSTAPD_DRIVER),NL80211)
    $(error BOARD_HOSTAPD_DRIVER set to $(BOARD_HOSTAPD_DRIVER) but current soong expected it should be NL80211 only!)
endif
endif

ifdef BOARD_WPA_SUPPLICANT_DRIVER
ifneq ($(BOARD_WPA_SUPPLICANT_DRIVER),NL80211)
    $(error BOARD_WPA_SUPPLICANT_DRIVER set to $(BOARD_WPA_SUPPLICANT_DRIVER) but current soong expected it should be NL80211 only!)
endif
endif

# This is for CONFIG_DRIVER_NL80211_BRCM, CONFIG_DRIVER_NL80211_SYNA, CONFIG_DRIVER_NL80211_QCA
# And it is only used for a cflags setting in driver.
$(call soong_config_set,wpa_supplicant_8,board_wlan_device,$(BOARD_WLAN_DEVICE))

# Belong to CONFIG_IEEE80211AX definition
ifeq ($(WIFI_FEATURE_HOSTAPD_11AX),true)
$(call soong_config_set_bool,wpa_supplicant_8,hostapd_11ax,true)
endif

# PLATFORM_VERSION
$(call soong_config_set,wpa_supplicant_8,platform_version,$(PLATFORM_VERSION))

# BOARD_HOSTAPD_PRIVATE_LIB
ifeq ($(BOARD_HOSTAPD_PRIVATE_LIB),)
$(call soong_config_set_bool,wpa_supplicant_8,hostapd_use_stub_lib,true)
else
$(call soong_config_set,wpa_supplicant_8,board_hostapd_private_lib,$(BOARD_HOSTAPD_PRIVATE_LIB))
endif

ifeq ($(BOARD_HOSTAPD_CONFIG_80211W_MFP_OPTIONAL),true)
$(call soong_config_set_bool,wpa_supplicant_8,board_hostapd_config_80211w_mfp_optional,true)
endif

ifneq ($(BOARD_HOSTAPD_PRIVATE_LIB_EVENT),)
$(call soong_config_set_bool,wpa_supplicant_8,board_hostapd_private_lib_event,true)
endif

# BOARD_WPA_SUPPLICANT_PRIVATE_LIB
ifeq ($(BOARD_WPA_SUPPLICANT_PRIVATE_LIB),)
$(call soong_config_set_bool,wpa_supplicant_8,wpa_supplicant_use_stub_lib,true)
else
$(call soong_config_set,wpa_supplicant_8,board_wpa_supplicant_private_lib,$(BOARD_WPA_SUPPLICANT_PRIVATE_LIB))
endif

ifneq ($(BOARD_WPA_SUPPLICANT_PRIVATE_LIB_EVENT),)
$(call soong_config_set_bool,wpa_supplicant_8,board_wpa_supplicant_private_lib_event,true)
endif

ifeq ($(WIFI_PRIV_CMD_UPDATE_MBO_CELL_STATUS), enabled)
$(call soong_config_set_bool,wpa_supplicant_8,wifi_priv_cmd_update_mbo_cell_status,true)
endif

ifeq ($(WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY), true)
$(call soong_config_set_bool,wpa_supplicant_8,wifi_hidl_unified_supplicant_service_rc_entry,true)
endif

# New added in internal main
ifeq ($(WIFI_BRCM_OPEN_SOURCE_MULTI_AKM), enabled)
$(call soong_config_set_bool,wpa_supplicant_8,wifi_brcm_open_source_multi_akm,true)
endif
