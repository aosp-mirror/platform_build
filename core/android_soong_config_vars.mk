# Copyright (C) 2020 The Android Open Source Project
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

# This file defines the Soong Config Variable namespace ANDROID, and also any
# variables in that namespace.

# The expectation is that no vendor should be using the ANDROID namespace. This
# check ensures that we don't collide with any existing vendor usage.

ifdef SOONG_CONFIG_ANDROID
$(error The Soong config namespace ANDROID is reserved.)
endif

$(call add_soong_config_namespace,ANDROID)

# Add variables to the namespace below:

$(call add_soong_config_var,ANDROID,BOARD_USES_ODMIMAGE)
$(call soong_config_set_bool,ANDROID,BOARD_USES_RECOVERY_AS_BOOT,$(BOARD_USES_RECOVERY_AS_BOOT))
$(call soong_config_set_bool,ANDROID,BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT,$(BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT))
$(call add_soong_config_var,ANDROID,CHECK_DEV_TYPE_VIOLATIONS)
$(call soong_config_set_bool,ANDROID,HAS_BOARD_SYSTEM_EXT_PREBUILT_DIR,$(if $(BOARD_SYSTEM_EXT_PREBUILT_DIR),true,false))
$(call soong_config_set_bool,ANDROID,HAS_BOARD_PRODUCT_PREBUILT_DIR,$(if $(BOARD_PRODUCT_PREBUILT_DIR),true,false))
$(call add_soong_config_var,ANDROID,PLATFORM_SEPOLICY_VERSION)
$(call add_soong_config_var,ANDROID,PLATFORM_SEPOLICY_COMPAT_VERSIONS)
$(call add_soong_config_var,ANDROID,PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT)
$(call soong_config_set_bool,ANDROID,RELEASE_BOARD_API_LEVEL_FROZEN,$(RELEASE_BOARD_API_LEVEL_FROZEN))
$(call add_soong_config_var,ANDROID,TARGET_DYNAMIC_64_32_DRMSERVER)
$(call add_soong_config_var,ANDROID,TARGET_ENABLE_MEDIADRM_64)
$(call add_soong_config_var,ANDROID,TARGET_DYNAMIC_64_32_MEDIASERVER)

$(call add_soong_config_var,ANDROID,ADDITIONAL_M4DEFS,$(if $(BOARD_SEPOLICY_M4DEFS),$(addprefix -D,$(BOARD_SEPOLICY_M4DEFS))))

# For Sanitizers
$(call soong_config_set_bool,ANDROID,ASAN_ENABLED,$(if $(filter address,$(SANITIZE_TARGET)),true,false))
$(call soong_config_set_bool,ANDROID,HWASAN_ENABLED,$(if $(filter hwaddress,$(SANITIZE_TARGET)),true,false))
$(call soong_config_set_bool,ANDROID,SANITIZE_TARGET_SYSTEM_ENABLED,$(if $(filter true,$(SANITIZE_TARGET_SYSTEM)),true,false))

# For init.environ.rc
$(call soong_config_set_bool,ANDROID,GCOV_COVERAGE,$(NATIVE_COVERAGE))
$(call soong_config_set_bool,ANDROID,CLANG_COVERAGE,$(CLANG_COVERAGE))
$(call soong_config_set,ANDROID,SCUDO_ALLOCATION_RING_BUFFER_SIZE,$(PRODUCT_SCUDO_ALLOCATION_RING_BUFFER_SIZE))

$(call soong_config_set_bool,ANDROID,EMMA_INSTRUMENT,$(if $(filter true,$(EMMA_INSTRUMENT)),true,false))

# PRODUCT_PRECOMPILED_SEPOLICY defaults to true. Explicitly check if it's "false" or not.
$(call soong_config_set_bool,ANDROID,PRODUCT_PRECOMPILED_SEPOLICY,$(if $(filter false,$(PRODUCT_PRECOMPILED_SEPOLICY)),false,true))

