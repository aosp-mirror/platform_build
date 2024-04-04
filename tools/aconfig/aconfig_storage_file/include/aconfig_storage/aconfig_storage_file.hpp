#pragma once

#include <stdint.h>
#include <string>
#include <android-base/result.h>

namespace aconfig_storage {
/// Create flag info file based on package and flag map
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \input flag_info_out: flag info file to be created
android::base::Result<void> create_flag_info(
    std::string const& package_map,
    std::string const& flag_map,
    std::string const& flag_info_out);
} // namespace aconfig_storage
