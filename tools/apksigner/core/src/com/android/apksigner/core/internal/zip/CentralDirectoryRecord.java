/*
 * Copyright (C) 2016 The Android Open Source Project
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

package com.android.apksigner.core.internal.zip;

import com.android.apksigner.core.zip.ZipFormatException;

import java.nio.BufferUnderflowException;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;

/**
 * ZIP Central Directory (CD) Record.
 */
public class CentralDirectoryRecord {

    /**
     * Comparator which compares records by the offset of the corresponding Local File Header in the
     * archive.
     */
    public static final Comparator<CentralDirectoryRecord> BY_LOCAL_FILE_HEADER_OFFSET_COMPARATOR =
            new ByLocalFileHeaderOffsetComparator();

    private static final int RECORD_SIGNATURE = 0x02014b50;
    private static final int HEADER_SIZE_BYTES = 46;

    private static final int GP_FLAGS_OFFSET = 8;
    private static final int COMPRESSION_METHOD_OFFSET = 10;
    private static final int CRC32_OFFSET = 16;
    private static final int COMPRESSED_SIZE_OFFSET = 20;
    private static final int UNCOMPRESSED_SIZE_OFFSET = 24;
    private static final int NAME_LENGTH_OFFSET = 28;
    private static final int EXTRA_LENGTH_OFFSET = 30;
    private static final int COMMENT_LENGTH_OFFSET = 32;
    private static final int LOCAL_FILE_HEADER_OFFSET = 42;
    private static final int NAME_OFFSET = HEADER_SIZE_BYTES;

    private final short mGpFlags;
    private final short mCompressionMethod;
    private final long mCrc32;
    private final long mCompressedSize;
    private final long mUncompressedSize;
    private final long mLocalFileHeaderOffset;
    private final String mName;

    private CentralDirectoryRecord(
            short gpFlags,
            short compressionMethod,
            long crc32,
            long compressedSize,
            long uncompressedSize,
            long localFileHeaderOffset,
            String name) {
        mGpFlags = gpFlags;
        mCompressionMethod = compressionMethod;
        mCrc32 = crc32;
        mCompressedSize = compressedSize;
        mUncompressedSize = uncompressedSize;
        mLocalFileHeaderOffset = localFileHeaderOffset;
        mName = name;
    }

    public String getName() {
        return mName;
    }

    public short getGpFlags() {
        return mGpFlags;
    }

    public short getCompressionMethod() {
        return mCompressionMethod;
    }

    public long getCrc32() {
        return mCrc32;
    }

    public long getCompressedSize() {
        return mCompressedSize;
    }

    public long getUncompressedSize() {
        return mUncompressedSize;
    }

    public long getLocalFileHeaderOffset() {
        return mLocalFileHeaderOffset;
    }

    /**
     * Returns the Central Directory Record starting at the current position of the provided buffer
     * and advances the buffer's position immediately past the end of the record.
     */
    public static CentralDirectoryRecord getRecord(ByteBuffer buf) throws ZipFormatException {
        ZipUtils.assertByteOrderLittleEndian(buf);
        if (buf.remaining() < HEADER_SIZE_BYTES) {
            throw new ZipFormatException(
                    "Input too short. Need at least: " + HEADER_SIZE_BYTES
                            + " bytes, available: " + buf.remaining() + " bytes",
                    new BufferUnderflowException());
        }
        int bufPosition = buf.position();
        int recordSignature = buf.getInt(bufPosition);
        if (recordSignature != RECORD_SIGNATURE) {
            throw new ZipFormatException(
                    "Not a Central Directory record. Signature: 0x"
                            + Long.toHexString(recordSignature & 0xffffffffL));
        }
        short gpFlags = buf.getShort(bufPosition + GP_FLAGS_OFFSET);
        short compressionMethod = buf.getShort(bufPosition + COMPRESSION_METHOD_OFFSET);
        long crc32 = ZipUtils.getUnsignedInt32(buf, bufPosition + CRC32_OFFSET);
        long compressedSize = ZipUtils.getUnsignedInt32(buf, bufPosition + COMPRESSED_SIZE_OFFSET);
        long uncompressedSize =
                ZipUtils.getUnsignedInt32(buf,  bufPosition + UNCOMPRESSED_SIZE_OFFSET);
        int nameSize = ZipUtils.getUnsignedInt16(buf, bufPosition + NAME_LENGTH_OFFSET);
        int extraSize = ZipUtils.getUnsignedInt16(buf, bufPosition + EXTRA_LENGTH_OFFSET);
        int commentSize = ZipUtils.getUnsignedInt16(buf, bufPosition + COMMENT_LENGTH_OFFSET);
        long localFileHeaderOffset =
                ZipUtils.getUnsignedInt32(buf, bufPosition + LOCAL_FILE_HEADER_OFFSET);
        int recordSize = HEADER_SIZE_BYTES + nameSize + extraSize + commentSize;
        if (recordSize > buf.remaining()) {
            throw new ZipFormatException(
                    "Input too short. Need: " + recordSize + " bytes, available: "
                            + buf.remaining() + " bytes",
                    new BufferUnderflowException());
        }
        String name = getName(buf, bufPosition + NAME_OFFSET, nameSize);
        buf.position(bufPosition + recordSize);
        return new CentralDirectoryRecord(
                gpFlags,
                compressionMethod,
                crc32,
                compressedSize,
                uncompressedSize,
                localFileHeaderOffset,
                name);
    }

    static String getName(ByteBuffer record, int position, int nameLengthBytes) {
        byte[] nameBytes;
        int nameBytesOffset;
        if (record.hasArray()) {
            nameBytes = record.array();
            nameBytesOffset = record.arrayOffset() + position;
        } else {
            nameBytes = new byte[nameLengthBytes];
            nameBytesOffset = 0;
            int originalPosition = record.position();
            try {
                record.position(position);
                record.get(nameBytes);
            } finally {
                record.position(originalPosition);
            }
        }
        return new String(nameBytes, nameBytesOffset, nameLengthBytes, StandardCharsets.UTF_8);
    }

    private static class ByLocalFileHeaderOffsetComparator
            implements Comparator<CentralDirectoryRecord> {
        @Override
        public int compare(CentralDirectoryRecord r1, CentralDirectoryRecord r2) {
            long offset1 = r1.getLocalFileHeaderOffset();
            long offset2 = r2.getLocalFileHeaderOffset();
            if (offset1 > offset2) {
                return 1;
            } else if (offset1 < offset2) {
                return -1;
            } else {
                return 0;
            }
        }
    }
}
