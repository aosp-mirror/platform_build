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
using ::android::base::ReadFileToString;
using ::android::base::WriteStringToFile;
using ::android::base::Result;
using ::android::base::Error;
using ::aconfig_storage::test_only_api::get_package_offset_impl;
using ::aconfig_storage::test_only_api::get_flag_offset_impl;
using ::aconfig_storage::test_only_api::get_boolean_flag_value_impl;
using ::aconfig_storage::get_storage_file_version;

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
    if (chmod(temp_file.c_str(), S_IRUSR | S_IRGRP) == -1) {
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


TEST_F(AconfigStorageTest, test_storage_version_query) {
  auto query = get_storage_file_version(package_map);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
  query = get_storage_file_version(flag_map);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
  query = get_storage_file_version(flag_val);
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_EQ(query.version_number, 1);
}

TEST_F(AconfigStorageTest, test_package_offset_query) {
  auto query = get_package_offset_impl(
      storage_record_pb, "system", "com.android.aconfig.storage.test_1");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 0);
  ASSERT_EQ(query.boolean_offset, 0);

  query = get_package_offset_impl(
      storage_record_pb, "system", "com.android.aconfig.storage.test_2");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 1);
  ASSERT_EQ(query.boolean_offset, 3);

  query = get_package_offset_impl(
      storage_record_pb, "system", "com.android.aconfig.storage.test_4");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 2);
  ASSERT_EQ(query.boolean_offset, 6);
}

TEST_F(AconfigStorageTest, test_invalid_package_offset_query) {
  auto query = get_package_offset_impl(
      storage_record_pb, "system", "com.android.aconfig.storage.test_3");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.package_exists);

  query = get_package_offset_impl(
      storage_record_pb, "vendor", "com.android.aconfig.storage.test_1");
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);
}

TEST_F(AconfigStorageTest, test_flag_offset_query) {
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
    auto query = get_flag_offset_impl(storage_record_pb, "system", package_id, flag_name);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_TRUE(query.flag_exists);
    ASSERT_EQ(query.flag_offset, expected_offset);
  }
}

TEST_F(AconfigStorageTest, test_invalid_flag_offset_query) {
  auto query = get_flag_offset_impl(storage_record_pb, "system", 0, "none_exist");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);

  query = get_flag_offset_impl(storage_record_pb, "system", 3, "enabled_ro");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);

  query = get_flag_offset_impl(storage_record_pb, "vendor", 0, "enabled_ro");
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);
}

TEST_F(AconfigStorageTest, test_boolean_flag_value_query) {
  for (int offset = 0; offset < 8; ++offset) {
    auto query = get_boolean_flag_value_impl(storage_record_pb, "system", offset);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_FALSE(query.flag_value);
  }
}

TEST_F(AconfigStorageTest, test_invalid_boolean_flag_value_query) {
  auto query = get_boolean_flag_value_impl(storage_record_pb, "vendor", 0);
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);

  query = get_boolean_flag_value_impl(storage_record_pb, "system", 8);
  ASSERT_EQ(query.error_message,
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
  ASSERT_FALSE(query.query_success);
}
