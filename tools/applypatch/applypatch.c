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

#include <errno.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <unistd.h>

#include "mincrypt/sha.h"
#include "applypatch.h"

// Read a file into memory; store it and its associated metadata in
// *file.  Return 0 on success.
int LoadFileContents(const char* filename, FileContents* file) {
  file->data = NULL;

  if (stat(filename, &file->st) != 0) {
    fprintf(stderr, "failed to stat \"%s\": %s\n", filename, strerror(errno));
    return -1;
  }

  file->size = file->st.st_size;
  file->data = malloc(file->size);

  FILE* f = fopen(filename, "rb");
  if (f == NULL) {
    fprintf(stderr, "failed to open \"%s\": %s\n", filename, strerror(errno));
    free(file->data);
    return -1;
  }

  size_t bytes_read = fread(file->data, 1, file->size, f);
  if (bytes_read != file->size) {
    fprintf(stderr, "short read of \"%s\" (%d bytes of %d)\n",
            filename, bytes_read, file->size);
    free(file->data);
    return -1;
  }
  fclose(f);

  SHA(file->data, file->size, file->sha1);
  return 0;
}

// Save the contents of the given FileContents object under the given
// filename.  Return 0 on success.
int SaveFileContents(const char* filename, FileContents file) {
  FILE* f = fopen(filename, "wb");
  if (f == NULL) {
    fprintf(stderr, "failed to open \"%s\" for write: %s\n",
            filename, strerror(errno));
    return -1;
  }

  size_t bytes_written = fwrite(file.data, 1, file.size, f);
  if (bytes_written != file.size) {
    fprintf(stderr, "short write of \"%s\" (%d bytes of %d)\n",
            filename, bytes_written, file.size);
    return -1;
  }
  fflush(f);
  fsync(fileno(f));
  fclose(f);

  if (chmod(filename, file.st.st_mode) != 0) {
    fprintf(stderr, "chmod of \"%s\" failed: %s\n", filename, strerror(errno));
    return -1;
  }
  if (chown(filename, file.st.st_uid, file.st.st_gid) != 0) {
    fprintf(stderr, "chown of \"%s\" failed: %s\n", filename, strerror(errno));
    return -1;
  }

  return 0;
}


// Take a string 'str' of 40 hex digits and parse it into the 20
// byte array 'digest'.  'str' may contain only the digest or be of
// the form "<digest>:<anything>".  Return 0 on success, -1 on any
// error.
int ParseSha1(const char* str, uint8_t* digest) {
  int i;
  const char* ps = str;
  uint8_t* pd = digest;
  for (i = 0; i < SHA_DIGEST_SIZE * 2; ++i, ++ps) {
    int digit;
    if (*ps >= '0' && *ps <= '9') {
      digit = *ps - '0';
    } else if (*ps >= 'a' && *ps <= 'f') {
      digit = *ps - 'a' + 10;
    } else if (*ps >= 'A' && *ps <= 'F') {
      digit = *ps - 'A' + 10;
    } else {
      return -1;
    }
    if (i % 2 == 0) {
      *pd = digit << 4;
    } else {
      *pd |= digit;
      ++pd;
    }
  }
  if (*ps != '\0' && *ps != ':') return -1;
  return 0;
}

// Parse arguments (which should be of the form "<sha1>" or
// "<sha1>:<filename>" into the array *patches, returning the number
// of Patch objects in *num_patches.  Return 0 on success.
int ParseShaArgs(int argc, char** argv, Patch** patches, int* num_patches) {
  *num_patches = argc;
  *patches = malloc(*num_patches * sizeof(Patch));

  int i;
  for (i = 0; i < *num_patches; ++i) {
    if (ParseSha1(argv[i], (*patches)[i].sha1) != 0) {
      fprintf(stderr, "failed to parse sha1 \"%s\"\n", argv[i]);
      return -1;
    }
    if (argv[i][SHA_DIGEST_SIZE*2] == '\0') {
      (*patches)[i].patch_filename = NULL;
    } else if (argv[i][SHA_DIGEST_SIZE*2] == ':') {
      (*patches)[i].patch_filename = argv[i] + (SHA_DIGEST_SIZE*2+1);
    } else {
      fprintf(stderr, "failed to parse filename \"%s\"\n", argv[i]);
      return -1;
    }
  }

  return 0;
}

// Search an array of Patch objects for one matching the given sha1.
// Return the Patch object on success, or NULL if no match is found.
const Patch* FindMatchingPatch(uint8_t* sha1, Patch* patches, int num_patches) {
  int i;
  for (i = 0; i < num_patches; ++i) {
    if (memcmp(patches[i].sha1, sha1, SHA_DIGEST_SIZE) == 0) {
      return patches+i;
    }
  }
  return NULL;
}

