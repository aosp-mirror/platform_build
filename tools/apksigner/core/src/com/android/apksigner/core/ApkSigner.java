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

package com.android.apksigner.core;

import java.io.Closeable;
import java.io.File;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.security.SignatureException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.android.apksigner.core.apk.ApkUtils;
import com.android.apksigner.core.internal.apk.v2.V2SchemeVerifier;
import com.android.apksigner.core.internal.util.ByteBufferDataSource;
import com.android.apksigner.core.internal.util.Pair;
import com.android.apksigner.core.internal.zip.CentralDirectoryRecord;
import com.android.apksigner.core.internal.zip.EocdRecord;
import com.android.apksigner.core.internal.zip.LocalFileRecord;
import com.android.apksigner.core.internal.zip.ZipUtils;
import com.android.apksigner.core.util.DataSink;
import com.android.apksigner.core.util.DataSinks;
import com.android.apksigner.core.util.DataSource;
import com.android.apksigner.core.util.DataSources;
import com.android.apksigner.core.zip.ZipFormatException;

/**
 * APK signer.
 *
 * <p>The signer preserves as much of the input APK as possible. For example, it preserves the
 * order of APK entries and preserves their contents, including compressed form and alignment of
 * data.
 *
 * <p>Use {@link Builder} to obtain instances of this signer.
 */
public class ApkSigner {

    /**
     * Extensible data block/field header ID used for storing information about alignment of
     * uncompressed entries as well as for aligning the entries's data. See ZIP appnote.txt section
     * 4.5 Extensible data fields.
     */
    private static final short ALIGNMENT_ZIP_EXTRA_DATA_FIELD_HEADER_ID = (short) 0xd935;

    /**
     * Minimum size (in bytes) of the extensible data block/field used for alignment of uncompressed
     * entries.
     */
    private static final short ALIGNMENT_ZIP_EXTRA_DATA_FIELD_MIN_SIZE_BYTES = 6;

    private final ApkSignerEngine mSignerEngine;

    private final File mInputApkFile;
    private final DataSource mInputApkDataSource;

    private final File mOutputApkFile;
    private final DataSink mOutputApkDataSink;
    private final DataSource mOutputApkDataSource;

    private ApkSigner(
            ApkSignerEngine signerEngine,
            File inputApkFile,
            DataSource inputApkDataSource,
            File outputApkFile,
            DataSink outputApkDataSink,
            DataSource outputApkDataSource) {
        mSignerEngine = signerEngine;

        mInputApkFile = inputApkFile;
        mInputApkDataSource = inputApkDataSource;

        mOutputApkFile = outputApkFile;
        mOutputApkDataSink = outputApkDataSink;
        mOutputApkDataSource = outputApkDataSource;
    }

    /**
     * Signs the input APK and outputs the resulting signed APK. The input APK is not modified.
     *
     * @throws IOException if an I/O error is encountered while reading or writing the APKs
     * @throws ZipFormatException if the input APK is malformed at ZIP format level
     * @throws NoSuchAlgorithmException if the APK signatures cannot be produced or verified because
     *         a required cryptographic algorithm implementation is missing
     * @throws InvalidKeyException if a signature could not be generated because a signing key is
     *         not suitable for generating the signature
     * @throws SignatureException if an error occurred while generating or verifying a signature
     * @throws IllegalStateException if this signer's configuration is missing required information
     *         or if the signing engine is in an invalid state.
     */
    public void sign()
            throws IOException, ZipFormatException, NoSuchAlgorithmException, InvalidKeyException,
                    SignatureException, IllegalStateException {
        Closeable in = null;
        DataSource inputApk;
        try {
            if (mInputApkDataSource != null) {
                inputApk = mInputApkDataSource;
            } else if (mInputApkFile != null) {
                RandomAccessFile inputFile = new RandomAccessFile(mInputApkFile, "r");
                in = inputFile;
                inputApk = DataSources.asDataSource(inputFile);
            } else {
                throw new IllegalStateException("Input APK not specified");
            }

            Closeable out = null;
            try {
                DataSink outputApkOut;
                DataSource outputApkIn;
                if (mOutputApkDataSink != null) {
                    outputApkOut = mOutputApkDataSink;
                    outputApkIn = mOutputApkDataSource;
                } else if (mOutputApkFile != null) {
                    RandomAccessFile outputFile = new RandomAccessFile(mOutputApkFile, "rw");
                    out = outputFile;
                    outputFile.setLength(0);
                    outputApkOut = DataSinks.asDataSink(outputFile);
                    outputApkIn = DataSources.asDataSource(outputFile);
                } else {
                    throw new IllegalStateException("Output APK not specified");
                }

                sign(mSignerEngine, inputApk, outputApkOut, outputApkIn);
            } finally {
                if (out != null) {
                    out.close();
                }
            }
        } finally {
            if (in != null) {
                in.close();
            }
        }
    }

