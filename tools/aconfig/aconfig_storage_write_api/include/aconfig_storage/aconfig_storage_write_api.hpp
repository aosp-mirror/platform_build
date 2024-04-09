#pragma once

#include <stdint.h>
#include <string>

#include <android-base/result.h>
#include <aconfig_storage/aconfig_storage_read_api.hpp>

using namespace android::base;

namespace aconfig_storage {

/// Mapped flag value file
struct MutableMappedStorageFile{
  void* file_ptr;
  size_t file_size;
};

/// DO NOT USE APIS IN THE FOLLOWING NAMESPACE DIRECTLY
namespace private_internal_api {

Result<MutableMappedStorageFile> get_mutable_mapped_file_impl(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type);

} // namespace private_internal_api

/// Get mapped writeable storage file
Result<MutableMappedStorageFile> get_mutable_mapped_file(
    std::string const& container,
    StorageFileType file_type);

/// Set boolean flag value
Result<void> set_boolean_flag_value(
    const MutableMappedStorageFile& file,
    uint32_t offset,
    bool value);

/// Set if flag is sticky
Result<void> set_flag_is_sticky(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value);

/// Set if flag has override
Result<void> set_flag_has_override(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value);

/// Create flag info file based on package and flag map
/// \input package_map: package map file
/// \input flag_map: flag map file
/// \input flag_info_out: flag info file to be created
Result<void> create_flag_info(
    std::string const& package_map,
    std::string const& flag_map,
    std::string const& flag_info_out);

} // namespace aconfig_storage
