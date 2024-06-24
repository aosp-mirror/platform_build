
#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/unique_fd.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"
#include "aconfig_storage/aconfig_storage_write_api.hpp"

namespace aconfig_storage {

/// Map a storage file
android::base::Result<MutableMappedStorageFile *> map_mutable_storage_file(
    std::string const &file) {
  struct stat file_stat;
  if (stat(file.c_str(), &file_stat) < 0) {
    return android::base::ErrnoError() << "stat failed";
  }

  if ((file_stat.st_mode & (S_IWUSR | S_IWGRP | S_IWOTH)) == 0) {
    return android::base::Error() << "cannot map nonwriteable file";
  }

  size_t file_size = file_stat.st_size;

  android::base::unique_fd ufd(open(file.c_str(), O_RDWR | O_NOFOLLOW | O_CLOEXEC));
  if (ufd.get() == -1) {
    return android::base::ErrnoError() << "failed to open " << file;
  };

  void *const map_result =
      mmap(nullptr, file_size, PROT_READ | PROT_WRITE, MAP_SHARED, ufd.get(), 0);
  if (map_result == MAP_FAILED) {
    return android::base::ErrnoError() << "mmap failed";
  }

  auto mapped_file = new MutableMappedStorageFile();
  mapped_file->file_ptr = map_result;
  mapped_file->file_size = file_size;

  return mapped_file;
}

/// Set boolean flag value
android::base::Result<void> set_boolean_flag_value(
    const MutableMappedStorageFile &file,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t *>(file.file_ptr), file.file_size);
  auto update_cxx = update_boolean_flag_value_cxx(content, offset, value);
  if (!update_cxx.update_success) {
    return android::base::Error() << update_cxx.error_message.c_str();
  }
  if (!msync(static_cast<uint8_t *>(file.file_ptr) + update_cxx.offset, 1, MS_SYNC)) {
    return android::base::ErrnoError() << "msync failed";
  }
  return {};
}

/// Set if flag has server override
android::base::Result<void> set_flag_has_server_override(
    const MutableMappedStorageFile &file,
    FlagValueType value_type,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t *>(file.file_ptr), file.file_size);
  auto update_cxx = update_flag_has_server_override_cxx(
      content, static_cast<uint16_t>(value_type), offset, value);
  if (!update_cxx.update_success) {
    return android::base::Error() << update_cxx.error_message.c_str();
  }
  if (!msync(static_cast<uint8_t *>(file.file_ptr) + update_cxx.offset, 1, MS_SYNC)) {
    return android::base::ErrnoError() << "msync failed";
  }
  return {};
}

/// Set if flag has local override
android::base::Result<void> set_flag_has_local_override(
    const MutableMappedStorageFile &file,
    FlagValueType value_type,
    uint32_t offset,
    bool value) {
  auto content = rust::Slice<uint8_t>(
      static_cast<uint8_t *>(file.file_ptr), file.file_size);
  auto update_cxx = update_flag_has_local_override_cxx(
      content, static_cast<uint16_t>(value_type), offset, value);
  if (!update_cxx.update_success) {
    return android::base::Error() << update_cxx.error_message.c_str();
  }
  if (!msync(static_cast<uint8_t *>(file.file_ptr) + update_cxx.offset, 1, MS_SYNC)) {
    return android::base::ErrnoError() << "msync failed";
  }
  return {};
}

android::base::Result<void> create_flag_info(
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
