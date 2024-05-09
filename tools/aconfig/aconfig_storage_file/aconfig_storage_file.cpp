#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"

#include "aconfig_storage/aconfig_storage_file.hpp"

using namespace android::base;

namespace aconfig_storage {

Result<std::vector<FlagValueSummary>> list_flags(
    const std::string& package_map,
    const std::string& flag_map,
    const std::string& flag_val) {
  auto flag_list_cxx = list_flags_cxx(rust::Str(package_map.c_str()),
                                      rust::Str(flag_map.c_str()),
                                      rust::Str(flag_val.c_str()));
  if (flag_list_cxx.query_success) {
    auto flag_list = std::vector<FlagValueSummary>();
    for (const auto& flag_cxx : flag_list_cxx.flags) {
      auto flag = FlagValueSummary();
      flag.package_name = std::string(flag_cxx.package_name);
      flag.flag_name = std::string(flag_cxx.flag_name);
      flag.flag_value = std::string(flag_cxx.flag_value);
      flag.value_type = std::string(flag_cxx.value_type);
      flag_list.push_back(flag);
    }
    return flag_list;
  } else {
    return Error() << flag_list_cxx.error_message;
  }
}

Result<std::vector<FlagValueAndInfoSummary>> list_flags_with_info(
    const std::string& package_map,
    const std::string& flag_map,
    const std::string& flag_val,
    const std::string& flag_info) {
  auto flag_list_cxx = list_flags_with_info_cxx(rust::Str(package_map.c_str()),
                                                rust::Str(flag_map.c_str()),
                                                rust::Str(flag_val.c_str()),
                                                rust::Str(flag_info.c_str()));
  if (flag_list_cxx.query_success) {
    auto flag_list = std::vector<FlagValueAndInfoSummary>();
    for (const auto& flag_cxx : flag_list_cxx.flags) {
      auto flag = FlagValueAndInfoSummary();
      flag.package_name = std::string(flag_cxx.package_name);
      flag.flag_name = std::string(flag_cxx.flag_name);
      flag.flag_value = std::string(flag_cxx.flag_value);
      flag.value_type = std::string(flag_cxx.value_type);
      flag.is_readwrite = flag_cxx.is_readwrite;
      flag.has_server_override = flag_cxx.has_server_override;
      flag.has_local_override = flag_cxx.has_local_override;
      flag_list.push_back(flag);
    }
    return flag_list;
  } else {
    return Error() << flag_list_cxx.error_message;
  }
}

} // namespace aconfig_storage
