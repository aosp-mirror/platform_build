#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/result.h>
#include <protos/aconfig_storage_metadata.pb.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"
#include "aconfig_storage/aconfig_storage_read_api.hpp"

using storage_records_pb = android::aconfig_storage_metadata::storage_files;
using storage_record_pb = android::aconfig_storage_metadata::storage_file_info;
using namespace android::base;

namespace aconfig_storage {

/// Storage location pb file
static constexpr char kAvailableStorageRecordsPb[] =
    "/metadata/aconfig/available_storage_file_records.pb";

/// Read aconfig storage records pb file
static Result<storage_records_pb> read_storage_records_pb(std::string const& pb_file) {
  auto records = storage_records_pb();
  auto content = std::string();
  if (!ReadFileToString(pb_file, &content)) {
    return ErrnoError() << "ReadFileToString failed";
  }

  if (!records.ParseFromString(content)) {
    return ErrnoError() << "Unable to parse persistent storage records protobuf";
  }
  return records;
}

/// Get storage file path
static Result<std::string> find_storage_file(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type) {
  auto records_pb = read_storage_records_pb(pb_file);
  if (!records_pb.ok()) {
    return Error() << "Unable to read storage records from " << pb_file
                   << " : " << records_pb.error();
  }

  for (auto& entry : records_pb->files()) {
    if (entry.container() == container) {
      switch(file_type) {
        case StorageFileType::package_map:
          return entry.package_map();
        case StorageFileType::flag_map:
          return entry.flag_map();
        case StorageFileType::flag_val:
          return entry.flag_val();
        default:
          return Error() << "Invalid file type " << file_type;
      }
    }
  }

  return Error() << "Unable to find storage files for container " << container;;
}

/// Map a storage file
static Result<MappedStorageFile> map_storage_file(std::string const& file) {
  int fd = open(file.c_str(), O_CLOEXEC | O_NOFOLLOW | O_RDONLY);
  if (fd == -1) {
    return Error() << "failed to open " << file;
  };

  struct stat fd_stat;
  if (fstat(fd, &fd_stat) < 0) {
    return Error() << "fstat failed";
  }

  if ((fd_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) != 0) {
    return Error() << "cannot map writeable file";
  }

  size_t file_size = fd_stat.st_size;

  void* const map_result = mmap(nullptr, file_size, PROT_READ, MAP_SHARED, fd, 0);
  if (map_result == MAP_FAILED) {
    return Error() << "mmap failed";
  }

  auto mapped_file = MappedStorageFile();
  mapped_file.file_ptr = map_result;
  mapped_file.file_size = file_size;

  return mapped_file;
}

namespace private_internal_api {

/// Get mapped file implementation.
MappedStorageFileQuery get_mapped_file_impl(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type) {
  auto query =  MappedStorageFileQuery();

  auto file_result = find_storage_file(pb_file, container, file_type);
  if (!file_result.ok()) {
    query.query_success = false;
    query.error_message = file_result.error().message();
    query.mapped_file.file_ptr = nullptr;
    query.mapped_file.file_size = 0;
    return query;
  }

  auto mapped_file_result = map_storage_file(*file_result);
  if (!mapped_file_result.ok()) {
    query.query_success = false;
    query.error_message = mapped_file_result.error().message();
    query.mapped_file.file_ptr = nullptr;
    query.mapped_file.file_size = 0;
  } else {
    query.query_success = true;
    query.error_message = "";
    query.mapped_file = *mapped_file_result;
  }

  return query;
}

} // namespace private internal api

/// Get mapped storage file
MappedStorageFileQuery get_mapped_file(
    std::string const& container,
    StorageFileType file_type) {
  return private_internal_api::get_mapped_file_impl(
      kAvailableStorageRecordsPb, container, file_type);
}

/// Get storage file version number
VersionNumberQuery get_storage_file_version(
    std::string const& file_path) {
  auto version_cxx = get_storage_file_version_cxx(
      rust::Str(file_path.c_str()));
  auto version = VersionNumberQuery();
  version.query_success = version_cxx.query_success;
  version.error_message = std::string(version_cxx.error_message.c_str());
  version.version_number = version_cxx.version_number;
  return version;
}

/// Get package offset
PackageOffsetQuery get_package_offset(
    MappedStorageFile const& file,
    std::string const& package) {
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto offset_cxx = get_package_offset_cxx(content, rust::Str(package.c_str()));
  auto offset = PackageOffsetQuery();
  offset.query_success = offset_cxx.query_success;
  offset.error_message = std::string(offset_cxx.error_message.c_str());
  offset.package_exists = offset_cxx.package_exists;
  offset.package_id = offset_cxx.package_id;
  offset.boolean_offset = offset_cxx.boolean_offset;
  return offset;
}

/// Get flag offset
FlagOffsetQuery get_flag_offset(
    MappedStorageFile const& file,
    uint32_t package_id,
    std::string const& flag_name){
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto offset_cxx = get_flag_offset_cxx(content, package_id, rust::Str(flag_name.c_str()));
  auto offset = FlagOffsetQuery();
  offset.query_success = offset_cxx.query_success;
  offset.error_message = std::string(offset_cxx.error_message.c_str());
  offset.flag_exists = offset_cxx.flag_exists;
  offset.flag_offset = offset_cxx.flag_offset;
  return offset;
}

/// Get boolean flag value
BooleanFlagValueQuery get_boolean_flag_value(
    MappedStorageFile const& file,
    uint32_t offset) {
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto value_cxx = get_boolean_flag_value_cxx(content, offset);
  auto value = BooleanFlagValueQuery();
  value.query_success = value_cxx.query_success;
  value.error_message = std::string(value_cxx.error_message.c_str());
  value.flag_value = value_cxx.flag_value;
  return value;
}

} // namespace aconfig_storage
