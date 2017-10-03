/*
 * Copyright (C) 2006 The Android Open Source Project
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

//
// Access to entries in a Zip archive.
//

#include "ZipEntry.h"

#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <inttypes.h>

using namespace android;

#define LOG(...) fprintf(stderr, __VA_ARGS__)

/* Jan 01 2008 */
#define STATIC_DATE (28 << 9 | 1 << 5 | 1)
#define STATIC_TIME 0

/*
 * Initialize a new ZipEntry structure from a FILE* positioned at a
 * CentralDirectoryEntry. Rewrites the headers to remove the dynamic
 * timestamps.
 *
 * On exit, the file pointer will be at the start of the next CDE or
 * at the EOCD.
 */
status_t ZipEntry::initAndRewriteFromCDE(FILE* fp)
{
    status_t result;
    long posn;

    /* read the CDE */
    result = mCDE.rewrite(fp);
    if (result != 0) {
        LOG("mCDE.rewrite failed\n");
        return result;
    }

    /* using the info in the CDE, go load up the LFH */
    posn = ftell(fp);
    if (fseek(fp, mCDE.mLocalHeaderRelOffset, SEEK_SET) != 0) {
        LOG("local header seek failed (%" PRIu32 ")\n",
            mCDE.mLocalHeaderRelOffset);
        return -1;
    }

    result = mLFH.rewrite(fp);
    if (result != 0) {
        LOG("mLFH.rewrite failed\n");
        return result;
    }

    if (fseek(fp, posn, SEEK_SET) != 0)
        return -1;

    return 0;
}

/*
 * ===========================================================================
 *      ZipEntry::LocalFileHeader
 * ===========================================================================
 */

/*
 * Rewrite a local file header.
 *
 * On entry, "fp" points to the signature at the start of the header.
 */
status_t ZipEntry::LocalFileHeader::rewrite(FILE* fp)
{
    uint8_t buf[kLFHLen];

    if (fread(buf, 1, kLFHLen, fp) != kLFHLen)
        return -1;

    if (ZipEntry::getLongLE(&buf[0x00]) != kSignature) {
        LOG("whoops: didn't find expected signature\n");
        return -1;
    }

    ZipEntry::putShortLE(&buf[0x0a], STATIC_TIME);
    ZipEntry::putShortLE(&buf[0x0c], STATIC_DATE);

    if (fseek(fp, -kLFHLen, SEEK_CUR) != 0)
        return -1;

    if (fwrite(buf, 1, kLFHLen, fp) != kLFHLen)
        return -1;

    return 0;
}

/*
 * ===========================================================================
 *      ZipEntry::CentralDirEntry
 * ===========================================================================
 */

/*
 * Read and rewrite the central dir entry that appears next in the file.
 *
 * On entry, "fp" should be positioned on the signature bytes for the
 * entry.  On exit, "fp" will point at the signature word for the next
 * entry or for the EOCD.
 */
status_t ZipEntry::CentralDirEntry::rewrite(FILE* fp)
{
    uint8_t buf[kCDELen];
    uint16_t fileNameLength, extraFieldLength, fileCommentLength;

    if (fread(buf, 1, kCDELen, fp) != kCDELen)
        return -1;

    if (ZipEntry::getLongLE(&buf[0x00]) != kSignature) {
        LOG("Whoops: didn't find expected signature\n");
        return -1;
    }

    ZipEntry::putShortLE(&buf[0x0c], STATIC_TIME);
    ZipEntry::putShortLE(&buf[0x0e], STATIC_DATE);

    fileNameLength = ZipEntry::getShortLE(&buf[0x1c]);
    extraFieldLength = ZipEntry::getShortLE(&buf[0x1e]);
    fileCommentLength = ZipEntry::getShortLE(&buf[0x20]);
    mLocalHeaderRelOffset = ZipEntry::getLongLE(&buf[0x2a]);

    if (fseek(fp, -kCDELen, SEEK_CUR) != 0)
        return -1;

    if (fwrite(buf, 1, kCDELen, fp) != kCDELen)
        return -1;

    if (fseek(fp, fileNameLength + extraFieldLength + fileCommentLength, SEEK_CUR) != 0)
        return -1;

    return 0;
}
