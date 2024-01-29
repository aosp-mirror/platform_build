#!/bin/bash

set -ex

function apply_droidstubs_hack() {
    if ! grep -q 'STOPSHIP: RESTORE THIS LOGIC WHEN DECLARING "REL" BUILD' "$top/build/soong/java/droidstubs.go" ; then
        local build_soong_git_root="$(readlink -f $top/build/soong)"
        patch --strip=1 --no-backup-if-mismatch --directory="$build_soong_git_root" --input=../../build/make/tools/finalization/build_soong_java_droidstubs.go.apply_hack.diff
    fi
}

function apply_resources_sdk_int_fix() {
    if ! grep -q 'public static final int RESOURCES_SDK_INT = SDK_INT;' "$top/frameworks/base/core/java/android/os/Build.java" ; then
        local base_git_root="$(readlink -f $top/frameworks/base)"
        patch --strip=1 --no-backup-if-mismatch --directory="$base_git_root" --input=../../build/make/tools/finalization/frameworks_base.apply_resource_sdk_int.diff
    fi
}

function finalize_bionic_ndk() {
    # Adding __ANDROID_API_<>__.
    # If this hasn't done then it's not used and not really needed. Still, let's check and add this.
    local api_level="$top/bionic/libc/include/android/api-level.h"
    if ! grep -q "\__.*$((${FINAL_PLATFORM_SDK_VERSION}))" $api_level ; then
        local tmpfile=$(mktemp /tmp/finalization.XXXXXX)
        echo "
/** Names the \"${FINAL_PLATFORM_CODENAME:0:1}\" API level ($FINAL_PLATFORM_SDK_VERSION), for comparison against \`__ANDROID_API__\`. */
#define __ANDROID_API_${FINAL_PLATFORM_CODENAME:0:1}__ $FINAL_PLATFORM_SDK_VERSION" > "$tmpfile"

        local api_level="$top/bionic/libc/include/android/api-level.h"
        sed -i -e "/__.*$((${FINAL_PLATFORM_SDK_VERSION}-1))/r""$tmpfile" $api_level

        rm "$tmpfile"
    fi
}

function finalize_modules_utils() {
    local shortCodename="${FINAL_PLATFORM_CODENAME:0:1}"
    local methodPlaceholder="INSERT_NEW_AT_LEAST_${shortCodename}_METHOD_HERE"

    local tmpfile=$(mktemp /tmp/finalization.XXXXXX)
    echo "    /** Checks if the device is running on a release version of Android $FINAL_PLATFORM_CODENAME or newer */
    @ChecksSdkIntAtLeast(api = $FINAL_PLATFORM_SDK_VERSION /* BUILD_VERSION_CODES.$FINAL_PLATFORM_CODENAME */)
    public static boolean isAtLeast${FINAL_PLATFORM_CODENAME:0:1}() {
        return SDK_INT >= $FINAL_PLATFORM_SDK_VERSION;
    }" > "$tmpfile"

    local javaFuncRegex='\/\*\*[^{]*isAtLeast'"${shortCodename}"'() {[^{}]*}'
    local javaFuncReplace="N;N;N;N;N;N;N;N; s/$javaFuncRegex/$methodPlaceholder/; /$javaFuncRegex/!{P;D};"

    local javaSdkLevel="$top/frameworks/libs/modules-utils/java/com/android/modules/utils/build/SdkLevel.java"
    sed -i "$javaFuncReplace" $javaSdkLevel

    sed -i "/${methodPlaceholder}"'/{
           r '"$tmpfile"'
           d}' $javaSdkLevel

    echo "// Checks if the device is running on release version of Android ${FINAL_PLATFORM_CODENAME:0:1} or newer.
inline bool IsAtLeast${FINAL_PLATFORM_CODENAME:0:1}() { return android_get_device_api_level() >= $FINAL_PLATFORM_SDK_VERSION; }" > "$tmpfile"

    local cppFuncRegex='\/\/[^{]*IsAtLeast'"${shortCodename}"'() {[^{}]*}'
    local cppFuncReplace="N;N;N;N;N;N; s/$cppFuncRegex/$methodPlaceholder/; /$cppFuncRegex/!{P;D};"

    local cppSdkLevel="$top/frameworks/libs/modules-utils/build/include/android-modules-utils/sdk_level.h"
    sed -i "$cppFuncReplace" $cppSdkLevel
    sed -i "/${methodPlaceholder}"'/{
           r '"$tmpfile"'
           d}' $cppSdkLevel

    rm "$tmpfile"
}

