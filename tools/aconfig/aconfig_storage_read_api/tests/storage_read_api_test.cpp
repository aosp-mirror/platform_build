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
#include <memory>
#include <cstdio>

#include <sys/stat.h>
#include "aconfig_storage/aconfig_storage_read_api.hpp"
#include <gtest/gtest.h>
#include <android-base/file.h>
#include <android-base/result.h>

using namespace android::base;

namespace api = aconfig_storage;
namespace private_api = aconfig_storage::private_internal_api;

class AconfigStorageTest : public ::testing::Test {
 protected:
  Result<void> copy_file(std::string const& src_file,
                         std::string const& dst_file) {
    auto content = std::string();
    if (!ReadFileToString(src_file, &content)) {
      return Error() << "failed to read file: " << src_file;
    }
    if (!WriteStringToFile(content, dst_file)) {
      return Error() << "failed to copy file: " << dst_file;
    }
    return {};
  }

  void SetUp() override {
    auto const test_dir = android::base::GetExecutableDirectory();
    storage_dir = std::string(root_dir.path);
    auto maps_dir = storage_dir + "/maps";
    auto boot_dir = storage_dir + "/boot";
    mkdir(maps_dir.c_str(), 0775);
    mkdir(boot_dir.c_str(), 0775);
    package_map = std::string(maps_dir) + "/mockup.package.map";
    flag_map = std::string(maps_dir) + "/mockup.flag.map";
    flag_val = std::string(boot_dir) + "/mockup.val";
    flag_info = std::string(boot_dir) + "/mockup.info";
    copy_file(test_dir + "/package.map", package_map);
    copy_file(test_dir + "/flag.map", flag_map);
    copy_file(test_dir + "/flag.val", flag_val);
    copy_file(test_dir + "/flag.info", flag_info);
  }

  void TearDown() override {
    std::remove(package_map.c_str());
    std::remove(flag_map.c_str());
    std::remove(flag_val.c_str());
    std::remove(flag_info.c_str());
  }

  TemporaryDir root_dir;
  std::string storage_dir;
  std::string package_map;
  std::string flag_map;
  std::string flag_val;
  std::string flag_info;
};

/// Test to lock down storage file version query api
TEST_F(AconfigStorageTest, test_storage_version_query) {
  auto version = api::get_storage_file_version(package_map);
  ASSERT_TRUE(version.ok());
  ASSERT_EQ(*version, 1);
  version = api::get_storage_file_version(flag_map);
  ASSERT_TRUE(version.ok());
  ASSERT_EQ(*version, 1);
  version = api::get_storage_file_version(flag_val);
  ASSERT_TRUE(version.ok());
  ASSERT_EQ(*version, 1);
  version = api::get_storage_file_version(flag_info);
  ASSERT_TRUE(version.ok());
  ASSERT_EQ(*version, 1);
}

/// Negative test to lock down the error when mapping none exist storage files
TEST_F(AconfigStorageTest, test_none_exist_storage_file_mapping) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "vendor", api::StorageFileType::package_map);
  ASSERT_FALSE(mapped_file_result.ok());
  ASSERT_EQ(mapped_file_result.error(),
            std::string("failed to open ") + storage_dir
            + "/maps/vendor.package.map: No such file or directory");
}

/// Test to lock down storage package context query api
TEST_F(AconfigStorageTest, test_package_context_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::package_map);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto context = api::get_package_read_context(
      *mapped_file, "com.android.aconfig.storage.test_1");
  ASSERT_TRUE(context.ok());
  ASSERT_TRUE(context->package_exists);
  ASSERT_EQ(context->package_id, 0);
  ASSERT_EQ(context->boolean_start_index, 0);

  context = api::get_package_read_context(
      *mapped_file, "com.android.aconfig.storage.test_2");
  ASSERT_TRUE(context.ok());
  ASSERT_TRUE(context->package_exists);
  ASSERT_EQ(context->package_id, 1);
  ASSERT_EQ(context->boolean_start_index, 3);

  context = api::get_package_read_context(
      *mapped_file, "com.android.aconfig.storage.test_4");
  ASSERT_TRUE(context.ok());
  ASSERT_TRUE(context->package_exists);
  ASSERT_EQ(context->package_id, 2);
  ASSERT_EQ(context->boolean_start_index, 6);
}

