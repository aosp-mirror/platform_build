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

TEST(AconfigTest, TestDisabledRwExportedFlag) {
  ASSERT_FALSE(com_android_aconfig_test_disabled_rw_exported());
  ASSERT_FALSE(provider_->disabled_rw_exported());
  ASSERT_FALSE(disabled_rw_exported());
}

TEST(AconfigTest, TestEnabledFixedRoExportedFlag) {
  // TODO: change to assertTrue(enabledFixedRoExported()) when the build supports reading tests/*.values
  ASSERT_FALSE(com_android_aconfig_test_enabled_fixed_ro_exported());
  ASSERT_FALSE(provider_->enabled_fixed_ro_exported());
  ASSERT_FALSE(enabled_fixed_ro_exported());
}

TEST(AconfigTest, TestEnabledRoExportedFlag) {
  // TODO: change to assertTrue(enabledRoExported()) when the build supports reading tests/*.values
  ASSERT_FALSE(com_android_aconfig_test_enabled_ro_exported());
  ASSERT_FALSE(provider_->enabled_ro_exported());
  ASSERT_FALSE(enabled_ro_exported());
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}