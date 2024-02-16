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

#include "aconfig_storage/aconfig_storage.hpp"
#include <gtest/gtest.h>
#include <protos/aconfig_storage_metadata.pb.h>
#include <android-base/file.h>

using android::aconfig_storage_metadata::storage_files;
using ::android::base::WriteStringToFile;
using ::aconfig_storage::test_only_api::get_package_offset_impl;
using ::aconfig_storage::test_only_api::get_flag_offset_impl;
using ::aconfig_storage::test_only_api::get_boolean_flag_value_impl;

void write_storage_location_pb_to_file(std::string const& file_path) {
  auto const test_dir = android::base::GetExecutableDirectory();
  auto proto = storage_files();
  auto* info = proto.add_files();
  info->set_version(0);
  info->set_container("system");
  info->set_package_map(test_dir + "/tests/tmp.ro.package.map");
  info->set_flag_map(test_dir + "/tests/tmp.ro.flag.map");
  info->set_flag_val(test_dir + "/tests/tmp.ro.flag.val");
  info->set_timestamp(12345);

  auto content = std::string();
  proto.SerializeToString(&content);
  ASSERT_TRUE(WriteStringToFile(content, file_path))
      << "Failed to write a file: " << file_path;
}

TEST(AconfigStorageTest, test_package_offset_query) {
  auto pb_file = std::string("/tmp/test_package_offset_query.pb");
  write_storage_location_pb_to_file(pb_file);

  auto query = get_package_offset_impl(
      pb_file, "system", "com.android.aconfig.storage.test_1");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 0);
  ASSERT_EQ(query.boolean_offset, 0);

  query = get_package_offset_impl(
      pb_file, "system", "com.android.aconfig.storage.test_2");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 1);
  ASSERT_EQ(query.boolean_offset, 3);

  query = get_package_offset_impl(
      pb_file, "system", "com.android.aconfig.storage.test_4");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_TRUE(query.package_exists);
  ASSERT_EQ(query.package_id, 2);
  ASSERT_EQ(query.boolean_offset, 6);
}

TEST(AconfigStorageTest, test_invalid_package_offset_query) {
  auto pb_file = std::string("/tmp/test_package_offset_query.pb");
  write_storage_location_pb_to_file(pb_file);

  auto query = get_package_offset_impl(
      pb_file, "system", "com.android.aconfig.storage.test_3");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.package_exists);

  query = get_package_offset_impl(
      pb_file, "vendor", "com.android.aconfig.storage.test_1");
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);
}

TEST(AconfigStorageTest, test_flag_offset_query) {
  auto pb_file = std::string("/tmp/test_package_offset_query.pb");
  write_storage_location_pb_to_file(pb_file);

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
    auto query = get_flag_offset_impl(pb_file, "system", package_id, flag_name);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_TRUE(query.flag_exists);
    ASSERT_EQ(query.flag_offset, expected_offset);
  }
}

TEST(AconfigStorageTest, test_invalid_flag_offset_query) {
  auto pb_file = std::string("/tmp/test_invalid_package_offset_query.pb");
  write_storage_location_pb_to_file(pb_file);

  auto query = get_flag_offset_impl(pb_file, "system", 0, "none_exist");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);

  query = get_flag_offset_impl(pb_file, "system", 3, "enabled_ro");
  ASSERT_EQ(query.error_message, std::string());
  ASSERT_TRUE(query.query_success);
  ASSERT_FALSE(query.flag_exists);

  query = get_flag_offset_impl(pb_file, "vendor", 0, "enabled_ro");
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);
}

TEST(AconfigStorageTest, test_boolean_flag_value_query) {
  auto pb_file = std::string("/tmp/test_boolean_flag_value_query.pb");
  write_storage_location_pb_to_file(pb_file);
  for (int offset = 0; offset < 8; ++offset) {
    auto query = get_boolean_flag_value_impl(pb_file, "system", offset);
    ASSERT_EQ(query.error_message, std::string());
    ASSERT_TRUE(query.query_success);
    ASSERT_FALSE(query.flag_value);
  }
}

TEST(AconfigStorageTest, test_invalid_boolean_flag_value_query) {
  auto pb_file = std::string("/tmp/test_invalid_boolean_flag_value_query.pb");
  write_storage_location_pb_to_file(pb_file);

  auto query = get_boolean_flag_value_impl(pb_file, "vendor", 0);
  ASSERT_EQ(query.error_message,
            std::string("StorageFileNotFound(Storage file does not exist for vendor)"));
  ASSERT_FALSE(query.query_success);

  query = get_boolean_flag_value_impl(pb_file, "system", 8);
  ASSERT_EQ(query.error_message,
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
  ASSERT_FALSE(query.query_success);
}
