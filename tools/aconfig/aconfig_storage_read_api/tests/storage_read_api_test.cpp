/*
 * Copyright (C) 2024 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <string>
#include <vector>
#include <cstdio>

#include <sys/stat.h>
#include "aconfig_storage/aconfig_storage_read_api.hpp"
#include <gtest/gtest.h>
#include <protos/aconfig_storage_metadata.pb.h>
#include <android-base/file.h>
#include <android-base/result.h>

using android::aconfig_storage_metadata::storage_files;
using namespace android::base;

namespace api = aconfig_storage;
namespace private_api = aconfig_storage::private_internal_api;

class AconfigStorageTest : public ::testing::Test {
 protected:
  Result<std::string> copy_to_ro_temp_file(std::string const& source_file) {
    auto temp_file = std::string(std::tmpnam(nullptr));
    auto content = std::string();
    if (!ReadFileToString(source_file, &content)) {
      return Error() << "failed to read file: " << source_file;
    }
    if (!WriteStringToFile(content, temp_file)) {
      return Error() << "failed to copy file: " << source_file;
    }
    if (chmod(temp_file.c_str(), S_IRUSR | S_IRGRP | S_IROTH) == -1) {
      return Error() << "failed to make file read only";
    }
    return temp_file;
  }

  Result<std::string> write_storage_location_pb_file(std::string const& package_map,
                                                     std::string const& flag_map,
                                                     std::string const& flag_val) {
    auto temp_file = std::tmpnam(nullptr);
    auto proto = storage_files();
    auto* info = proto.add_files();
    info->set_version(0);
    info->set_container("system");
    info->set_package_map(package_map);
    info->set_flag_map(flag_map);
    info->set_flag_val(flag_val);
    info->set_timestamp(12345);

    auto content = std::string();
    proto.SerializeToString(&content);
    if (!WriteStringToFile(content, temp_file)) {
      return Error() << "failed to write storage records pb file";
    }
    return temp_file;
  }

  void SetUp() override {
    auto const test_dir = android::base::GetExecutableDirectory();
    package_map = *copy_to_ro_temp_file(test_dir + "/package.map");
    flag_map = *copy_to_ro_temp_file(test_dir + "/flag.map");
    flag_val = *copy_to_ro_temp_file(test_dir + "/flag.val");
    storage_record_pb = *write_storage_location_pb_file(
        package_map, flag_map, flag_val);
  }

  void TearDown() override {
    std::remove(package_map.c_str());
    std::remove(flag_map.c_str());
    std::remove(flag_val.c_str());
    std::remove(storage_record_pb.c_str());
  }

  std::string package_map;
  std::string flag_map;
  std::string flag_val;
  std::string storage_record_pb;
};

/// Test to lock down storage file version query api
TEST_F(AconfigStorageTest, test_storage_version_query) {
  auto query = api::get_storage_file_version(package_map);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
  query = api::get_storage_file_version(flag_map);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
  query = api::get_storage_file_version(flag_val);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
}

/// Negative test to lock down the error when mapping none exist storage files
TEST_F(AconfigStorageTest, test_none_exist_storage_file_mapping) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "vendor", api::StorageFileType::package_map);
  ASSERT_FALSE(mapped_file_query.query_success);
  ASSERT_EQ(mapped_file_query.error_message,
            "Unable to find storage files for container vendor");
}

/// Negative test to lock down the error when mapping a writeable storage file
TEST_F(AconfigStorageTest, test_writable_storage_file_mapping) {
  ASSERT_TRUE(chmod(package_map.c_str(),
                    S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH) != -1);
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::package_map);
  ASSERT_FALSE(mapped_file_query.query_success);
  ASSERT_EQ(mapped_file_query.error_message, "cannot map writeable file");

  ASSERT_TRUE(chmod(flag_map.c_str(),
                    S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH) != -1);
  mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_map);
  ASSERT_FALSE(mapped_file_query.query_success);
  ASSERT_EQ(mapped_file_query.error_message, "cannot map writeable file");

  ASSERT_TRUE(chmod(flag_val.c_str(),
                    S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH) != -1);
  mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_val);
  ASSERT_FALSE(mapped_file_query.query_success);
  ASSERT_EQ(mapped_file_query.error_message, "cannot map writeable file");
}

/// Test to lock down storage package offset query api
TEST_F(AconfigStorageTest, test_package_offset_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::package_map);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  auto query = api::get_package_offset(
      mapped_file, "com.android.aconfig.storage.test_1");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 0);
  ASSERT_EQ(query.boolean_offset, 0);

  query = api::get_package_offset(
      mapped_file, "com.android.aconfig.storage.test_2");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 1);
  ASSERT_EQ(query.boolean_offset, 3);

  query = api::get_package_offset(
      mapped_file, "com.android.aconfig.storage.test_4");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 2);
  ASSERT_EQ(query.boolean_offset, 6);
}

/// Test to lock down when querying none exist package
TEST_F(AconfigStorageTest, test_none_existent_package_offset_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::package_map);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  auto query = api::get_package_offset(
      mapped_file, "com.android.aconfig.storage.test_3");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.package_exists);
}

/// Test to lock down storage flag offset query api
TEST_F(AconfigStorageTest, test_flag_offset_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_map);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  auto baseline = std::vector<std::tuple<int, std::string, int>>{
    {0, "enabled_ro", 1},
    {0, "enabled_rw", 2},
    {1, "disabled_ro", 0},
    {2, "enabled_ro", 1},
    {1, "enabled_fixed_ro", 1},
    {1, "enabled_ro", 2},
    {2, "enabled_fixed_ro", 0},
    {0, "disabled_rw", 0},
  };
  for (auto const&[package_id, flag_name, expected_offset] : baseline) {
    auto query = api::get_flag_offset(mapped_file, package_id, flag_name);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_TRUE(query.flag_exists);
    ASSERT_EQ(query.flag_offset, expected_offset);
  }
}

/// Test to lock down when querying none exist flag
TEST_F(AconfigStorageTest, test_none_existent_flag_offset_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_map);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  auto query = api::get_flag_offset(mapped_file, 0, "none_exist");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);

  query = api::get_flag_offset(mapped_file, 3, "enabled_ro");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);
}

/// Test to lock down storage flag value query api
TEST_F(AconfigStorageTest, test_boolean_flag_value_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  for (int offset = 0; offset < 8; ++offset) {
    auto query = api::get_boolean_flag_value(mapped_file, offset);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_FALSE(query.flag_value);
  }
}

/// Negative test to lock down the error when querying flag value out of range
TEST_F(AconfigStorageTest, test_invalid_boolean_flag_value_query) {
  auto mapped_file_query = private_api::get_mapped_file_impl(
      storage_record_pb, "system", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_query.query_success);
  auto mapped_file = mapped_file_query.mapped_file;

  auto query = api::get_boolean_flag_value(mapped_file, 8);
  ASSERT_EQ(query.error_message,
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
  ASSERT_FALSE(query.query_success);
}
