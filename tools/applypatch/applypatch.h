/*
 * Copyright (C) 2008 The Android Open Source Project
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

#ifndef _APPLYPATCH_H
#define _APPLYPATCH_H

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

// applypatch.c
size_t FreeSpaceForFile(const char* filename);

// xdelta3.c
int ApplyXDelta3Patch(const unsigned char* old_data, ssize_t old_size,
                      const char* patch_filename,
                      FILE* output, SHA_CTX* ctx);

// bsdiff.c
void ShowBSDiffLicense();
int ApplyBSDiffPatch(const unsigned char* old_data, ssize_t old_size,
                     const char* patch_filename,
                     FILE* output, SHA_CTX* ctx);

// freecache.c
int MakeFreeSpaceOnCache(size_t bytes_needed);

#endif
