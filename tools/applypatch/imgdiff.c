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

/*
 * This program constructs binary patches for images -- such as boot.img
 * and recovery.img -- that consist primarily of large chunks of gzipped
 * data interspersed with uncompressed data.  Doing a naive bsdiff of
 * these files is not useful because small changes in the data lead to
 * large changes in the compressed bitstream; bsdiff patches of gzipped
 * data are typically as large as the data itself.
 *
 * To patch these usefully, we break the source and target images up into
 * chunks of two types: "normal" and "gzip".  Normal chunks are simply
 * patched using a plain bsdiff.  Gzip chunks are first expanded, then a
 * bsdiff is applied to the uncompressed data, then the patched data is
 * gzipped using the same encoder parameters.  Patched chunks are
 * concatenated together to create the output file; the output image
 * should be *exactly* the same series of bytes as the target image used
 * originally to generate the patch.
 *
 * To work well with this tool, the gzipped sections of the target
 * image must have been generated using the same deflate encoder that
 * is available in applypatch, namely, the one in the zlib library.
 * In practice this means that images should be compressed using the
 * "minigzip" tool included in the zlib distribution, not the GNU gzip
 * program.
 *
 * An "imgdiff" patch consists of a header describing the chunk structure
 * of the file and any encoding parameters needed for the gzipped
 * chunks, followed by N bsdiff patches, one per chunk.
 *
 * For a diff to be generated, the source and target images must have the
 * same "chunk" structure: that is, the same number of gzipped and normal
 * chunks in the same order.  Android boot and recovery images currently
 * consist of five chunks:  a small normal header, a gzipped kernel, a
 * small normal section, a gzipped ramdisk, and finally a small normal
 * footer.
 *
 * Caveats:  we locate gzipped sections within the source and target
 * images by searching for the byte sequence 1f8b0800:  1f8b is the gzip
 * magic number; 08 specifies the "deflate" encoding [the only encoding
 * supported by the gzip standard]; and 00 is the flags byte.  We do not
 * currently support any extra header fields (which would be indicated by
 * a nonzero flags byte).  We also don't handle the case when that byte
 * sequence appears spuriously in the file.  (Note that it would have to
 * occur spuriously within a normal chunk to be a problem.)
 *
 *
 * The imgdiff patch header looks like this:
 *
 *    "IMGDIFF1"                  (8)   [magic number and version]
 *    chunk count                 (4)
 *    for each chunk:
 *        chunk type              (4)   [CHUNK_NORMAL or CHUNK_GZIP]
 *        source start            (8)
 *        source len              (8)
 *        bsdiff patch offset     (8)   [from start of patch file]
 *        if chunk type == CHUNK_GZIP:
 *           source expanded len  (8)   [size of uncompressed source]
 *           target expected len  (8)   [size of uncompressed target]
 *           gzip level           (4)
 *                method          (4)
 *                windowBits      (4)
 *                memLevel        (4)
 *                strategy        (4)
 *           gzip header len      (4)
 *           gzip header          (gzip header len)
 *           gzip footer          (8)
 *
 * All integers are little-endian.  "source start" and "source len"
 * specify the section of the input image that comprises this chunk,
 * including the gzip header and footer for gzip chunks.  "source
 * expanded len" is the size of the uncompressed source data.  "target
 * expected len" is the size of the uncompressed data after applying
 * the bsdiff patch.  The next five parameters specify the zlib
 * parameters to be used when compressing the patched data, and the
 * next three specify the header and footer to be wrapped around the
 * compressed data to create the output chunk (so that header contents
 * like the timestamp are recreated exactly).
 *
 * After the header there are 'chunk count' bsdiff patches; the offset
 * of each from the beginning of the file is specified in the header.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "zlib.h"
#include "imgdiff.h"

typedef struct {
  int type;             // CHUNK_NORMAL or CHUNK_GZIP
  size_t start;         // offset of chunk in original image file

  size_t len;
  unsigned char* data;  // data to be patched (ie, uncompressed, for
                        // gzip chunks)

  // everything else is for CHUNK_GZIP chunks only:

  size_t gzip_header_len;
  unsigned char* gzip_header;
  unsigned char* gzip_footer;

  // original (compressed) gzip data, including header and footer
  size_t gzip_len;
  unsigned char* gzip_data;

  // deflate encoder parameters
  int level, method, windowBits, memLevel, strategy;
} ImageChunk;

/*
 * Read the given file and break it up into chunks, putting the number
 * of chunks and their info in *num_chunks and **chunks,
 * respectively.  Returns a malloc'd block of memory containing the
 * contents of the file; various pointers in the output chunk array
 * will point into this block of memory.  The caller should free the
 * return value when done with all the chunks.  Returns NULL on
 * failure.
 */
