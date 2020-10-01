#!/bin/bash
set -e

STRIP_PATH="${1}"
CORE="${2}"
VENDOR="${3}"

TMPDIR="$(mktemp -d ${CORE}.vndk_lib_check.XXXXXXXX)"
stripped_core="${TMPDIR}/core"
stripped_vendor="${TMPDIR}/vendor"

function cleanup() {
  rm -f "${stripped_core}" "${stripped_vendor}"
  rmdir "${TMPDIR}"
}
trap cleanup EXIT

function strip_lib() {
  ${STRIP_PATH} \
    -i ${1} \
    -o ${2} \
    -d /dev/null \
    --remove-build-id
}

strip_lib ${CORE} ${stripped_core}
strip_lib ${VENDOR} ${stripped_vendor}
if ! cmp -s ${stripped_core} ${stripped_vendor}; then
  echo "ERROR: VNDK library $(basename ${CORE%.so}) has different core and" \
    "vendor variants! This means that the copy used in the system.img/etc" \
    "and vendor.img/etc images are different. In order to preserve space on" \
    "some devices, it is helpful if they are the same. Frequently, " \
    "libraries are different because they or their dependencies compile" \
    "things based on the macro '__ANDROID_VNDK__' or they specify custom" \
    "options under 'target: { vendor: { ... } }'. Here are some possible" \
    "resolutions:"
  echo "ERROR: 1). Remove differences, possibly using the libvndksupport" \
    "function android_is_in_vendor_process in order to turn this into a" \
    "runtime difference."
  echo "ERROR: 2). Add the library to the VndkMustUseVendorVariantList" \
    "variable in build/soong/cc/config/vndk.go, which is used to" \
    "acknowledge this difference."
  exit 1
fi