    private static void sign(
            ApkSignerEngine signerEngine,
            DataSource inputApk,
            DataSink outputApkOut,
            DataSource outputApkIn)
                    throws IOException, ZipFormatException, NoSuchAlgorithmException,
                            InvalidKeyException, SignatureException {
        // Step 1. Find input APK's main ZIP sections
        ApkUtils.ZipSections inputZipSections = ApkUtils.findZipSections(inputApk);
        long apkSigningBlockOffset = -1;
        try {
            Pair<DataSource, Long> apkSigningBlockAndOffset =
                    V2SchemeVerifier.findApkSigningBlock(inputApk, inputZipSections);
            signerEngine.inputApkSigningBlock(apkSigningBlockAndOffset.getFirst());
            apkSigningBlockOffset = apkSigningBlockAndOffset.getSecond();
        } catch (V2SchemeVerifier.SignatureNotFoundException e) {
            // Input APK does not contain an APK Signing Block. That's OK. APKs are not required to
            // contain this block. It's only needed if the APK is signed using APK Signature Scheme
            // v2.
        }

        // Step 2. Parse the input APK's ZIP Central Directory
        ByteBuffer inputCd = getZipCentralDirectory(inputApk, inputZipSections);
        List<CentralDirectoryRecord> inputCdRecords =
                parseZipCentralDirectory(inputCd, inputZipSections);

        // Step 3. Iterate over input APK's entries and output the Local File Header + data of those
        // entries which need to be output. Entries are iterated in the order in which their Local
        // File Header records are stored in the file. This is to achieve better data locality in
        // case Central Directory entries are in the wrong order.
        List<CentralDirectoryRecord> inputCdRecordsSortedByLfhOffset =
                new ArrayList<>(inputCdRecords);
        Collections.sort(
                inputCdRecordsSortedByLfhOffset,
                CentralDirectoryRecord.BY_LOCAL_FILE_HEADER_OFFSET_COMPARATOR);
        DataSource inputApkLfhSection =
                inputApk.slice(
                        0,
                        (apkSigningBlockOffset != -1)
                                ? apkSigningBlockOffset
                                : inputZipSections.getZipCentralDirectoryOffset());
        int lastModifiedDateForNewEntries = -1;
        int lastModifiedTimeForNewEntries = -1;
        long inputOffset = 0;
        long outputOffset = 0;
        Map<String, CentralDirectoryRecord> outputCdRecordsByName =
                new HashMap<>(inputCdRecords.size());
        for (final CentralDirectoryRecord inputCdRecord : inputCdRecordsSortedByLfhOffset) {
            String entryName = inputCdRecord.getName();
            ApkSignerEngine.InputJarEntryInstructions entryInstructions =
                    signerEngine.inputJarEntry(entryName);
            boolean shouldOutput;
            switch (entryInstructions.getOutputPolicy()) {
                case OUTPUT:
                    shouldOutput = true;
                    break;
                case OUTPUT_BY_ENGINE:
                case SKIP:
                    shouldOutput = false;
                    break;
                default:
                    throw new RuntimeException(
                            "Unknown output policy: " + entryInstructions.getOutputPolicy());
            }

            long inputLocalFileHeaderStartOffset = inputCdRecord.getLocalFileHeaderOffset();
            if (inputLocalFileHeaderStartOffset > inputOffset) {
                // Unprocessed data in input starting at inputOffset and ending and the start of
                // this record's LFH. We output this data verbatim because this signer is supposed
                // to preserve as much of input as possible.
                long chunkSize = inputLocalFileHeaderStartOffset - inputOffset;
                inputApkLfhSection.feed(inputOffset, chunkSize, outputApkOut);
                outputOffset += chunkSize;
                inputOffset = inputLocalFileHeaderStartOffset;
            }
            LocalFileRecord inputLocalFileRecord =
                    LocalFileRecord.getRecord(
                            inputApkLfhSection, inputCdRecord, inputApkLfhSection.size());
            inputOffset += inputLocalFileRecord.getSize();

            ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                    entryInstructions.getInspectJarEntryRequest();
            if (inspectEntryRequest != null) {
                fulfillInspectInputJarEntryRequest(
                        inputApkLfhSection, inputLocalFileRecord, inspectEntryRequest);
            }

            if (shouldOutput) {
                // Find the max value of last modified, to be used for new entries added by the
                // signer.
                int lastModifiedDate = inputCdRecord.getLastModificationDate();
                int lastModifiedTime = inputCdRecord.getLastModificationTime();
                if ((lastModifiedDateForNewEntries == -1)
                        || (lastModifiedDate > lastModifiedDateForNewEntries)
                        || ((lastModifiedDate == lastModifiedDateForNewEntries)
                                && (lastModifiedTime > lastModifiedTimeForNewEntries))) {
                    lastModifiedDateForNewEntries = lastModifiedDate;
                    lastModifiedTimeForNewEntries = lastModifiedTime;
                }

                inspectEntryRequest = signerEngine.outputJarEntry(entryName);
                if (inspectEntryRequest != null) {
                    fulfillInspectInputJarEntryRequest(
                            inputApkLfhSection, inputLocalFileRecord, inspectEntryRequest);
                }

                // Output entry's Local File Header + data
                long outputLocalFileHeaderOffset = outputOffset;
                long outputLocalFileRecordSize =
                        outputInputJarEntryLfhRecordPreservingDataAlignment(
                                inputApkLfhSection,
                                inputLocalFileRecord,
                                outputApkOut,
                                outputLocalFileHeaderOffset);
                outputOffset += outputLocalFileRecordSize;

                // Enqueue entry's Central Directory record for output
                CentralDirectoryRecord outputCdRecord;
                if (outputLocalFileHeaderOffset == inputLocalFileRecord.getStartOffsetInArchive()) {
                    outputCdRecord = inputCdRecord;
                } else {
                    outputCdRecord =
                            inputCdRecord.createWithModifiedLocalFileHeaderOffset(
                                    outputLocalFileHeaderOffset);
                }
                outputCdRecordsByName.put(entryName, outputCdRecord);
            }
        }
        long inputLfhSectionSize = inputApkLfhSection.size();
        if (inputOffset < inputLfhSectionSize) {
            // Unprocessed data in input starting at inputOffset and ending and the end of the input
            // APK's LFH section. We output this data verbatim because this signer is supposed
            // to preserve as much of input as possible.
            long chunkSize = inputLfhSectionSize - inputOffset;
            inputApkLfhSection.feed(inputOffset, chunkSize, outputApkOut);
            outputOffset += chunkSize;
            inputOffset = inputLfhSectionSize;
        }

        // Step 4. Sort output APK's Central Directory records in the order in which they should
        // appear in the output
        List<CentralDirectoryRecord> outputCdRecords = new ArrayList<>(inputCdRecords.size() + 10);
        for (CentralDirectoryRecord inputCdRecord : inputCdRecords) {
            String entryName = inputCdRecord.getName();
            CentralDirectoryRecord outputCdRecord = outputCdRecordsByName.get(entryName);
            if (outputCdRecord != null) {
                outputCdRecords.add(outputCdRecord);
            }
        }

        // Step 5. Generate and output JAR signatures, if necessary. This may output more Local File
        // Header + data entries and add to the list of output Central Directory records.
        ApkSignerEngine.OutputJarSignatureRequest outputJarSignatureRequest =
                signerEngine.outputJarEntries();
        if (outputJarSignatureRequest != null) {
            if (lastModifiedDateForNewEntries == -1) {
                lastModifiedDateForNewEntries = 0x3a21; // Jan 1 2009 (DOS)
                lastModifiedTimeForNewEntries = 0;
            }
            for (ApkSignerEngine.OutputJarSignatureRequest.JarEntry entry :
                    outputJarSignatureRequest.getAdditionalJarEntries()) {
                String entryName = entry.getName();
                byte[] uncompressedData = entry.getData();
                ZipUtils.DeflateResult deflateResult =
                        ZipUtils.deflate(ByteBuffer.wrap(uncompressedData));
                byte[] compressedData = deflateResult.output;
                long uncompressedDataCrc32 = deflateResult.inputCrc32;

                ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                        signerEngine.outputJarEntry(entryName);
                if (inspectEntryRequest != null) {
                    inspectEntryRequest.getDataSink().consume(
                            uncompressedData, 0, uncompressedData.length);
                    inspectEntryRequest.done();
                }

                long localFileHeaderOffset = outputOffset;
                outputOffset +=
                        LocalFileRecord.outputRecordWithDeflateCompressedData(
                                entryName,
                                lastModifiedTimeForNewEntries,
                                lastModifiedDateForNewEntries,
                                compressedData,
                                uncompressedDataCrc32,
                                uncompressedData.length,
                                outputApkOut);


                outputCdRecords.add(
                        CentralDirectoryRecord.createWithDeflateCompressedData(
                                entryName,
                                lastModifiedTimeForNewEntries,
                                lastModifiedDateForNewEntries,
                                uncompressedDataCrc32,
                                compressedData.length,
                                uncompressedData.length,
                                localFileHeaderOffset));
            }
            outputJarSignatureRequest.done();
        }

        // Step 6. Construct output ZIP Central Directory in an in-memory buffer
        long outputCentralDirSizeBytes = 0;
        for (CentralDirectoryRecord record : outputCdRecords) {
            outputCentralDirSizeBytes += record.getSize();
        }
        if (outputCentralDirSizeBytes > Integer.MAX_VALUE) {
            throw new IOException(
                    "Output ZIP Central Directory too large: " + outputCentralDirSizeBytes
                            + " bytes");
        }
        ByteBuffer outputCentralDir = ByteBuffer.allocate((int) outputCentralDirSizeBytes);
        for (CentralDirectoryRecord record : outputCdRecords) {
            record.copyTo(outputCentralDir);
        }
        outputCentralDir.flip();
        DataSource outputCentralDirDataSource = new ByteBufferDataSource(outputCentralDir);
        long outputCentralDirStartOffset = outputOffset;
        int outputCentralDirRecordCount = outputCdRecords.size();

        // Step 7. Construct output ZIP End of Central Directory record in an in-memory buffer
        ByteBuffer outputEocd =
                EocdRecord.createWithModifiedCentralDirectoryInfo(
                        inputZipSections.getZipEndOfCentralDirectory(),
                        outputCentralDirRecordCount,
                        outputCentralDirDataSource.size(),
                        outputCentralDirStartOffset);

        // Step 8. Generate and output APK Signature Scheme v2 signatures, if necessary. This may
        // insert an APK Signing Block just before the output's ZIP Central Directory
        ApkSignerEngine.OutputApkSigningBlockRequest outputApkSigingBlockRequest =
                signerEngine.outputZipSections(
                        outputApkIn,
                        outputCentralDirDataSource,
                        DataSources.asDataSource(outputEocd));
        if (outputApkSigingBlockRequest != null) {
            byte[] outputApkSigningBlock = outputApkSigingBlockRequest.getApkSigningBlock();
            outputApkOut.consume(outputApkSigningBlock, 0, outputApkSigningBlock.length);
            ZipUtils.setZipEocdCentralDirectoryOffset(
                    outputEocd, outputCentralDirStartOffset + outputApkSigningBlock.length);
            outputApkSigingBlockRequest.done();
        }

        // Step 9. Output ZIP Central Directory and ZIP End of Central Directory
        outputCentralDirDataSource.feed(0, outputCentralDirDataSource.size(), outputApkOut);
        outputApkOut.consume(outputEocd);
        signerEngine.outputDone();
    }

