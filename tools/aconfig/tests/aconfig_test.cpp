/*
 * Copyright (C) 2023 The Android Open Source Project
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

#include "com_android_aconfig_test.h"
#include "gtest/gtest.h"

using namespace com::android::aconfig::test;

TEST(AconfigTest, TestDisabledReadOnlyFlag) {
  ASSERT_FALSE(com_android_aconfig_test_disabled_ro());
  ASSERT_FALSE(provider_->disabled_ro());
  ASSERT_FALSE(disabled_ro());
}

TEST(AconfigTest, TestEnabledReadOnlyFlag) {
  ASSERT_TRUE(com_android_aconfig_test_enabled_ro());
  ASSERT_TRUE(provider_->enabled_ro());
  ASSERT_TRUE(enabled_ro());
}

TEST(AconfigTest, TestDisabledReadWriteFlag) {
  ASSERT_FALSE(com_android_aconfig_test_disabled_rw());
  ASSERT_FALSE(provider_->disabled_rw());
  ASSERT_FALSE(disabled_rw());
}

TEST(AconfigTest, TestEnabledReadWriteFlag) {
  ASSERT_TRUE(com_android_aconfig_test_enabled_rw());
  ASSERT_TRUE(provider_->enabled_rw());
  ASSERT_TRUE(enabled_rw());
}

TEST(AconfigTest, TestEnabledFixedReadOnlyFlag) {
  ASSERT_TRUE(com_android_aconfig_test_enabled_fixed_ro());
  ASSERT_TRUE(provider_->enabled_fixed_ro());
  ASSERT_TRUE(enabled_fixed_ro());
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
