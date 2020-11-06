#include "gmock/gmock.h"
#include "gtest/gtest.h"

#include "ZipAlign.h"

#include <stdio.h>
#include <string>

#include <android-base/file.h>

using namespace android;

static std::string GetTestPath(const std::string& filename) {
  static std::string test_data_dir = android::base::GetExecutableDirectory() + "/tests/data/";
  return test_data_dir + filename;
}

TEST(Align, Unaligned) {
  const std::string src = GetTestPath("unaligned.zip");
  const std::string dst = GetTestPath("unaligned_out.zip");

  int processed = process(src.c_str(), dst.c_str(), 4, true, false, 4096);
  ASSERT_EQ(0, processed);

  int verified = verify(dst.c_str(), 4, true, false);
  ASSERT_EQ(0, verified);
}
