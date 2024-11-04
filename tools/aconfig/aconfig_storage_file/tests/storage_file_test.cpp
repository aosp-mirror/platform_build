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
#include <android-base/file.h>
#include <android-base/result.h>
#include <gtest/gtest.h>
#include "aconfig_storage/aconfig_storage_file.hpp"

using namespace android::base;
using namespace aconfig_storage;

void verify_value(const FlagValueSummary& flag,
                  const std::string& package_name,
                  const std::string& flag_name,
                  const std::string& flag_val,
                  const std::string& value_type) {
  ASSERT_EQ(flag.package_name, package_name);
  ASSERT_EQ(flag.flag_name, flag_name);
  ASSERT_EQ(flag.flag_value, flag_val);
  ASSERT_EQ(flag.value_type, value_type);
}

void verify_value_info(const FlagValueAndInfoSummary& flag,
                       const std::string& package_name,
                       const std::string& flag_name,
                       const std::string& flag_val,
                       const std::string& value_type,
                       bool is_readwrite,
                       bool has_server_override,
                       bool has_local_override) {
  ASSERT_EQ(flag.package_name, package_name);
  ASSERT_EQ(flag.flag_name, flag_name);
  ASSERT_EQ(flag.flag_value, flag_val);
  ASSERT_EQ(flag.value_type, value_type);
  ASSERT_EQ(flag.is_readwrite, is_readwrite);
  ASSERT_EQ(flag.has_server_override, has_server_override);
  ASSERT_EQ(flag.has_local_override, has_local_override);
}

TEST(AconfigStorageFileTest, test_list_flag) {
  auto const test_base_dir = GetExecutableDirectory();
  auto const test_dir = test_base_dir + "/data/v1";
  auto const package_map = test_dir + "/package.map";
  auto const flag_map = test_dir + "/flag.map";
  auto const flag_val = test_dir + "/flag.val";
  auto flag_list_result = aconfig_storage::list_flags(
      package_map, flag_map, flag_val);
  ASSERT_TRUE(flag_list_result.ok());

  auto const& flag_list = *flag_list_result;
  ASSERT_EQ(flag_list.size(), 8);
  verify_value(flag_list[0], "com.android.aconfig.storage.test_1", "disabled_rw",
               "false", "ReadWriteBoolean");
  verify_value(flag_list[1], "com.android.aconfig.storage.test_1", "enabled_ro",
               "true", "ReadOnlyBoolean");
  verify_value(flag_list[2], "com.android.aconfig.storage.test_1", "enabled_rw",
               "true", "ReadWriteBoolean");
  verify_value(flag_list[3], "com.android.aconfig.storage.test_2", "disabled_rw",
               "false", "ReadWriteBoolean");
  verify_value(flag_list[4], "com.android.aconfig.storage.test_2", "enabled_fixed_ro",
               "true", "FixedReadOnlyBoolean");
  verify_value(flag_list[5], "com.android.aconfig.storage.test_2", "enabled_ro",
               "true", "ReadOnlyBoolean");
  verify_value(flag_list[6], "com.android.aconfig.storage.test_4", "enabled_fixed_ro",
               "true", "FixedReadOnlyBoolean");
  verify_value(flag_list[7], "com.android.aconfig.storage.test_4", "enabled_rw",
               "true", "ReadWriteBoolean");
}

TEST(AconfigStorageFileTest, test_list_flag_with_info) {
  auto const base_test_dir = GetExecutableDirectory();
  auto const test_dir = base_test_dir + "/data/v1";
  auto const package_map = test_dir + "/package.map";
  auto const flag_map = test_dir + "/flag.map";
  auto const flag_val = test_dir + "/flag.val";
  auto const flag_info = test_dir + "/flag.info";
  auto flag_list_result = aconfig_storage::list_flags_with_info(
      package_map, flag_map, flag_val, flag_info);
  ASSERT_TRUE(flag_list_result.ok());

  auto const& flag_list = *flag_list_result;
  ASSERT_EQ(flag_list.size(), 8);
  verify_value_info(flag_list[0], "com.android.aconfig.storage.test_1", "disabled_rw",
                    "false", "ReadWriteBoolean", true, false, false);
  verify_value_info(flag_list[1], "com.android.aconfig.storage.test_1", "enabled_ro",
                    "true", "ReadOnlyBoolean", false, false, false);
  verify_value_info(flag_list[2], "com.android.aconfig.storage.test_1", "enabled_rw",
                    "true", "ReadWriteBoolean", true, false, false);
  verify_value_info(flag_list[3], "com.android.aconfig.storage.test_2", "disabled_rw",
                    "false", "ReadWriteBoolean", true, false, false);
  verify_value_info(flag_list[4], "com.android.aconfig.storage.test_2", "enabled_fixed_ro",
                    "true", "FixedReadOnlyBoolean", false, false, false);
  verify_value_info(flag_list[5], "com.android.aconfig.storage.test_2", "enabled_ro",
                    "true", "ReadOnlyBoolean", false, false, false);
  verify_value_info(flag_list[6], "com.android.aconfig.storage.test_4", "enabled_fixed_ro",
                    "true", "FixedReadOnlyBoolean", false, false, false);
  verify_value_info(flag_list[7], "com.android.aconfig.storage.test_4", "enabled_rw",
                    "true", "ReadWriteBoolean", true, false, false);
}
