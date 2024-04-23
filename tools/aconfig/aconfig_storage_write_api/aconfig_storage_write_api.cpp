
#include <android-base/file.h>
#include <android-base/logging.h>
#include <protos/aconfig_storage_metadata.pb.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"
#include "aconfig_storage/aconfig_storage_write_api.hpp"

using storage_records_pb = android::aconfig_storage_metadata::storage_files;
using storage_record_pb = android::aconfig_storage_metadata::storage_file_info;
using namespace android::base;

namespace aconfig_storage {

/// Storage location pb file
static constexpr char kPersistStorageRecordsPb[] =
    "/metadata/aconfig/persistent_storage_file_records.pb";

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
        case StorageFileType::flag_info:
          return entry.flag_info();
        default:
          return Error() << "Invalid file type " << file_type;
      }
    }
  }

  return Error() << "Unable to find storage files for container " << container;
}


namespace private_internal_api {

/// Get mutable mapped file implementation.
Result<MutableMappedStorageFile> get_mutable_mapped_file_impl(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type) {
  if (file_type != StorageFileType::flag_val &&
      file_type != StorageFileType::flag_info) {
    return Error() << "Cannot create mutable mapped file for this file type";
  }

  auto file_result = find_storage_file(pb_file, container, file_type);
  if (!file_result.ok()) {
    return Error() << file_result.error();
  }

  return map_mutable_storage_file(*file_result);
}

} // namespace private internal api

/// Map a storage file
Result<MutableMappedStorageFile> map_mutable_storage_file(std::string const& file) {
  struct stat file_stat;
  if (stat(file.c_str(), &file_stat) < 0) {
    return ErrnoError() << "stat failed";
  }

  if ((file_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) == 0) {
    return Error() << "cannot map nonwriteable file";
  }

  size_t file_size = file_stat.st_size;

  const int fd = open(file.c_str(), O_RDWR | O_NOFOLLOW | O_CLOEXEC);
  if (fd == -1) {
    return ErrnoError() << "failed to open " << file;
  };

  void* const map_result =
      mmap(nullptr, file_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (map_result == MAP_FAILED) {
    return ErrnoError() << "mmap failed";
  }

  auto mapped_file = MutableMappedStorageFile();
  mapped_file.file_ptr = map_result;
  mapped_file.file_size = file_size;

  return mapped_file;
}

/// Get mutable mapped file
Result<MutableMappedStorageFile> get_mutable_mapped_file(
    std::string const& container,
    StorageFileType file_type) {
  return private_internal_api::get_mutable_mapped_file_impl(
      kPersistStorageRecordsPb, container, file_type);
}

/// Set boolean flag value
Result<void> set_boolean_flag_value(
    const MutableMappedStorageFile& file,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto update_cxx = update_boolean_flag_value_cxx(content, offset, value);
  if (!update_cxx.update_success) {
    return Error() << std::string(update_cxx.error_message.c_str());
  }
  return {};
}

/// Set if flag is sticky
Result<void> set_flag_is_sticky(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto update_cxx = update_flag_is_sticky_cxx(
      content, static_cast<uint16_t>(value_type), offset, value);
  if (!update_cxx.update_success) {
    return Error() << std::string(update_cxx.error_message.c_str());
  }
  return {};
}

/// Set if flag has override
Result<void> set_flag_has_override(
    const MutableMappedStorageFile& file,
    FlagValueType value_type,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto update_cxx = update_flag_has_override_cxx(
      content, static_cast<uint16_t>(value_type), offset, value);
  if (!update_cxx.update_success) {
    return Error() << std::string(update_cxx.error_message.c_str());
  }
  return {};
}

Result<void> create_flag_info(
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