unsigned char* ReadImage(const char* filename,
                         int* num_chunks, ImageChunk** chunks) {
  struct stat st;
  if (stat(filename, &st) != 0) {
    fprintf(stderr, "failed to stat \"%s\": %s\n", filename, strerror(errno));
    return NULL;
  }

  unsigned char* img = malloc(st.st_size + 4);
  FILE* f = fopen(filename, "rb");
  if (fread(img, 1, st.st_size, f) != st.st_size) {
    fprintf(stderr, "failed to read \"%s\" %s\n", filename, strerror(errno));
    fclose(f);
    return NULL;
  }
  fclose(f);

  // append 4 zero bytes to the data so we can always search for the
  // four-byte string 1f8b0800 starting at any point in the actual
  // file data, without special-casing the end of the data.
  memset(img+st.st_size, 0, 4);

  size_t pos = 0;

  *num_chunks = 0;
  *chunks = NULL;

  while (pos < st.st_size) {
    unsigned char* p = img+pos;

    // Reallocate the list for every chunk; we expect the number of
    // chunks to be small (5 for typical boot and recovery images).
    ++*num_chunks;
    *chunks = realloc(*chunks, *num_chunks * sizeof(ImageChunk));
    ImageChunk* curr = *chunks + (*num_chunks-1);
    curr->start = pos;

    if (st.st_size - pos >= 4 &&
        p[0] == 0x1f && p[1] == 0x8b &&
        p[2] == 0x08 &&    // deflate compression
        p[3] == 0x00) {    // no header flags
      // 'pos' is the offset of the start of a gzip chunk.

      curr->type = CHUNK_GZIP;
      curr->gzip_header_len = GZIP_HEADER_LEN;
      curr->gzip_header = p;

      // We must decompress this chunk in order to discover where it
      // ends, and so we can put the uncompressed data and its length
      // into curr->data and curr->len;

      size_t allocated = 32768;
      curr->len = 0;
      curr->data = malloc(allocated);
      curr->gzip_data = p;

      z_stream strm;
      strm.zalloc = Z_NULL;
      strm.zfree = Z_NULL;
      strm.opaque = Z_NULL;
      strm.avail_in = st.st_size - (pos + curr->gzip_header_len);
      strm.next_in = p + GZIP_HEADER_LEN;

      // -15 means we are decoding a 'raw' deflate stream; zlib will
      // not expect zlib headers.
      int ret = inflateInit2(&strm, -15);

      do {
        strm.avail_out = allocated - curr->len;
        strm.next_out = curr->data + curr->len;
        ret = inflate(&strm, Z_NO_FLUSH);
        curr->len = allocated - strm.avail_out;
        if (strm.avail_out == 0) {
          allocated *= 2;
          curr->data = realloc(curr->data, allocated);
        }
      } while (ret != Z_STREAM_END);

      curr->gzip_len = st.st_size - strm.avail_in - pos + GZIP_FOOTER_LEN;
      pos = st.st_size - strm.avail_in;
      inflateEnd(&strm);

      // consume the gzip footer.
      curr->gzip_footer = img+pos;
      pos += GZIP_FOOTER_LEN;
      p = img+pos;

      // The footer (that we just skipped over) contains the size of
      // the uncompressed data.  Double-check to make sure that it
      // matches the size of the data we got when we actually did
      // the decompression.
      size_t footer_size = p[-4] + (p[-3] << 8) + (p[-2] << 16) + (p[-1] << 24);
      if (footer_size != curr->len) {
        fprintf(stderr, "Error: footer size %d != decompressed size %d\n",
                footer_size, curr->len);
        free(img);
        return NULL;
      }
    } else {
      // 'pos' is not the offset of the start of a gzip chunk, so scan
      // forward until we find a gzip header.
      curr->type = CHUNK_NORMAL;
      curr->data = p;

      for (curr->len = 0; curr->len < (st.st_size - pos); ++curr->len) {
        if (p[curr->len] == 0x1f &&
            p[curr->len+1] == 0x8b &&
            p[curr->len+2] == 0x08 &&
            p[curr->len+3] == 0x00) {
          break;
        }
      }
      pos += curr->len;
    }
  }

  return img;
}

