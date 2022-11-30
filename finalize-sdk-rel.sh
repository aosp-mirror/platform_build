#!/bin/bash

set -ex

function finalize_sdk_rel() {
    local DEV_SRC_DIR="$(dirname "$0")"/../..
    local BUILD_PREFIX='UP1A'
    local PLATFORM_CODENAME='UpsideDownCake'
    local PLATFORM_VERSION='14'
    local PLATFORM_SDK_VERSION='34'

    # build/make/core/version_defaults.mk
    sed -i -e "s/PLATFORM_VERSION_CODENAME.${BUILD_PREFIX} := .*/PLATFORM_VERSION_CODENAME.${BUILD_PREFIX} := REL/g" "$DEV_SRC_DIR/build/make/core/version_defaults.mk"

    # cts
    echo "$PLATFORM_VERSION" > "$DEV_SRC_DIR/cts/tests/tests/os/assets/platform_versions.txt"
    git -C "$DEV_SRC_DIR/cts" mv hostsidetests/theme/assets/${PLATFORM_CODENAME} hostsidetests/theme/assets/${PLATFORM_SDK_VERSION}

    # system/sepolicy
    mkdir -p "$DEV_SRC_DIR/system/sepolicy/prebuilts/api/${PLATFORM_SDK_VERSION}.0/"
    cp -r "$DEV_SRC_DIR/system/sepolicy/public/" "$DEV_SRC_DIR/system/sepolicy/prebuilts/api/${PLATFORM_SDK_VERSION}.0/"
    cp -r "$DEV_SRC_DIR/system/sepolicy/private/" "$DEV_SRC_DIR/system/sepolicy/prebuilts/api/${PLATFORM_SDK_VERSION}.0/"

    # prebuilts/abi-dumps/ndk
    git -C "$DEV_SRC_DIR/prebuilts/abi-dumps/ndk" mv ${PLATFORM_CODENAME} ${PLATFORM_SDK_VERSION}

    # prebuilts/abi-dumps/vndk
    git -C "$DEV_SRC_DIR/prebuilts/abi-dumps/vndk" mv ${PLATFORM_CODENAME} ${PLATFORM_SDK_VERSION}

    # prebuilts/abi-dumps/platform
    git -C "$DEV_SRC_DIR/prebuilts/abi-dumps/platform" mv ${PLATFORM_CODENAME} ${PLATFORM_SDK_VERSION}
}

finalize_sdk_rel