    private static void fulfillInspectInputJarEntryRequest(
            DataSource lfhSection,
            LocalFileRecord localFileRecord,
            ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest)
                    throws IOException, ZipFormatException {
        localFileRecord.outputUncompressedData(lfhSection, inspectEntryRequest.getDataSink());
        inspectEntryRequest.done();
    }

    private static long outputInputJarEntryLfhRecordPreservingDataAlignment(
            DataSource inputLfhSection,
            LocalFileRecord inputRecord,
            DataSink outputLfhSection,
            long outputOffset) throws IOException {
        long inputOffset = inputRecord.getStartOffsetInArchive();
        if (inputOffset == outputOffset) {
            // This record's data will be aligned same as in the input APK.
            return inputRecord.outputRecord(inputLfhSection, outputLfhSection);
        }
        int dataAlignmentMultiple = getInputJarEntryDataAlignmentMultiple(inputRecord);
        if ((dataAlignmentMultiple <= 1)
                || ((inputOffset % dataAlignmentMultiple)
                        == (outputOffset % dataAlignmentMultiple))) {
            // This record's data will be aligned same as in the input APK.
            return inputRecord.outputRecord(inputLfhSection, outputLfhSection);
        }

        long inputDataStartOffset = inputOffset + inputRecord.getDataStartOffsetInRecord();
        if ((inputDataStartOffset % dataAlignmentMultiple) != 0) {
            // This record's data is not aligned in the input APK. No need to align it in the
            // output.
            return inputRecord.outputRecord(inputLfhSection, outputLfhSection);
        }

        // This record's data needs to be re-aligned in the output. This is achieved using the
        // record's extra field.
        ByteBuffer aligningExtra =
                createExtraFieldToAlignData(
                        inputRecord.getExtra(),
                        outputOffset + inputRecord.getExtraFieldStartOffsetInsideRecord(),
                        dataAlignmentMultiple);
        return inputRecord.outputRecordWithModifiedExtra(
                inputLfhSection, aligningExtra, outputLfhSection);
    }

