#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"
#include "aconfig_storage/aconfig_storage_file.hpp"

namespace aconfig_storage {
android::base::Result<void> create_flag_info(
    std::string const& package_map,
    std::string const& flag_map,
    std::string const& flag_info_out) {
  auto creation_cxx = create_flag_info_cxx(
      rust::Str(package_map.c_str()),
      rust::Str(flag_map.c_str()),
      rust::Str(flag_info_out.c_str()));
  if (creation_cxx.success) {
    return {};
  } else {
    return android::base::Error() << creation_cxx.error_message;
  }
}
} // namespace aconfig_storage
