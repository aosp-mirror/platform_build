#!/bin/bash

set -ex

function finalize_locally_mainline_sdk() {
    local MAINLINE_EXTENSION='6'

    local top="$(dirname "$0")"/../..

    # Bump SDK extension version.
    "$top/packages/modules/SdkExtensions/gen_sdk/bump_sdk.sh" ${MAINLINE_EXTENSION}

    local version_defaults="$top/build/make/core/version_defaults.mk"
    sed -i -e "s/PLATFORM_SDK_EXTENSION_VERSION := .*/PLATFORM_SDK_EXTENSION_VERSION := ${MAINLINE_EXTENSION}/g" $version_defaults

    # Build modules SDKs.
    TARGET_BUILD_VARIANT=userdebug UNBUNDLED_BUILD_SDKS_FROM_SOURCE=true "$top/vendor/google/build/mainline_modules_sdks.sh"

    # Update prebuilts.
    "$top/prebuilts/build-tools/path/linux-x86/python3" "$top/packages/modules/common/tools/finalize_sdk.py" -l -b 0 -f ${MAINLINE_EXTENSION} -r '' 0
}

finalize_locally_mainline_sdk

