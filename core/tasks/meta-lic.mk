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

# Declare license metadata for non-module files released with products.

# Moved here from device/generic/car/Android.mk
$(eval $(call declare-1p-copy-files,device/generic/car,))

# Moved here from device/generic/trusty/Android.mk
$(eval $(call declare-1p-copy-files,device/generic/trusty,))

# Moved here from device/generic/uml/Android.mk
$(eval $(call declare-1p-copy-files,device/generic/uml,))

# Moved here from device/google_car/common/Android.mk
$(eval $(call declare-1p-copy-files,device/google_car/common,))

# Moved here from device/google/atv/Android.mk
$(eval $(call declare-1p-copy-files,device/google/atv,atv-component-overrides.xml))
$(eval $(call declare-1p-copy-files,device/google/atv,tv_core_hardware.xml))

# Moved here from device/google/bramble/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/bramble,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/bramble,audio_policy_configuration.xml))

# Moved here from device/google/barbet/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/barbet,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/barbet,audio_policy_configuration.xml))

# Moved here from device/google/coral/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/coral,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/coral,display_19261132550654593.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/coral,audio_policy_configuration.xml))
$(eval $(call declare-1p-copy-files,device/google/coral,display_19260504575090817.xml))

# Moved here from device/google/cuttlefish/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,.idc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,wpa_supplicant.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,init.cutf_cvm.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,fstab.cf.f2fs.hctr2,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,fstab.cf.f2fs.cts,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,fstab.cf.ext4.hctr2,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,fstab.cf.ext4.cts,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,init.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish,audio_policy.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-copy-files-license-metadata,device/google/cuttlefish/shared/config,pci.ids,SPDX-license-identifier-BSD-3-Clause,notice,device/google/cuttlefish/shared/config/LICENSE_BSD,))

$(eval $(call declare-1p-copy-files,device/google/cuttlefish,privapp-permissions-cuttlefish.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,media_profiles_V1_0.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,media_codecs_performance.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,cuttlefish_excluded_hardware.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,media_codecs.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,media_codecs_google_video.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,car_audio_configuration.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,audio_policy_configuration.xml))
$(eval $(call declare-1p-copy-files,device/google/cuttlefish,preinstalled-packages-product-car-cuttlefish.xml))
$(eval $(call declare-1p-copy-files,hardware/google/camera/devices,.json))

# Moved here from device/google/gs101/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,p2p_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/gs101,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/gs101,audio_policy_configuration.xml))

# Move here from device/google/raviole/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,libnfc-nci-raven.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/raviole,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/raviole,audio_policy_configuration.xml))

# Moved here from device/google/redfin/Android.mk
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,default-permissions.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,libnfc-nci.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,fstab.postinstall,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,ueventd.rc,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,hals.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,media_profiles_V1_0.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,media_codecs_performance.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,device_state_configuration.xml,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,task_profiles.json,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,p2p_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,wpa_supplicant.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))
$(eval $(call declare-copy-files-license-metadata,device/google/redfin,wpa_supplicant_overlay.conf,SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,))

$(eval $(call declare-1p-copy-files,device/google/redfin,audio_policy_configuration.xml))

# Moved here from device/sample/Android.mk
$(eval $(call declare-1p-copy-files,device/sample,))

# Moved here from device/google/trout/Android.mk
$(eval $(call declare-1p-copy-files,device/google/trout,))

# Moved here from frameworks/av/media/Android.mk
$(eval $(call declare-1p-copy-files,frameworks/av/media/libeffects,audio_effects.conf))
$(eval $(call declare-1p-copy-files,frameworks/av/media/libeffects,audio_effects.xml))
$(eval $(call declare-1p-copy-files,frameworks/av/media/libstagefright,))

# Moved here from frameworks/av/services/Android.mk
$(eval $(call declare-1p-copy-files,frameworks/av/services/audiopolicy,))

# Moved here from frameworks/base/Android.mk
$(eval $(call declare-1p-copy-files,frameworks/base,.ogg))
$(eval $(call declare-1p-copy-files,frameworks/base,.kl))
$(eval $(call declare-1p-copy-files,frameworks/base,.kcm))
$(eval $(call declare-1p-copy-files,frameworks/base,.idc))
$(eval $(call declare-1p-copy-files,frameworks/base,dirty-image-objects))
$(eval $(call declare-1p-copy-files,frameworks/base/config,))
$(eval $(call declare-1p-copy-files,frameworks/native/data,))

# Moved here from hardware/google/camera/Android.mk
$(eval $(call declare-1p-copy-files,hardware/google/camera,))

# Moved here from hardware/interfaces/tv/Android.mk
$(eval $(call declare-1p-copy-files,hardware/interfaces/tv,tuner_vts_config_1_0.xml))
$(eval $(call declare-1p-copy-files,hardware/interfaces/tv,tuner_vts_config_1_1.xml))

# Moved here from device/generic/goldfish/Android.mk
$(eval $(call declare-1p-copy-files,device/generic/goldfish/data,))
$(eval $(call declare-1p-copy-files,device/generic/goldfish/input,))
$(eval $(call declare-1p-copy-files,device/generic/goldfish/wifi,))
$(eval $(call declare-1p-copy-files,device/generic/goldfish/camera,))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,hals.conf))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,init.qemu-adb-keys.sh))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,init.system_ext.rc))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,.json))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,ueventd.rc))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,wpa_supplicant.conf))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,media_profiles_V1_0.xml))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,init.ranchu.rc))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,fstab.ranchu))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,display_settings.xml))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,display_settings_freeform.xml))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,device_state_configuration.xml))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,init.ranchu-core.sh))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,init.ranchu-net.sh))
$(eval $(call declare-1p-copy-files,device/generic/goldfish,audio_policy_configuration.xml))

# Moved here from packages/services/Car/Android.mk
$(eval $(call declare-1p-copy-files,packages/services/Car,))

# Moved here from hardware/libhardware_legacy/Android.mk
$(eval $(call declare-1p-copy-files,hardware/libhardware_legacy,))

# Moved here from system/core/rootdir/Android.mk
$(eval $(call declare-1p-copy-files,system/core/rootdir,))