    private static int getInputJarEntryDataAlignmentMultiple(LocalFileRecord entry) {
        if (entry.isDataCompressed()) {
            // Compressed entries don't need to be aligned
            return 1;
        }

        // Attempt to obtain the alignment multiple from the entry's extra field.
        ByteBuffer extra = entry.getExtra();
        if (extra.hasRemaining()) {
            extra.order(ByteOrder.LITTLE_ENDIAN);
            // FORMAT: sequence of fields. Each field consists of:
            //   * uint16 ID
            //   * uint16 size
            //   * 'size' bytes: payload
            while (extra.remaining() >= 4) {
                short headerId  = extra.getShort();
                int dataSize = ZipUtils.getUnsignedInt16(extra);
                if (dataSize > extra.remaining()) {
                    // Malformed field -- insufficient input remaining
                    break;
                }
                if (headerId != ALIGNMENT_ZIP_EXTRA_DATA_FIELD_HEADER_ID) {
                    // Skip this field
                    extra.position(extra.position() + dataSize);
                    continue;
                }
                // This is APK alignment field.
                // FORMAT:
                //  * uint16 alignment multiple (in bytes)
                //  * remaining bytes -- padding to achieve alignment of data which starts after
                //    the extra field
                if (dataSize < 2) {
                    // Malformed
                    break;
                }
                return ZipUtils.getUnsignedInt16(extra);
            }
        }

        // Fall back to filename-based defaults
        return (entry.getName().endsWith(".so")) ? 4096 : 4;
    }

