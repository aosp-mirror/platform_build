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
#include "aconfig_storage/aconfig_storage_write_api.hpp"
#include <gtest/gtest.h>
#include <android-base/file.h>
#include <android-base/result.h>

#include "rust/cxx.h"
#include "aconfig_storage/lib.rs.h"

using namespace android::base;

namespace api = aconfig_storage;
namespace private_api = aconfig_storage::private_internal_api;

class AconfigStorageTest : public ::testing::Test {
 protected:
  Result<std::string> copy_to_rw_temp_file(std::string const& source_file) {
    auto temp_file = std::string(std::tmpnam(nullptr));
    auto content = std::string();
    if (!ReadFileToString(source_file, &content)) {
      return Error() << "failed to read file: " << source_file;
    }
    if (!WriteStringToFile(content, temp_file)) {
      return Error() << "failed to copy file: " << source_file;
    }
    if (chmod(temp_file.c_str(),
              S_IRUSR | S_IRGRP | S_IROTH | S_IWUSR | S_IWGRP | S_IWOTH) == -1) {
      return Error() << "failed to chmod";
    }
    return temp_file;
  }

  void SetUp() override {
    auto const test_dir = android::base::GetExecutableDirectory();
    flag_val = *copy_to_rw_temp_file(test_dir + "/flag.val");
    flag_info = *copy_to_rw_temp_file(test_dir + "/flag.info");
  }

  void TearDown() override {
    std::remove(flag_val.c_str());
    std::remove(flag_info.c_str());
  }

  std::string flag_val;
  std::string flag_info;
};

/// Negative test to lock down the error when mapping a non writeable storage file
TEST_F(AconfigStorageTest, test_non_writable_storage_file_mapping) {
  ASSERT_TRUE(chmod(flag_val.c_str(), S_IRUSR | S_IRGRP | S_IROTH) != -1);
  auto mapped_file_result = api::map_mutable_storage_file(flag_val);
  ASSERT_FALSE(mapped_file_result.ok());
  auto it = mapped_file_result.error().message().find("cannot map nonwriteable file");
  ASSERT_TRUE(it != std::string::npos) << mapped_file_result.error().message();
}

/// Test to lock down storage flag value update api
TEST_F(AconfigStorageTest, test_boolean_flag_value_update) {
  auto mapped_file_result = api::map_mutable_storage_file(flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MutableMappedStorageFile>(*mapped_file_result);

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_boolean_flag_value(*mapped_file, offset, true);
    ASSERT_TRUE(update_result.ok());
    auto value = api::get_boolean_flag_value(*mapped_file, offset);
    ASSERT_TRUE(value.ok());
    ASSERT_TRUE(*value);
  }

  // load the file on disk and check has been updated
  std::ifstream file(flag_val, std::ios::binary | std::ios::ate);
  std::streamsize size = file.tellg();
  file.seekg(0, std::ios::beg);

  std::vector<uint8_t> buffer(size);
  file.read(reinterpret_cast<char *>(buffer.data()), size);

  auto content = rust::Slice<const uint8_t>(
      buffer.data(), mapped_file->file_size);

  for (int offset = 0; offset < 8; ++offset) {
    auto value_cxx = get_boolean_flag_value_cxx(content, offset);
    ASSERT_TRUE(value_cxx.query_success);
    ASSERT_TRUE(value_cxx.flag_value);
  }
}

/// Negative test to lock down the error when querying flag value out of range
TEST_F(AconfigStorageTest, test_invalid_boolean_flag_value_update) {
  auto mapped_file_result = api::map_mutable_storage_file(flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MutableMappedStorageFile>(*mapped_file_result);
  auto update_result = api::set_boolean_flag_value(*mapped_file, 8, true);
  ASSERT_FALSE(update_result.ok());
  ASSERT_EQ(update_result.error().message(),
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
}

/// Test to lock down storage flag has server override update api
TEST_F(AconfigStorageTest, test_flag_has_server_override_update) {
  auto mapped_file_result = api::map_mutable_storage_file(flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MutableMappedStorageFile>(*mapped_file_result);

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_has_server_override(
        *mapped_file, api::FlagValueType::Boolean, offset, true);
    ASSERT_TRUE(update_result.ok()) << update_result.error();
    auto attribute = api::get_flag_attribute(
        *mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_TRUE(*attribute & api::FlagInfoBit::HasServerOverride);
  }

  // load the file on disk and check has been updated
  std::ifstream file(flag_info, std::ios::binary | std::ios::ate);
  std::streamsize size = file.tellg();
  file.seekg(0, std::ios::beg);

  std::vector<uint8_t> buffer(size);
  file.read(reinterpret_cast<char *>(buffer.data()), size);

  auto content = rust::Slice<const uint8_t>(
      buffer.data(), mapped_file->file_size);

  for (int offset = 0; offset < 8; ++offset) {
    auto attribute = get_flag_attribute_cxx(content, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.query_success);
    ASSERT_TRUE(attribute.flag_attribute & api::FlagInfoBit::HasServerOverride);
  }

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_has_server_override(
        *mapped_file, api::FlagValueType::Boolean, offset, false);
    ASSERT_TRUE(update_result.ok());
    auto attribute = api::get_flag_attribute(
        *mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_FALSE(*attribute & api::FlagInfoBit::HasServerOverride);
  }

  std::ifstream file2(flag_info, std::ios::binary);
  buffer.clear();
  file2.read(reinterpret_cast<char *>(buffer.data()), size);
  for (int offset = 0; offset < 8; ++offset) {
    auto attribute = get_flag_attribute_cxx(content, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.query_success);
    ASSERT_FALSE(attribute.flag_attribute & api::FlagInfoBit::HasServerOverride);
  }
}

/// Test to lock down storage flag has local override update api
TEST_F(AconfigStorageTest, test_flag_has_local_override_update) {
  auto mapped_file_result = api::map_mutable_storage_file(flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = std::unique_ptr<api::MutableMappedStorageFile>(*mapped_file_result);

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_has_local_override(
        *mapped_file, api::FlagValueType::Boolean, offset, true);
    ASSERT_TRUE(update_result.ok());
    auto attribute = api::get_flag_attribute(
        *mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_TRUE(*attribute & api::FlagInfoBit::HasLocalOverride);
  }

  // load the file on disk and check has been updated
  std::ifstream file(flag_info, std::ios::binary | std::ios::ate);
  std::streamsize size = file.tellg();
  file.seekg(0, std::ios::beg);

  std::vector<uint8_t> buffer(size);
  file.read(reinterpret_cast<char *>(buffer.data()), size);

  auto content = rust::Slice<const uint8_t>(
      buffer.data(), mapped_file->file_size);

  for (int offset = 0; offset < 8; ++offset) {
    auto attribute = get_flag_attribute_cxx(content, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.query_success);
    ASSERT_TRUE(attribute.flag_attribute & api::FlagInfoBit::HasLocalOverride);
  }

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_has_local_override(
        *mapped_file, api::FlagValueType::Boolean, offset, false);
    ASSERT_TRUE(update_result.ok());
    auto attribute = api::get_flag_attribute(
        *mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_FALSE(*attribute & api::FlagInfoBit::HasLocalOverride);
  }

  std::ifstream file2(flag_info, std::ios::binary);
  buffer.clear();
  file2.read(reinterpret_cast<char *>(buffer.data()), size);
  for (int offset = 0; offset < 8; ++offset) {
    auto attribute = get_flag_attribute_cxx(content, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.query_success);
    ASSERT_FALSE(attribute.flag_attribute & api::FlagInfoBit::HasLocalOverride);
  }
}