function bumpSdkExtensionsVersion() {
    local SDKEXT="packages/modules/SdkExtensions/"

    # This used to call bump_sdk.sh utility.
    # However due to TS, we have to build the gen_sdk with a correct set of settings.

    # "$top/packages/modules/SdkExtensions/gen_sdk/bump_sdk.sh" ${FINAL_MAINLINE_EXTENSION}
    # Leave the last commit as a set of modified files.
    # The code to create a finalization topic will pick it up later.
    # git -C ${SDKEXT} reset HEAD~1

    local sdk="${FINAL_MAINLINE_EXTENSION}"
    local modules_arg=

    TARGET_PRODUCT=aosp_arm64 \
        TARGET_RELEASE=fina_1 \
        TARGET_BUILD_VARIANT=userdebug \
        DIST_DIR=out/dist \
        $top/build/soong/soong_ui.bash --make-mode --soong-only gen_sdk

    ANDROID_BUILD_TOP="$top" out/soong/host/linux-x86/bin/gen_sdk \
        --database ${SDKEXT}/gen_sdk/extensions_db.textpb \
        --action new_sdk \
        --sdk "$sdk" \
        $modules_arg
}

function finalize_sdk_resources() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local SDK_CODENAME="public static final int $FINAL_PLATFORM_CODENAME_JAVA = CUR_DEVELOPMENT;"
    local SDK_VERSION="public static final int $FINAL_PLATFORM_CODENAME_JAVA = $FINAL_PLATFORM_SDK_VERSION;"

    # The full process can be found at (INTERNAL) go/android-sdk-finalization.

    # apply droidstubs hack to prevent tools from incrementing an API version
    apply_droidstubs_hack

    # bionic/NDK
    finalize_bionic_ndk

    # Finalize SDK

    # frameworks/libs/modules-utils
    finalize_modules_utils

    # development/sdk
    local platform_source="$top/development/sdk/platform_source.prop_template"
    sed -i -e 's/Pkg\.Revision.*/Pkg\.Revision=1/g' $platform_source
    local build_tools_source="$top/development/sdk/build_tools_source.prop_template"
    sed -i -e 's/Pkg\.Revision.*/Pkg\.Revision=${PLATFORM_SDK_VERSION}.0.0/g' $build_tools_source

    # build/bazel
    local codename_version="\"${FINAL_PLATFORM_CODENAME}\": ${FINAL_PLATFORM_SDK_VERSION}"
    if ! grep -q "$codename_version" "$top/build/bazel/rules/common/api_constants.bzl" ; then
        sed -i -e "/:.*$((${FINAL_PLATFORM_SDK_VERSION}-1)),/a \\    $codename_version," "$top/build/bazel/rules/common/api_constants.bzl"
    fi

    # cts
    echo ${FINAL_PLATFORM_VERSION} > "$top/cts/tests/tests/os/assets/platform_releases.txt"
    sed -i -e "s/EXPECTED_SDK = $((${FINAL_PLATFORM_SDK_VERSION}-1))/EXPECTED_SDK = ${FINAL_PLATFORM_SDK_VERSION}/g" "$top/cts/tests/tests/os/src/android/os/cts/BuildVersionTest.java"

    # libcore
    sed -i "s%$SDK_CODENAME%$SDK_VERSION%g" "$top/libcore/dalvik/src/main/java/dalvik/annotation/compat/VersionCodes.java"

    # platform_testing
    local version_codes="$top/platform_testing/libraries/compatibility-common-util/src/com/android/compatibility/common/util/VersionCodes.java"
    sed -i -e "/=.*$((${FINAL_PLATFORM_SDK_VERSION}-1));/a \\    ${SDK_VERSION}" $version_codes

    # tools/platform-compat
    local class2nonsdklist="$top/tools/platform-compat/java/com/android/class2nonsdklist/Class2NonSdkList.java"
    if ! grep -q "\.*map.put($((${FINAL_PLATFORM_SDK_VERSION}))" $class2nonsdklist ; then
      local sdk_version="map.put(${FINAL_PLATFORM_SDK_VERSION}, FLAG_UNSUPPORTED);"
      sed -i -e "/.*map.put($((${FINAL_PLATFORM_SDK_VERSION}-1))/a \\        ${sdk_version}" $class2nonsdklist
    fi

    # Finalize resources
    "$top/frameworks/base/tools/aapt2/tools/finalize_res.py" \
           "$top/frameworks/base/core/res/res/values/public-staging.xml" \
           "$top/frameworks/base/core/res/res/values/public-final.xml"

    # frameworks/base
    sed -i "s%$SDK_CODENAME%$SDK_VERSION%g" "$top/frameworks/base/core/java/android/os/Build.java"
    apply_resources_sdk_int_fix
    sed -i -e "/=.*$((${FINAL_PLATFORM_SDK_VERSION}-1)),/a \\    SDK_${FINAL_PLATFORM_CODENAME_JAVA} = ${FINAL_PLATFORM_SDK_VERSION}," "$top/frameworks/base/tools/aapt/SdkConstants.h"
    sed -i -e "/=.*$((${FINAL_PLATFORM_SDK_VERSION}-1)),/a \\  SDK_${FINAL_PLATFORM_CODENAME_JAVA} = ${FINAL_PLATFORM_SDK_VERSION}," "$top/frameworks/base/tools/aapt2/SdkConstants.h"

    # Bump Mainline SDK extension version.
    bumpSdkExtensionsVersion

    # target to build SDK
    local sdk_m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=fina_1 TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"

    # Force update current.txt
    $sdk_m clobber
    $sdk_m update-api
}

finalize_sdk_resources