    private static ByteBuffer createExtraFieldToAlignData(
            ByteBuffer original,
            long extraStartOffset,
            int dataAlignmentMultiple) {
        if (dataAlignmentMultiple <= 1) {
            return original;
        }

        // In the worst case scenario, we'll increase the output size by 6 + dataAlignment - 1.
        ByteBuffer result = ByteBuffer.allocate(original.remaining() + 5 + dataAlignmentMultiple);
        result.order(ByteOrder.LITTLE_ENDIAN);

        // Step 1. Output all extra fields other than the one which is to do with alignment
        // FORMAT: sequence of fields. Each field consists of:
        //   * uint16 ID
        //   * uint16 size
        //   * 'size' bytes: payload
        while (original.remaining() >= 4) {
            short headerId  = original.getShort();
            int dataSize = ZipUtils.getUnsignedInt16(original);
            if (dataSize > original.remaining()) {
                // Malformed field -- insufficient input remaining
                break;
            }
            if (((headerId == 0) && (dataSize == 0))
                    || (headerId == ALIGNMENT_ZIP_EXTRA_DATA_FIELD_HEADER_ID)) {
                // Ignore the field if it has to do with the old APK data alignment method (filling
                // the extra field with 0x00 bytes) or the new APK data alignment method.
                original.position(original.position() + dataSize);
                continue;
            }
            // Copy this field (including header) to the output
            original.position(original.position() - 4);
            int originalLimit = original.limit();
            original.limit(original.position() + 4 + dataSize);
            result.put(original);
            original.limit(originalLimit);
        }

        // Step 2. Add alignment field
        // FORMAT:
        //  * uint16 extra header ID
        //  * uint16 extra data size
        //        Payload ('data size' bytes)
        //      * uint16 alignment multiple (in bytes)
        //      * remaining bytes -- padding to achieve alignment of data which starts after the
        //        extra field
        long dataMinStartOffset =
                extraStartOffset + result.position()
                        + ALIGNMENT_ZIP_EXTRA_DATA_FIELD_MIN_SIZE_BYTES;
        int paddingSizeBytes =
                (dataAlignmentMultiple - ((int) (dataMinStartOffset % dataAlignmentMultiple)))
                        % dataAlignmentMultiple;
        result.putShort(ALIGNMENT_ZIP_EXTRA_DATA_FIELD_HEADER_ID);
        ZipUtils.putUnsignedInt16(result, 2 + paddingSizeBytes);
        ZipUtils.putUnsignedInt16(result, dataAlignmentMultiple);
        result.position(result.position() + paddingSizeBytes);
        result.flip();

        return result;
    }

