#
# Copyright (C) 2018 The Android Open Source Project
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

# Base modules and settings for the system partition.
PRODUCT_PACKAGES += \
    abx \
    aconfigd-system \
    adbd_system_api \
    aflags \
    am \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.system.suspend-service \
    android.test.base \
    android.test.mock \
    android.test.runner \
    apexd \
    appops \
    app_process \
    appwidget \
    atrace \
    audioserver \
    BackupRestoreConfirmation \
    bcc \
    blank_screen \
    blkid \
    bmgr \
    bootanimation \
    bootstat \
    boringssl_self_test \
    bpfloader \
    bu \
    bugreport \
    bugreportz \
    build_flag_system \
    cgroups.json \
    charger \
    cmd \
    com.android.adbd \
    com.android.adservices \
    com.android.appsearch \
    com.android.btservices \
    com.android.configinfrastructure \
    com.android.conscrypt \
    com.android.devicelock \
    com.android.extservices \
    com.android.healthfitness \
    com.android.i18n \
    com.android.ipsec \
    com.android.location.provider \
    com.android.media \
    com.android.media.swcodec \
    com.android.mediaprovider \
    com.android.ondevicepersonalization \
    com.android.os.statsd \
    com.android.permission \
    com.android.resolv \
    com.android.rkpd \
    com.android.neuralnetworks \
    com.android.scheduling \
    com.android.sdkext \
    com.android.tethering \
    $(RELEASE_PACKAGE_TZDATA_MODULE) \
    com.android.uwb \
    com.android.virt \
    com.android.wifi \
    ContactsProvider \
    content \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    debuggerd\
    device_config \
    dmctl \
    dnsmasq \
    dmesgd \
    DownloadProvider \
    dpm \
    dump.erofs \
    dumpstate \
    dumpsys \
    E2eeContactKeysProvider \
    e2fsck \
    enhanced-confirmation.xml \
    ExtShared \
    flags_health_check \
    framework-graphics \
    framework-location \
    framework-minus-apex \
    framework-minus-apex-install-dependencies \
    framework-sysconfig.xml \
    fsck.erofs \
    fsck_msdos \
    fsverity-release-cert-der \
    fs_config_files_system \
    fs_config_dirs_system \
    gpu_counter_producer \
    group_system \
    gsid \
    gsi_tool \
    heapprofd \
    heapprofd_client \
    gatekeeperd \
    gpuservice \
    hid \
    idmap2 \
    idmap2d \
    ime \
    ims-common \
    incident \
    incidentd \
    incident_helper \
    incident-helper-cmd \
    init.environ.rc \
    init_system \
    initial-package-stopped-states.xml \
    input \
    installd \
    IntentResolver \
    ip \
    iptables \
    javax.obex \
    kcmdlinectrl \
    keystore2 \
    credstore \
    ld.mc \
    libaaudio \
    libalarm_jni \
    libamidi \
    libandroid \
    libandroidfw \
    libandroid_runtime \
    libandroid_servers \
    libartpalette-system \
    libaudioeffect_jni \
    libbinder \
    libbinder_ndk \
    libbinder_rpc_unstable \
    libc.bootstrap \
    libcamera2ndk \
    libcutils \
    libdl.bootstrap \
    libdl_android.bootstrap \
    libdrmframework \
    libdrmframework_jni \
    libEGL \
    libETC1 \
    libfdtrack \
    libFFTEm \
    libfilterfw \
    libgatekeeper \
    libGLESv1_CM \
    libGLESv2 \
    libGLESv3 \
    libgui \
    libhardware \
    libhardware_legacy \
    libincident \
    libinput \
    libinputflinger \
    libiprouteutil \
    libjnigraphics \
    libjpeg \
    liblog \
    libm.bootstrap \
    libmedia \
    libmedia_jni \
    libmediandk \
    libmonkey_jni \
    libmtp \
    libnetd_client \
    libnetlink \
    libnetutils \
    libneuralnetworks_packageinfo \
    libOpenMAXAL \
    libOpenSLES \
    libpdfium \
    libpower \
    libpowermanager \
    libradio_metadata \
    librtp_jni \
    libsensorservice \
    libsfplugin_ccodec \
    libskia \
    libsonic \
    libsonivox \
    libsoundpool \
    libspeexresampler \
    libsqlite \
    libstagefright \
    libstagefright_foundation \
    libstagefright_omx \
    libstdc++ \
    libsysutils \
    libui \
    libusbhost \
    libutils \
    libvintf_jni \
    libvulkan \
    libwilhelm \
    linker \
    llkd \
    llndk_libs \
    lmkd \
    LocalTransport \
    locksettings \
    logcat \
    logd \
    lpdump \
    lshal \
    mdnsd \
    mediacodec.policy \
    mediaextractor \
    mediametrics \
    media_profiles_V1_0.dtd \
    MediaProviderLegacy \
    mediaserver \
    mke2fs \
    mkfs.erofs \
    monkey \
    misctrl \
    mtectrl \
    ndc \
    netd \
    NetworkStack \
    odsign \
    org.apache.http.legacy \
    otacerts \
    PackageInstaller \
    package-shareduid-allowlist.xml \
    passwd_system \
    perfetto \
    perfetto-extras \
    ping \
    ping6 \
    pintool \
    platform.xml \
    pm \
    prefetch \
    preinstalled-packages-asl-files.xml \
    preinstalled-packages-platform.xml \
    preinstalled-packages-strict-signature.xml \
    printflags \
    privapp-permissions-platform.xml \
    prng_seeder \
    recovery-persist \
    resize2fs \
    rss_hwm_reset \
    run-as \
    sanitizer.libraries.txt \
    schedtest \
    screencap \
    sdcard \
    secdiscard \
    SecureElement \
    selinux_policy_system \
    sensorservice \
    service \
    servicemanager \
    services \
    settings \
    SettingsProvider \
    sfdo \
    sgdisk \
    Shell \
    shell_and_utilities_system \
    sm \
    snapuserd \
    storaged \
    surfaceflinger \
    svc \
    system-build.prop \
    task_profiles.json \
    tc \
    telecom \
    telephony-common \
    tombstoned \
    traced \
    traced_probes \
    tradeinmode \
    tune2fs \
    uiautomator \
    uinput \
    uncrypt \
    usbd \
    vdc \
    vintf \
    voip-common \
    vold \
    watchdogd \
    wificond \
    wifi.rc \
    wm \