// Returns 0 if the contents of the file (argv[2]) or the cached file
// match any of the sha1's on the command line (argv[3:]).  Returns
// nonzero otherwise.
int CheckMode(int argc, char** argv) {
  if (argc < 3) {
    fprintf(stderr, "no filename given\n");
    return 2;
  }

  int num_patches;
  Patch* patches;
  if (ParseShaArgs(argc-3, argv+3, &patches, &num_patches) != 0) { return 1; }

  FileContents file;
  file.data = NULL;

  if (LoadFileContents(argv[2], &file) != 0 ||
      FindMatchingPatch(file.sha1, patches, num_patches) == NULL) {
    fprintf(stderr, "file \"%s\" doesn't have any of expected "
            "sha1 sums; checking cache\n", argv[2]);

    free(file.data);

    // If the source file is missing or corrupted, it might be because
    // we were killed in the middle of patching it.  A copy of it
    // should have been made in CACHE_TEMP_SOURCE.  If that file
    // exists and matches the sha1 we're looking for, the check still
    // passes.

    if (LoadFileContents(CACHE_TEMP_SOURCE, &file) != 0) {
      fprintf(stderr, "failed to load cache file\n");
      return 1;
    }

    if (FindMatchingPatch(file.sha1, patches, num_patches) == NULL) {
      fprintf(stderr, "cache bits don't match any sha1 for \"%s\"\n",
              argv[2]);
      return 1;
    }
  }

  free(file.data);
  return 0;
}

int ShowLicenses() {
  ShowBSDiffLicense();
  return 0;
}

// Return the amount of free space (in bytes) on the filesystem
// containing filename.  filename must exist.  Return -1 on error.
size_t FreeSpaceForFile(const char* filename) {
  struct statfs sf;
  if (statfs(filename, &sf) != 0) {
    fprintf(stderr, "failed to statfs %s: %s\n", filename, strerror(errno));
    return -1;
  }
  return sf.f_bsize * sf.f_bfree;
}

// This program applies binary patches to files in a way that is safe
// (the original file is not touched until we have the desired
// replacement for it) and idempotent (it's okay to run this program
// multiple times).
//
// - if the sha1 hash of <file> is <tgt-sha1>, does nothing and exits
//   successfully.
//
// - otherwise, if the sha1 hash of <file> is <src-sha1>, applies the
//   bsdiff <patch> to <file> to produce a new file (the type of patch
//   is automatically detected from the file header).  If that new
//   file has sha1 hash <tgt-sha1>, moves it to replace <file>, and
//   exits successfully.
//
// - otherwise, or if any error is encountered, exits with non-zero
//   status.

