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
m -j [<goals>]              # Execute the configured build.

Usage of "m" imitates usage of the program "make".
See '"${SCRIPT_DIR}"'/Usage.txt for more info about build usage and concepts.

Common goals are:

    clean                   (aka clobber) equivalent to rm -rf out/
    checkbuild              Build every module defined in the source tree
    droid                   Default target
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
    psnod                   Quickly rebuild the product_services image from built packages
                            Stands for "ProductServices, NO Dependencies"
    onod                    Quickly rebuild the odm image from built packages
                            Stands for "ODM, NO Dependencies"


So, for example, you could run:

cd '"${TOP}"'
source build/envsetup.sh
lunch aosp_arm-userdebug
m -j java

to build all of the java code for the userdebug variant of the aosp_arm device.
'

echo "$message"
