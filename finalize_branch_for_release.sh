#!/bin/bash

set -e

source "$(dirname "$0")"/envsetup.sh

# default target to modify tree and build SDK
lunch aosp_arm64-userdebug

set -x

# This script is WIP and only finalizes part of the Android branch for release.
# The full process can be found at (INTERNAL) go/android-sdk-finalization.

# VNDK snapshot (TODO)
# SDK snapshots (TODO)
# Update references in the codebase to new API version (TODO)
# ...

AIDL_TRANSITIVE_FREEZE=true m aidl-freeze-api

m check-vndk-list || update-vndk-list.sh # for new versions of AIDL interfaces

# for now, we simulate the release state for AIDL, but in the future, we would want
# to actually turn the branch into the REL state and test with that
AIDL_FROZEN_REL=true m # test build

# Build SDK (TODO)
# lunch sdk...
# m ...
