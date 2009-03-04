# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Usage:
#
# Source this file into your environment.  Then:
#
#    $ golden_builds sdk-sdk generic-eng generic-userdebug dream-eng
# 
# will build a set of combos.  This might take a while.  Then you can
# go make changes, and run:
#
#    $ check_builds sdk-sdk generic-eng generic-userdebug dream-eng
#
# Go get dinner, and when you get back, there will be a file
# test-builds/sizes.html that has a pretty chart of which files are
# in which tree, and how big they are.  In that chart, cells for files
# that are missing are red, and rows where the file sizes are not all
# the same will be blue.
#

TEST_BUILD_DIR=test-builds

function do_builds
{
    PREFIX=$1
    shift
    while [ -n "$1" ]
    do
        rm -rf $TEST_BUILD_DIR/$PREFIX-$1
        make -j6 PRODUCT-$1 dist DIST_DIR=$TEST_BUILD_DIR/$PREFIX-$1
        if [ $? -ne 0 ] ; then
            echo FAILED
            return
        fi
        shift
    done
}

function golden_builds
{
    rm -rf $TEST_BUILD_DIR/golden-* $TEST_BUILD_DIR/dist-*
    do_builds golden "$@"
}

function check_builds
{
    rm -rf $TEST_BUILD_DIR/dist-*
    do_builds dist "$@"
    build/tools/compare_fileslist.py \
            $TEST_BUILD_DIR/golden-*/installed-files.txt \
            $TEST_BUILD_DIR/dist-*/installed-files.txt \
        > $TEST_BUILD_DIR/sizes.html
}

