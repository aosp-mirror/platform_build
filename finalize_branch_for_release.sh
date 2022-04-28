#!/bin/bash

set -e

source ../envsetup.sh

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

# TODO(b/229413853): test while simulating 'rel' for more requirements AIDL_FROZEN_REL=true
m # test build

# Build SDK (TODO)
# lunch sdk...
# m ...
