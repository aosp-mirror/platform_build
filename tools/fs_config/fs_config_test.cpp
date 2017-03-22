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

#include <android-base/file.h>
#include <android-base/macros.h>
#include <android-base/stringprintf.h>
#include <gtest/gtest.h>
#include <private/android_filesystem_config.h>
#include <private/fs_config.h>

#include "android_filesystem_config_test_data.h"

// must run test in the test directory
const static char fs_config_generate_command[] = "./fs_config_generate_test";

static std::string popenToString(std::string command) {
  std::string ret;

  FILE* fp = popen(command.c_str(), "r");
  if (fp) {
    if (!android::base::ReadFdToString(fileno(fp), &ret)) ret = "";
    pclose(fp);
  }
  return ret;
}

static void confirm(std::string&& data, const fs_path_config* config,
                    ssize_t num_config) {
  const struct fs_path_config_from_file* pc =
      reinterpret_cast<const fs_path_config_from_file*>(data.c_str());
  size_t len = data.size();

  ASSERT_TRUE(config != NULL);
  ASSERT_LT(0, num_config);

  while (len > 0) {
    uint16_t host_len = pc->len;
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
  confirm(popenToString(
              android::base::StringPrintf("%s -D", fs_config_generate_command)),
          android_device_dirs, arraysize(android_device_dirs));
}

TEST(fs_conf_test, files) {
  confirm(popenToString(
              android::base::StringPrintf("%s -F", fs_config_generate_command)),
          android_device_files, arraysize(android_device_files));
}
