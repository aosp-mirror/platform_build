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
// Access to Zip archives.
//

#include "ZipFile.h"

#include <memory.h>
#include <sys/stat.h>
#include <errno.h>
#include <assert.h>
#include <inttypes.h>

using namespace android;

#define LOG(...) fprintf(stderr, __VA_ARGS__)

/*
 * Open a file and rewrite the headers
 */
status_t ZipFile::rewrite(const char* zipFileName)
{
    assert(mZipFp == NULL);     // no reopen

    /* open the file */
    mZipFp = fopen(zipFileName, "r+b");
    if (mZipFp == NULL) {
        int err = errno;
        LOG("fopen failed: %d\n", err);
        return -1;
    }

    /*
     * Load the central directory.  If that fails, then this probably
     * isn't a Zip archive.
     */
    return rewriteCentralDir();
}

/*
 * Find the central directory, read and rewrite the contents.
 *
 * The fun thing about ZIP archives is that they may or may not be
 * readable from start to end.  In some cases, notably for archives
 * that were written to stdout, the only length information is in the
 * central directory at the end of the file.
 *
 * Of course, the central directory can be followed by a variable-length
 * comment field, so we have to scan through it backwards.  The comment
 * is at most 64K, plus we have 18 bytes for the end-of-central-dir stuff
 * itself, plus apparently sometimes people throw random junk on the end
 * just for the fun of it.
 *
 * This is all a little wobbly.  If the wrong value ends up in the EOCD
 * area, we're hosed.  This appears to be the way that everbody handles
 * it though, so we're in pretty good company if this fails.
 */
status_t ZipFile::rewriteCentralDir(void)
{
    status_t result = 0;
    uint8_t* buf = NULL;
    off_t fileLength, seekStart;
    long readAmount;
    int i;

    fseek(mZipFp, 0, SEEK_END);
    fileLength = ftell(mZipFp);
    rewind(mZipFp);

    /* too small to be a ZIP archive? */
    if (fileLength < EndOfCentralDir::kEOCDLen) {
        LOG("Length is %ld -- too small\n", (long)fileLength);
        result = -1;
        goto bail;
    }

    buf = new uint8_t[EndOfCentralDir::kMaxEOCDSearch];
    if (buf == NULL) {
        LOG("Failure allocating %d bytes for EOCD search",
             EndOfCentralDir::kMaxEOCDSearch);
        result = -1;
        goto bail;
    }

    if (fileLength > EndOfCentralDir::kMaxEOCDSearch) {
        seekStart = fileLength - EndOfCentralDir::kMaxEOCDSearch;
        readAmount = EndOfCentralDir::kMaxEOCDSearch;
    } else {
        seekStart = 0;
        readAmount = (long) fileLength;
    }
    if (fseek(mZipFp, seekStart, SEEK_SET) != 0) {
        LOG("Failure seeking to end of zip at %ld", (long) seekStart);
        result = -1;
        goto bail;
    }

    /* read the last part of the file into the buffer */
    if (fread(buf, 1, readAmount, mZipFp) != (size_t) readAmount) {
        LOG("short file? wanted %ld\n", readAmount);
        result = -1;
        goto bail;
    }

    /* find the end-of-central-dir magic */
    for (i = readAmount - 4; i >= 0; i--) {
        if (buf[i] == 0x50 &&
            ZipEntry::getLongLE(&buf[i]) == EndOfCentralDir::kSignature)
        {
            break;
        }
    }
    if (i < 0) {
        LOG("EOCD not found, not Zip\n");
        result = -1;
        goto bail;
    }

    /* extract eocd values */
    result = mEOCD.readBuf(buf + i, readAmount - i);
    if (result != 0) {
        LOG("Failure reading %ld bytes of EOCD values", readAmount - i);
        goto bail;
    }

    /*
     * So far so good.  "mCentralDirSize" is the size in bytes of the
     * central directory, so we can just seek back that far to find it.
     * We can also seek forward mCentralDirOffset bytes from the
     * start of the file.
     *
     * We're not guaranteed to have the rest of the central dir in the
     * buffer, nor are we guaranteed that the central dir will have any
     * sort of convenient size.  We need to skip to the start of it and
     * read the header, then the other goodies.
     *
     * The only thing we really need right now is the file comment, which
     * we're hoping to preserve.
     */
    if (fseek(mZipFp, mEOCD.mCentralDirOffset, SEEK_SET) != 0) {
        LOG("Failure seeking to central dir offset %" PRIu32 "\n",
             mEOCD.mCentralDirOffset);
        result = -1;
        goto bail;
    }

    /*
     * Loop through and read the central dir entries.
     */
    int entry;
    for (entry = 0; entry < mEOCD.mTotalNumEntries; entry++) {
        ZipEntry* pEntry = new ZipEntry;

        result = pEntry->initAndRewriteFromCDE(mZipFp);
        if (result != 0) {
            LOG("initFromCDE failed\n");
            delete pEntry;
            goto bail;
        }

        delete pEntry;
    }


    /*
     * If all went well, we should now be back at the EOCD.
     */
    uint8_t checkBuf[4];
    if (fread(checkBuf, 1, 4, mZipFp) != 4) {
        LOG("EOCD check read failed\n");
        result = -1;
        goto bail;
    }
    if (ZipEntry::getLongLE(checkBuf) != EndOfCentralDir::kSignature) {
        LOG("EOCD read check failed\n");
        result = -1;
        goto bail;
    }

bail:
    delete[] buf;
    return result;
}

/*
 * ===========================================================================
 *      ZipFile::EndOfCentralDir
 * ===========================================================================
 */

/*
 * Read the end-of-central-dir fields.
 *
 * "buf" should be positioned at the EOCD signature, and should contain
 * the entire EOCD area including the comment.
 */
status_t ZipFile::EndOfCentralDir::readBuf(const uint8_t* buf, int len)
{
    uint16_t diskNumber, diskWithCentralDir, numEntries;

    if (len < kEOCDLen) {
        /* looks like ZIP file got truncated */
        LOG(" Zip EOCD: expected >= %d bytes, found %d\n",
            kEOCDLen, len);
        return -1;
    }

    /* this should probably be an assert() */
    if (ZipEntry::getLongLE(&buf[0x00]) != kSignature)
        return -1;

    diskNumber = ZipEntry::getShortLE(&buf[0x04]);
    diskWithCentralDir = ZipEntry::getShortLE(&buf[0x06]);
    numEntries = ZipEntry::getShortLE(&buf[0x08]);
    mTotalNumEntries = ZipEntry::getShortLE(&buf[0x0a]);
    mCentralDirOffset = ZipEntry::getLongLE(&buf[0x10]);

    if (diskNumber != 0 || diskWithCentralDir != 0 ||
        numEntries != mTotalNumEntries)
    {
        LOG("Archive spanning not supported\n");
        return -1;
    }

    return 0;
}
