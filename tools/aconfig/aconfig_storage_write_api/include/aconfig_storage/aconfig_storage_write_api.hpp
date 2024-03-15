#pragma once

#include <stdint.h>
#include <string>

#include <android-base/result.h>

using namespace android::base;

namespace aconfig_storage {

/// Mapped flag value file
struct MappedFlagValueFile{
  void* file_ptr;
  size_t file_size;
};

/// DO NOT USE APIS IN THE FOLLOWING NAMESPACE DIRECTLY
namespace private_internal_api {

Result<MappedFlagValueFile> get_mapped_flag_value_file_impl(
    std::string const& pb_file,
    std::string const& container);

} // namespace private_internal_api

/// Get mapped writeable flag value file
Result<MappedFlagValueFile> get_mapped_flag_value_file(
    std::string const& container);

/// Set boolean flag value
Result<void> set_boolean_flag_value(
    const MappedFlagValueFile& file,
    uint32_t offset,
    bool value);

} // namespace aconfig_storage
