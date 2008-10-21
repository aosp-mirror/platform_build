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
#include <unistd.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>

#include <stdarg.h>
#include <fcntl.h>
#include <termios.h>

#include <zlib.h>   // for adler32()

static int verbose = 0;

/*
 * Android File Archive format:
 *
 * magic[5]: 'A' 'F' 'A' 'R' '\n'
 * version[4]: 0x00 0x00 0x00 0x01
 * for each file:
 *     file magic[4]: 'F' 'I' 'L' 'E'
 *     namelen[4]: Length of file name, including NUL byte (big-endian)
 *     name[*]: NUL-terminated file name
 *     datalen[4]: Length of file (big-endian)
 *     data[*]: Unencoded file data
 *     adler32[4]: adler32 of the unencoded file data (big-endian)
 *     file end magic[4]: 'f' 'i' 'l' 'e'
 * end magic[4]: 'E' 'N' 'D' 0x00
 *
 * This format is about as simple as possible;  it was designed to
 * make it easier to transfer multiple files over an stdin/stdout
 * pipe to another process, so word-alignment wasn't necessary.
 */

static void
die(const char *why, ...)
{
    va_list ap;
    
    va_start(ap, why);
    fprintf(stderr, "error: ");
    vfprintf(stderr, why, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}

static void
write_big_endian(size_t v)
{
    putchar((v >> 24) & 0xff);
    putchar((v >> 16) & 0xff);
    putchar((v >>  8) & 0xff);
    putchar( v        & 0xff);
}

static void
_eject(struct stat *s, char *out, int olen, char *data, size_t datasize)
{
    unsigned long adler;

    /* File magic.
     */
    printf("FILE");

    /* Name length includes the NUL byte.
     */
    write_big_endian(olen + 1);

    /* File name and terminating NUL.
     */
    printf("%s", out);
    putchar('\0');

    /* File length.
     */
    write_big_endian(datasize);

    /* File data.
     */
    if (fwrite(data, 1, datasize, stdout) != datasize) {
        die("Error writing file data");
    }

    /* Checksum.
     */
    adler = adler32(0, NULL, 0);
    adler = adler32(adler, (unsigned char *)data, datasize);
    write_big_endian(adler);

    /* File end magic.
     */
    printf("file");
}

static void _archive(char *in, int ilen);

static void
_archive_dir(char *in, int ilen)
{
    int t;
    DIR *d;
    struct dirent *de;

    if (verbose) {
        fprintf(stderr, "_archive_dir('%s', %d)\n", in, ilen);
    }
    
    d = opendir(in);
    if (d == 0) {
        die("cannot open directory '%s'", in);
    }
    
    while ((de = readdir(d)) != 0) {
            /* xxx: feature? maybe some dotfiles are okay */
        if (strcmp(de->d_name, ".") == 0 ||
            strcmp(de->d_name, "..") == 0)
        {
            continue;
        }

        t = strlen(de->d_name);
        in[ilen] = '/';
        memcpy(in + ilen + 1, de->d_name, t + 1);

        _archive(in, ilen + t + 1);

        in[ilen] = '\0';
    }
}

static void
_archive(char *in, int ilen)
{
    struct stat s;

    if (verbose) {
        fprintf(stderr, "_archive('%s', %d)\n", in, ilen);
    }
    
    if (lstat(in, &s)) {
        die("could not stat '%s'\n", in);
    }

    if (S_ISREG(s.st_mode)) {
        char *tmp;
        int fd;

        fd = open(in, O_RDONLY);
        if (fd < 0) {
            die("cannot open '%s' for read", in);
        }

        tmp = (char*) malloc(s.st_size);
        if (tmp == 0) {
            die("cannot allocate %d bytes", s.st_size);
        }

        if (read(fd, tmp, s.st_size) != s.st_size) {
            die("cannot read %d bytes", s.st_size);
        }

        _eject(&s, in, ilen, tmp, s.st_size);
        
        free(tmp);
        close(fd);
    } else if (S_ISDIR(s.st_mode)) {
        _archive_dir(in, ilen);
    } else {
        /* We don't handle links, etc. */
        die("Unknown '%s' (mode %d)?\n", in, s.st_mode);
    }
}

void archive(const char *start)
{
    char in[8192];

    strcpy(in, start);

    _archive_dir(in, strlen(in));
}

int
main(int argc, char *argv[])
{
    struct termios old_termios;

    if (argc == 1) {
        die("usage: %s <dir-list>", argv[0]);
    }
    argc--;
    argv++;

    /* Force stdout into raw mode.
     */
    struct termios s;
    if (tcgetattr(1, &s) < 0) {
        die("Could not get termios for stdout");
    }
    old_termios = s;
    cfmakeraw(&s);
    if (tcsetattr(1, TCSANOW, &s) < 0) {
        die("Could not set termios for stdout");
    }

    /* Print format magic and version.
     */
    printf("AFAR\n");
    write_big_endian(1);

    while (argc-- > 0) {
        archive(*argv++);
    }

    /* Print end magic.
     */
    printf("END");
    putchar('\0');

    /* Restore stdout.
     */
    if (tcsetattr(1, TCSANOW, &old_termios) < 0) {
        die("Could not restore termios for stdout");
    }

    return 0;
}
