source build/envsetup.sh

# This function prefixes the given command with appropriate variables needed
# for the build to be executed with RBE.
function use_rbe() {
  local RBE_LOG_DIR="/tmp"
  local RBE_BINARIES_DIR="prebuilts/remoteexecution-client/latest/"
  local DOCKER_IMAGE="gcr.io/androidbuild-re-dockerimage/android-build-remoteexec-image@sha256:582efb38f0c229ea39952fff9e132ccbe183e14869b39888010dacf56b360d62"

  # Do not set an invocation-ID and let reproxy auto-generate one.
  USE_RBE="true" \
  FLAG_server_address="unix:///tmp/reproxy_$RANDOM.sock" \
  FLAG_exec_root="$(gettop)" \
  FLAG_platform="container-image=docker://${DOCKER_IMAGE}" \
  RBE_use_application_default_credentials="true" \
  RBE_log_dir="${RBE_LOG_DIR}" \
  RBE_reproxy_wait_seconds="20" \
  RBE_output_dir="${RBE_LOG_DIR}" \
  RBE_log_path="text://${RBE_LOG_DIR}/reproxy_log.txt" \
  RBE_CXX_EXEC_STRATEGY="remote_local_fallback" \
  RBE_cpp_dependency_scanner_plugin="${RBE_BINARIES_DIR}/dependency_scanner_go_plugin.so" \
  RBE_DIR=${RBE_BINARIES_DIR} \
  RBE_re_proxy="${RBE_BINARIES_DIR}/reproxy" \
  $@
}

# This function detects if the uploader is available and sets the path of it to
# ANDROID_ENABLE_METRICS_UPLOAD.
function _export_metrics_uploader() {
  local uploader_path="$(gettop)/vendor/google/misc/metrics_uploader_prebuilt/metrics_uploader.sh"
  if [ -x "${uploader_path}" ]; then
    export ANDROID_ENABLE_METRICS_UPLOAD="${uploader_path}"
  fi
}

# This function sets RBE specific environment variables needed for the build to
# executed by RBE. This file should be sourced once per checkout of Android code.
function _set_rbe_vars() {
  export USE_RBE="true"
  export RBE_CXX_EXEC_STRATEGY="remote_local_fallback"
  export RBE_JAVAC=1
  export RBE_R8=1
  export RBE_D8=1
}

_export_metrics_uploader
_set_rbe_vars
