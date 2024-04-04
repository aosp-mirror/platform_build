
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
    std::string const& container) {
  auto records_pb = read_storage_records_pb(pb_file);
  if (!records_pb.ok()) {
    return Error() << "Unable to read storage records from " << pb_file
                   << " : " << records_pb.error();
  }

  for (auto& entry : records_pb->files()) {
    if (entry.container() == container) {
        return entry.flag_val();
    }
  }

  return Error() << "Unable to find storage files for container " << container;;
}

/// Map a storage file
static Result<MappedFlagValueFile> map_storage_file(std::string const& file) {
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

  auto mapped_file = MappedFlagValueFile();
  mapped_file.file_ptr = map_result;
  mapped_file.file_size = file_size;

  return mapped_file;
}

namespace private_internal_api {

/// Get mapped file implementation.
Result<MappedFlagValueFile> get_mapped_flag_value_file_impl(
    std::string const& pb_file,
    std::string const& container) {
  auto file_result = find_storage_file(pb_file, container);
  if (!file_result.ok()) {
    return Error() << file_result.error();
  }
  auto mapped_result = map_storage_file(*file_result);
  if (!mapped_result.ok()) {
    return Error() << "failed to map " << *file_result << ": "
                   << mapped_result.error();
  }
  return *mapped_result;
}

} // namespace private internal api

/// Get mapped writeable flag value file
Result<MappedFlagValueFile> get_mapped_flag_value_file(
    std::string const& container) {
  return private_internal_api::get_mapped_flag_value_file_impl(
      kPersistStorageRecordsPb, container);
}

/// Set boolean flag value
Result<void> set_boolean_flag_value(
    const MappedFlagValueFile& file,
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
