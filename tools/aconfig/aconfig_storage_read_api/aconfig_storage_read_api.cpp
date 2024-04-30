#include <android-base/file.h>
#include <android-base/logging.h>
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
    "/metadata/aconfig/boot/available_storage_file_records.pb";

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

  return Error() << "Unable to find storage files for container " << container;;
}

namespace private_internal_api {

/// Get mapped file implementation.
Result<MappedStorageFile> get_mapped_file_impl(
    std::string const& pb_file,
    std::string const& container,
    StorageFileType file_type) {
  auto file_result = find_storage_file(pb_file, container, file_type);
  if (!file_result.ok()) {
    return Error() << file_result.error();
  }
  return map_storage_file(*file_result);
}

} // namespace private internal api

/// Map a storage file
Result<MappedStorageFile> map_storage_file(std::string const& file) {
  int fd = open(file.c_str(), O_CLOEXEC | O_NOFOLLOW | O_RDONLY);
  if (fd == -1) {
    return ErrnoError() << "failed to open " << file;
  };

  struct stat fd_stat;
  if (fstat(fd, &fd_stat) < 0) {
    return ErrnoError() << "fstat failed";
  }
  size_t file_size = fd_stat.st_size;

  void* const map_result = mmap(nullptr, file_size, PROT_READ, MAP_SHARED, fd, 0);
  if (map_result == MAP_FAILED) {
    return ErrnoError() << "mmap failed";
  }

  auto mapped_file = MappedStorageFile();
  mapped_file.file_ptr = map_result;
  mapped_file.file_size = file_size;

  return mapped_file;
}

/// Map from StoredFlagType to FlagValueType
android::base::Result<FlagValueType> map_to_flag_value_type(
    StoredFlagType stored_type) {
  switch (stored_type) {
    case StoredFlagType::ReadWriteBoolean:
    case StoredFlagType::ReadOnlyBoolean:
    case StoredFlagType::FixedReadOnlyBoolean:
      return FlagValueType::Boolean;
    default:
      return Error() << "Unsupported stored flag type";
  }
}

/// Get mapped storage file
Result<MappedStorageFile> get_mapped_file(
    std::string const& container,
    StorageFileType file_type) {
  return private_internal_api::get_mapped_file_impl(
      kAvailableStorageRecordsPb, container, file_type);
}

/// Get storage file version number
Result<uint32_t> get_storage_file_version(
    std::string const& file_path) {
  auto version_cxx = get_storage_file_version_cxx(
      rust::Str(file_path.c_str()));
  if (version_cxx.query_success) {
    return version_cxx.version_number;
  } else {
    return Error() << version_cxx.error_message;
  }
}

/// Get package context
Result<PackageReadContext> get_package_read_context(
    MappedStorageFile const& file,
    std::string const& package) {
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto context_cxx = get_package_read_context_cxx(content, rust::Str(package.c_str()));
  if (context_cxx.query_success) {
    auto context = PackageReadContext();
    context.package_exists = context_cxx.package_exists;
    context.package_id = context_cxx.package_id;
    context.boolean_start_index = context_cxx.boolean_start_index;
    return context;
  } else {
    return Error() << context_cxx.error_message;
  }
}

/// Get flag read context
Result<FlagReadContext> get_flag_read_context(
    MappedStorageFile const& file,
    uint32_t package_id,
    std::string const& flag_name){
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto context_cxx = get_flag_read_context_cxx(content, package_id, rust::Str(flag_name.c_str()));
  if (context_cxx.query_success) {
    auto context = FlagReadContext();
    context.flag_exists = context_cxx.flag_exists;
    context.flag_type = static_cast<StoredFlagType>(context_cxx.flag_type);
    context.flag_index = context_cxx.flag_index;
    return context;
  } else {
   return Error() << context_cxx.error_message;
  }
}

/// Get boolean flag value
Result<bool> get_boolean_flag_value(
    MappedStorageFile const& file,
    uint32_t index) {
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto value_cxx = get_boolean_flag_value_cxx(content, index);
  if (value_cxx.query_success) {
    return value_cxx.flag_value;
  } else {
    return Error() << value_cxx.error_message;
  }
}

/// Get boolean flag attribute
Result<uint8_t> get_flag_attribute(
    MappedStorageFile const& file,
    FlagValueType value_type,
    uint32_t index) {
  auto content = rust::Slice<const uint8_t>(
      static_cast<uint8_t*>(file.file_ptr), file.file_size);
  auto info_cxx = get_flag_attribute_cxx(
      content, static_cast<uint16_t>(value_type), index);
  if (info_cxx.query_success) {
    return info_cxx.flag_attribute;
  } else {
    return Error() << info_cxx.error_message;
  }
}
} // namespace aconfig_storage