#define BUFFER_SIZE 32768

/*
 * Takes the uncompressed data stored in the chunk, compresses it
 * using the zlib parameters stored in the chunk, and checks that it
 * matches exactly the compressed data we started with (also stored in
 * the chunk).  Return 0 on success.
 */
int TryReconstruction(ImageChunk* chunk, unsigned char* out) {
  size_t p = chunk->gzip_header_len;

  z_stream strm;
  strm.zalloc = Z_NULL;
  strm.zfree = Z_NULL;
  strm.opaque = Z_NULL;
  strm.avail_in = chunk->len;
  strm.next_in = chunk->data;
  int ret;
  ret = deflateInit2(&strm, chunk->level, chunk->method, chunk->windowBits,
                     chunk->memLevel, chunk->strategy);
  do {
    strm.avail_out = BUFFER_SIZE;
    strm.next_out = out;
    ret = deflate(&strm, Z_FINISH);
    size_t have = BUFFER_SIZE - strm.avail_out;

    if (memcmp(out, chunk->gzip_data+p, have) != 0) {
      // mismatch; data isn't the same.
      deflateEnd(&strm);
      return -1;
    }
    p += have;
  } while (ret != Z_STREAM_END);
  deflateEnd(&strm);
  if (p + GZIP_FOOTER_LEN != chunk->gzip_len) {
    // mismatch; ran out of data before we should have.
    return -1;
  }
  return 0;
}

/*
 * Verify that we can reproduce exactly the same compressed data that
 * we started with.  Sets the level, method, windowBits, memLevel, and
 * strategy fields in the chunk to the encoding parameters needed to
 * produce the right output.  Returns 0 on success.
 */
int ReconstructGzipChunk(ImageChunk* chunk) {
  if (chunk->type != CHUNK_GZIP) {
    fprintf(stderr, "attempt to reconstruct non-gzip chunk\n");
    return -1;
  }

  size_t p = 0;
  unsigned char* out = malloc(BUFFER_SIZE);

  // We only check two combinations of encoder parameters:  level 6
  // (the default) and level 9 (the maximum).
  for (chunk->level = 6; chunk->level <= 9; chunk->level += 3) {
    chunk->windowBits = -15;  // 32kb window; negative to indicate a raw stream.
    chunk->memLevel = 8;      // the default value.
    chunk->method = Z_DEFLATED;
    chunk->strategy = Z_DEFAULT_STRATEGY;

    if (TryReconstruction(chunk, out) == 0) {
      free(out);
      return 0;
    }
  }

  free(out);
  return -1;
}

/** Write a 4-byte value to f in little-endian order. */
void Write4(int value, FILE* f) {
  fputc(value & 0xff, f);
  fputc((value >> 8) & 0xff, f);
  fputc((value >> 16) & 0xff, f);
  fputc((value >> 24) & 0xff, f);
}

/** Write an 8-byte value to f in little-endian order. */
void Write8(long long value, FILE* f) {
  fputc(value & 0xff, f);
  fputc((value >> 8) & 0xff, f);
  fputc((value >> 16) & 0xff, f);
  fputc((value >> 24) & 0xff, f);
  fputc((value >> 32) & 0xff, f);
  fputc((value >> 40) & 0xff, f);
  fputc((value >> 48) & 0xff, f);
  fputc((value >> 56) & 0xff, f);
}


