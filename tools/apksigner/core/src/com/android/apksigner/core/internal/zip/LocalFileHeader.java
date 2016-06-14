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

import java.io.Closeable;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.zip.DataFormatException;
import java.util.zip.Inflater;

import com.android.apksigner.core.internal.util.ByteBufferSink;
import com.android.apksigner.core.util.DataSink;
import com.android.apksigner.core.util.DataSource;
import com.android.apksigner.core.zip.ZipFormatException;

/**
 * ZIP Local File Header.
 */
public class LocalFileHeader {
    private static final int RECORD_SIGNATURE = 0x04034b50;
    private static final int HEADER_SIZE_BYTES = 30;

    private static final int GP_FLAGS_OFFSET = 6;
    private static final int COMPRESSION_METHOD_OFFSET = 8;
    private static final int CRC32_OFFSET = 14;
    private static final int COMPRESSED_SIZE_OFFSET = 18;
    private static final int UNCOMPRESSED_SIZE_OFFSET = 22;
    private static final int NAME_LENGTH_OFFSET = 26;
    private static final int EXTRA_LENGTH_OFFSET = 28;
    private static final int NAME_OFFSET = HEADER_SIZE_BYTES;

    private static final short GP_FLAG_DATA_DESCRIPTOR_USED = 0x08;

    private LocalFileHeader() {}

    /**
     * Returns the uncompressed data pointed to by the provided ZIP Central Directory (CD) record.
     */
    public static byte[] getUncompressedData(
            DataSource source,
            long sourceOffsetInArchive,
            CentralDirectoryRecord cdRecord,
            long cdStartOffsetInArchive) throws ZipFormatException, IOException {
        if (cdRecord.getUncompressedSize() > Integer.MAX_VALUE) {
            throw new IOException(
                    cdRecord.getName() + " too large: " + cdRecord.getUncompressedSize());
        }
        byte[] result = new byte[(int) cdRecord.getUncompressedSize()];
        ByteBuffer resultBuf = ByteBuffer.wrap(result);
        ByteBufferSink resultSink = new ByteBufferSink(resultBuf);
        sendUncompressedData(
                source,
                sourceOffsetInArchive,
                cdRecord,
                cdStartOffsetInArchive,
                resultSink);
        if (resultBuf.hasRemaining()) {
            throw new ZipFormatException(
                    "Data of " + cdRecord.getName() + " shorter than specified in Central Directory"
                            + ". Expected: " + result.length + " bytes,  read: "
                            + resultBuf.position() + " bytes");
        }
        return result;
    }

