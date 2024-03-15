#pragma once

#include <stdint.h>
#include <string>
#include <android-base/result.h>

namespace aconfig_storage {

/// Storage file type enum
enum StorageFileType {
  package_map,
  flag_map,
  flag_val
};

/// Mapped storage file
struct MappedStorageFile {
  void* file_ptr;
  size_t file_size;
};

/// Package offset query result
struct PackageOffset {
  bool package_exists;
  uint32_t package_id;
  uint32_t boolean_offset;
};

/// Flag offset query result
struct FlagOffset {
  bool flag_exists;
  uint16_t flag_offset;
};

/// DO NOT USE APIS IN THE FOLLOWING NAMESPACE DIRECTLY
namespace private_internal_api {

android::base::Result<MappedStorageFile> get_mapped_file_impl(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type);

} // namespace private_internal_api

/// Get mapped storage file
/// \input container: stoarge container name
/// \input file_type: storage file type enum
/// \returns a MappedStorageFileQuery
android::base::Result<MappedStorageFile> get_mapped_file(
    std::string const& container,
    StorageFileType file_type);

/// Get storage file version number
/// \input file_path: the path to the storage file
/// \returns the storage file version
android::base::Result<uint32_t> get_storage_file_version(
    std::string const& file_path);

/// Get package offset
/// \input file: mapped storage file
/// \input package: the flag package name
/// \returns a package offset
android::base::Result<PackageOffset> get_package_offset(
    MappedStorageFile const& file,
    std::string const& package);

/// Get flag offset
/// \input file: mapped storage file
/// \input package_id: the flag package id obtained from package offset query
/// \input flag_name: flag name
/// \returns the flag offset
android::base::Result<FlagOffset> get_flag_offset(
    MappedStorageFile const& file,
    uint32_t package_id,
    std::string const& flag_name);

/// Get boolean flag value
/// \input file: mapped storage file
/// \input offset: the boolean flag value byte offset in the file
/// \returns the boolean flag value
android::base::Result<bool> get_boolean_flag_value(
    MappedStorageFile const& file,
    uint32_t offset);

} // namespace aconfig_storage