    private static ByteBuffer getZipCentralDirectory(
            DataSource apk,
            ApkUtils.ZipSections apkSections) throws IOException, ZipFormatException {
        long cdSizeBytes = apkSections.getZipCentralDirectorySizeBytes();
        if (cdSizeBytes > Integer.MAX_VALUE) {
            throw new ZipFormatException("ZIP Central Directory too large: " + cdSizeBytes);
        }
        long cdOffset = apkSections.getZipCentralDirectoryOffset();
        ByteBuffer cd = apk.getByteBuffer(cdOffset, (int) cdSizeBytes);
        cd.order(ByteOrder.LITTLE_ENDIAN);
        return cd;
    }

    private static List<CentralDirectoryRecord> parseZipCentralDirectory(
            ByteBuffer cd,
            ApkUtils.ZipSections apkSections) throws ZipFormatException {
        long cdOffset = apkSections.getZipCentralDirectoryOffset();
        int expectedCdRecordCount = apkSections.getZipCentralDirectoryRecordCount();
        List<CentralDirectoryRecord> cdRecords = new ArrayList<>(expectedCdRecordCount);
        Set<String> entryNames = new HashSet<>(expectedCdRecordCount);
        for (int i = 0; i < expectedCdRecordCount; i++) {
            CentralDirectoryRecord cdRecord;
            int offsetInsideCd = cd.position();
            try {
                cdRecord = CentralDirectoryRecord.getRecord(cd);
            } catch (ZipFormatException e) {
                throw new ZipFormatException(
                        "Failed to parse ZIP Central Directory record #" + (i + 1)
                                + " at file offset " + (cdOffset + offsetInsideCd),
                        e);
            }
            String entryName = cdRecord.getName();
            if (!entryNames.add(entryName)) {
                throw new ZipFormatException(
                        "Malformed APK: multiple JAR entries with the same name: " + entryName);
            }
            cdRecords.add(cdRecord);
        }
        if (cd.hasRemaining()) {
            throw new ZipFormatException(
                    "Unused space at the end of ZIP Central Directory: " + cd.remaining()
                        + " bytes starting at file offset " + (cdOffset + cd.position()));
        }

        return cdRecords;
    }