    /**
     * Sends the uncompressed data pointed to by the provided ZIP Central Directory (CD) record into
     * the provided data sink.
     */
    public static void sendUncompressedData(
            DataSource source,
            long sourceOffsetInArchive,
            CentralDirectoryRecord cdRecord,
            long cdStartOffsetInArchive,
            DataSink sink) throws ZipFormatException, IOException {

        // IMPLEMENTATION NOTE: This method attempts to mimic the behavior of Android platform
        // exhibited when reading an APK for the purposes of verifying its signatures.

        String entryName = cdRecord.getName();
        byte[] cdNameBytes = entryName.getBytes(StandardCharsets.UTF_8);
        int headerSizeWithName = HEADER_SIZE_BYTES + cdNameBytes.length;
        long localFileHeaderOffsetInArchive = cdRecord.getLocalFileHeaderOffset();
        long headerEndInArchive = localFileHeaderOffsetInArchive + headerSizeWithName;
        if (headerEndInArchive >= cdStartOffsetInArchive) {
            throw new ZipFormatException(
                    "Local File Header of " + entryName + " extends beyond start of Central"
                            + " Directory. LFH end: " + headerEndInArchive
                            + ", CD start: " + cdStartOffsetInArchive);
        }
        ByteBuffer header;
        try {
            header =
                    source.getByteBuffer(
                            localFileHeaderOffsetInArchive - sourceOffsetInArchive,
                            headerSizeWithName);
        } catch (IOException e) {
            throw new IOException("Failed to read Local File Header of " + entryName, e);
        }
        header.order(ByteOrder.LITTLE_ENDIAN);

        int recordSignature = header.getInt(0);
        if (recordSignature != RECORD_SIGNATURE) {
            throw new ZipFormatException(
                    "Not a Local File Header record for entry " + entryName + ". Signature: 0x"
                            + Long.toHexString(recordSignature & 0xffffffffL));
        }
        short gpFlags = header.getShort(GP_FLAGS_OFFSET);
        if ((gpFlags & GP_FLAG_DATA_DESCRIPTOR_USED) == 0) {
            long crc32 = ZipUtils.getUnsignedInt32(header, CRC32_OFFSET);
            if (crc32 != cdRecord.getCrc32()) {
                throw new ZipFormatException(
                        "CRC-32 mismatch between Local File Header and Central Directory for entry "
                                + entryName + ". LFH: " + crc32 + ", CD: " + cdRecord.getCrc32());
            }
            long compressedSize = ZipUtils.getUnsignedInt32(header, COMPRESSED_SIZE_OFFSET);
            if (compressedSize != cdRecord.getCompressedSize()) {
                throw new ZipFormatException(
                        "Compressed size mismatch between Local File Header and Central Directory"
                                + " for entry " + entryName + ". LFH: " + compressedSize
                                + ", CD: " + cdRecord.getCompressedSize());
            }
            long uncompressedSize = ZipUtils.getUnsignedInt32(header, UNCOMPRESSED_SIZE_OFFSET);
            if (uncompressedSize != cdRecord.getUncompressedSize()) {
                throw new ZipFormatException(
                        "Uncompressed size mismatch between Local File Header and Central Directory"
                                + " for entry " + entryName + ". LFH: " + uncompressedSize
                                + ", CD: " + cdRecord.getUncompressedSize());
            }
        }
        int nameLength = ZipUtils.getUnsignedInt16(header, NAME_LENGTH_OFFSET);
        if (nameLength > cdNameBytes.length) {
            throw new ZipFormatException(
                    "Name mismatch between Local File Header and Central Directory for entry"
                            + entryName + ". LFH: " + nameLength
                            + " bytes, CD: " + cdNameBytes.length + " bytes");
        }
        String name = CentralDirectoryRecord.getName(header, NAME_OFFSET, nameLength);
        if (!entryName.equals(name)) {
            throw new ZipFormatException(
                    "Name mismatch between Local File Header and Central Directory. LFH: \""
                            + name + "\", CD: \"" + entryName + "\"");
        }
        int extraLength = ZipUtils.getUnsignedInt16(header, EXTRA_LENGTH_OFFSET);

        short compressionMethod = header.getShort(COMPRESSION_METHOD_OFFSET);
        boolean compressed;
        switch (compressionMethod) {
            case ZipUtils.COMPRESSION_METHOD_STORED:
                compressed = false;
                break;
            case ZipUtils.COMPRESSION_METHOD_DEFLATED:
                compressed = true;
                break;
            default:
                throw new ZipFormatException(
                        "Unsupported compression method of entry " + entryName
                                + ": " + (compressionMethod & 0xffff));
        }

        long dataStartOffsetInArchive =
                localFileHeaderOffsetInArchive + HEADER_SIZE_BYTES + nameLength + extraLength;
        long dataSize;
        if (compressed) {
            dataSize = cdRecord.getCompressedSize();
        } else {
            dataSize = cdRecord.getUncompressedSize();
        }
        long dataEndOffsetInArchive = dataStartOffsetInArchive + dataSize;
        if (dataEndOffsetInArchive > cdStartOffsetInArchive) {
            throw new ZipFormatException(
                    "Local File Header data of " + entryName + " extends beyond Central Directory"
                            + ". LFH data start: " + dataStartOffsetInArchive
                            + ", LFH data end: " + dataEndOffsetInArchive
                            + ", CD start: " + cdStartOffsetInArchive);
        }

        long dataOffsetInSource = dataStartOffsetInArchive - sourceOffsetInArchive;
        try {
            if (compressed) {
                try (InflateSinkAdapter inflateAdapter = new InflateSinkAdapter(sink)) {
                    source.feed(dataOffsetInSource, dataSize, inflateAdapter);
                }
            } else {
                source.feed(dataOffsetInSource, dataSize, sink);
            }
        } catch (IOException e) {
            throw new IOException(
                    "Failed to read data of " + ((compressed) ? "compressed" : "uncompressed")
                        + " entry " + entryName,
                    e);
        }
        // Interestingly, Android doesn't check that uncompressed data's CRC-32 is as expected. We
        // thus don't check either.
    }

    private static class InflateSinkAdapter implements DataSink, Closeable {
        private final DataSink mDelegate;

        private Inflater mInflater = new Inflater(true);
        private byte[] mOutputBuffer;
        private byte[] mInputBuffer;
        private boolean mClosed;

        private InflateSinkAdapter(DataSink delegate) {
            mDelegate = delegate;
        }

        @Override
        public void consume(byte[] buf, int offset, int length) throws IOException {
            checkNotClosed();
            mInflater.setInput(buf, offset, length);
            if (mOutputBuffer == null) {
                mOutputBuffer = new byte[65536];
            }
            while (!mInflater.finished()) {
                int outputChunkSize;
                try {
                    outputChunkSize = mInflater.inflate(mOutputBuffer);
                } catch (DataFormatException e) {
                    throw new IOException("Failed to inflate data", e);
                }
                if (outputChunkSize == 0) {
                    return;
                }
                // mDelegate.consume(mOutputBuffer, 0, outputChunkSize);
                mDelegate.consume(ByteBuffer.wrap(mOutputBuffer, 0, outputChunkSize));
            }
        }

        @Override
        public void consume(ByteBuffer buf) throws IOException {
            checkNotClosed();
            if (buf.hasArray()) {
                consume(buf.array(), buf.arrayOffset() + buf.position(), buf.remaining());
                buf.position(buf.limit());
            } else {
                if (mInputBuffer == null) {
                    mInputBuffer = new byte[65536];
                }
                while (buf.hasRemaining()) {
                    int chunkSize = Math.min(buf.remaining(), mInputBuffer.length);
                    buf.get(mInputBuffer, 0, chunkSize);
                    consume(mInputBuffer, 0, chunkSize);
                }
            }
        }

        @Override
        public void close() throws IOException {
            mClosed = true;
            mInputBuffer = null;
            mOutputBuffer = null;
            if (mInflater != null) {
                mInflater.end();
                mInflater = null;
            }
        }

        private void checkNotClosed() {
            if (mClosed) {
                throw new IllegalStateException("Closed");
            }
        }
    }
}
