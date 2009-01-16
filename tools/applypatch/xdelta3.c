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

#include <stdio.h>
#include <errno.h>
#include <unistd.h>

#include "xdelta3.h"
#include "mincrypt/sha.h"

int ApplyXDelta3Patch(const unsigned char* old_data, ssize_t old_size,
                      const char* patch_filename,
                      FILE* output, SHA_CTX* ctx) {
#define WINDOW_SIZE 32768

  int ret;
  xd3_stream stream;
  xd3_config config;

  xd3_init_config(&config, 0);
  config.winsize = WINDOW_SIZE;
  ret = xd3_config_stream(&stream, &config);
  if (ret != 0) {
    fprintf(stderr, "xd3_config_stream error: %s\n", xd3_strerror(ret));
    return 1;
  }

  // In xdelta3 terms, the "input" is the patch file: it contains a
  // sequence of instruction codes and data that will be executed to
  // produce the output file.  The "source" is the original data file;
  // it is a blob of data to which instructions in the input may refer
  // (eg, an instruction may say "copy such-and-such range of bytes
  // from the source to the output").

  // For simplicity, we provide the entire source to xdelta as a
  // single block.  This means it should never have to ask us to load
  // blocks of the source file.
  xd3_source source;
  source.name = "old name";
  source.size = old_size;
  source.ioh = NULL;
  source.blksize = old_size;
  source.curblkno = 0;
  source.curblk = old_data;
  source.onblk = old_size;

  ret = xd3_set_source(&stream, &source);
  if (ret != 0) {
    fprintf(stderr, "xd3_set_source error: %s\n", xd3_strerror(ret));
    return 1;
  }

  unsigned char buffer[WINDOW_SIZE];
  FILE* input = fopen(patch_filename, "rb");
  if (input == NULL) {
    fprintf(stderr, "failed to open patch file %s: %d (%s)\n",
            patch_filename, errno, strerror(errno));
    return 1;
  }

  size_t bytes_read;

  do {
    bytes_read = fread(buffer, 1, WINDOW_SIZE, input);
    if (feof(input)) {
      xd3_set_flags(&stream, XD3_FLUSH);
    }
    xd3_avail_input(&stream, buffer, bytes_read);
 process:
    ret = xd3_decode_input(&stream);
    switch (ret) {
      case XD3_INPUT:
        continue;
      case XD3_OUTPUT:
        SHA_update(ctx, stream.next_out, stream.avail_out);
        if (fwrite(stream.next_out, 1, stream.avail_out, output) !=
            stream.avail_out) {
          fprintf(stderr, "short write of output file: %d (%s)\n",
                  errno, strerror(errno));
          return 1;
        }
        xd3_consume_output(&stream);
        goto process;
      case XD3_GETSRCBLK:
        // We provided the entire source file already; it should never
        // have to ask us for a block.
        fprintf(stderr, "xd3_decode_input: unexpected GETSRCBLK\n");
        return 1;
      case XD3_GOTHEADER:
      case XD3_WINSTART:
      case XD3_WINFINISH:
        // These are informational events we don't care about.
        goto process;
      default:
        fprintf(stderr, "xd3_decode_input: unknown error %s (%s)\n",
                xd3_strerror(ret), stream.msg);
        return 1;
    }
  } while (!feof(input));

  fclose(input);
  return 0;

#undef WINDOW_SIZE
}
