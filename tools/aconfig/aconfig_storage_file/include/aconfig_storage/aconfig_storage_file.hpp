#pragma once

#include <vector>
#include <string>
#include <android-base/result.h>

namespace aconfig_storage {

/// Flag value summary for a flag
struct FlagValueSummary {
  std::string package_name;
  std::string flag_name;
  std::string flag_value;
  std::string value_type;
};

/// List all flag values
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \input flag_val: flag value file
android::base::Result<std::vector<FlagValueSummary>> list_flags(
    const std::string& package_map,
    const std::string& flag_map,
    const std::string& flag_val);

/// Flag value and info summary for a flag
struct FlagValueAndInfoSummary {
  std::string package_name;
  std::string flag_name;
  std::string flag_value;
  std::string value_type;
  bool is_readwrite;
  bool has_server_override;
  bool has_local_override;
};

/// List all flag values with their flag info
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \input flag_val: flag value file
/// \input flag_info: flag info file
android::base::Result<std::vector<FlagValueAndInfoSummary>> list_flags_with_info(
    const std::string& package_map,
    const std::string& flag_map,
    const std::string& flag_val,
    const std::string& flag_info);

}// namespace aconfig_storage
