#!/bin/bash

set -ex

export FINAL_BUG_ID='275409981'

export FINAL_PLATFORM_CODENAME='UpsideDownCake'
export CURRENT_PLATFORM_CODENAME='VanillaIceCream'
export FINAL_PLATFORM_CODENAME_JAVA='UPSIDE_DOWN_CAKE'
export FINAL_PLATFORM_SDK_VERSION='34'
export FINAL_PLATFORM_VERSION='14'

export FINAL_BUILD_PREFIX='UP1A'

export FINAL_MAINLINE_EXTENSION='7'

# Options:
# 'unfinalized' - branch is in development state,
# 'sdk' - SDK/API is finalized
# 'rel' - branch is finalized, switched to REL
export FINAL_STATE='unfinalized'
