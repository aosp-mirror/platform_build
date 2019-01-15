/*
 * Copyright (C) 2017 The Android Open Source Project
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

#include <stdio.h>
#include <sys/cdefs.h>

#include <string>
#include <vector>

#include <android-base/file.h>
#include <android-base/macros.h>
#include <android-base/strings.h>
#include <gtest/gtest.h>
#include <private/android_filesystem_config.h>
#include <private/fs_config.h>

#include "android_filesystem_config_test_data.h"

// must run test in the test directory
static const std::string fs_config_generate_command = "./fs_config_generate_test";

static std::string popenToString(const std::string command) {
  std::string ret;

  auto fp = popen(command.c_str(), "r");
  if (fp) {
    if (!android::base::ReadFdToString(fileno(fp), &ret)) ret = "";
    pclose(fp);
  }
  return ret;
}

static void confirm(std::string&& data, const fs_path_config* config,
                    ssize_t num_config) {
  auto pc = reinterpret_cast<const fs_path_config_from_file*>(data.c_str());
  auto len = data.size();

  ASSERT_TRUE(config != NULL);
  ASSERT_LT(0, num_config);

  while (len > 0) {
    auto host_len = pc->len;
    if (host_len > len) break;

    EXPECT_EQ(config->mode, pc->mode);
    EXPECT_EQ(config->uid, pc->uid);
    EXPECT_EQ(config->gid, pc->gid);
    EXPECT_EQ(config->capabilities, pc->capabilities);
    EXPECT_STREQ(config->prefix, pc->prefix);

    EXPECT_LT(0, num_config);
    --num_config;
    if (num_config >= 0) ++config;
    pc = reinterpret_cast<const fs_path_config_from_file*>(
        reinterpret_cast<const char*>(pc) + host_len);
    len -= host_len;
  }
  EXPECT_EQ(0, num_config);
}

/* See local android_filesystem_config.h for test data */

TEST(fs_conf_test, dirs) {
  confirm(popenToString(fs_config_generate_command + " -D"),
          android_device_dirs, arraysize(android_device_dirs));
}

TEST(fs_conf_test, files) {
  confirm(popenToString(fs_config_generate_command + " -F"),
          android_device_files, arraysize(android_device_files));
}

static bool is_system(const char* prefix) {
  return !android::base::StartsWith(prefix, "vendor/") &&
         !android::base::StartsWith(prefix, "system/vendor/") &&
         !android::base::StartsWith(prefix, "oem/") &&
         !android::base::StartsWith(prefix, "system/oem/") &&
         !android::base::StartsWith(prefix, "odm/") &&
         !android::base::StartsWith(prefix, "system/odm/") &&
         !android::base::StartsWith(prefix, "product/") &&
         !android::base::StartsWith(prefix, "system/product/") &&
         !android::base::StartsWith(prefix, "product_services/") &&
         !android::base::StartsWith(prefix, "system/product_services/");
}

TEST(fs_conf_test, system_dirs) {
  std::vector<fs_path_config> dirs;
  auto config = android_device_dirs;
  for (auto num = arraysize(android_device_dirs); num; --num) {
    if (is_system(config->prefix)) {
      dirs.emplace_back(*config);
    }
    ++config;
  }
  confirm(popenToString(fs_config_generate_command + " -D -P -vendor,-oem,-odm,-product,-product_services"),
          &dirs[0], dirs.size());
}

static void fs_conf_test_dirs(const std::string& partition_name) {
  std::vector<fs_path_config> dirs;
  auto config = android_device_dirs;
  const auto str = partition_name + "/";
  const auto alt_str = "system/" + partition_name + "/";
  for (auto num = arraysize(android_device_dirs); num; --num) {
    if (android::base::StartsWith(config->prefix, str) ||
        android::base::StartsWith(config->prefix, alt_str)) {
      dirs.emplace_back(*config);
    }
    ++config;
  }
  confirm(popenToString(fs_config_generate_command + " -D -P " + partition_name),
          &dirs[0], dirs.size());
}

TEST(fs_conf_test, vendor_dirs) {
  fs_conf_test_dirs("vendor");
}

TEST(fs_conf_test, oem_dirs) {
  fs_conf_test_dirs("oem");
}

TEST(fs_conf_test, odm_dirs) {
  fs_conf_test_dirs("odm");
}

TEST(fs_conf_test, system_files) {
  std::vector<fs_path_config> files;
  auto config = android_device_files;
  for (auto num = arraysize(android_device_files); num; --num) {
    if (is_system(config->prefix)) {
      files.emplace_back(*config);
    }
    ++config;
  }
  confirm(popenToString(fs_config_generate_command + " -F -P -vendor,-oem,-odm,-product,-product_services"),
          &files[0], files.size());
}

static void fs_conf_test_files(const std::string& partition_name) {
  std::vector<fs_path_config> files;
  auto config = android_device_files;
  const auto str = partition_name + "/";
  const auto alt_str = "system/" + partition_name + "/";
  for (auto num = arraysize(android_device_files); num; --num) {
    if (android::base::StartsWith(config->prefix, str) ||
        android::base::StartsWith(config->prefix, alt_str)) {
      files.emplace_back(*config);
    }
    ++config;
  }
  confirm(popenToString(fs_config_generate_command + " -F -P " + partition_name),
          &files[0], files.size());
}

TEST(fs_conf_test, vendor_files) {
  fs_conf_test_files("vendor");
}

TEST(fs_conf_test, oem_files) {
  fs_conf_test_files("oem");
}

TEST(fs_conf_test, odm_files) {
  fs_conf_test_files("odm");
}

TEST(fs_conf_test, product_files) {
  fs_conf_test_files("product");
}

TEST(fs_conf_test, product_services_files) {
  fs_conf_test_files("product_services");
}
