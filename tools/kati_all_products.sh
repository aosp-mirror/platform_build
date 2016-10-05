#!/bin/bash -e

cd $ANDROID_BUILD_TOP
mkdir -p out.kati
source build/envsetup.sh

get_build_var all_named_products | sed "s/ /\n/g" | parallel "$@" --progress "(source build/envsetup.sh; lunch {}-eng && m -j OUT_DIR=out.kati/{} out.kati/{}/build-{}.ninja) >out.kati/log.{} 2>&1"