/*
 * Given source and target chunks, compute a bsdiff patch between them
 * by running bsdiff in a subprocess.  Return the patch data, placing
 * its length in *size.  Return NULL on failure.  We expect the bsdiff
 * program to be in the path.
 */
unsigned char* MakePatch(ImageChunk* src, ImageChunk* tgt, size_t* size) {
  char stemp[] = "/tmp/imgdiff-src-XXXXXX";
  char ttemp[] = "/tmp/imgdiff-tgt-XXXXXX";
  char ptemp[] = "/tmp/imgdiff-patch-XXXXXX";
  mkstemp(stemp);
  mkstemp(ttemp);
  mkstemp(ptemp);

  FILE* f = fopen(stemp, "wb");
  if (f == NULL) {
    fprintf(stderr, "failed to open src chunk %s: %s\n",
            stemp, strerror(errno));
    return NULL;
  }
  if (fwrite(src->data, 1, src->len, f) != src->len) {
    fprintf(stderr, "failed to write src chunk to %s: %s\n",
            stemp, strerror(errno));
    return NULL;
  }
  fclose(f);

  f = fopen(ttemp, "wb");
  if (f == NULL) {
    fprintf(stderr, "failed to open tgt chunk %s: %s\n",
            ttemp, strerror(errno));
    return NULL;
  }
  if (fwrite(tgt->data, 1, tgt->len, f) != tgt->len) {
    fprintf(stderr, "failed to write tgt chunk to %s: %s\n",
            ttemp, strerror(errno));
    return NULL;
  }
  fclose(f);

  char cmd[200];
  sprintf(cmd, "bsdiff %s %s %s", stemp, ttemp, ptemp);
  if (system(cmd) != 0) {
    fprintf(stderr, "failed to run bsdiff: %s\n", strerror(errno));
    return NULL;
  }

  struct stat st;
  if (stat(ptemp, &st) != 0) {
    fprintf(stderr, "failed to stat patch file %s: %s\n",
            ptemp, strerror(errno));
    return NULL;
  }

  unsigned char* data = malloc(st.st_size);
  *size = st.st_size;

  f = fopen(ptemp, "rb");
  if (f == NULL) {
    fprintf(stderr, "failed to open patch %s: %s\n", ptemp, strerror(errno));
    return NULL;
  }
  if (fread(data, 1, st.st_size, f) != st.st_size) {
    fprintf(stderr, "failed to read patch %s: %s\n", ptemp, strerror(errno));
    return NULL;
  }
  fclose(f);

  unlink(stemp);
  unlink(ttemp);
  unlink(ptemp);

  return data;
}

/*
 * Cause a gzip chunk to be treated as a normal chunk (ie, as a blob
 * of uninterpreted data).  The resulting patch will likely be about
 * as big as the target file, but it lets us handle the case of images
 * where some gzip chunks are reconstructible but others aren't (by
 * treating the ones that aren't as normal chunks).
 */
void ChangeGzipChunkToNormal(ImageChunk* ch) {
  ch->type = CHUNK_NORMAL;
  free(ch->data);
  ch->data = ch->gzip_data;
  ch->len = ch->gzip_len;
}