# For art modules
$(call soong_config_set_bool,art_module,host_prefer_32_bit,$(if $(filter true,$(HOST_PREFER_32_BIT)),true,false))
ifdef ART_DEBUG_OPT_FLAG
$(call soong_config_set,art_module,art_debug_opt_flag,$(ART_DEBUG_OPT_FLAG))
endif
# The default value of ART_BUILD_HOST_DEBUG is true
$(call soong_config_set_bool,art_module,art_build_host_debug,$(if $(filter false,$(ART_BUILD_HOST_DEBUG)),false,true))

ifdef TARGET_BOARD_AUTO
  $(call add_soong_config_var_value, ANDROID, target_board_auto, $(TARGET_BOARD_AUTO))
endif

# Apex build mode variables
ifdef APEX_BUILD_FOR_PRE_S_DEVICES
$(call add_soong_config_var_value,ANDROID,library_linking_strategy,prefer_static)
else
ifdef KEEP_APEX_INHERIT
$(call add_soong_config_var_value,ANDROID,library_linking_strategy,prefer_static)
endif
endif

# Enable SystemUI optimizations by default unless explicitly set.
SYSTEMUI_OPTIMIZE_JAVA ?= true
$(call add_soong_config_var,ANDROID,SYSTEMUI_OPTIMIZE_JAVA)

ifdef PRODUCT_AVF_ENABLED
$(call add_soong_config_var_value,ANDROID,avf_enabled,$(PRODUCT_AVF_ENABLED))
endif

# Enable AVF remote attestation according to the flag value if PRODUCT_AVF_REMOTE_ATTESTATION_DISABLED is not
# set to true explicitly.
ifneq (true,$(PRODUCT_AVF_REMOTE_ATTESTATION_DISABLED))
  $(call add_soong_config_var_value,ANDROID,avf_remote_attestation_enabled,$(RELEASE_AVF_ENABLE_REMOTE_ATTESTATION))
endif

ifdef PRODUCT_AVF_MICRODROID_GUEST_GKI_VERSION
$(call add_soong_config_var_value,ANDROID,avf_microdroid_guest_gki_version,$(PRODUCT_AVF_MICRODROID_GUEST_GKI_VERSION))
endif

ifdef PRODUCT_MEMCG_V2_FORCE_ENABLED
$(call add_soong_config_var_value,ANDROID,memcg_v2_force_enabled,$(PRODUCT_MEMCG_V2_FORCE_ENABLED))
endif

ifdef PRODUCT_CGROUP_V2_SYS_APP_ISOLATION_ENABLED
$(call add_soong_config_var_value,ANDROID,cgroup_v2_sys_app_isolation,$(PRODUCT_CGROUP_V2_SYS_APP_ISOLATION_ENABLED))
endif

$(call add_soong_config_var_value,ANDROID,release_avf_allow_preinstalled_apps,$(RELEASE_AVF_ALLOW_PREINSTALLED_APPS))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_device_assignment,$(RELEASE_AVF_ENABLE_DEVICE_ASSIGNMENT))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_dice_changes,$(RELEASE_AVF_ENABLE_DICE_CHANGES))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_early_vm,$(RELEASE_AVF_ENABLE_EARLY_VM))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_llpvm_changes,$(RELEASE_AVF_ENABLE_LLPVM_CHANGES))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_multi_tenant_microdroid_vm,$(RELEASE_AVF_ENABLE_MULTI_TENANT_MICRODROID_VM))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_network,$(RELEASE_AVF_ENABLE_NETWORK))
# TODO(b/341292601): This flag is needed until the V release. We with clean it up after V together
# with most of the release_avf_ flags here.
$(call add_soong_config_var_value,ANDROID,release_avf_enable_remote_attestation,$(RELEASE_AVF_ENABLE_REMOTE_ATTESTATION))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_vendor_modules,$(RELEASE_AVF_ENABLE_VENDOR_MODULES))
$(call add_soong_config_var_value,ANDROID,release_avf_enable_virt_cpufreq,$(RELEASE_AVF_ENABLE_VIRT_CPUFREQ))
$(call add_soong_config_var_value,ANDROID,release_avf_microdroid_kernel_version,$(RELEASE_AVF_MICRODROID_KERNEL_VERSION))
$(call add_soong_config_var_value,ANDROID,release_avf_support_custom_vm_with_paravirtualized_devices,$(RELEASE_AVF_SUPPORT_CUSTOM_VM_WITH_PARAVIRTUALIZED_DEVICES))

