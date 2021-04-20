#!/bin/bash

# locate some directories
cd "$(dirname $0)"
SCRIPT_DIR="${PWD}"
cd ../..
TOP="${PWD}"

message='usage: banchan <module> ... [<product>|arm|x86|arm64|x86_64] [eng|userdebug|user]

banchan selects individual APEX modules to be built by the Android build system.
Like "tapas", "banchan" does not request the building of images for a device but
instead configures it for an unbundled build of the given modules, suitable for
installing on any api-compatible device.

The difference from "tapas" is that "banchan" sets the appropriate products etc
for building APEX modules rather than apps (APKs).

The module names should match apex{} modules in Android.bp files, typically
starting with "com.android.".

The product argument should be a product name ending in "_<arch>", where <arch>
is one of arm, x86, arm64, x86_64. It can also be just an arch, in which case
the standard product for building modules with that architecture is used, i.e.
module_<arch>.

The usage of the other arguments matches that of the rest of the platform
build system and can be found by running `m help`'

echo "$message"
