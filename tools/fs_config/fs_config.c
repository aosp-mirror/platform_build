/*
 * Copyright (C) 2008 The Android Open Source Project
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
#include <stdlib.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <inttypes.h>

#include "private/android_filesystem_config.h"
#include "private/fs_config.h"

// This program takes a list of files and directories (indicated by a
// trailing slash) on the stdin, and prints to stdout each input
// filename along with its desired uid, gid, and mode (in octal).
// The leading slash should be stripped from the input.
//
// After the first 4 columns, optional key=value pairs are emitted
// for each file.  Currently, the following keys are supported:
//
//   -C: capabilities=[hex capabilities value]
//
// Example input:
//
//      system/etc/dbus.conf
//      data/app/
//
// Output:
//
//      system/etc/dbus.conf 1002 1002 440
//      data/app 1000 1000 771
//
// Note that the output will omit the trailing slash from
// directories.

static void usage() {
  fprintf(stderr, "Usage: fs_config [-D product_out_path] [-R root] [-C]\n");
}

int main(int argc, char** argv) {
  char buffer[1024];
  const char* product_out_path = NULL;
  char* root_path = NULL;
  int print_capabilities = 0;
  int opt;
  while((opt = getopt(argc, argv, "CR:D:")) != -1) {
    switch(opt) {
    case 'C':
      print_capabilities = 1;
      break;
    case 'R':
      root_path = optarg;
      break;
    case 'D':
      product_out_path = optarg;
      break;
    default:
      usage();
      exit(EXIT_FAILURE);
    }
  }

  if (root_path != NULL) {
    size_t root_len = strlen(root_path);
    /* Trim any trailing slashes from the root path. */
    while (root_len && root_path[--root_len] == '/') {
      root_path[root_len] = '\0';
    }
  }

  while (fgets(buffer, 1023, stdin) != NULL) {
    int is_dir = 0;
    int i;
    for (i = 0; i < 1024 && buffer[i]; ++i) {
      switch (buffer[i]) {
        case '\n':
          buffer[i-is_dir] = '\0';
          if (i == 0) {
            is_dir = 1; // empty line is considered as root directory
          }
          i = 1025;
          break;
        case '/':
          is_dir = 1;
          break;
        default:
          is_dir = 0;
          break;
      }
    }

    unsigned uid = 0, gid = 0, mode = 0;
    uint64_t capabilities;
    fs_config(buffer, is_dir, product_out_path, &uid, &gid, &mode, &capabilities);
    if (root_path != NULL && strcmp(buffer, root_path) == 0) {
      /* The root of the filesystem needs to be an empty string. */
      strcpy(buffer, "");
    }
    printf("%s %d %d %o", buffer, uid, gid, mode);

    if (print_capabilities) {
      printf(" capabilities=0x%" PRIx64, capabilities);
    }

    printf("\n");
  }
  return 0;
}
