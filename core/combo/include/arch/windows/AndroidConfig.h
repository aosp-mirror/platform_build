/*
 * Copyright (C) 2005 The Android Open Source Project
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
 * Android config -- "CYGWIN_NT-5.1".
 *
 * Cygwin has pthreads, but GDB seems to get confused if you use it to
 * create threads.  By "confused", I mean it freezes up the first time the
 * debugged process creates a thread, even if you use CreateThread.  The
 * mere presence of pthreads linkage seems to cause problems.
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

/* MingW doesn't define __BEGIN_DECLS / __END_DECLS. */

#ifndef __BEGIN_DECLS
#  ifdef __cplusplus
#    define __BEGIN_DECLS extern "C" {
#  else
#    define __BEGIN_DECLS
#  endif
#endif

#ifndef __END_DECLS
#  ifdef __cplusplus
#    define __END_DECLS }
#  else
#    define __END_DECLS
#  endif
#endif

/* TODO: replace references to this. */
#define HAVE_WIN32_IPC

#ifdef __CYGWIN__
#error "CYGWIN is unsupported for platform builds"
#endif

/*
 * Define this if you build against MSVCRT.DLL
 */
#define HAVE_MS_C_RUNTIME

/*
 * Define this if we want to use WinSock.
 */
#define HAVE_WINSOCK

/*
 * We need to choose between 32-bit and 64-bit off_t.  All of our code should
 * agree on the same size.  For desktop systems, use 64-bit values,
 * because some of our libraries (e.g. wxWidgets) expect to be built that way.
 */
#define _FILE_OFFSET_BITS 64
#define _LARGEFILE_SOURCE 1

/*
 * Add any extra platform-specific defines here.
 */
#define WIN32 1                 /* stock Cygwin doesn't define these */
#define _WIN32 1
#define _WIN32_WINNT 0x0500     /* admit to using >= Win2K */

#define HAVE_WINDOWS_PATHS      /* needed by simulator */

/*
 * The default path separator for the platform
 */
#define OS_PATH_SEPARATOR '\\'

/*
 * Various definitions missing in MinGW
 */
#ifdef USE_MINGW
#define S_IRGRP 0
#endif

#endif /*_ANDROID_CONFIG_H*/
