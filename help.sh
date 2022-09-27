#!/bin/bash

# locate some directories
cd "$(dirname $0)"
SCRIPT_DIR="${PWD}"
cd ../..
TOP="${PWD}"

message='The basic Android build process is:

cd '"${TOP}"'
source build/envsetup.sh    # Add "lunch" (and other utilities and variables)
                            # to the shell environment.
lunch [<product>-<variant>] # Choose the device to target.
m [<goals>]                 # Execute the configured build.

Usage of "m" imitates usage of the program "make".
See '"${SCRIPT_DIR}"'/Usage.txt for more info about build usage and concepts.

The parallelism of the build can be set with a -jN argument to "m".  If you
don'\''t provide a -j argument, the build system automatically selects a parallel
task count that it thinks is optimal for your system.

Common goals are:

    clean                   (aka clobber) equivalent to rm -rf out/
    checkbuild              Build every module defined in the source tree
    droid                   Default target
    sync                    Build everything in the default target except the images,
                            for use with adb sync.
    nothing                 Do not build anything, just parse and validate the build structure

    java                    Build all the java code in the source tree
    native                  Build all the native code in the source tree

    host                    Build all the host code (not to be run on a device) in the source tree
    target                  Build all the target code (to be run on the device) in the source tree

    (java|native)-(host|target)
    (host|target)-(java|native)
                            Build the intersection of the two given arguments

    snod                    Quickly rebuild the system image from built packages
                            Stands for "System, NO Dependencies"
    vnod                    Quickly rebuild the vendor image from built packages
                            Stands for "Vendor, NO Dependencies"
    pnod                    Quickly rebuild the product image from built packages
                            Stands for "Product, NO Dependencies"
    senod                   Quickly rebuild the system_ext image from built packages
                            Stands for "SystemExt, NO Dependencies"
    onod                    Quickly rebuild the odm image from built packages
                            Stands for "Odm, NO Dependencies"
    vdnod                   Quickly rebuild the vendor_dlkm image from built packages
                            Stands for "VendorDlkm, NO Dependencies"
    odnod                   Quickly rebuild the odm_dlkm image from built packages
                            Stands for "OdmDlkm, NO Dependencies"
    sdnod                   Quickly rebuild the system_dlkm image from built packages
                            Stands for "SystemDlkm, NO Dependencies"


So, for example, you could run:

cd '"${TOP}"'
source build/envsetup.sh
lunch aosp_arm-userdebug
m -j java

to build all of the java code for the userdebug variant of the aosp_arm device.
'

echo "$message"
