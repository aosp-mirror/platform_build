#pragma once

#include <stdint.h>
#include <string>

#include <android-base/result.h>
#include <aconfig_storage/aconfig_storage_read_api.hpp>


namespace aconfig_storage {

/// Mapped flag value file
struct MutableMappedStorageFile : MappedStorageFile {};

/// Map a storage file
android::base::Result<MutableMappedStorageFile*> map_mutable_storage_file(
    std::string const& file);

/// Set boolean flag value
android::base::Result<void> set_boolean_flag_value(
    const MutableMappedStorageFile& file,
    uint32_t offset,
    bool value);

/// Set if flag has server override
android::base::Result<void> set_flag_has_server_override(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value);

/// Set if flag has local override
android::base::Result<void> set_flag_has_local_override(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value);

/// Create flag info file based on package and flag map
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \input flag_info_out: flag info file to be created
android::base::Result<void> create_flag_info(
    std::string const& package_map,
    std::string const& flag_map,
    std::string const& flag_info_out);

} // namespace aconfig_storage
