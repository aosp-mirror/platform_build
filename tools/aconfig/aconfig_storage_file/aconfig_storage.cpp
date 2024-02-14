#include "aconfig_storage/aconfig_storage.hpp"

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"

namespace aconfig_storage {

/// Get package offset
PackageOffsetQuery get_package_offset(
    std::string const& container,
    std::string const& package) {
  auto offset_cxx =  get_package_offset_cxx(
      rust::Str(container.c_str()),
      rust::Str(package.c_str()));
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
    std::string const& container,
    uint32_t package_id,
    std::string const& flag_name) {
  auto offset_cxx =  get_flag_offset_cxx(
      rust::Str(container.c_str()),
      package_id,
      rust::Str(flag_name.c_str()));
  auto offset = FlagOffsetQuery();
  offset.query_success = offset_cxx.query_success;
  offset.error_message = std::string(offset_cxx.error_message.c_str());
  offset.flag_exists = offset_cxx.flag_exists;
  offset.flag_offset = offset_cxx.flag_offset;
  return offset;
}

/// Get boolean flag value
BooleanFlagValueQuery get_boolean_flag_value(
    std::string const& container,
    uint32_t offset) {
  auto value_cxx =  get_boolean_flag_value_cxx(
      rust::Str(container.c_str()),
      offset);
  auto value = BooleanFlagValueQuery();
  value.query_success = value_cxx.query_success;
  value.error_message = std::string(value_cxx.error_message.c_str());
  value.flag_value = value_cxx.flag_value;
  return value;
}

namespace test_only_api {
PackageOffsetQuery get_package_offset_impl(
    std::string const& pb_file,
    std::string const& container,
    std::string const& package) {
  auto offset_cxx =  get_package_offset_cxx_impl(
      rust::Str(pb_file.c_str()),
      rust::Str(container.c_str()),
      rust::Str(package.c_str()));
  auto offset = PackageOffsetQuery();
  offset.query_success = offset_cxx.query_success;
  offset.error_message = std::string(offset_cxx.error_message.c_str());
  offset.package_exists = offset_cxx.package_exists;
  offset.package_id = offset_cxx.package_id;
  offset.boolean_offset = offset_cxx.boolean_offset;
  return offset;
}

FlagOffsetQuery get_flag_offset_impl(
    std::string const& pb_file,
    std::string const& container,
    uint32_t package_id,
    std::string const& flag_name) {
  auto offset_cxx =  get_flag_offset_cxx_impl(
      rust::Str(pb_file.c_str()),
      rust::Str(container.c_str()),
      package_id,
      rust::Str(flag_name.c_str()));
  auto offset = FlagOffsetQuery();
  offset.query_success = offset_cxx.query_success;
  offset.error_message = std::string(offset_cxx.error_message.c_str());
  offset.flag_exists = offset_cxx.flag_exists;
  offset.flag_offset = offset_cxx.flag_offset;
  return offset;
}

BooleanFlagValueQuery get_boolean_flag_value_impl(
    std::string const& pb_file,
    std::string const& container,
    uint32_t offset) {
  auto value_cxx =  get_boolean_flag_value_cxx_impl(
      rust::Str(pb_file.c_str()),
      rust::Str(container.c_str()),
      offset);
  auto value = BooleanFlagValueQuery();
  value.query_success = value_cxx.query_success;
  value.error_message = std::string(value_cxx.error_message.c_str());
  value.flag_value = value_cxx.flag_value;
  return value;
}
} // namespace test_only_api
} // namespace aconfig_storage
