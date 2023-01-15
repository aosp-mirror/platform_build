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
        LOG("fopen \"%s\" failed: %s\n", zipFileName, strerror(errno));
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
    fseeko(mZipFp, 0, SEEK_END);
    off_t fileLength = ftello(mZipFp);
    rewind(mZipFp);

    /* too small to be a ZIP archive? */
    if (fileLength < EndOfCentralDir::kEOCDLen) {
        LOG("Length is %lld -- too small\n", (long long) fileLength);
        return -1;
    }

    off_t seekStart;
    size_t readAmount;
    if (fileLength > EndOfCentralDir::kMaxEOCDSearch) {
        seekStart = fileLength - EndOfCentralDir::kMaxEOCDSearch;
        readAmount = EndOfCentralDir::kMaxEOCDSearch;
    } else {
        seekStart = 0;
        readAmount = fileLength;
    }
    if (fseeko(mZipFp, seekStart, SEEK_SET) != 0) {
        LOG("Failure seeking to end of zip at %lld", (long long) seekStart);
        return -1;
    }

    /* read the last part of the file into the buffer */
    uint8_t buf[EndOfCentralDir::kMaxEOCDSearch];
    if (fread(buf, 1, readAmount, mZipFp) != readAmount) {
        LOG("short file? wanted %zu\n", readAmount);
        return -1;
    }

    /* find the end-of-central-dir magic */
    int i;
    for (i = readAmount - 4; i >= 0; i--) {
        if (buf[i] == 0x50 &&
            ZipEntry::getLongLE(&buf[i]) == EndOfCentralDir::kSignature)
        {
            break;
        }
    }
    if (i < 0) {
        LOG("EOCD not found, not Zip\n");
        return -1;
    }

    /* extract eocd values */
    status_t result = mEOCD.readBuf(buf + i, readAmount - i);
    if (result != 0) {
        LOG("Failure reading %zu bytes of EOCD values", readAmount - i);
        return result;
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
    if (fseeko(mZipFp, mEOCD.mCentralDirOffset, SEEK_SET) != 0) {
        LOG("Failure seeking to central dir offset %" PRIu32 "\n",
             mEOCD.mCentralDirOffset);
        return -1;
    }

    /*
     * Loop through and read the central dir entries.
     */
    for (int entry = 0; entry < mEOCD.mTotalNumEntries; entry++) {
        ZipEntry* pEntry = new ZipEntry;
        result = pEntry->initAndRewriteFromCDE(mZipFp);
        delete pEntry;
        if (result != 0) {
            LOG("initFromCDE failed\n");
            return -1;
        }
    }

    /*
     * If all went well, we should now be back at the EOCD.
     */
    uint8_t checkBuf[4];
    if (fread(checkBuf, 1, 4, mZipFp) != 4) {
        LOG("EOCD check read failed\n");
        return -1;
    }
    if (ZipEntry::getLongLE(checkBuf) != EndOfCentralDir::kSignature) {
        LOG("EOCD read check failed\n");
        return -1;
    }

    return 0;
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