# When we release crashrecovery module
ifeq ($(RELEASE_CRASHRECOVERY_MODULE),true)
  PRODUCT_PACKAGES += \
        com.android.crashrecovery \

else
  PRODUCT_PACKAGES += \
    framework-platformcrashrecovery \

endif

# When we release ondeviceintelligence in neuralnetworks module
ifneq ($(RELEASE_ONDEVICE_INTELLIGENCE_MODULE),true)
  PRODUCT_PACKAGES += \
        framework-ondeviceintelligence-platform

endif


# When we release uprobestats module
ifeq ($(RELEASE_UPROBESTATS_MODULE),true)
    PRODUCT_PACKAGES += \
        com.android.uprobestats \

else
    PRODUCT_PACKAGES += \
        uprobestats \
        libuprobestats_client \

endif

# These packages are not used on Android TV
ifneq ($(PRODUCT_IS_ATV),true)
  PRODUCT_PACKAGES += \
      $(RELEASE_PACKAGE_SOUND_PICKER) \

endif

# Product does not support Dynamic System Update
ifneq ($(PRODUCT_NO_DYNAMIC_SYSTEM_UPDATE),true)
    PRODUCT_PACKAGES += \
        DynamicSystemInstallationService \

endif

# Check if the build supports NFC apex or not
ifeq ($(RELEASE_PACKAGE_NFC_STACK),NfcNci)
    PRODUCT_PACKAGES += \
        framework-nfc \
        NfcNci
else
    PRODUCT_PACKAGES += \
        com.android.nfcservices
endif

# Check if the build supports Profiling module
ifeq ($(RELEASE_PACKAGE_PROFILING_MODULE),true)
    PRODUCT_PACKAGES += \
       com.android.profiling
endif

ifeq ($(RELEASE_USE_WEBVIEW_BOOTSTRAP_MODULE),true)
    PRODUCT_PACKAGES += \
        com.android.webview.bootstrap
endif

# Only add the jar when it is not in the Tethering module. Otherwise,
# it will be added via com.android.tethering
ifneq ($(RELEASE_MOVE_VCN_TO_MAINLINE),true)
    PRODUCT_PACKAGES += \
        framework-connectivity-b
endif

ifneq (,$(RELEASE_RANGING_STACK))
    PRODUCT_PACKAGES += \
        com.android.ranging
endif

ifeq ($(RELEASE_MEMORY_MANAGEMENT_DAEMON),true)
  PRODUCT_PACKAGES += \
        mm_daemon
endif

# VINTF data for system image
PRODUCT_PACKAGES += \
    system_manifest.xml \
    system_compatibility_matrix.xml \

# Base modules when shipping api level is less than or equal to 34
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_34 += \
    android.hidl.memory@1.0-impl \

# hwservicemanager is now installed on system_ext, but apexes might be using
# old libraries that are expecting it to be installed on system. This allows
# those apexes to continue working. The symlink can be removed once we are sure
# there are no devices using hwservicemanager (when Android V launching devices
# are no longer supported for dessert upgrades).
PRODUCT_PACKAGES += \
    hwservicemanager_compat_symlink_module \

PRODUCT_PACKAGES_ARM64 := libclang_rt.hwasan \
 libclang_rt.hwasan.bootstrap \
 libc_hwasan \

# Jacoco agent JARS to be built and installed, if any.
ifeq ($(EMMA_INSTRUMENT),true)
  ifneq ($(EMMA_INSTRUMENT_STATIC),true)
    # For instrumented build, if Jacoco is not being included statically
    # in instrumented packages then include Jacoco classes in the product
    # packages.
    PRODUCT_PACKAGES += jacocoagent
    ifneq ($(EMMA_INSTRUMENT_FRAMEWORK),true)
      # For instrumented build, if Jacoco is not being included statically
      # in instrumented packages and has not already been included in the
      # bootclasspath via ART_APEX_JARS then include Jacoco classes into the
      # bootclasspath.
      PRODUCT_BOOT_JARS += jacocoagent
    endif # EMMA_INSTRUMENT_FRAMEWORK
  endif # EMMA_INSTRUMENT_STATIC
