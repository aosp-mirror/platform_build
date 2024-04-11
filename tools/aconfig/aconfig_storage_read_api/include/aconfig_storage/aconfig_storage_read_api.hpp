#pragma once

#include <stdint.h>
#include <string>
#include <android-base/result.h>

namespace aconfig_storage {

/// Storage file type enum
enum StorageFileType {
  package_map,
  flag_map,
  flag_val,
  flag_info
};

/// Mapped storage file
struct MappedStorageFile {
  void* file_ptr;
  size_t file_size;
};

/// Package read context query result
struct PackageReadContext {
  bool package_exists;
  uint32_t package_id;
  uint32_t boolean_start_index;
};

/// Flag type enum, to be consistent with the one defined in aconfig_storage_file/src/lib.rs
enum StoredFlagType {
  ReadWriteBoolean = 0,
  ReadOnlyBoolean = 1,
  FixedReadOnlyBoolean = 2,
};

/// Flag read context query result
struct FlagReadContext {
  bool flag_exists;
  StoredFlagType flag_type;
  uint16_t flag_index;
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

/// Get package read context
/// \input file: mapped storage file
/// \input package: the flag package name
/// \returns a package read context
android::base::Result<PackageReadContext> get_package_read_context(
    MappedStorageFile const& file,
    std::string const& package);

/// Get flag read context
/// \input file: mapped storage file
/// \input package_id: the flag package id obtained from package offset query
/// \input flag_name: flag name
/// \returns the flag read context
android::base::Result<FlagReadContext> get_flag_read_context(
    MappedStorageFile const& file,
    uint32_t package_id,
    std::string const& flag_name);

/// Get boolean flag value
/// \input file: mapped storage file
/// \input index: the boolean flag index in the file
/// \returns the boolean flag value
android::base::Result<bool> get_boolean_flag_value(
    MappedStorageFile const& file,
    uint32_t index);

/// Flag info enum, to be consistent with the one defined in aconfig_storage_file/src/lib.rs
enum FlagInfoBit {
  IsSticky = 1<<0,
  IsReadWrite = 1<<1,
  HasOverride = 1<<2,
};

/// Get boolean flag attribute
/// \input file: mapped storage file
/// \input index: the boolean flag index in the file
/// \returns the boolean flag attribute
android::base::Result<uint8_t> get_boolean_flag_attribute(
    MappedStorageFile const& file,
    uint32_t index);
} // namespace aconfig_storage