/// Test to lock down when querying none exist package
TEST_F(AconfigStorageTest, test_none_existent_package_context_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::package_map);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto context = api::get_package_read_context(
      *mapped_file, "com.android.aconfig.storage.test_3");
  ASSERT_TRUE(context.ok());
  ASSERT_FALSE(context->package_exists);
}

/// Test to lock down storage flag context query api
TEST_F(AconfigStorageTest, test_flag_context_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_map);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto baseline = std::vector<std::tuple<int, std::string, api::StoredFlagType, int>>{
    {0, "enabled_ro", api::StoredFlagType::ReadOnlyBoolean, 1},
    {0, "enabled_rw", api::StoredFlagType::ReadWriteBoolean, 2},
    {2, "enabled_rw", api::StoredFlagType::ReadWriteBoolean, 1},
    {1, "disabled_rw", api::StoredFlagType::ReadWriteBoolean, 0},
    {1, "enabled_fixed_ro", api::StoredFlagType::FixedReadOnlyBoolean, 1},
    {1, "enabled_ro", api::StoredFlagType::ReadOnlyBoolean, 2},
    {2, "enabled_fixed_ro", api::StoredFlagType::FixedReadOnlyBoolean, 0},
    {0, "disabled_rw", api::StoredFlagType::ReadWriteBoolean, 0},
  };
  for (auto const&[package_id, flag_name, flag_type, flag_index] : baseline) {
    auto context = api::get_flag_read_context(*mapped_file, package_id, flag_name);
    ASSERT_TRUE(context.ok());
    ASSERT_TRUE(context->flag_exists);
    ASSERT_EQ(context->flag_type, flag_type);
    ASSERT_EQ(context->flag_index, flag_index);
  }
}

/// Test to lock down when querying none exist flag
TEST_F(AconfigStorageTest, test_none_existent_flag_context_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_map);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto context = api::get_flag_read_context(*mapped_file, 0, "none_exist");
  ASSERT_TRUE(context.ok());
  ASSERT_FALSE(context->flag_exists);

  context = api::get_flag_read_context(*mapped_file, 3, "enabled_ro");
  ASSERT_TRUE(context.ok());
  ASSERT_FALSE(context->flag_exists);
}

/// Test to lock down storage flag value query api
TEST_F(AconfigStorageTest, test_boolean_flag_value_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto expected_value = std::vector<bool>{
    false, true, true, false, true, true, true, true};
  for (int index = 0; index < 8; ++index) {
    auto value = api::get_boolean_flag_value(*mapped_file, index);
    ASSERT_TRUE(value.ok());
    ASSERT_EQ(*value, expected_value[index]);
  }
}

/// Negative test to lock down the error when querying flag value out of range
TEST_F(AconfigStorageTest, test_invalid_boolean_flag_value_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto value = api::get_boolean_flag_value(*mapped_file, 8);
  ASSERT_FALSE(value.ok());
  ASSERT_EQ(value.error(),
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
}

/// Test to lock down storage flag info query api
TEST_F(AconfigStorageTest, test_boolean_flag_info_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto expected_value = std::vector<bool>{
    true, false, true, true, false, false, false, true};
  for (int index = 0; index < 8; ++index) {
    auto attribute = api::get_flag_attribute(*mapped_file, api::FlagValueType::Boolean, index);
    ASSERT_TRUE(attribute.ok());
    ASSERT_EQ(*attribute & static_cast<uint8_t>(api::FlagInfoBit::HasServerOverride), 0);
    ASSERT_EQ((*attribute & static_cast<uint8_t>(api::FlagInfoBit::IsReadWrite)) != 0,
              expected_value[index]);
    ASSERT_EQ(*attribute & static_cast<uint8_t>(api::FlagInfoBit::HasLocalOverride), 0);
  }
}

/// Negative test to lock down the error when querying flag info out of range
TEST_F(AconfigStorageTest, test_invalid_boolean_flag_info_query) {
  auto mapped_file_result = private_api::get_mapped_file_impl(
      storage_dir, "mockup", api::StorageFileType::flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MappedStorageFile>(*mapped_file_result);

  auto attribute = api::get_flag_attribute(*mapped_file, api::FlagValueType::Boolean, 8);
  ASSERT_FALSE(attribute.ok());
  ASSERT_EQ(attribute.error(),
            std::string("InvalidStorageFileOffset(Flag info offset goes beyond the end of the file.)"));
}
