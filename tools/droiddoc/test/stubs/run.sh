#!/bin/sh
#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DIR=tools/droiddoc/test/stubs

pushd $TOP

. $TOP/$DIR/func.sh

mkdir -p out/stubs_compiled
find $DIR/src -name "*.java" | xargs javac -d out/stubs_compiled

build_stubs a $DIR/src $A_STUBS
build_stubs b $A_STUBS $B_STUBS

compile_stubs a $A_STUBS

echo EXPECTED
diff -r $DIR/expected $A_STUBS
echo TWICE STUBBED
diff -r $A_STUBS $B_STUBS

popd &> /dev/null



