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
  echo "VNDK library not in vndkMustUseVendorVariantList but has different core and vendor variant: $(basename ${CORE})"
  echo "If the two variants need to have different runtime behavior, consider using libvndksupport."
  exit 1
fi
