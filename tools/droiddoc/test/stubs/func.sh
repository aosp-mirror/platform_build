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

export A_STUBS=out/stubs/a/stubs
export B_STUBS=out/stubs/b/stubs
export EXPECTED_STUBS=out/stubs/expected/stubs
export EXPECTED=$DIR/expected

function build_stubs()
{
    ID=$1
    SRC_DIR=$2
    STUBS_DIR=$3

    OBJ_DIR=out/stubs/$ID

    rm -rf $OBJ_DIR &> /dev/null
    mkdir -p $OBJ_DIR

    find $SRC_DIR -name '*.java' > $OBJ_DIR/javadoc-src-list
    ( \
        LD_LIBRARY_PATH=out/host/darwin-x86/lib \
        javadoc \
            \@$OBJ_DIR/javadoc-src-list \
            -J-Xmx512m \
            -J-Djava.library.path=out/host/darwin-x86/lib \
             \
            -quiet \
            -doclet DroidDoc \
            -docletpath out/host/darwin-x86/framework/clearsilver.jar:out/host/darwin-x86/framework/droiddoc.jar \
            -templatedir tools/droiddoc/templates \
            -classpath out/target/common/obj/JAVA_LIBRARIES/core_intermediates/classes.jar:out/target/common/obj/JAVA_LIBRARIES/ext_intermediates/classes.jar:out/target/common/obj/JAVA_LIBRARIES/framework_intermediates/classes.jar \
            -sourcepath $SRC_DIR:out/target/common/obj/JAVA_LIBRARIES/core_intermediates/classes.jar:out/target/common/obj/JAVA_LIBRARIES/ext_intermediates/classes.jar:out/target/common/obj/JAVA_LIBRARIES/framework_intermediates/classes.jar \
            -d $OBJ_DIR/docs \
            -hdf page.build MAIN-eng.joeo.20080710.121320 -hdf page.now "10 Jul 2008 12:13" \
            -stubs $STUBS_DIR \
            -stubpackages com.android.stubs:com.android.stubs.a:com.android.stubs.b:com.android.stubs.hidden \
        && rm -rf $OBJ_DIR/docs/assets \
        && mkdir -p $OBJ_DIR/docs/assets \
        && cp -fr tools/droiddoc/templates/assets/* $OBJ_DIR/docs/assets/ \
    )# || (rm -rf $OBJ_DIR; exit 45)
}

function compile_stubs()
{
    ID=$1
    STUBS_DIR=$2

    OBJ_DIR=out/stubs/$ID
    CLASS_DIR=$OBJ_DIR/class
    mkdir -p $CLASS_DIR

    find $STUBS_DIR -name "*.java" > $OBJ_DIR/java-src-list
    javac @$OBJ_DIR/java-src-list -d $CLASS_DIR
}