$(call add_soong_config_var_value,ANDROID,release_binder_death_recipient_weak_from_jni,$(RELEASE_BINDER_DEATH_RECIPIENT_WEAK_FROM_JNI))

$(call add_soong_config_var_value,ANDROID,release_libpower_no_lock_binder_txn,$(RELEASE_LIBPOWER_NO_LOCK_BINDER_TXN))

$(call add_soong_config_var_value,ANDROID,release_package_libandroid_runtime_punch_holes,$(RELEASE_PACKAGE_LIBANDROID_RUNTIME_PUNCH_HOLES))

$(call add_soong_config_var_value,ANDROID,release_selinux_data_data_ignore,$(RELEASE_SELINUX_DATA_DATA_IGNORE))
ifneq (,$(filter eng userdebug,$(TARGET_BUILD_VARIANT)))
    # write appcompat system properties on userdebug and eng builds
    $(call add_soong_config_var_value,ANDROID,release_write_appcompat_override_system_properties,true)
endif

# Enable system_server optimizations by default unless explicitly set or if
# there may be dependent runtime jars.
# TODO(b/240588226): Remove the off-by-default exceptions after handling
# system_server jars automatically w/ R8.
ifeq (true,$(PRODUCT_BROKEN_SUBOPTIMAL_ORDER_OF_SYSTEM_SERVER_JARS))
  # If system_server jar ordering is broken, don't assume services.jar can be
  # safely optimized in isolation, as there may be dependent jars.
  SYSTEM_OPTIMIZE_JAVA ?= false
else ifneq (platform:services,$(lastword $(PRODUCT_SYSTEM_SERVER_JARS)))
  # If services is not the final jar in the dependency ordering, don't assume
  # it can be safely optimized in isolation, as there may be dependent jars.
  SYSTEM_OPTIMIZE_JAVA ?= false
else
  SYSTEM_OPTIMIZE_JAVA ?= true
endif

ifeq (true,$(FULL_SYSTEM_OPTIMIZE_JAVA))
  SYSTEM_OPTIMIZE_JAVA := true
endif

$(call add_soong_config_var,ANDROID,SYSTEM_OPTIMIZE_JAVA)
$(call add_soong_config_var,ANDROID,FULL_SYSTEM_OPTIMIZE_JAVA)

# TODO(b/319697968): Remove this build flag support when metalava fully supports flagged api
$(call soong_config_set,ANDROID,release_hidden_api_exportable_stubs,$(RELEASE_HIDDEN_API_EXPORTABLE_STUBS))

# Check for SupplementalApi module.
ifeq ($(wildcard packages/modules/SupplementalApi),)
$(call add_soong_config_var_value,ANDROID,include_nonpublic_framework_api,false)
else
$(call add_soong_config_var_value,ANDROID,include_nonpublic_framework_api,true)
endif

# Add crashrecovery build flag to soong
$(call soong_config_set,ANDROID,release_crashrecovery_module,$(RELEASE_CRASHRECOVERY_MODULE))
# Add crashrecovery file move flags to soong, for both platform and module
ifeq (true,$(RELEASE_CRASHRECOVERY_FILE_MOVE))
  $(call soong_config_set,ANDROID,crashrecovery_files_in_module,true)
  $(call soong_config_set,ANDROID,crashrecovery_files_in_platform,false)
else
  $(call soong_config_set,ANDROID,crashrecovery_files_in_module,false)
  $(call soong_config_set,ANDROID,crashrecovery_files_in_platform,true)
