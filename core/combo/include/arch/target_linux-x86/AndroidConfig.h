/*
 * Copyright 2005 The Android Open Source Project
 *
 * Android config -- "target_linux-x86".  Used for x86 linux target devices.
 */
#ifndef _ANDROID_CONFIG_H
#define _ANDROID_CONFIG_H

/*
 * ===========================================================================
 *                              !!! IMPORTANT !!!
 * ===========================================================================
 *
 * This file is included by ALL C/C++ source files.  Don't put anything in
 * here unless you are absolutely certain it can't go anywhere else.
 *
 * Any C++ stuff must be wrapped with "#ifdef __cplusplus".  Do not use "//"
 * comments.
 */

/*
 * Define if we have <malloc.h> header
 */
#define HAVE_MALLOC_H 1

/*
 * Define if we're running on *our* linux on device or emulator.
 */
#define HAVE_ANDROID_OS 1

/*
 * The default path separator for the platform
 */
#define OS_PATH_SEPARATOR '/'

/*
 * Define if <stdint.h> exists.
 */
#define HAVE_STDINT_H 1

#endif /* _ANDROID_CONFIG_H */
