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
// Class to rewrite zip file headers to remove dynamic timestamps.
//
#ifndef __LIBS_ZIPFILE_H
#define __LIBS_ZIPFILE_H

#include <stdio.h>

#include "ZipEntry.h"

namespace android {

/*
 * Manipulate a Zip archive.
 */
class ZipFile {
public:
    ZipFile(void) : mZipFp(NULL) {}
    ~ZipFile(void) {
        if (mZipFp != NULL)
            fclose(mZipFp);
    }

    /*
     * Rewrite an archive's headers to remove dynamic timestamps.
     */
    status_t rewrite(const char* zipFileName);

private:
    /* these are private and not defined */
    ZipFile(const ZipFile& src);
    ZipFile& operator=(const ZipFile& src);

    class EndOfCentralDir {
    public:
        EndOfCentralDir(void) : mTotalNumEntries(0), mCentralDirOffset(0) {}

        status_t readBuf(const uint8_t* buf, int len);

        uint16_t mTotalNumEntries;
        uint32_t mCentralDirOffset;      // offset from first disk

        enum {
            kSignature      = 0x06054b50,
            kEOCDLen        = 22,       // EndOfCentralDir len, excl. comment

            kMaxCommentLen  = 65535,    // longest possible in ushort
            kMaxEOCDSearch  = kMaxCommentLen + EndOfCentralDir::kEOCDLen,

        };
    };

    /* read all entries in the central dir */
    status_t rewriteCentralDir(void);

    /*
     * We use stdio FILE*, which gives us buffering but makes dealing
     * with files >2GB awkward.  Until we support Zip64, we're fine.
     */
    FILE*           mZipFp;             // Zip file pointer

    /* one of these per file */
    EndOfCentralDir mEOCD;
};

}; // namespace android

#endif // __LIBS_ZIPFILE_H
