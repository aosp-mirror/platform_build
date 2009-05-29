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

// See imgdiff.c in this directory for a description of the patch file
// format.

#include <stdio.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

#include "zlib.h"
#include "mincrypt/sha.h"
#include "applypatch.h"
#include "imgdiff.h"

int Read4(unsigned char* p) {
  return (int)(((unsigned int)p[3] << 24) |
               ((unsigned int)p[2] << 16) |
               ((unsigned int)p[1] << 8) |
               (unsigned int)p[0]);
}

long long Read8(unsigned char* p) {
  return (long long)(((unsigned long long)p[7] << 56) |
                     ((unsigned long long)p[6] << 48) |
                     ((unsigned long long)p[5] << 40) |
                     ((unsigned long long)p[4] << 32) |
                     ((unsigned long long)p[3] << 24) |
                     ((unsigned long long)p[2] << 16) |
                     ((unsigned long long)p[1] << 8) |
                     (unsigned long long)p[0]);
}

/*
 * Apply the patch given in 'patch_filename' to the source data given
 * by (old_data, old_size).  Write the patched output to the 'output'
 * file, and update the SHA context with the output data as well.
 * Return 0 on success.
 */
int ApplyImagePatch(const unsigned char* old_data, ssize_t old_size,
                    const char* patch_filename,
                    FILE* output, SHA_CTX* ctx) {
  FILE* f;
  if ((f = fopen(patch_filename, "rb")) == NULL) {
    fprintf(stderr, "failed to open patch file\n");
    return -1;
  }

  unsigned char header[12];
  if (fread(header, 1, 12, f) != 12) {
    fprintf(stderr, "failed to read patch file header\n");
    return -1;
  }

  if (memcmp(header, "IMGDIFF1", 8) != 0) {
    fprintf(stderr, "corrupt patch file header (magic number)\n");
    return -1;
  }

  int num_chunks = Read4(header+8);

  int i;
  for (i = 0; i < num_chunks; ++i) {
    // each chunk's header record starts with 28 bytes (4 + 8*3).
    unsigned char chunk[28];
    if (fread(chunk, 1, 28, f) != 28) {
      fprintf(stderr, "failed to read chunk %d record\n", i);
      return -1;
    }

    int type = Read4(chunk);
    size_t src_start = Read8(chunk+4);
    size_t src_len = Read8(chunk+12);
    size_t patch_offset = Read8(chunk+20);

    if (type == CHUNK_NORMAL) {
      fprintf(stderr, "CHUNK %d:  normal   patch offset %d\n", i, patch_offset);

      ApplyBSDiffPatch(old_data + src_start, src_len,
                       patch_filename, patch_offset,
                       output, ctx);
    } else if (type == CHUNK_GZIP) {
      fprintf(stderr, "CHUNK %d:  gzip     patch offset %d\n", i, patch_offset);

      // gzip chunks have an additional 40 + gzip_header_len + 8 bytes
      // in their chunk header.
      unsigned char* gzip = malloc(40);
      if (fread(gzip, 1, 40, f) != 40) {
        fprintf(stderr, "failed to read chunk %d initial gzip data\n", i);
        return -1;
      }
      size_t gzip_header_len = Read4(gzip+36);
      gzip = realloc(gzip, 40 + gzip_header_len + 8);
      if (fread(gzip+40, 1, gzip_header_len+8, f) != gzip_header_len+8) {
        fprintf(stderr, "failed to read chunk %d remaining gzip data\n", i);
        return -1;
      }

      size_t expanded_len = Read8(gzip);
      size_t target_len = Read8(gzip);
      int gz_level = Read4(gzip+16);
      int gz_method = Read4(gzip+20);
      int gz_windowBits = Read4(gzip+24);
      int gz_memLevel = Read4(gzip+28);
      int gz_strategy = Read4(gzip+32);

      // Decompress the source data; the chunk header tells us exactly
      // how big we expect it to be when decompressed.

      unsigned char* expanded_source = malloc(expanded_len);
      if (expanded_source == NULL) {
        fprintf(stderr, "failed to allocate %d bytes for expanded_source\n", expanded_len);
        return -1;
      }

      z_stream strm;
      strm.zalloc = Z_NULL;
      strm.zfree = Z_NULL;
      strm.opaque = Z_NULL;
      strm.avail_in = src_len - (gzip_header_len + 8);
      strm.next_in = (unsigned char*)(old_data + src_start + gzip_header_len);
      strm.avail_out = expanded_len;
      strm.next_out = expanded_source;

      int ret;
      ret = inflateInit2(&strm, -15);
      if (ret != Z_OK) {
        fprintf(stderr, "failed to init source inflation: %d\n", ret);
        return -1;
      }

      // Because we've provided enough room to accommodate the output
      // data, we expect one call to inflate() to suffice.
      ret = inflate(&strm, Z_SYNC_FLUSH);
      if (ret != Z_STREAM_END) {
        fprintf(stderr, "source inflation returned %d\n", ret);
        return -1;
      }
      // We should have filled the output buffer exactly.
      if (strm.avail_out != 0) {
        fprintf(stderr, "source inflation short by %d bytes\n", strm.avail_out);
        return -1;
      }
      inflateEnd(&strm);

      // Next, apply the bsdiff patch (in memory) to the uncompressed
      // data.
      unsigned char* uncompressed_target_data;
      ssize_t uncompressed_target_size;
      if (ApplyBSDiffPatchMem(expanded_source, expanded_len,
                              patch_filename, patch_offset,
                              &uncompressed_target_data,
                              &uncompressed_target_size) != 0) {
        return -1;
      }

      // Now compress the target data and append it to the output.

      // start with the gzip header.
      fwrite(gzip+40, 1, gzip_header_len, output);
      SHA_update(ctx, gzip+40, gzip_header_len);

      // we're done with the expanded_source data buffer, so we'll
      // reuse that memory to receive the output of deflate.
      unsigned char* temp_data = expanded_source;
      ssize_t temp_size = expanded_len;
      if (temp_size < 32768) {
        // ... unless the buffer is too small, in which case we'll
        // allocate a fresh one.
        free(temp_data);
        temp_data = malloc(32768);
        temp_size = 32768;
      }

      // now the deflate stream
      strm.zalloc = Z_NULL;
      strm.zfree = Z_NULL;
      strm.opaque = Z_NULL;
      strm.avail_in = uncompressed_target_size;
      strm.next_in = uncompressed_target_data;
      ret = deflateInit2(&strm, gz_level, gz_method, gz_windowBits,
                         gz_memLevel, gz_strategy);
      do {
        strm.avail_out = temp_size;
        strm.next_out = temp_data;
        ret = deflate(&strm, Z_FINISH);
        size_t have = temp_size - strm.avail_out;

        if (fwrite(temp_data, 1, have, output) != have) {
          fprintf(stderr, "failed to write %d compressed bytes to output\n",
                  have);
          return -1;
        }
        SHA_update(ctx, temp_data, have);
      } while (ret != Z_STREAM_END);
      deflateEnd(&strm);

      // lastly, the gzip footer.
      fwrite(gzip+40+gzip_header_len, 1, 8, output);
      SHA_update(ctx, gzip+40+gzip_header_len, 8);

      free(temp_data);
      free(uncompressed_target_data);
      free(gzip);
    } else {
      fprintf(stderr, "patch chunk %d is unknown type %d\n", i, type);
      return -1;
    }
  }

  return 0;
}
