#pragma once

#include <stdint.h>
#include <string>

namespace aconfig_storage {

/// Package offset query result
struct PackageOffsetQuery {
  bool query_success;
  std::string error_message;
  bool package_exists;
  uint32_t package_id;
  uint32_t boolean_offset;
};

/// Flag offset query result
struct FlagOffsetQuery {
  bool query_success;
  std::string error_message;
  bool flag_exists;
  uint16_t flag_offset;
};

/// Boolean flag value query result
struct BooleanFlagValueQuery {
  bool query_success;
  std::string error_message;
  bool flag_value;
};

/// Get package offset
/// \input container: the flag container name
/// \input package: the flag package name
/// \returns a PackageOffsetQuery
PackageOffsetQuery get_package_offset(
    std::string const& container,
    std::string const& package);

/// Get flag offset
/// \input container: the flag container name
/// \input package_id: the flag package id obtained from package offset query
/// \input flag_name: flag name
/// \returns a FlagOffsetQuery
FlagOffsetQuery get_flag_offset(
    std::string const& container,
    uint32_t package_id,
    std::string const& flag_name);

/// Get boolean flag value
/// \input container: the flag container name
/// \input offset: the boolean flag value byte offset in the file
/// \returns a BooleanFlagValueQuery
BooleanFlagValueQuery get_boolean_flag_value(
    std::string const& container,
    uint32_t offset);

/// DO NOT USE APIS IN THE FOLLOWING NAMESPACE, TEST ONLY
namespace test_only_api {
PackageOffsetQuery get_package_offset_impl(
    std::string const& pb_file,
    std::string const& container,
    std::string const& package);

FlagOffsetQuery get_flag_offset_impl(
    std::string const& pb_file,
    std::string const& container,
    uint32_t package_id,
    std::string const& flag_name);

BooleanFlagValueQuery get_boolean_flag_value_impl(
    std::string const& pb_file,
    std::string const& container,
    uint32_t offset);
} // namespace test_only_api
} // namespace aconfig_storage
