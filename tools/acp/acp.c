/*
 * Copyright 2005 The Android Open Source Project
 *
 * Android "cp" replacement.
 *
 * The GNU/Linux "cp" uses O_LARGEFILE in its open() calls, utimes() instead
 * of utime(), and getxattr()/setxattr() instead of chmod().  These are
 * probably "better", but are non-portable, and not necessary for our
 * purposes.
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <getopt.h>
#include <dirent.h>
#include <fcntl.h>
#include <utime.h>
#include <limits.h>
#include <errno.h>
#include <assert.h>
#include <host/CopyFile.h>

/*#define DEBUG_MSGS*/
#ifdef DEBUG_MSGS
# define DBUG(x) printf x
#else
# define DBUG(x) ((void)0)
#endif

#define FSSEP '/'       /* filename separator char */


/*
 * Process the command-line file arguments.
 *
 * Returns 0 on success.
 */
int process(int argc, char* const argv[], unsigned int options)
{
    int retVal = 0;
    int i, cc;
    char* stripDest = NULL;
    int stripDestLen;
    struct stat destStat;
    bool destMustBeDir = false;
    struct stat sb;

    assert(argc >= 2);

    /*
     * Check for and trim a trailing slash on the last arg.
     *
     * It's useful to be able to say "cp foo bar/" when you want to copy
     * a single file into a directory.  If you say "cp foo bar", and "bar"
     * does not exist, it will create "bar", when what you really wanted
     * was for the cp command to fail with "directory does not exist".
     */
    stripDestLen = strlen(argv[argc-1]);
    stripDest = malloc(stripDestLen+1);
    memcpy(stripDest, argv[argc-1], stripDestLen+1);
    if (stripDest[stripDestLen-1] == FSSEP) {
        stripDest[--stripDestLen] = '\0';
        destMustBeDir = true;
    }

    if (argc > 2)
        destMustBeDir = true;

    /*
     * Start with a quick check to ensure that, if we're expecting to copy
     * to a directory, the target already exists and is actually a directory.
     * It's okay if it's a symlink to a directory.
     *
     * If it turns out to be a directory, go ahead and raise the
     * destMustBeDir flag so we do some path concatenation below.
     */
    if (stat(stripDest, &sb) < 0) {
        if (destMustBeDir) {
            if (errno == ENOENT)
                fprintf(stderr,
                    "acp: destination directory '%s' does not exist\n",
                    stripDest);
            else
                fprintf(stderr, "acp: unable to stat dest dir\n");
            retVal = 1;
            goto bail;
        }
    } else {
        if (S_ISDIR(sb.st_mode)) {
            DBUG(("--- dest exists and is a dir, setting flag\n"));
            destMustBeDir = true;
        } else if (destMustBeDir) {
            fprintf(stderr,
                "acp: destination '%s' is not a directory\n",
                stripDest);
            retVal = 1;
            goto bail;
        }
    }

    /*
     * Copying files.
     *
     * Strip trailing slashes off.  They shouldn't be there, but
     * sometimes file completion will put them in for directories.
     *
     * The observed behavior of GNU and BSD cp is that they print warnings
     * if something fails, but continue on.  If any part fails, the command
     * exits with an error status.
     */
    for (i = 0; i < argc-1; i++) {
        const char* srcName;
        char* src;
        char* dst;
        int copyResult;
        int srcLen;

        /* make a copy of the source name, and strip trailing '/' */
        srcLen = strlen(argv[i]);
        src = malloc(srcLen+1);
        memcpy(src, argv[i], srcLen+1);

        if (src[srcLen-1] == FSSEP)
            src[--srcLen] = '\0';

        /* find just the name part */
        srcName = strrchr(src, FSSEP);
        if (srcName == NULL) {
            srcName = src;
        } else {
            srcName++;
            assert(*srcName != '\0');
        }
        
        if (destMustBeDir) {
            /* concatenate dest dir and src name */
            int srcNameLen = strlen(srcName);

            dst = malloc(stripDestLen +1 + srcNameLen +1);
            memcpy(dst, stripDest, stripDestLen);
            dst[stripDestLen] = FSSEP;
            memcpy(dst + stripDestLen+1, srcName, srcNameLen+1);
        } else {
            /* simple */
            dst = stripDest;
        }

        /*
         * Copy the source to the destination.
         */
        copyResult = copyFile(src, dst, options);

        if (copyResult != 0)
            retVal = 1;

        free(src);
        if (dst != stripDest)
            free(dst);
    }

bail:
    free(stripDest);
    return retVal;
}

/*
 * Set up the options.
 */
int main(int argc, char* const argv[])
{
    bool wantUsage;
    int ic, retVal;
    int verboseLevel;
    unsigned int options;

    verboseLevel = 0;
    options = 0;
    wantUsage = false;

    while (1) {
        ic = getopt(argc, argv, "defprtuv");
        if (ic < 0)
            break;

        switch (ic) {
            case 'd':
                options |= COPY_NO_DEREFERENCE;
                break;
            case 'e':
                options |= COPY_TRY_EXE;
                break;
            case 'f':
                options |= COPY_FORCE;
                break;
            case 'p':
                options |= COPY_PERMISSIONS;
                break;
            case 't':
                options |= COPY_TIMESTAMPS;
                break;
            case 'r':
                options |= COPY_RECURSIVE;
                break;
            case 'u':
                options |= COPY_UPDATE_ONLY;
                break;
            case 'v':
                verboseLevel++;
                break;
            default:
                fprintf(stderr, "Unexpected arg -%c\n", ic);
                wantUsage = true;
                break;
        }

        if (wantUsage)
            break;
    }

    options |= verboseLevel & COPY_VERBOSE_MASK;

    if (optind == argc-1) {
        fprintf(stderr, "acp: missing destination file\n");
        return 2;
    } else if (optind+2 > argc)
        wantUsage = true;

    if (wantUsage) {
        fprintf(stderr, "Usage: acp [OPTION]... SOURCE DEST\n");
        fprintf(stderr, "  or:  acp [OPTION]... SOURCE... DIRECTORY\n");
        fprintf(stderr, "\nOptions:\n");
        fprintf(stderr, "  -d  never follow (dereference) symbolic links\n");
        fprintf(stderr, "  -e  if source file doesn't exist, try adding "
                        "'.exe' [Win32 only]\n");
        fprintf(stderr, "  -f  use force, removing existing file if it's "
                        "not writeable\n");
        fprintf(stderr, "  -p  preserve mode, ownership\n");
        fprintf(stderr, "  -r  recursive copy\n");
        fprintf(stderr, "  -t  preserve timestamps\n");
        fprintf(stderr, "  -u  update only: don't copy if dest is newer\n");
        fprintf(stderr, "  -v  verbose output (-vv is more verbose)\n");
        return 2;
    }

    retVal = process(argc-optind, argv+optind, options);
    DBUG(("EXIT: %d\n", retVal));
    return retVal;
}

