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
// Zip archive entries.
//
// The ZipEntry class is tightly meshed with the ZipFile class.
//
#ifndef __LIBS_ZIPENTRY_H
#define __LIBS_ZIPENTRY_H

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

typedef int status_t;

namespace android {

class ZipFile;

/*
 * ZipEntry objects represent a single entry in a Zip archive.
 *
 * File information is stored in two places: next to the file data (the Local
 * File Header, and possibly a Data Descriptor), and at the end of the file
 * (the Central Directory Entry).  The two must be kept in sync.
 */
class ZipEntry {
public:
    friend class ZipFile;

    ZipEntry(void) {}
    ~ZipEntry(void) {}

    /*
     * Some basic functions for raw data manipulation.  "LE" means
     * Little Endian.
     */
    static inline uint16_t getShortLE(const uint8_t* buf) {
        return buf[0] | (buf[1] << 8);
    }
    static inline uint32_t getLongLE(const uint8_t* buf) {
        return buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
    }
    static inline void putShortLE(uint8_t* buf, uint16_t val) {
        buf[0] = (uint8_t) val;
        buf[1] = (uint8_t) (val >> 8);
    }

protected:
    /*
     * Initialize the structure from the file, which is pointing at
     * our Central Directory entry. And rewrite it.
     */
    status_t initAndRewriteFromCDE(FILE* fp);

private:
    /* these are private and not defined */
    ZipEntry(const ZipEntry& src);
    ZipEntry& operator=(const ZipEntry& src);

    /*
     * Every entry in the Zip archive starts off with one of these.
     */
    class LocalFileHeader {
    public:
        LocalFileHeader(void) {}

        status_t rewrite(FILE* fp);

        enum {
            kSignature      = 0x04034b50,
            kLFHLen         = 30,       // LocalFileHdr len, excl. var fields
        };
    };

    /*
     * Every entry in the Zip archive has one of these in the "central
     * directory" at the end of the file.
     */
    class CentralDirEntry {
    public:
        CentralDirEntry(void) :
            mLocalHeaderRelOffset(0)
        {}

        status_t rewrite(FILE* fp);

        uint32_t mLocalHeaderRelOffset;

        enum {
            kSignature      = 0x02014b50,
            kCDELen         = 46,       // CentralDirEnt len, excl. var fields
        };
    };

    LocalFileHeader     mLFH;
    CentralDirEntry     mCDE;
};

}; // namespace android

#endif // __LIBS_ZIPENTRY_H
