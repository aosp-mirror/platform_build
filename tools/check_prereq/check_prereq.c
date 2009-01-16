/*
 * Copyright (C) 2009 The Android Open Source Project
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
#include <sys/system_properties.h>
#include <cutils/properties.h>

// Compare the timestamp of the new build (passed on the command line)
// against the current value of ro.build.date.utc.  Exit successfully
// if the new build is newer than the current build (or if the
// timestamps are the same).
int main(int argc, char** argv) {
  if (argc != 2) {
 usage:
    fprintf(stderr, "usage: %s <timestamp>\n", argv[0]);
    return 2;
  }

  char value[PROPERTY_VALUE_MAX];
  char* default_value = "0";

  property_get("ro.build.date.utc", value, default_value);

  long current = strtol(value, NULL, 10);
  char* end;
  long install = strtol(argv[1], &end, 10);

  printf("current build time: [%ld]  new build time: [%ld]\n",
         current, install);

  return (*end == 0 && current > 0 && install >= current) ? 0 : 1;
}
