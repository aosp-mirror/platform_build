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
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

#include "private/android_filesystem_config.h"

// This program takes a list of files and directories (indicated by a
// trailing slash) on the stdin, and prints to stdout each input
// filename along with its desired uid, gid, and mode (in octal).
// The leading slash should be stripped from the input.
//
// Example input:
//
//    system/etc/dbus.conf
//    data/app/
//
// Output:
//
//    system/etc/dbus.conf 1002 1002 440
//    data/app 1000 1000 771
//
// Note that the output will omit the trailing slash from
// directories.

int main(int argc, char** argv) {
  char buffer[1024];

  while (fgets(buffer, 1023, stdin) != NULL) {
    int is_dir = 0;
    int i;
    for (i = 0; i < 1024 && buffer[i]; ++i) {
      switch (buffer[i]) {
        case '\n':
          buffer[i-is_dir] = '\0';
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
    fs_config(buffer, is_dir, &uid, &gid, &mode);
    printf("%s %d %d %o\n", buffer, uid, gid, mode);
  }
  return 0;
}