int main(int argc, char** argv) {
  if (argc < 2) {
 usage:
    fprintf(stderr, "usage: %s <file> <tgt-sha1> <tgt-size> [<src-sha1>:<patch> ...]\n"
                    "   or  %s -c <file> [<sha1> ...]\n"
                    "   or  %s -s <bytes>\n"
                    "   or  %s -l\n",
            argv[0], argv[0], argv[0], argv[0]);
    return 1;
  }

  if (strncmp(argv[1], "-l", 3) == 0) {
    return ShowLicenses();
  }

  if (strncmp(argv[1], "-c", 3) == 0) {
    return CheckMode(argc, argv);
  }

  if (strncmp(argv[1], "-s", 3) == 0) {
    if (argc != 3) {
      goto usage;
    }
    size_t bytes = strtol(argv[2], NULL, 10);
    if (MakeFreeSpaceOnCache(bytes) < 0) {
      printf("unable to make %ld bytes available on /cache\n", (long)bytes);
      return 1;
    } else {
      return 0;
    }
  }

  uint8_t target_sha1[SHA_DIGEST_SIZE];

  const char* source_filename = argv[1];

  // assume that source_filename (eg "/system/app/Foo.apk") is located
  // on the same filesystem as its top-level directory ("/system").
  // We need something that exists for calling statfs().
  char* source_fs = strdup(argv[1]);
  char* slash = strchr(source_fs+1, '/');
  if (slash != NULL) {
    *slash = '\0';
  }

  if (ParseSha1(argv[2], target_sha1) != 0) {
    fprintf(stderr, "failed to parse tgt-sha1 \"%s\"\n", argv[2]);
    return 1;
  }

  unsigned long target_size = strtoul(argv[3], NULL, 0);

  int num_patches;
  Patch* patches;
  if (ParseShaArgs(argc-4, argv+4, &patches, &num_patches) < 0) { return 1; }

  FileContents copy_file;
  FileContents source_file;
  const char* source_patch_filename = NULL;
  const char* copy_patch_filename = NULL;
  int made_copy = 0;

  if (LoadFileContents(source_filename, &source_file) == 0) {
    if (memcmp(source_file.sha1, target_sha1, SHA_DIGEST_SIZE) == 0) {
      // The early-exit case:  the patch was already applied, this file
      // has the desired hash, nothing for us to do.
      fprintf(stderr, "\"%s\" is already target; no patch needed\n",
              source_filename);
      return 0;
    }

    const Patch* to_use =
        FindMatchingPatch(source_file.sha1, patches, num_patches);
    if (to_use != NULL) {
      source_patch_filename = to_use->patch_filename;
    }
  }

  if (source_patch_filename == NULL) {
    free(source_file.data);
    fprintf(stderr, "source file is bad; trying copy\n");

    if (LoadFileContents(CACHE_TEMP_SOURCE, &copy_file) < 0) {
      // fail.
      fprintf(stderr, "failed to read copy file\n");
      return 1;
    }

    const Patch* to_use =
        FindMatchingPatch(copy_file.sha1, patches, num_patches);
    if (to_use != NULL) {
      copy_patch_filename = to_use->patch_filename;
    }

    if (copy_patch_filename == NULL) {
      // fail.
      fprintf(stderr, "copy file doesn't match source SHA-1s either\n");
      return 1;
    }
  }

  // Is there enough room in the target filesystem to hold the patched file?
  size_t free_space = FreeSpaceForFile(source_fs);
  int enough_space = free_space > (target_size * 3 / 2);  // 50% margin of error
  printf("target %ld bytes; free space %ld bytes; enough %d\n",
         (long)target_size, (long)free_space, enough_space);

  if (!enough_space && source_patch_filename != NULL) {
    // Using the original source, but not enough free space.  First
    // copy the source file to cache, then delete it from the original
    // location.
    if (MakeFreeSpaceOnCache(source_file.size) < 0) {
      fprintf(stderr, "not enough free space on /cache\n");
      return 1;
    }

    if (SaveFileContents(CACHE_TEMP_SOURCE, source_file) < 0) {
      fprintf(stderr, "failed to back up source file\n");
      return 1;
    }
    made_copy = 1;
    unlink(source_filename);

    size_t free_space = FreeSpaceForFile(source_fs);
    printf("(now %ld bytes free for source)\n", (long)free_space);
  }

  FileContents* source_to_use;
  const char* patch_filename;
  if (source_patch_filename != NULL) {
    source_to_use = &source_file;
    patch_filename = source_patch_filename;
  } else {
    source_to_use = &copy_file;
    patch_filename = copy_patch_filename;
  }

  // We write the decoded output to "<file>.patch".
  char* outname = (char*)malloc(strlen(source_filename) + 10);
  strcpy(outname, source_filename);
  strcat(outname, ".patch");
  FILE* output = fopen(outname, "wb");
  if (output == NULL) {
    fprintf(stderr, "failed to patch file %s: %s\n",
            source_filename, strerror(errno));
    return 1;
  }

#define MAX_HEADER_LENGTH 8
  unsigned char header[MAX_HEADER_LENGTH];
  FILE* patchf = fopen(patch_filename, "rb");
  if (patchf == NULL) {
    fprintf(stderr, "failed to open patch file %s: %s\n",
            patch_filename, strerror(errno));
    return 1;
  }
  int header_bytes_read = fread(header, 1, MAX_HEADER_LENGTH, patchf);
  fclose(patchf);

  SHA_CTX ctx;
  SHA_init(&ctx);

  if (header_bytes_read >= 4 &&
      header[0] == 0xd6 && header[1] == 0xc3 &&
      header[2] == 0xc4 && header[3] == 0) {
    // xdelta3 patches begin "VCD" (with the high bits set) followed
    // by a zero byte (the version number).
    fprintf(stderr, "error:  xdelta3 patches no longer supported\n");
    return 1;
  } else if (header_bytes_read >= 8 &&
             memcmp(header, "BSDIFF40", 8) == 0) {
    int result = ApplyBSDiffPatch(source_to_use->data, source_to_use->size,
                                  patch_filename, output, &ctx);
    if (result != 0) {
      fprintf(stderr, "ApplyBSDiffPatch failed\n");
      return result;
    }
  } else {
    fprintf(stderr, "Unknown patch file format");
    return 1;
  }

  fflush(output);
  fsync(fileno(output));
  fclose(output);

  const uint8_t* current_target_sha1 = SHA_final(&ctx);
  if (memcmp(current_target_sha1, target_sha1, SHA_DIGEST_SIZE) != 0) {
    fprintf(stderr, "patch did not produce expected sha1\n");
    return 1;
  }

  // Give the .patch file the same owner, group, and mode of the
  // original source file.
  if (chmod(outname, source_to_use->st.st_mode) != 0) {
    fprintf(stderr, "chmod of \"%s\" failed: %s\n", outname, strerror(errno));
    return 1;
  }
  if (chown(outname, source_to_use->st.st_uid, source_to_use->st.st_gid) != 0) {
    fprintf(stderr, "chown of \"%s\" failed: %s\n", outname, strerror(errno));
    return 1;
  }

  // Finally, rename the .patch file to replace the original source file.
  if (rename(outname, source_filename) != 0) {
    fprintf(stderr, "rename of .patch to \"%s\" failed: %s\n",
            source_filename, strerror(errno));
    return 1;
  }

  // If this run of applypatch created the copy, and we're here, we
  // can delete it.
  if (made_copy) unlink(CACHE_TEMP_SOURCE);

  // Success!
  return 0;
}