endif # EMMA_INSTRUMENT

ifeq (,$(DISABLE_WALLPAPER_BACKUP))
  PRODUCT_PACKAGES += \
    WallpaperBackup
endif

PRODUCT_PACKAGES += \
    libEGL_angle \
    libGLESv1_CM_angle \
    libGLESv2_angle

# For testing purposes
ifeq ($(FORCE_AUDIO_SILENT), true)
    PRODUCT_SYSTEM_PROPERTIES += ro.audio.silent=1
endif

# Host tools to install
PRODUCT_HOST_PACKAGES += \
    BugReport \
    adb \
    adevice \
    atest \
    bcc \
    bit \
    dump.erofs \
    e2fsck \
    fastboot \
    flags_health_check \
    fsck.erofs \
    icu-data_host_i18n_apex \
    tzdata_icu_res_files_host_prebuilts \
    idmap2 \
    incident_report \
    ld.mc \
    lpdump \
    mke2fs \
    mkfs.erofs \
    pbtombstone \
    resize2fs \
    sgdisk \
    sqlite3 \
    tinyplay \
    tune2fs \
    unwind_info \
    unwind_reg_info \
    unwind_symbols \
    tzdata_host \
    tzdata_host_tzdata_apex \
    tzlookup.xml_host_tzdata_apex \
    tz_version_host \
    tz_version_host_tzdata_apex \

# For art-tools, if the dependencies have changed, please sync them to art/Android.bp as well.
PRODUCT_HOST_PACKAGES += \
    ahat \
    dexdump \
    hprof-conv
# A subset of the tools are disabled when HOST_PREFER_32_BIT is defined as make reports that
# they are not supported on host (b/129323791). This is likely due to art_apex disabling host
# APEX builds when HOST_PREFER_32_BIT is set (b/120617876).
ifneq ($(HOST_PREFER_32_BIT),true)
PRODUCT_HOST_PACKAGES += \
    dexlist \
    oatdump
endif


PRODUCT_PACKAGES += init.usb.rc init.usb.configfs.rc

PRODUCT_PACKAGES += etc_hosts

PRODUCT_PACKAGES += init.zygote32.rc
PRODUCT_VENDOR_PROPERTIES += ro.zygote?=zygote32

PRODUCT_SYSTEM_PROPERTIES += debug.atrace.tags.enableflags=0
PRODUCT_SYSTEM_PROPERTIES += persist.traced.enable=1

# Include kernel configs.
PRODUCT_PACKAGES += \
    approved-ogki-builds.xml \
    kernel-lifetimes.xml

# Packages included only for eng or userdebug builds, previously debug tagged
PRODUCT_PACKAGES_DEBUG := \
    adevice_fingerprint \
    arping \
    dmuserd \
    evemu-record \
    idlcli \
    init-debug.rc \
    iotop \
    iperf3 \
    iw \
    layertracegenerator \
    libclang_rt.ubsan_standalone \
    logpersist.start \
    logtagd.rc \
    ot-cli-ftd \
    ot-ctl \
    procrank \
    profcollectd \
    profcollectctl \
    record_binder \
    servicedispatcher \
    showmap \
    snapshotctl \
    sqlite3 \
    ss \
    start_with_lockagent \
    strace \
    su \
    sanitizer-status \
    tracepath \
    tracepath6 \
    traceroute6 \
    unwind_info \
    unwind_reg_info \
    unwind_symbols \

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    SettingsProvider \

ifeq (,$(DISABLE_WALLPAPER_BACKUP))
  PRODUCT_SYSTEM_SERVER_APPS += \
    WallpaperBackup
endif

PRODUCT_PACKAGES_DEBUG_JAVA_COVERAGE := \
    libdumpcoverage

PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/preloaded-classes:system/etc/preloaded-classes)

# Enable dirty image object binning to reduce dirty pages in the image.
PRODUCT_PACKAGES += dirty-image-objects

# Enable go/perfetto-persistent-tracing for eng builds
ifneq (,$(filter eng, $(TARGET_BUILD_VARIANT)))
    PRODUCT_PRODUCT_PROPERTIES += persist.debug.perfetto.persistent_sysui_tracing_for_bugreport=1
endif

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)

# Ensure all trunk-stable flags are available.
$(call inherit-product, $(SRC_TARGET_DIR)/product/build_variables.mk)

# Use "image" APEXes always.
$(call inherit-product,$(SRC_TARGET_DIR)/product/updatable_apex.mk)

$(call soong_config_set, bionic, large_system_property_node, $(RELEASE_LARGE_SYSTEM_PROPERTY_NODE))
$(call soong_config_set, Aconfig, read_from_new_storage, $(RELEASE_READ_FROM_NEW_STORAGE))
$(call soong_config_set, SettingsLib, legacy_avatar_picker_app_enabled, $(if $(RELEASE_AVATAR_PICKER_APP),,true))
