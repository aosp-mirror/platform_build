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

#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <private/android_filesystem_config.h>

/*
 * This program expects android_device_dirs and android_device_files
 * to be defined in the supplied android_filesystem_config.h file in
 * the device/<vendor>/<product> $(TARGET_DEVICE_DIR). Then generates
 * the binary format used in the /system/etc/fs_config_dirs and
 * the /system/etc/fs_config_files to be used by the runtimes.
 */
#ifdef ANDROID_FILESYSTEM_CONFIG
#include ANDROID_FILESYSTEM_CONFIG
#else
#include "android_filesystem_config.h"
#endif

#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
static const struct fs_path_config android_device_dirs[] = { };
#endif

#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_FILES
static const struct fs_path_config android_device_files[] = {
#ifdef NO_ANDROID_FILESYSTEM_CONFIG_DEVICE_DIRS
    {0000, AID_ROOT, AID_ROOT, 0, "system/etc/fs_config_dirs"},
    {0000, AID_ROOT, AID_ROOT, 0, "vendor/etc/fs_config_dirs"},
    {0000, AID_ROOT, AID_ROOT, 0, "oem/etc/fs_config_dirs"},
    {0000, AID_ROOT, AID_ROOT, 0, "odm/etc/fs_config_dirs"},
#endif
    {0000, AID_ROOT, AID_ROOT, 0, "system/etc/fs_config_files"},
    {0000, AID_ROOT, AID_ROOT, 0, "vendor/etc/fs_config_files"},
    {0000, AID_ROOT, AID_ROOT, 0, "oem/etc/fs_config_files"},
    {0000, AID_ROOT, AID_ROOT, 0, "odm/etc/fs_config_files"},
};
#endif

static void usage() {
  fprintf(stderr,
    "Generate binary content for fs_config_dirs (-D) and fs_config_files (-F)\n"
    "from device-specific android_filesystem_config.h override.  Filter based\n"
    "on a comma separated partition list (-P) whitelist or prefixed by a\n"
    "minus blacklist.  Partitions are identified as path references to\n"
    "<partition>/ or system/<partition>/\n\n"
    "Usage: fs_config_generate -D|-F [-P list] [-o output-file]\n");
}

/* If tool switches to C++, use android-base/macros.h array_size() */
#ifndef ARRAY_SIZE /* popular macro */
#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))
#endif

int main(int argc, char** argv) {
  const struct fs_path_config* pc;
  const struct fs_path_config* end;
  bool dir = false, file = false;
  const char* partitions = NULL;
  FILE* fp = stdout;
  int opt;
  static const char optstring[] = "DFP:ho:";

  while ((opt = getopt(argc, argv, optstring)) != -1) {
    switch (opt) {
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
    case 'P':
      if (partitions) {
        fprintf(stderr, "Specify only one partition list\n");
        usage();
        exit(EXIT_FAILURE);
      }
      while (*optarg && isspace(*optarg)) ++optarg;
      if (!optarg[0]) {
        fprintf(stderr, "Partition list empty\n");
        usage();
        exit(EXIT_FAILURE);
      }
      if (!optarg[1]) {
        fprintf(stderr, "Partition list too short \"%s\"\n", optarg);
        usage();
        exit(EXIT_FAILURE);
      }
      if ((optarg[0] == '-') && strchr(optstring, optarg[1]) && !optarg[2]) {
        fprintf(stderr, "Partition list is a flag \"%s\"\n", optarg);
        usage();
        exit(EXIT_FAILURE);
      }
      partitions = optarg;
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

  if (optind < argc) {
    fprintf(stderr, "Unknown non-argument \"%s\"\n", argv[optind]);
    usage();
    exit(EXIT_FAILURE);
  }

  if (!file && !dir) {
    fprintf(stderr, "Must specify either -F or -D\n");
    usage();
    exit(EXIT_FAILURE);
  }

  if (dir) {
    pc = android_device_dirs;
    end = &android_device_dirs[ARRAY_SIZE(android_device_dirs)];
  } else {
    pc = android_device_files;
    end = &android_device_files[ARRAY_SIZE(android_device_files)];
  }
  for (; (pc < end) && pc->prefix; pc++) {
    bool submit;
    char buffer[512];
    ssize_t len = fs_config_generate(buffer, sizeof(buffer), pc);
    if (len < 0) {
      fprintf(stderr, "Entry too large\n");
      exit(EXIT_FAILURE);
    }
    submit = true;
    if (partitions) {
      char* partitions_copy = strdup(partitions);
      char* arg = partitions_copy;
      char* sv = NULL; /* Do not leave uninitialized, NULL is known safe. */
      /* Deal with case all iterated partitions are blacklists with no match */
      bool all_blacklist_but_no_match = true;
      submit = false;

      if (!partitions_copy) {
        fprintf(stderr, "Failed to allocate a copy of %s\n", partitions);
        exit(EXIT_FAILURE);
      }
      /* iterate through (officially) comma separated list of partitions */
      while (!!(arg = strtok_r(arg, ",:; \t\n\r\f", &sv))) {
        static const char system[] = "system/";
        size_t plen;
        bool blacklist = false;
        if (*arg == '-') {
          blacklist = true;
          ++arg;
        } else {
          all_blacklist_but_no_match = false;
        }
        plen = strlen(arg);
        /* deal with evil callers */
        while (arg[plen - 1] == '/') {
          --plen;
        }
        /* check if we have <partition>/ or /system/<partition>/ */
        if ((!strncmp(pc->prefix, arg, plen) && (pc->prefix[plen] == '/')) ||
            (!strncmp(pc->prefix, system, strlen(system)) &&
             !strncmp(pc->prefix + strlen(system), arg, plen) &&
             (pc->prefix[strlen(system) + plen] == '/'))) {
          all_blacklist_but_no_match = false;
          /* we have a match !!! */
          if (!blacklist) submit = true;
          break;
        }
        arg = NULL;
      }
      free(partitions_copy);
      if (all_blacklist_but_no_match) submit = true;
    }
    if (submit && (fwrite(buffer, 1, len, fp) != (size_t)len)) {
      fprintf(stderr, "Write failure\n");
      exit(EXIT_FAILURE);
    }
  }
  fclose(fp);

  return 0;
}