int main(int argc, char** argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: %s <src-img> <tgt-img> <patch-file>\n", argv[0]);
    return 2;
  }

  int num_src_chunks;
  ImageChunk* src_chunks;
  if (ReadImage(argv[1], &num_src_chunks, &src_chunks) == NULL) {
    fprintf(stderr, "failed to break apart source image\n");
    return 1;
  }

  int num_tgt_chunks;
  ImageChunk* tgt_chunks;
  if (ReadImage(argv[2], &num_tgt_chunks, &tgt_chunks) == NULL) {
    fprintf(stderr, "failed to break apart target image\n");
    return 1;
  }

  // Verify that the source and target images have the same chunk
  // structure (ie, the same sequence of gzip and normal chunks).

  if (num_src_chunks != num_tgt_chunks) {
    fprintf(stderr, "source and target don't have same number of chunks!\n");
    return 1;
  }
  int i;
  for (i = 0; i < num_src_chunks; ++i) {
    if (src_chunks[i].type != tgt_chunks[i].type) {
      fprintf(stderr, "source and target don't have same chunk "
              "structure! (chunk %d)\n", i);
      return 1;
    }
  }

  // Confirm that given the uncompressed chunk data in the target, we
  // can recompress it and get exactly the same bits as are in the
  // input target image.  If this fails, treat the chunk as a normal
  // non-gzipped chunk.

  for (i = 0; i < num_tgt_chunks; ++i) {
    if (tgt_chunks[i].type == CHUNK_GZIP) {
      if (ReconstructGzipChunk(tgt_chunks+i) < 0) {
        printf("failed to reconstruct target gzip chunk %d; "
               "treating as normal chunk\n", i);
        ChangeGzipChunkToNormal(tgt_chunks+i);
        ChangeGzipChunkToNormal(src_chunks+i);
      } else {
        printf("reconstructed target gzip chunk %d\n", i);
      }
    }
  }

  // Compute bsdiff patches for each chunk's data (the uncompressed
  // data, in the case of gzip chunks).

  unsigned char** patch_data = malloc(num_src_chunks * sizeof(unsigned char*));
  size_t* patch_size = malloc(num_src_chunks * sizeof(size_t));
  for (i = 0; i < num_src_chunks; ++i) {
    patch_data[i] = MakePatch(src_chunks+i, tgt_chunks+i, patch_size+i);
    printf("patch %d is %d bytes (of %d)\n", i, patch_size[i],
           tgt_chunks[i].type == CHUNK_NORMAL ? tgt_chunks[i].len : tgt_chunks[i].gzip_len);

  }

  // Figure out how big the imgdiff file header is going to be, so
  // that we can correctly compute the offset of each bsdiff patch
  // within the file.

  size_t total_header_size = 12;
  for (i = 0; i < num_src_chunks; ++i) {
    total_header_size += 4 + 8*3;
    if (src_chunks[i].type == CHUNK_GZIP) {
      total_header_size += 8*2 + 4*6 + tgt_chunks[i].gzip_header_len + 8;
    }
  }

  size_t offset = total_header_size;

  FILE* f = fopen(argv[3], "wb");

  // Write out the headers.

  fwrite("IMGDIFF1", 1, 8, f);
  Write4(num_src_chunks, f);
  for (i = 0; i < num_tgt_chunks; ++i) {
    Write4(tgt_chunks[i].type, f);
    Write8(src_chunks[i].start, f);
    Write8(src_chunks[i].type == CHUNK_NORMAL ? src_chunks[i].len :
           (src_chunks[i].gzip_len + src_chunks[i].gzip_header_len + 8), f);
    Write8(offset, f);

    if (tgt_chunks[i].type == CHUNK_GZIP) {
      Write8(src_chunks[i].len, f);
      Write8(tgt_chunks[i].len, f);
      Write4(tgt_chunks[i].level, f);
      Write4(tgt_chunks[i].method, f);
      Write4(tgt_chunks[i].windowBits, f);
      Write4(tgt_chunks[i].memLevel, f);
      Write4(tgt_chunks[i].strategy, f);
      Write4(tgt_chunks[i].gzip_header_len, f);
      fwrite(tgt_chunks[i].gzip_header, 1, tgt_chunks[i].gzip_header_len, f);
      fwrite(tgt_chunks[i].gzip_footer, 1, GZIP_FOOTER_LEN, f);
    }

    offset += patch_size[i];
  }

  // Append each chunk's bsdiff patch, in order.

  for (i = 0; i < num_tgt_chunks; ++i) {
    fwrite(patch_data[i], 1, patch_size[i], f);
  }

  fclose(f);

  return 0;
}
