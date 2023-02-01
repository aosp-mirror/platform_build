#
# Copyright (C) 2022 The Android Open Source Project
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
# This file adds WIFI variables into soong config namespace (`wifi`)
# ###############################################################

ifdef BOARD_WLAN_DEVICE
    $(call soong_config_set,wifi,board_wlan_device,$(BOARD_WLAN_DEVICE))
endif
ifdef WIFI_DRIVER_MODULE_PATH
    $(call soong_config_set,wifi,driver_module_path,$(WIFI_DRIVER_MODULE_PATH))
endif
ifdef WIFI_DRIVER_MODULE_ARG
    $(call soong_config_set,wifi,driver_module_arg,$(WIFI_DRIVER_MODULE_ARG))
endif
ifdef WIFI_DRIVER_MODULE_NAME
    $(call soong_config_set,wifi,driver_module_name,$(WIFI_DRIVER_MODULE_NAME))
endif
ifdef WIFI_DRIVER_FW_PATH_STA
    $(call soong_config_set,wifi,driver_fw_path_sta,$(WIFI_DRIVER_FW_PATH_STA))
endif
ifdef WIFI_DRIVER_FW_PATH_AP
    $(call soong_config_set,wifi,driver_fw_path_ap,$(WIFI_DRIVER_FW_PATH_AP))
endif
ifdef WIFI_DRIVER_FW_PATH_P2P
    $(call soong_config_set,wifi,driver_fw_path_p2p,$(WIFI_DRIVER_FW_PATH_P2P))
endif
ifdef WIFI_DRIVER_FW_PATH_PARAM
    $(call soong_config_set,wifi,driver_fw_path_param,$(WIFI_DRIVER_FW_PATH_PARAM))
endif
ifdef WIFI_DRIVER_STATE_CTRL_PARAM
    $(call soong_config_set,wifi,driver_state_ctrl_param,$(WIFI_DRIVER_STATE_CTRL_PARAM))
endif
ifdef WIFI_DRIVER_STATE_ON
    $(call soong_config_set,wifi,driver_state_on,$(WIFI_DRIVER_STATE_ON))
endif
ifdef WIFI_DRIVER_STATE_OFF
    $(call soong_config_set,wifi,driver_state_off,$(WIFI_DRIVER_STATE_OFF))
endif
ifdef WIFI_MULTIPLE_VENDOR_HALS
    $(call soong_config_set,wifi,multiple_vendor_hals,$(WIFI_MULTIPLE_VENDOR_HALS))
endif
ifneq ($(wildcard vendor/google/libraries/GoogleWifiConfigLib),)
    $(call soong_config_set,wifi,google_wifi_config_lib,true)
endif
ifdef WIFI_HAL_INTERFACE_COMBINATIONS
    $(call soong_config_set,wifi,hal_interface_combinations,$(WIFI_HAL_INTERFACE_COMBINATIONS))
endif
ifdef WIFI_HIDL_FEATURE_AWARE
    $(call soong_config_set,wifi,hidl_feature_aware,true)
endif
ifdef WIFI_HIDL_FEATURE_DUAL_INTERFACE
    $(call soong_config_set,wifi,hidl_feature_dual_interface,true)
endif
ifdef WIFI_HIDL_FEATURE_DISABLE_AP
    $(call soong_config_set,wifi,hidl_feature_disable_ap,true)
endif
ifdef WIFI_HIDL_FEATURE_DISABLE_AP_MAC_RANDOMIZATION
    $(call soong_config_set,wifi,hidl_feature_disable_ap_mac_randomization,true)
endif
ifdef WIFI_AVOID_IFACE_RESET_MAC_CHANGE
    $(call soong_config_set,wifi,avoid_iface_reset_mac_change,true)
endif