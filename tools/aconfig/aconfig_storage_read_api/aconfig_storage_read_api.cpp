#include <android-base/unique_fd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"
#include "aconfig_storage/aconfig_storage_read_api.hpp"

namespace aconfig_storage {

/// Storage location pb file
static constexpr char kStorageDir[] = "/metadata/aconfig";

/// destructor
MappedStorageFile::~MappedStorageFile() {
  munmap(file_ptr, file_size);
}

/// Get storage file path
static Result<std::string> find_storage_file(
    std::string const& storage_dir,
    std::string const& container,
    StorageFileType file_type) {
  switch(file_type) {
    case StorageFileType::package_map:
      return storage_dir + "/maps/" + container + ".package.map";
    case StorageFileType::flag_map:
      return storage_dir + "/maps/" + container + ".flag.map";
    case StorageFileType::flag_val:
      return storage_dir + "/boot/" + container + ".val";
    case StorageFileType::flag_info:
      return storage_dir + "/boot/" + container + ".info";
    default:
      auto result = Result<std::string>();
      result.errmsg = "Invalid storage file type";
      return result;
  }
}

namespace private_internal_api {

/// Get mapped file implementation.
Result<MappedStorageFile*> get_mapped_file_impl(
    std::string const& storage_dir,
    std::string const& container,
    StorageFileType file_type) {
  auto file_result = find_storage_file(storage_dir, container, file_type);
  if (!file_result.ok()) {
    auto result = Result<MappedStorageFile*>();
    result.errmsg = file_result.error();
    return result;
  }
  return map_storage_file(*file_result);
}

} // namespace private internal api

/// Map a storage file
Result<MappedStorageFile*> map_storage_file(std::string const& file) {
  android::base::unique_fd ufd(open(file.c_str(), O_CLOEXEC | O_NOFOLLOW | O_RDONLY));
  if (ufd.get() == -1) {
    auto result = Result<MappedStorageFile*>();
    result.errmsg = std::string("failed to open ") + file + ": " + strerror(errno);
    return result;
  };

  struct stat fd_stat;
  if (fstat(ufd.get(), &fd_stat) < 0) {
    auto result = Result<MappedStorageFile*>();
    result.errmsg = std::string("fstat failed: ") + strerror(errno);
    return result;
  }
  size_t file_size = fd_stat.st_size;

  void* const map_result = mmap(nullptr, file_size, PROT_READ, MAP_SHARED, ufd.get(), 0);
  if (map_result == MAP_FAILED) {
    auto result = Result<MappedStorageFile*>();
    result.errmsg = std::string("mmap failed: ") + strerror(errno);
    return result;
  }

  auto mapped_file = new MappedStorageFile();
  mapped_file->file_ptr = map_result;
  mapped_file->file_size = file_size;

  return mapped_file;
}

/// Map from StoredFlagType to FlagValueType
Result<FlagValueType> map_to_flag_value_type(
    StoredFlagType stored_type) {
  switch (stored_type) {
    case StoredFlagType::ReadWriteBoolean:
    case StoredFlagType::ReadOnlyBoolean:
    case StoredFlagType::FixedReadOnlyBoolean:
      return FlagValueType::Boolean;
    default:
      auto result = Result<FlagValueType>();
      result.errmsg = "Unsupported stored flag type";
      return result;
  }
}

/// Get mapped storage file
Result<MappedStorageFile*> get_mapped_file(
    std::string const& container,
    StorageFileType file_type) {
  return private_internal_api::get_mapped_file_impl(
      kStorageDir, container, file_type);
}

/// Get storage file version number
Result<uint32_t> get_storage_file_version(
    std::string const& file_path) {
  auto version_cxx = get_storage_file_version_cxx(
      rust::Str(file_path.c_str()));
  if (version_cxx.query_success) {
    return version_cxx.version_number;
  } else {
    auto result = Result<uint32_t>();
    result.errmsg = version_cxx.error_message.c_str();
    return result;
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
    auto result = Result<PackageReadContext>();
    result.errmsg = context_cxx.error_message.c_str();
    return result;
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
    auto result = Result<FlagReadContext>();
    result.errmsg = context_cxx.error_message.c_str();
    return result;
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
    auto result = Result<bool>();
    result.errmsg = value_cxx.error_message.c_str();
    return result;
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
    auto result = Result<uint8_t>();
    result.errmsg = info_cxx.error_message.c_str();
    return result;
  }
}
} // namespace aconfig_storage