endif
# Required as platform_bootclasspath is using this namespace
$(call soong_config_set,bootclasspath,release_crashrecovery_module,$(RELEASE_CRASHRECOVERY_MODULE))

# Enable Profiling module. Also used by platform_bootclasspath.
$(call soong_config_set,ANDROID,release_package_profiling_module,$(RELEASE_PACKAGE_PROFILING_MODULE))
$(call soong_config_set,bootclasspath,release_package_profiling_module,$(RELEASE_PACKAGE_PROFILING_MODULE))

# Add perf-setup build flag to soong
# Note: BOARD_PERFSETUP_SCRIPT location must be under platform_testing/scripts/perf-setup/.
ifdef BOARD_PERFSETUP_SCRIPT
  $(call soong_config_set,perf,board_perfsetup_script,$(notdir $(BOARD_PERFSETUP_SCRIPT)))
endif

# Add target_use_pan_display flag for hardware/libhardware:gralloc.default
$(call soong_config_set_bool,gralloc,target_use_pan_display,$(if $(filter true,$(TARGET_USE_PAN_DISPLAY)),true,false))

# Add use_camera_v4l2_hal flag for hardware/libhardware/modules/camera/3_4:camera.v4l2
$(call soong_config_set_bool,camera,use_camera_v4l2_hal,$(if $(filter true,$(USE_CAMERA_V4L2_HAL)),true,false))

# Add audioserver_multilib flag for hardware/interfaces/soundtrigger/2.0/default:android.hardware.soundtrigger@2.0-impl
ifneq ($(strip $(AUDIOSERVER_MULTILIB)),)
  $(call soong_config_set,soundtrigger,audioserver_multilib,$(AUDIOSERVER_MULTILIB))
endif

# Add sim_count, disable_rild_oem_hook, and use_aosp_rild flag for ril related modules
$(call soong_config_set,ril,sim_count,$(SIM_COUNT))
ifneq ($(DISABLE_RILD_OEM_HOOK), false)
  $(call soong_config_set_bool,ril,disable_rild_oem_hook,true)
endif
ifneq ($(ENABLE_VENDOR_RIL_SERVICE), true)
  $(call soong_config_set_bool,ril,use_aosp_rild,true)
endif

# Export target_board_platform to soong for hardware/google/graphics/common/libmemtrack:memtrack.$(TARGET_BOARD_PLATFORM)
$(call soong_config_set,ANDROID,target_board_platform,$(TARGET_BOARD_PLATFORM))

# Export board_uses_scaler_m2m1shot and board_uses_align_restriction to soong for hardware/google/graphics/common/libscaler:libexynosscaler
$(call soong_config_set_bool,google_graphics,board_uses_scaler_m2m1shot,$(if $(filter true,$(BOARD_USES_SCALER_M2M1SHOT)),true,false))
$(call soong_config_set_bool,google_graphics,board_uses_align_restriction,$(if $(filter true,$(BOARD_USES_ALIGN_RESTRICTION)),true,false))

# Export video_codec variables to soong for exynos modules
$(call soong_config_set,video_codec,target_soc_name,$(TARGET_SOC_NAME))
$(call soong_config_set_bool,video_codec,board_use_codec2_hidl_1_2,$(if $(filter true,$(BOARD_USE_CODEC2_HIDL_1_2)),true,false))
$(call soong_config_set_bool,video_codec,board_support_mfc_enc_bt2020,$(if $(filter true,$(BOARD_SUPPORT_MFC_ENC_BT2020)),true,false))
$(call soong_config_set_bool,video_codec,board_support_flexible_p010,$(if $(filter true,$(BOARD_SUPPORT_FLEXIBLE_P010)),true,false))
$(call soong_config_set,video_codec,board_support_mfc_version,$(BOARD_SUPPORT_MFC_VERSION))
$(call soong_config_set_bool,video_codec,board_use_codec2_aidl,$(if $(BOARD_USE_CODEC2_AIDL),true,false))
