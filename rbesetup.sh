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
