#!/bin/bash

set -ex

export FINAL_BUG_ID='0' # CI only

export FINAL_PLATFORM_CODENAME='VanillaIceCream'
export CURRENT_PLATFORM_CODENAME='VanillaIceCream'
export FINAL_PLATFORM_CODENAME_JAVA='VANILLA_ICE_CREAM'
export FINAL_PLATFORM_VERSION='15'

# Set arbitrary large values for CI.
# SDK_VERSION needs to be <61 (lint/libs/lint-api/src/main/java/com/android/tools/lint/detector/api/ApiConstraint.kt)
# There are multiple places where we rely on next SDK version to be previous + 1, e.g. RESOURCES_SDK_INT.
# We might or might not fix this in future, but for now let's keep it +1.
export FINAL_PLATFORM_SDK_VERSION='35'
# Feel free to randomize once in a while to detect buggy version detection code.
export FINAL_MAINLINE_EXTENSION='58'

# Options:
# 'unfinalized' - branch is in development state,
# 'sdk' - SDK/API is finalized
# 'rel' - branch is finalized, switched to REL
export FINAL_STATE='unfinalized'

export BUILD_FROM_SOURCE_STUB=true