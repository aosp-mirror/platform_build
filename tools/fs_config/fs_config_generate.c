/*
 * Copyright (C) 2015 The Android Open Source Project
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

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <private/android_filesystem_config.h>

/*
 * This program expects android_device_dirs and android_device_files
 * to be defined in the supplied android_filesystem_config.h file in
 * the device/<vendor>/<product> $(TARGET_DEVICE_DIR). Then generates
 * the binary format used in the /system/etc/fs_config_dirs and
 * the /system/etc/fs_config_files to be used by the runtimes.
 */
#include "android_filesystem_config.h"

#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
  static const struct fs_path_config android_device_dirs[] = {
};
#endif

#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_FILES
static const struct fs_path_config android_device_files[] = {
#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
    { 0, AID_ROOT, AID_ROOT, 0, "system/etc/fs_config_dirs" },
#endif
    { 0, AID_ROOT, AID_ROOT, 0, "system/etc/fs_config_files" },
};
#endif

static void usage() {
  fprintf(stderr,
    "Generate binary content for fs_config_dirs (-D) and fs_config_files (-F)\n"
    "from device-specific android_filesystem_config.h override\n\n"
    "Usage: fs_config_generate -D|-F [-o output-file]\n");
}

int main(int argc, char** argv) {
  const struct fs_path_config *pc;
  const struct fs_path_config *end;
  bool dir = false, file = false;
  FILE *fp = stdout;
  int opt;

  while((opt = getopt(argc, argv, "DFho:")) != -1) {
    switch(opt) {
    case 'D':
      if (file) {
        fprintf(stderr, "Must specify only -D or -F\n");
        usage();
        exit(EXIT_FAILURE);
      }
      dir = true;
      break;
    case 'F':
      if (dir) {
        fprintf(stderr, "Must specify only -F or -D\n");
        usage();
        exit(EXIT_FAILURE);
      }
      file = true;
      break;
    case 'o':
      if (fp != stdout) {
        fprintf(stderr, "Specify only one output file\n");
        usage();
        exit(EXIT_FAILURE);
      }
      fp = fopen(optarg, "wb");
      if (fp == NULL) {
        fprintf(stderr, "Can not open \"%s\"\n", optarg);
        exit(EXIT_FAILURE);
      }
      break;
    case 'h':
      usage();
      exit(EXIT_SUCCESS);
    default:
      usage();
      exit(EXIT_FAILURE);
    }
  }

  if (!file && !dir) {
    fprintf(stderr, "Must specify either -F or -D\n");
    usage();
    exit(EXIT_FAILURE);
  }

  if (dir) {
    pc = android_device_dirs;
    end = &android_device_dirs[sizeof(android_device_dirs) / sizeof(android_device_dirs[0])];
  } else {
    pc = android_device_files;
    end = &android_device_files[sizeof(android_device_files) / sizeof(android_device_files[0])];
  }
  for(; (pc < end) && pc->prefix; pc++) {
    char buffer[512];
    ssize_t len = fs_config_generate(buffer, sizeof(buffer), pc);
    if (len < 0) {
      fprintf(stderr, "Entry too large\n");
      exit(EXIT_FAILURE);
    }
    if (fwrite(buffer, 1, len, fp) != (size_t)len) {
      fprintf(stderr, "Write failure\n");
      exit(EXIT_FAILURE);
    }
  }
  fclose(fp);

  return 0;
}
