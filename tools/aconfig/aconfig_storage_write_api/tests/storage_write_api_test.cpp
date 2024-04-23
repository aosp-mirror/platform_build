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
#include <protos/aconfig_storage_metadata.pb.h>
#include <android-base/file.h>
#include <android-base/result.h>

using android::aconfig_storage_metadata::storage_files;
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

  Result<std::string> write_storage_location_pb_file(std::string const& flag_val,
                                                     std::string const& flag_info) {
    auto temp_file = std::tmpnam(nullptr);
    auto proto = storage_files();
    auto* info = proto.add_files();
    info->set_version(0);
    info->set_container("mockup");
    info->set_package_map("some_package.map");
    info->set_flag_map("some_flag.map");
    info->set_flag_val(flag_val);
    info->set_flag_info(flag_info);
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
    flag_val = *copy_to_rw_temp_file(test_dir + "/flag.val");
    flag_info = *copy_to_rw_temp_file(test_dir + "/flag.info");
    storage_record_pb = *write_storage_location_pb_file(flag_val, flag_info);
  }

  void TearDown() override {
    std::remove(flag_val.c_str());
    std::remove(flag_info.c_str());
    std::remove(storage_record_pb.c_str());
  }

  std::string flag_val;
  std::string flag_info;
  std::string storage_record_pb;
};

/// Negative test to lock down the error when mapping none exist storage files
TEST_F(AconfigStorageTest, test_none_exist_storage_file_mapping) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "vendor", api::StorageFileType::flag_val);
  ASSERT_FALSE(mapped_file_result.ok());
  ASSERT_EQ(mapped_file_result.error().message(),
            "Unable to find storage files for container vendor");
}

/// Negative test to lock down the error when mapping a non writeable storage file
TEST_F(AconfigStorageTest, test_non_writable_storage_file_mapping) {
  ASSERT_TRUE(chmod(flag_val.c_str(), S_IRUSR | S_IRGRP | S_IROTH) != -1);
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_val);
  ASSERT_FALSE(mapped_file_result.ok());
  auto it = mapped_file_result.error().message().find("cannot map nonwriteable file");
  ASSERT_TRUE(it != std::string::npos) << mapped_file_result.error().message();
}

/// Negative test to lock down the error when mapping a file type that cannot be modified
TEST_F(AconfigStorageTest, test_invalid_storage_file_type_mapping) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::package_map);
  ASSERT_FALSE(mapped_file_result.ok());
  auto it = mapped_file_result.error().message().find(
      "Cannot create mutable mapped file for this file type");
  ASSERT_TRUE(it != std::string::npos) << mapped_file_result.error().message();

  mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_map);
  ASSERT_FALSE(mapped_file_result.ok());
  it = mapped_file_result.error().message().find(
      "Cannot create mutable mapped file for this file type");
  ASSERT_TRUE(it != std::string::npos) << mapped_file_result.error().message();
}

/// Test to lock down storage flag value update api
TEST_F(AconfigStorageTest, test_boolean_flag_value_update) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = *mapped_file_result;

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_boolean_flag_value(mapped_file, offset, true);
    ASSERT_TRUE(update_result.ok());
    auto ro_mapped_file = api::MappedStorageFile();
    ro_mapped_file.file_ptr = mapped_file.file_ptr;
    ro_mapped_file.file_size = mapped_file.file_size;
    auto value = api::get_boolean_flag_value(ro_mapped_file, offset);
    ASSERT_TRUE(value.ok());
    ASSERT_TRUE(*value);
  }
}

/// Negative test to lock down the error when querying flag value out of range
TEST_F(AconfigStorageTest, test_invalid_boolean_flag_value_update) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_val);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = *mapped_file_result;
  auto update_result = api::set_boolean_flag_value(mapped_file, 8, true);
  ASSERT_FALSE(update_result.ok());
  ASSERT_EQ(update_result.error().message(),
            std::string("InvalidStorageFileOffset(Flag value offset goes beyond the end of the file.)"));
}

/// Test to lock down storage flag stickiness update api
TEST_F(AconfigStorageTest, test_flag_is_sticky_update) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = *mapped_file_result;

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_is_sticky(
        mapped_file, api::FlagValueType::Boolean, offset, true);
    ASSERT_TRUE(update_result.ok());
    auto ro_mapped_file = api::MappedStorageFile();
    ro_mapped_file.file_ptr = mapped_file.file_ptr;
    ro_mapped_file.file_size = mapped_file.file_size;
    auto attribute = api::get_flag_attribute(
        ro_mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_TRUE(*attribute & api::FlagInfoBit::IsSticky);

    update_result = api::set_flag_is_sticky(
        mapped_file, api::FlagValueType::Boolean, offset, false);
    ASSERT_TRUE(update_result.ok());
    ro_mapped_file.file_ptr = mapped_file.file_ptr;
    ro_mapped_file.file_size = mapped_file.file_size;
    attribute = api::get_flag_attribute(
        ro_mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_FALSE(*attribute & api::FlagInfoBit::IsSticky);
  }
}

/// Test to lock down storage flag has override update api
TEST_F(AconfigStorageTest, test_flag_has_override_update) {
  auto mapped_file_result = private_api::get_mutable_mapped_file_impl(
      storage_record_pb, "mockup", api::StorageFileType::flag_info);
  ASSERT_TRUE(mapped_file_result.ok());
  auto mapped_file = *mapped_file_result;

  for (int offset = 0; offset < 8; ++offset) {
    auto update_result = api::set_flag_has_override(
        mapped_file, api::FlagValueType::Boolean, offset, true);
    ASSERT_TRUE(update_result.ok());
    auto ro_mapped_file = api::MappedStorageFile();
    ro_mapped_file.file_ptr = mapped_file.file_ptr;
    ro_mapped_file.file_size = mapped_file.file_size;
    auto attribute = api::get_flag_attribute(
        ro_mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_TRUE(*attribute & api::FlagInfoBit::HasOverride);

    update_result = api::set_flag_has_override(
        mapped_file, api::FlagValueType::Boolean, offset, false);
    ASSERT_TRUE(update_result.ok());
    ro_mapped_file.file_ptr = mapped_file.file_ptr;
    ro_mapped_file.file_size = mapped_file.file_size;
    attribute = api::get_flag_attribute(
        ro_mapped_file, api::FlagValueType::Boolean, offset);
    ASSERT_TRUE(attribute.ok());
    ASSERT_FALSE(*attribute & api::FlagInfoBit::HasOverride);
  }
}