    /**
     * Builder of {@link ApkSigner} instances.
     *
     * <p>The following information is required to construct a working {@code ApkSigner}:
     * <ul>
     * <li>{@link ApkSignerEngine} -- provided in the constructor,</li>
     * <li>APK to be signed -- see {@link #setInputApk(File) setInputApk} variants,</li>
     * <li>where to store the signed APK -- see {@link #setOutputApk(File) setOutputApk} variants.
     * </li>
     * </ul>
     */
    public static class Builder {
        private final ApkSignerEngine mSignerEngine;

        private File mInputApkFile;
        private DataSource mInputApkDataSource;

        private File mOutputApkFile;
        private DataSink mOutputApkDataSink;
        private DataSource mOutputApkDataSource;

        /**
         * Constructs a new {@code Builder} which will make {@code ApkSigner} use the provided
         * signing engine.
         */
        public Builder(ApkSignerEngine signerEngine) {
            mSignerEngine = signerEngine;
        }

        /**
         * Sets the APK to be signed.
         *
         * @see #setInputApk(DataSource)
         */
        public Builder setInputApk(File inputApk) {
            if (inputApk == null) {
                throw new NullPointerException("inputApk == null");
            }
            mInputApkFile = inputApk;
            mInputApkDataSource = null;
            return this;
        }

        /**
         * Sets the APK to be signed.
         *
         * @see #setInputApk(File)
         */
        public Builder setInputApk(DataSource inputApk) {
            if (inputApk == null) {
                throw new NullPointerException("inputApk == null");
            }
            mInputApkDataSource = inputApk;
            mInputApkFile = null;
            return this;
        }

        /**
         * Sets the location of the output (signed) APK. {@code ApkSigner} will create this file if
         * it doesn't exist.
         *
         * @see #setOutputApk(DataSink, DataSource)
         */
        public Builder setOutputApk(File outputApk) {
            if (outputApk == null) {
                throw new NullPointerException("outputApk == null");
            }
            mOutputApkFile = outputApk;
            mOutputApkDataSink = null;
            mOutputApkDataSource = null;
            return this;
        }

        /**
         * Sets the sink which will receive the output (signed) APK. Data received by the
         * {@code outputApkOut} sink must be visible through the {@code outputApkIn} data source.
         *
         * @see #setOutputApk(File)
         */
        public Builder setOutputApk(DataSink outputApkOut, DataSource outputApkIn) {
            if (outputApkOut == null) {
                throw new NullPointerException("outputApkOut == null");
            }
            if (outputApkIn == null) {
                throw new NullPointerException("outputApkIn == null");
            }
            mOutputApkFile = null;
            mOutputApkDataSink = outputApkOut;
            mOutputApkDataSource = outputApkIn;
            return this;
        }

        /**
         * Returns a new {@code ApkSigner} instance initialized according to the configuration of
         * this builder.
         */
        public ApkSigner build() {
            return new ApkSigner(
                    mSignerEngine,
                    mInputApkFile,
                    mInputApkDataSource,
                    mOutputApkFile,
                    mOutputApkDataSink,
                    mOutputApkDataSource);
        }
    }
}
