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

#ifndef _APPLYPATCH_H
#define _APPLYPATCH_H

#include <sys/stat.h>
#include "mincrypt/sha.h"

typedef struct _Patch {
  uint8_t sha1[SHA_DIGEST_SIZE];
  const char* patch_filename;
} Patch;

typedef struct _FileContents {
  uint8_t sha1[SHA_DIGEST_SIZE];
  unsigned char* data;
  size_t size;
  struct stat st;
} FileContents;

// When there isn't enough room on the target filesystem to hold the
// patched version of the file, we copy the original here and delete
// it to free up space.  If the expected source file doesn't exist, or
// is corrupted, we look to see if this file contains the bits we want
// and use it as the source instead.
#define CACHE_TEMP_SOURCE "/cache/saved.file"

// When writing to an MTD partition, we first put the output in this
// temp file, then copy it to the partition once the patching is
// finished (and the target sha1 verified).
#define MTD_TARGET_TEMP_FILE "/tmp/mtd-temp"

// applypatch.c
size_t FreeSpaceForFile(const char* filename);
int applypatch(int argc, char** argv);

// bsdiff.c
void ShowBSDiffLicense();
int ApplyBSDiffPatch(const unsigned char* old_data, ssize_t old_size,
                     const char* patch_filename, ssize_t offset,
                     FILE* output, SHA_CTX* ctx);
int ApplyBSDiffPatchMem(const unsigned char* old_data, ssize_t old_size,
                        const char* patch_filename, ssize_t patch_offset,
                        unsigned char** new_data, ssize_t* new_size);

// imgpatch.c
int ApplyImagePatch(const unsigned char* old_data, ssize_t old_size,
                     const char* patch_filename,
                     FILE* output, SHA_CTX* ctx);

// freecache.c
int MakeFreeSpaceOnCache(size_t bytes_needed);

#endif
