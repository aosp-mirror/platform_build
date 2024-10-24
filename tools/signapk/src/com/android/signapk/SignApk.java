/*
 * Copyright (C) 2008 The Android Open Source Project
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

package com.android.signapk;

import org.bouncycastle.asn1.ASN1InputStream;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.DEROutputStream;
import org.bouncycastle.asn1.cms.CMSObjectIdentifiers;
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo;
import org.bouncycastle.cert.jcajce.JcaCertStore;
import org.bouncycastle.cms.CMSException;
import org.bouncycastle.cms.CMSSignedData;
import org.bouncycastle.cms.CMSSignedDataGenerator;
import org.bouncycastle.cms.CMSTypedData;
import org.bouncycastle.cms.jcajce.JcaSignerInfoGeneratorBuilder;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.OperatorCreationException;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.operator.jcajce.JcaDigestCalculatorProviderBuilder;
import org.conscrypt.OpenSSLProvider;

import com.android.apksig.ApkSignerEngine;
import com.android.apksig.DefaultApkSignerEngine;
import com.android.apksig.SigningCertificateLineage;
import com.android.apksig.Hints;
import com.android.apksig.apk.ApkUtils;
import com.android.apksig.apk.MinSdkVersionException;
import com.android.apksig.util.DataSink;
import com.android.apksig.util.DataSource;
import com.android.apksig.util.DataSources;
import com.android.apksig.zip.ZipFormatException;

import java.io.Console;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FilterOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.lang.reflect.Constructor;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.NoSuchAlgorithmException;
import java.security.Key;
import java.security.KeyFactory;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.KeyStore.PrivateKeyEntry;
import java.security.PrivateKey;
import java.security.Provider;
import java.security.Security;
import java.security.UnrecoverableEntryException;
import java.security.UnrecoverableKeyException;
import java.security.cert.CertificateEncodingException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import java.util.jar.JarOutputStream;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;

import javax.crypto.Cipher;
import javax.crypto.EncryptedPrivateKeyInfo;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/**
 * HISTORICAL NOTE:
 *
 * Prior to the keylimepie release, SignApk ignored the signature
 * algorithm specified in the certificate and always used SHA1withRSA.
 *
 * Starting with JB-MR2, the platform supports SHA256withRSA, so we use
 * the signature algorithm in the certificate to select which to use
 * (SHA256withRSA or SHA1withRSA). Also in JB-MR2, EC keys are supported.
 *
 * Because there are old keys still in use whose certificate actually
 * says "MD5withRSA", we treat these as though they say "SHA1withRSA"
 * for compatibility with older releases.  This can be changed by
 * altering the getAlgorithm() function below.
 */


/**
 * Command line tool to sign JAR files (including APKs and OTA updates) in a way
 * compatible with the mincrypt verifier, using EC or RSA keys and SHA1 or
 * SHA-256 (see historical note). The tool can additionally sign APKs using
 * APK Signature Scheme v2.
 */
class SignApk {
    private static final String OTACERT_NAME = "META-INF/com/android/otacert";

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

    // bitmasks for which hash algorithms we need the manifest to include.
    private static final int USE_SHA1 = 1;
    private static final int USE_SHA256 = 2;

    /**
     * Returns the digest algorithm ID (one of {@code USE_SHA1} or {@code USE_SHA256}) to be used
     * for signing an OTA update package using the private key corresponding to the provided
     * certificate.
     */
    private static int getDigestAlgorithmForOta(X509Certificate cert) {
        String sigAlg = cert.getSigAlgName().toUpperCase(Locale.US);
        if ("SHA1WITHRSA".equals(sigAlg) || "MD5WITHRSA".equals(sigAlg)) {
            // see "HISTORICAL NOTE" above.
            return USE_SHA1;
        } else if (sigAlg.startsWith("SHA256WITH")) {
            return USE_SHA256;
        } else {
            throw new IllegalArgumentException("unsupported signature algorithm \"" + sigAlg +
                                               "\" in cert [" + cert.getSubjectDN());
        }
    }

    /**
     * Returns the JCA {@link java.security.Signature} algorithm to be used for signing and OTA
     * update package using the private key corresponding to the provided certificate and the
     * provided digest algorithm (see {@code USE_SHA1} and {@code USE_SHA256} constants).
     */
    private static String getJcaSignatureAlgorithmForOta(
            X509Certificate cert, int hash) {
        String sigAlgDigestPrefix;
        switch (hash) {
            case USE_SHA1:
                sigAlgDigestPrefix = "SHA1";
                break;
            case USE_SHA256:
                sigAlgDigestPrefix = "SHA256";
                break;
            default:
                throw new IllegalArgumentException("Unknown hash ID: " + hash);
        }

        String keyAlgorithm = cert.getPublicKey().getAlgorithm();
        if ("RSA".equalsIgnoreCase(keyAlgorithm)) {
            return sigAlgDigestPrefix + "withRSA";
        } else if ("EC".equalsIgnoreCase(keyAlgorithm)) {
            return sigAlgDigestPrefix + "withECDSA";
        } else {
            throw new IllegalArgumentException("Unsupported key algorithm: " + keyAlgorithm);
        }
    }

    private static X509Certificate readPublicKey(File file)
        throws IOException, GeneralSecurityException {
        FileInputStream input = new FileInputStream(file);
        try {
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            return (X509Certificate) cf.generateCertificate(input);
        } finally {
            input.close();
        }
    }

    /**
     * If a console doesn't exist, reads the password from stdin
     * If a console exists, reads the password from console and returns it as a string.
     *
     * @param keyFileName Name of the file containing the private key.  Used to prompt the user.
     */
    private static char[] readPassword(String keyFileName) {
        Console console;
        if ((console = System.console()) == null) {
            System.out.print(
                "Enter password for " + keyFileName + " (password will not be hidden): ");
            System.out.flush();
            BufferedReader stdin = new BufferedReader(new InputStreamReader(System.in));
            try {
                String result = stdin.readLine();
                return result == null ? null : result.toCharArray();
            } catch (IOException ex) {
                return null;
            }
        } else {
            return console.readPassword("[%s]", "Enter password for " + keyFileName);
        }
    }

    /**
     * Decrypt an encrypted PKCS#8 format private key.
     *
     * Based on ghstark's post on Aug 6, 2006 at
     * http://forums.sun.com/thread.jspa?threadID=758133&messageID=4330949
     *
     * @param encryptedPrivateKey The raw data of the private key
     * @param keyFile The file containing the private key
     */
    private static PKCS8EncodedKeySpec decryptPrivateKey(byte[] encryptedPrivateKey, File keyFile)
        throws GeneralSecurityException {
        EncryptedPrivateKeyInfo epkInfo;
        try {
            epkInfo = new EncryptedPrivateKeyInfo(encryptedPrivateKey);
        } catch (IOException ex) {
            // Probably not an encrypted key.
            return null;
        }

        SecretKeyFactory skFactory = SecretKeyFactory.getInstance(epkInfo.getAlgName());
        Key key = skFactory.generateSecret(new PBEKeySpec(readPassword(keyFile.getPath())));
        Cipher cipher = Cipher.getInstance(epkInfo.getAlgName());
        cipher.init(Cipher.DECRYPT_MODE, key, epkInfo.getAlgParameters());

        try {
            return epkInfo.getKeySpec(cipher);
        } catch (InvalidKeySpecException ex) {
            System.err.println("signapk: Password for " + keyFile + " may be bad.");
            throw ex;
        }
    }

    /** Read a PKCS#8 format private key. */
    private static PrivateKey readPrivateKey(File file)
        throws IOException, GeneralSecurityException {
        DataInputStream input = new DataInputStream(new FileInputStream(file));
        try {
            byte[] bytes = new byte[(int) file.length()];
            input.read(bytes);

            /* Check to see if this is in an EncryptedPrivateKeyInfo structure. */
            PKCS8EncodedKeySpec spec = decryptPrivateKey(bytes, file);
            if (spec == null) {
                spec = new PKCS8EncodedKeySpec(bytes);
            }

            /*
             * Now it's in a PKCS#8 PrivateKeyInfo structure. Read its Algorithm
             * OID and use that to construct a KeyFactory.
             */
            PrivateKeyInfo pki;
            try (ASN1InputStream bIn =
                    new ASN1InputStream(new ByteArrayInputStream(spec.getEncoded()))) {
                pki = PrivateKeyInfo.getInstance(bIn.readObject());
            }
            String algOid = pki.getPrivateKeyAlgorithm().getAlgorithm().getId();

            return KeyFactory.getInstance(algOid).generatePrivate(spec);
        } finally {
            input.close();
        }
    }

    private static KeyStore createKeyStore(String keyStoreName, String keyStorePin) throws
            CertificateException,
            IOException,
            KeyStoreException,
            NoSuchAlgorithmException {
        KeyStore keyStore = KeyStore.getInstance(keyStoreName);
        keyStore.load(null, keyStorePin == null ? null : keyStorePin.toCharArray());
        return keyStore;
    }

    /** Get a PKCS#11 private key from keyStore */
    private static PrivateKey loadPrivateKeyFromKeyStore(
            final KeyStore keyStore, final String keyName)
            throws CertificateException, KeyStoreException, NoSuchAlgorithmException,
                    UnrecoverableKeyException, UnrecoverableEntryException {
        final PrivateKeyEntry privateKeyEntry = (PrivateKeyEntry) keyStore.getEntry(keyName, null);
        if (privateKeyEntry == null) {
        throw new Error(
            "Key "
                + keyName
                + " not found in the token provided by PKCS11 library!");
        }
        return privateKeyEntry.getPrivateKey();
    }

    /**
     * Add a copy of the public key to the archive; this should
     * exactly match one of the files in
     * /system/etc/security/otacerts.zip on the device.  (The same
     * cert can be extracted from the OTA update package's signature
     * block but this is much easier to get at.)
     */
    private static void addOtacert(JarOutputStream outputJar,
                                   File publicKeyFile,
                                   long timestamp)
        throws IOException {

        JarEntry je = new JarEntry(OTACERT_NAME);
        je.setTime(timestamp);
        outputJar.putNextEntry(je);
        FileInputStream input = new FileInputStream(publicKeyFile);
        byte[] b = new byte[4096];
        int read;
        while ((read = input.read(b)) != -1) {
            outputJar.write(b, 0, read);
        }
        input.close();
    }


    /** Sign data and write the digital signature to 'out'. */
    private static void writeSignatureBlock(
        CMSTypedData data, X509Certificate publicKey, PrivateKey privateKey, int hash,
        OutputStream out)
        throws IOException,
               CertificateEncodingException,
               OperatorCreationException,
               CMSException {
        ArrayList<X509Certificate> certList = new ArrayList<X509Certificate>(1);
        certList.add(publicKey);
        JcaCertStore certs = new JcaCertStore(certList);

        CMSSignedDataGenerator gen = new CMSSignedDataGenerator();
        ContentSigner signer =
                new JcaContentSignerBuilder(
                        getJcaSignatureAlgorithmForOta(publicKey, hash))
                        .build(privateKey);
        gen.addSignerInfoGenerator(
            new JcaSignerInfoGeneratorBuilder(
                new JcaDigestCalculatorProviderBuilder()
                .build())
            .setDirectSignature(true)
            .build(signer, publicKey));
        gen.addCertificates(certs);
        CMSSignedData sigData = gen.generate(data, false);

        try (ASN1InputStream asn1 = new ASN1InputStream(sigData.getEncoded())) {
            DEROutputStream dos = new DEROutputStream(out);
            dos.writeObject(asn1.readObject());
        }
    }

    /**
     * Adds ZIP entries which represent the v1 signature (JAR signature scheme).
     */
    private static void addV1Signature(
            ApkSignerEngine apkSigner,
            ApkSignerEngine.OutputJarSignatureRequest v1Signature,
            JarOutputStream out,
            long timestamp) throws IOException {
        for (ApkSignerEngine.OutputJarSignatureRequest.JarEntry entry
                : v1Signature.getAdditionalJarEntries()) {
            String entryName = entry.getName();
            JarEntry outEntry = new JarEntry(entryName);
            outEntry.setTime(timestamp);
            out.putNextEntry(outEntry);
            byte[] entryData = entry.getData();
            out.write(entryData);
            ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                    apkSigner.outputJarEntry(entryName);
            if (inspectEntryRequest != null) {
                inspectEntryRequest.getDataSink().consume(entryData, 0, entryData.length);
                inspectEntryRequest.done();
            }
        }
    }

    /**
     * Copy all JAR entries from input to output. We set the modification times in the output to a
     * fixed time, so as to reduce variation in the output file and make incremental OTAs more
     * efficient.
     */
    private static void copyFiles(
            JarFile in,
            Pattern ignoredFilenamePattern,
            ApkSignerEngine apkSigner,
            JarOutputStream out,
            CountingOutputStream outCounter,
            long timestamp,
            int defaultAlignment) throws IOException {
        byte[] buffer = new byte[4096];
        int num;

        List<Hints.PatternWithRange> pinPatterns = extractPinPatterns(in);
        ArrayList<Hints.ByteRange> pinByteRanges = pinPatterns == null ? null : new ArrayList<>();

        ArrayList<String> names = new ArrayList<String>();
        for (Enumeration<JarEntry> e = in.entries(); e.hasMoreElements();) {
            JarEntry entry = e.nextElement();
            if (entry.isDirectory()) {
                continue;
            }
            String entryName = entry.getName();
            if ((ignoredFilenamePattern != null)
                    && (ignoredFilenamePattern.matcher(entryName).matches())) {
                continue;
            }
            if (Hints.PIN_BYTE_RANGE_ZIP_ENTRY_NAME.equals(entryName)) {
                continue;  // We regenerate it below.
            }
            names.add(entryName);
        }
        Collections.sort(names);

        boolean firstEntry = true;
        long offset = 0L;

        // We do the copy in two passes -- first copying all the
        // entries that are STORED, then copying all the entries that
        // have any other compression flag (which in practice means
        // DEFLATED).  This groups all the stored entries together at
        // the start of the file and makes it easier to do alignment
        // on them (since only stored entries are aligned).

        List<String> remainingNames = new ArrayList<>(names.size());
        for (String name : names) {
            JarEntry inEntry = in.getJarEntry(name);
            if (inEntry.getMethod() != JarEntry.STORED) {
                // Defer outputting this entry until we're ready to output compressed entries.
                remainingNames.add(name);
                continue;
            }

            if (!shouldOutputApkEntry(apkSigner, in, inEntry, buffer)) {
                continue;
            }

            // Preserve the STORED method of the input entry.
            JarEntry outEntry = new JarEntry(inEntry);
            outEntry.setTime(timestamp);
            // Discard comment and extra fields of this entry to
            // simplify alignment logic below and for consistency with
            // how compressed entries are handled later.
            outEntry.setComment(null);
            outEntry.setExtra(null);

            int alignment = getStoredEntryDataAlignment(name, defaultAlignment);
            // Alignment of the entry's data is achieved by adding a data block to the entry's Local
            // File Header extra field. The data block contains information about the alignment
            // value and the necessary padding bytes (0x00) to achieve the alignment.  This works
            // because the entry's data will be located immediately after the extra field.
            // See ZIP APPNOTE.txt section "4.5 Extensible data fields" for details about the format
            // of the extra field.

            // 'offset' is the offset into the file at which we expect the entry's data to begin.
            // This is the value we need to make a multiple of 'alignment'.
            offset += JarFile.LOCHDR + outEntry.getName().length();
            if (firstEntry) {
                // The first entry in a jar file has an extra field of four bytes that you can't get
                // rid of; any extra data you specify in the JarEntry is appended to these forced
                // four bytes.  This is JAR_MAGIC in JarOutputStream; the bytes are 0xfeca0000.
                // See http://bugs.java.com/bugdatabase/view_bug.do?bug_id=6808540
                // and http://bugs.java.com/bugdatabase/view_bug.do?bug_id=4138619.
                offset += 4;
                firstEntry = false;
            }
            int extraPaddingSizeBytes = 0;
            if (alignment > 0) {
                long paddingStartOffset = offset + ALIGNMENT_ZIP_EXTRA_DATA_FIELD_MIN_SIZE_BYTES;
                extraPaddingSizeBytes =
                        (alignment - (int) (paddingStartOffset % alignment)) % alignment;
            }
            byte[] extra =
                    new byte[ALIGNMENT_ZIP_EXTRA_DATA_FIELD_MIN_SIZE_BYTES + extraPaddingSizeBytes];
            ByteBuffer extraBuf = ByteBuffer.wrap(extra);
            extraBuf.order(ByteOrder.LITTLE_ENDIAN);
            extraBuf.putShort(ALIGNMENT_ZIP_EXTRA_DATA_FIELD_HEADER_ID); // Header ID
            extraBuf.putShort((short) (2 + extraPaddingSizeBytes)); // Data Size
            extraBuf.putShort((short) alignment);
            outEntry.setExtra(extra);
            offset += extra.length;

            long entryHeaderStart = outCounter.getWrittenBytes();
            out.putNextEntry(outEntry);
            ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                    (apkSigner != null) ? apkSigner.outputJarEntry(name) : null;
            DataSink entryDataSink =
                    (inspectEntryRequest != null) ? inspectEntryRequest.getDataSink() : null;

            long entryDataStart = outCounter.getWrittenBytes();
            try (InputStream data = in.getInputStream(inEntry)) {
                while ((num = data.read(buffer)) > 0) {
                    out.write(buffer, 0, num);
                    if (entryDataSink != null) {
                        entryDataSink.consume(buffer, 0, num);
                    }
                    offset += num;
                }
            }
            out.closeEntry();
            out.flush();
            if (inspectEntryRequest != null) {
                inspectEntryRequest.done();
            }

            if (pinPatterns != null) {
                boolean pinFileHeader = false;
                for (Hints.PatternWithRange pinPattern : pinPatterns) {
                    if (!pinPattern.matcher(name).matches()) {
                        continue;
                    }
                    Hints.ByteRange dataRange =
                        new Hints.ByteRange(
                            entryDataStart,
                            outCounter.getWrittenBytes());
                    Hints.ByteRange pinRange =
                        pinPattern.ClampToAbsoluteByteRange(dataRange);
                    if (pinRange != null) {
                        pinFileHeader = true;
                        pinByteRanges.add(pinRange);
                    }
                }
                if (pinFileHeader) {
                    pinByteRanges.add(new Hints.ByteRange(entryHeaderStart,
                                                          entryDataStart));
                }
            }
        }

        // Copy all the non-STORED entries.  We don't attempt to
        // maintain the 'offset' variable past this point; we don't do
        // alignment on these entries.

        for (String name : remainingNames) {
            JarEntry inEntry = in.getJarEntry(name);
            if (!shouldOutputApkEntry(apkSigner, in, inEntry, buffer)) {
                continue;
            }

            // Create a new entry so that the compressed len is recomputed.
            JarEntry outEntry = new JarEntry(name);
            outEntry.setTime(timestamp);
            long entryHeaderStart = outCounter.getWrittenBytes();
            out.putNextEntry(outEntry);
            ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                    (apkSigner != null) ? apkSigner.outputJarEntry(name) : null;
            DataSink entryDataSink =
                    (inspectEntryRequest != null) ? inspectEntryRequest.getDataSink() : null;

            long entryDataStart = outCounter.getWrittenBytes();
            InputStream data = in.getInputStream(inEntry);
            while ((num = data.read(buffer)) > 0) {
                out.write(buffer, 0, num);
                if (entryDataSink != null) {
                    entryDataSink.consume(buffer, 0, num);
                }
            }
            out.closeEntry();
            out.flush();
            if (inspectEntryRequest != null) {
                inspectEntryRequest.done();
            }

            if (pinPatterns != null) {
                boolean pinFileHeader = false;
                for (Hints.PatternWithRange pinPattern : pinPatterns) {
                    if (!pinPattern.matcher(name).matches()) {
                        continue;
                    }
                    Hints.ByteRange dataRange =
                        new Hints.ByteRange(
                            entryDataStart,
                            outCounter.getWrittenBytes());
                    Hints.ByteRange pinRange =
                        pinPattern.ClampToAbsoluteByteRange(dataRange);
                    if (pinRange != null) {
                        pinFileHeader = true;
                        pinByteRanges.add(pinRange);
                    }
                }
                if (pinFileHeader) {
                    pinByteRanges.add(new Hints.ByteRange(entryHeaderStart,
                                                          entryDataStart));
                }
            }
        }

        if (pinByteRanges != null) {
            // Cover central directory
            pinByteRanges.add(
                new Hints.ByteRange(outCounter.getWrittenBytes(),
                                    Long.MAX_VALUE));
            addPinByteRanges(out, pinByteRanges, timestamp);
        }
    }

    private static List<Hints.PatternWithRange> extractPinPatterns(JarFile in) throws IOException {
        ZipEntry pinMetaEntry = in.getEntry(Hints.PIN_HINT_ASSET_ZIP_ENTRY_NAME);
        if (pinMetaEntry == null) {
            return null;
        }
        InputStream pinMetaStream = in.getInputStream(pinMetaEntry);
        byte[] patternBlob = new byte[(int) pinMetaEntry.getSize()];
        pinMetaStream.read(patternBlob);
        return Hints.parsePinPatterns(patternBlob);
    }

    private static void addPinByteRanges(JarOutputStream outputJar,
                                         ArrayList<Hints.ByteRange> pinByteRanges,
                                         long timestamp) throws IOException {
        JarEntry je = new JarEntry(Hints.PIN_BYTE_RANGE_ZIP_ENTRY_NAME);
        je.setTime(timestamp);
        outputJar.putNextEntry(je);
        outputJar.write(Hints.encodeByteRangeList(pinByteRanges));
    }

    private static boolean shouldOutputApkEntry(
            ApkSignerEngine apkSigner, JarFile inFile, JarEntry inEntry, byte[] tmpbuf)
                    throws IOException {
        if (apkSigner == null) {
            return true;
        }

        ApkSignerEngine.InputJarEntryInstructions instructions =
                apkSigner.inputJarEntry(inEntry.getName());
        ApkSignerEngine.InspectJarEntryRequest inspectEntryRequest =
                instructions.getInspectJarEntryRequest();
        if (inspectEntryRequest != null) {
            provideJarEntry(inFile, inEntry, inspectEntryRequest, tmpbuf);
        }
        switch (instructions.getOutputPolicy()) {
            case OUTPUT:
                return true;
            case SKIP:
            case OUTPUT_BY_ENGINE:
                return false;
            default:
                throw new RuntimeException(
                        "Unsupported output policy: " + instructions.getOutputPolicy());
        }
    }

    private static void provideJarEntry(
            JarFile jarFile,
            JarEntry jarEntry,
            ApkSignerEngine.InspectJarEntryRequest request,
            byte[] tmpbuf) throws IOException {
        DataSink dataSink = request.getDataSink();
        try (InputStream in = jarFile.getInputStream(jarEntry)) {
            int chunkSize;
            while ((chunkSize = in.read(tmpbuf)) > 0) {
                dataSink.consume(tmpbuf, 0, chunkSize);
            }
            request.done();
        }
    }

    /**
     * Returns the multiple (in bytes) at which the provided {@code STORED} entry's data must start
     * relative to start of file or {@code 0} if alignment of this entry's data is not important.
     */
    private static int getStoredEntryDataAlignment(String entryName, int defaultAlignment) {
        if (defaultAlignment <= 0) {
            return 0;
        }

        if (entryName.endsWith(".so")) {
            // Align .so contents to memory page boundary to enable memory-mapped
            // execution.
            return 16384;
        } else {
            return defaultAlignment;
        }
    }

    private static class WholeFileSignerOutputStream extends FilterOutputStream {
        private boolean closing = false;
        private ByteArrayOutputStream footer = new ByteArrayOutputStream();
        private OutputStream tee;

        public WholeFileSignerOutputStream(OutputStream out, OutputStream tee) {
            super(out);
            this.tee = tee;
        }

        public void notifyClosing() {
            closing = true;
        }

        public void finish() throws IOException {
            closing = false;

            byte[] data = footer.toByteArray();
            if (data.length < 2)
                throw new IOException("Less than two bytes written to footer");
            write(data, 0, data.length - 2);
        }

        public byte[] getTail() {
            return footer.toByteArray();
        }

        @Override
        public void write(byte[] b) throws IOException {
            write(b, 0, b.length);
        }

        @Override
        public void write(byte[] b, int off, int len) throws IOException {
            if (closing) {
                // if the jar is about to close, save the footer that will be written
                footer.write(b, off, len);
            }
            else {
                // write to both output streams. out is the CMSTypedData signer and tee is the file.
                out.write(b, off, len);
                tee.write(b, off, len);
            }
        }

        @Override
        public void write(int b) throws IOException {
            if (closing) {
                // if the jar is about to close, save the footer that will be written
                footer.write(b);
            }
            else {
                // write to both output streams. out is the CMSTypedData signer and tee is the file.
                out.write(b);
                tee.write(b);
            }
        }
    }

    private static class CMSSigner implements CMSTypedData {
        private final JarFile inputJar;
        private final File publicKeyFile;
        private final X509Certificate publicKey;
        private final PrivateKey privateKey;
        private final int hash;
        private final long timestamp;
        private final OutputStream outputStream;
        private final ASN1ObjectIdentifier type;
        private WholeFileSignerOutputStream signer;

        // Files matching this pattern are not copied to the output.
        private static final Pattern STRIP_PATTERN =
                Pattern.compile("^(META-INF/((.*)[.](SF|RSA|DSA|EC)|com/android/otacert))|("
                        + Pattern.quote(JarFile.MANIFEST_NAME) + ")$");

        public CMSSigner(JarFile inputJar, File publicKeyFile,
                         X509Certificate publicKey, PrivateKey privateKey, int hash,
                         long timestamp, OutputStream outputStream) {
            this.inputJar = inputJar;
            this.publicKeyFile = publicKeyFile;
            this.publicKey = publicKey;
            this.privateKey = privateKey;
            this.hash = hash;
            this.timestamp = timestamp;
            this.outputStream = outputStream;
            this.type = new ASN1ObjectIdentifier(CMSObjectIdentifiers.data.getId());
        }

        /**
         * This should actually return byte[] or something similar, but nothing
         * actually checks it currently.
         */
        @Override
        public Object getContent() {
            return this;
        }

        @Override
        public ASN1ObjectIdentifier getContentType() {
            return type;
        }

        @Override
        public void write(OutputStream out) throws IOException {
            try {
                signer = new WholeFileSignerOutputStream(out, outputStream);
                CountingOutputStream outputJarCounter = new CountingOutputStream(signer);
                JarOutputStream outputJar = new JarOutputStream(outputJarCounter);

                copyFiles(inputJar, STRIP_PATTERN, null, outputJar,
                          outputJarCounter, timestamp, 0);
                addOtacert(outputJar, publicKeyFile, timestamp);

                signer.notifyClosing();
                outputJar.close();
                signer.finish();
            }
            catch (Exception e) {
                throw new IOException(e);
            }
        }

        public void writeSignatureBlock(ByteArrayOutputStream temp)
            throws IOException,
                   CertificateEncodingException,
                   OperatorCreationException,
                   CMSException {
            SignApk.writeSignatureBlock(this, publicKey, privateKey, hash, temp);
        }

        public WholeFileSignerOutputStream getSigner() {
            return signer;
        }
    }

    private static void signWholeFile(JarFile inputJar, File publicKeyFile,
                                      X509Certificate publicKey, PrivateKey privateKey,
                                      int hash, long timestamp,
                                      OutputStream outputStream) throws Exception {
        CMSSigner cmsOut = new CMSSigner(inputJar, publicKeyFile,
                publicKey, privateKey, hash, timestamp, outputStream);

        ByteArrayOutputStream temp = new ByteArrayOutputStream();

        // put a readable message and a null char at the start of the
        // archive comment, so that tools that display the comment
        // (hopefully) show something sensible.
        // TODO: anything more useful we can put in this message?
        byte[] message = "signed by SignApk".getBytes(StandardCharsets.UTF_8);
        temp.write(message);
        temp.write(0);

        cmsOut.writeSignatureBlock(temp);

        byte[] zipData = cmsOut.getSigner().getTail();

        // For a zip with no archive comment, the
        // end-of-central-directory record will be 22 bytes long, so
        // we expect to find the EOCD marker 22 bytes from the end.
        if (zipData[zipData.length-22] != 0x50 ||
            zipData[zipData.length-21] != 0x4b ||
            zipData[zipData.length-20] != 0x05 ||
            zipData[zipData.length-19] != 0x06) {
            throw new IllegalArgumentException("zip data already has an archive comment");
        }

        int total_size = temp.size() + 6;
        if (total_size > 0xffff) {
            throw new IllegalArgumentException("signature is too big for ZIP file comment");
        }
        // signature starts this many bytes from the end of the file
        int signature_start = total_size - message.length - 1;
        temp.write(signature_start & 0xff);
        temp.write((signature_start >> 8) & 0xff);
        // Why the 0xff bytes?  In a zip file with no archive comment,
        // bytes [-6:-2] of the file are the little-endian offset from
        // the start of the file to the central directory.  So for the
        // two high bytes to be 0xff 0xff, the archive would have to
        // be nearly 4GB in size.  So it's unlikely that a real
        // commentless archive would have 0xffs here, and lets us tell
        // an old signed archive from a new one.
        temp.write(0xff);
        temp.write(0xff);
        temp.write(total_size & 0xff);
        temp.write((total_size >> 8) & 0xff);
        temp.flush();

        // Signature verification checks that the EOCD header is the
        // last such sequence in the file (to avoid minzip finding a
        // fake EOCD appended after the signature in its scan).  The
        // odds of producing this sequence by chance are very low, but
        // let's catch it here if it does.
        byte[] b = temp.toByteArray();
        for (int i = 0; i < b.length-3; ++i) {
            if (b[i] == 0x50 && b[i+1] == 0x4b && b[i+2] == 0x05 && b[i+3] == 0x06) {
                throw new IllegalArgumentException("found spurious EOCD header at " + i);
            }
        }

        outputStream.write(total_size & 0xff);
        outputStream.write((total_size >> 8) & 0xff);
        temp.writeTo(outputStream);
    }

    /**
     * Tries to load a JSE Provider by class name. This is for custom PrivateKey
     * types that might be stored in PKCS#11-like storage.
     */
    private static void loadProviderIfNecessary(String providerClassName, String providerArg) {
        if (providerClassName == null) {
            return;
        }

        final Class<?> klass;
        try {
            final ClassLoader sysLoader = ClassLoader.getSystemClassLoader();
            if (sysLoader != null) {
                klass = sysLoader.loadClass(providerClassName);
            } else {
                klass = Class.forName(providerClassName);
            }
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            System.exit(1);
            return;
        }

        Constructor<?> constructor;
        Object o = null;
        if (providerArg == null) {
            try {
                constructor = klass.getConstructor();
                o = constructor.newInstance();
            } catch (ReflectiveOperationException e) {
                e.printStackTrace();
                System.err.println("Unable to instantiate " + providerClassName
                        + " with a zero-arg constructor");
                System.exit(1);
            }
        } else {
            try {
                constructor = klass.getConstructor(String.class);
                o = constructor.newInstance(providerArg);
            } catch (ReflectiveOperationException e) {
                // This is expected from JDK 9+; the single-arg constructor accepting the
                // configuration has been replaced with a configure(String) method to be invoked
                // after instantiating the Provider with the zero-arg constructor.
                try {
                    constructor = klass.getConstructor();
                    o = constructor.newInstance();
                    // The configure method will return either the modified Provider or a new
                    // Provider if this one cannot be configured in-place.
                    o = klass.getMethod("configure", String.class).invoke(o, providerArg);
                } catch (ReflectiveOperationException roe) {
                    roe.printStackTrace();
                    System.err.println("Unable to instantiate " + providerClassName
                            + " with the provided argument " + providerArg);
                    System.exit(1);
                }
            }
        }

        if (!(o instanceof Provider)) {
            System.err.println("Not a Provider class: " + providerClassName);
            System.exit(1);
        }

        Security.insertProviderAt((Provider) o, 1);
    }

    private static List<DefaultApkSignerEngine.SignerConfig> createSignerConfigs(
            PrivateKey[] privateKeys, X509Certificate[] certificates) {
        if (privateKeys.length != certificates.length) {
            throw new IllegalArgumentException(
                    "The number of private keys must match the number of certificates: "
                            + privateKeys.length + " vs" + certificates.length);
        }
        List<DefaultApkSignerEngine.SignerConfig> signerConfigs = new ArrayList<>();
        String signerNameFormat = (privateKeys.length == 1) ? "CERT" : "CERT%s";
        for (int i = 0; i < privateKeys.length; i++) {
            String signerName = String.format(Locale.US, signerNameFormat, (i + 1));
            DefaultApkSignerEngine.SignerConfig signerConfig =
                    new DefaultApkSignerEngine.SignerConfig.Builder(
                            signerName,
                            privateKeys[i],
                            Collections.singletonList(certificates[i]))
                            .build();
            signerConfigs.add(signerConfig);
        }
        return signerConfigs;
    }

    private static class ZipSections {
        DataSource beforeCentralDir;

        // The following fields are still valid after closing the backing DataSource.
        long beforeCentralDirSize;
        ByteBuffer centralDir;
        ByteBuffer eocd;
    }

    private static ZipSections findMainZipSections(DataSource apk)
            throws IOException, ZipFormatException {
        ApkUtils.ZipSections sections = ApkUtils.findZipSections(apk);
        long centralDirStartOffset = sections.getZipCentralDirectoryOffset();
        long centralDirSizeBytes = sections.getZipCentralDirectorySizeBytes();
        long centralDirEndOffset = centralDirStartOffset + centralDirSizeBytes;
        long eocdStartOffset = sections.getZipEndOfCentralDirectoryOffset();
        if (centralDirEndOffset != eocdStartOffset) {
            throw new ZipFormatException(
                    "ZIP Central Directory is not immediately followed by End of Central Directory"
                            + ". CD end: " + centralDirEndOffset
                            + ", EoCD start: " + eocdStartOffset);
        }

        ZipSections result = new ZipSections();

        result.beforeCentralDir = apk.slice(0, centralDirStartOffset);
        result.beforeCentralDirSize = result.beforeCentralDir.size();

        long centralDirSize = centralDirEndOffset - centralDirStartOffset;
        if (centralDirSize >= Integer.MAX_VALUE) throw new IndexOutOfBoundsException();
        result.centralDir = apk.getByteBuffer(centralDirStartOffset, (int)centralDirSize);

        long eocdSize = apk.size() - eocdStartOffset;
        if (eocdSize >= Integer.MAX_VALUE) throw new IndexOutOfBoundsException();
        result.eocd = apk.getByteBuffer(eocdStartOffset, (int)eocdSize);

        return result;
    }

    /**
     * Returns the API Level corresponding to the APK's minSdkVersion.
     *
     * @throws MinSdkVersionException if the API Level cannot be determined from the APK.
     */
    private static final int getMinSdkVersion(JarFile apk) throws MinSdkVersionException {
        JarEntry manifestEntry = apk.getJarEntry("AndroidManifest.xml");
        if (manifestEntry == null) {
            throw new MinSdkVersionException("No AndroidManifest.xml in APK");
        }
        byte[] manifestBytes;
        try {
            try (InputStream manifestIn = apk.getInputStream(manifestEntry)) {
                manifestBytes = toByteArray(manifestIn);
            }
        } catch (IOException e) {
            throw new MinSdkVersionException("Failed to read AndroidManifest.xml", e);
        }
        return ApkUtils.getMinSdkVersionFromBinaryAndroidManifest(ByteBuffer.wrap(manifestBytes));
    }

    private static byte[] toByteArray(InputStream in) throws IOException {
        ByteArrayOutputStream result = new ByteArrayOutputStream();
        byte[] buf = new byte[65536];
        int chunkSize;
        while ((chunkSize = in.read(buf)) != -1) {
            result.write(buf, 0, chunkSize);
        }
        return result.toByteArray();
    }

    private static void usage() {
        System.err.println("Usage: signapk [-w] " +
                           "[-a <alignment>] " +
                           "[--align-file-size] " +
                           "[-providerClass <className>] " +
                           "[-providerArg <configureArg>] " +
                           "[-loadPrivateKeysFromKeyStore <keyStoreName>]" +
                           "[-keyStorePin <pin>]" +
                           "[--min-sdk-version <n>] " +
                           "[--disable-v2] " +
                           "[--enable-v4] " +
                           "publickey.x509[.pem] privatekey.pk8 " +
                           "[publickey2.x509[.pem] privatekey2.pk8 ...] " +
                           "input.jar output.jar [output-v4-file]");
        System.exit(2);
    }

    public static void main(String[] args) {
        if (args.length < 4) usage();

        // Install Conscrypt as the highest-priority provider. Its crypto primitives are faster than
        // the standard or Bouncy Castle ones.
        Security.insertProviderAt(new OpenSSLProvider(), 1);
        // Install Bouncy Castle (as the lowest-priority provider) because Conscrypt does not offer
        // DSA which may still be needed.
        // TODO: Stop installing Bouncy Castle provider once DSA is no longer needed.
        Security.addProvider(new BouncyCastleProvider());

        boolean signWholeFile = false;
        String providerClass = null;
        String providerArg = null;
        String keyStoreName = null;
        String keyStorePin = null;
        int alignment = 4;
        boolean alignFileSize = false;
        Integer minSdkVersionOverride = null;
        boolean signUsingApkSignatureSchemeV2 = true;
        boolean signUsingApkSignatureSchemeV4 = false;
        SigningCertificateLineage certLineage = null;
        Integer rotationMinSdkVersion = null;

        int argstart = 0;
        while (argstart < args.length && args[argstart].startsWith("-")) {
            if ("-w".equals(args[argstart])) {
                signWholeFile = true;
                ++argstart;
            } else if ("-providerClass".equals(args[argstart])) {
                if (argstart + 1 >= args.length) {
                    usage();
                }
                providerClass = args[++argstart];
                ++argstart;
            } else if("-providerArg".equals(args[argstart])) {
                if (argstart + 1 >= args.length) {
                    usage();
                }
                providerArg = args[++argstart];
                ++argstart;
            } else if ("-loadPrivateKeysFromKeyStore".equals(args[argstart])) {
                if (argstart + 1 >= args.length) {
                    usage();
                }
                keyStoreName = args[++argstart];
                ++argstart;
            } else if ("-keyStorePin".equals(args[argstart])) {
                if (argstart + 1 >= args.length) {
                    usage();
                }
                keyStorePin = args[++argstart];
                ++argstart;
            } else if ("-a".equals(args[argstart])) {
                alignment = Integer.parseInt(args[++argstart]);
                ++argstart;
            } else if ("--align-file-size".equals(args[argstart])) {
                alignFileSize = true;
                ++argstart;
            } else if ("--min-sdk-version".equals(args[argstart])) {
                String minSdkVersionString = args[++argstart];
                try {
                    minSdkVersionOverride = Integer.parseInt(minSdkVersionString);
                } catch (NumberFormatException e) {
                    throw new IllegalArgumentException(
                            "--min-sdk-version must be a decimal number: " + minSdkVersionString);
                }
                ++argstart;
            } else if ("--disable-v2".equals(args[argstart])) {
                signUsingApkSignatureSchemeV2 = false;
                ++argstart;
            } else if ("--enable-v4".equals(args[argstart])) {
                signUsingApkSignatureSchemeV4 = true;
                ++argstart;
            } else if ("--lineage".equals(args[argstart])) {
                File lineageFile = new File(args[++argstart]);
                try {
                    certLineage = SigningCertificateLineage.readFromFile(lineageFile);
                } catch (Exception e) {
                    throw new IllegalArgumentException(
                            "Error reading lineage file: " + e.getMessage());
                }
                ++argstart;
            } else if ("--rotation-min-sdk-version".equals(args[argstart])) {
                String rotationMinSdkVersionString = args[++argstart];
                try {
                    rotationMinSdkVersion = Integer.parseInt(rotationMinSdkVersionString);
                } catch (NumberFormatException e) {
                    throw new IllegalArgumentException(
                            "--rotation-min-sdk-version must be a decimal number: " + rotationMinSdkVersionString);
                }
                ++argstart;
            } else {
                usage();
            }
        }

        int numArgsExcludeV4FilePath;
        if (signUsingApkSignatureSchemeV4) {
            numArgsExcludeV4FilePath = args.length - 1;
        } else {
            numArgsExcludeV4FilePath = args.length;
        }
        if ((numArgsExcludeV4FilePath - argstart) % 2 == 1) usage();
        int numKeys = ((numArgsExcludeV4FilePath - argstart) / 2) - 1;
        if (signWholeFile && numKeys > 1) {
            System.err.println("Only one key may be used with -w.");
            System.exit(2);
        }

        loadProviderIfNecessary(providerClass, providerArg);

        String inputFilename = args[numArgsExcludeV4FilePath - 2];
        String outputFilename = args[numArgsExcludeV4FilePath - 1];
        String outputV4Filename = "";
        if (signUsingApkSignatureSchemeV4) {
            outputV4Filename = args[args.length - 1];
        }

        JarFile inputJar = null;
        FileOutputStream outputFile = null;

        try {
            File firstPublicKeyFile = new File(args[argstart+0]);

            X509Certificate[] publicKey = new X509Certificate[numKeys];
            try {
                for (int i = 0; i < numKeys; ++i) {
                    int argNum = argstart + i*2;
                    publicKey[i] = readPublicKey(new File(args[argNum]));
                }
            } catch (IllegalArgumentException e) {
                System.err.println(e);
                System.exit(1);
            }

            // Set all ZIP file timestamps to Jan 1 2009 00:00:00.
            long timestamp = 1230768000000L;
            // The Java ZipEntry API we're using converts milliseconds since epoch into MS-DOS
            // timestamp using the current timezone. We thus adjust the milliseconds since epoch
            // value to end up with MS-DOS timestamp of Jan 1 2009 00:00:00.
            timestamp -= TimeZone.getDefault().getOffset(timestamp);
            KeyStore keyStore = null;
            if (keyStoreName != null) {
                keyStore = createKeyStore(keyStoreName, keyStorePin);
            }
            PrivateKey[] privateKey = new PrivateKey[numKeys];
            for (int i = 0; i < numKeys; ++i) {
                int argNum = argstart + i*2 + 1;
                if (keyStore == null) {
                    privateKey[i] = readPrivateKey(new File(args[argNum]));
                } else {
                    final String keyAlias = args[argNum];
                    privateKey[i] = loadPrivateKeyFromKeyStore(keyStore, keyAlias);
                }
            }
            inputJar = new JarFile(new File(inputFilename), false);  // Don't verify.

            outputFile = new FileOutputStream(outputFilename);

            // NOTE: Signing currently recompresses any compressed entries using Deflate (default
            // compression level for OTA update files and maximum compession level for APKs).
            if (signWholeFile) {
                int digestAlgorithm = getDigestAlgorithmForOta(publicKey[0]);
                signWholeFile(inputJar, firstPublicKeyFile,
                        publicKey[0], privateKey[0], digestAlgorithm,
                        timestamp,
                        outputFile);
            } else {
                // Determine the value to use as minSdkVersion of the APK being signed
                int minSdkVersion;
                if (minSdkVersionOverride != null) {
                    minSdkVersion = minSdkVersionOverride;
                } else {
                    try {
                        minSdkVersion = getMinSdkVersion(inputJar);
                    } catch (MinSdkVersionException e) {
                        throw new IllegalArgumentException(
                                "Cannot detect minSdkVersion. Use --min-sdk-version to override",
                                e);
                    }
                }

                DefaultApkSignerEngine.Builder builder = new DefaultApkSignerEngine.Builder(
                    createSignerConfigs(privateKey, publicKey), minSdkVersion)
                    .setV1SigningEnabled(true)
                    .setV2SigningEnabled(signUsingApkSignatureSchemeV2)
                    .setOtherSignersSignaturesPreserved(false)
                    .setCreatedBy("1.0 (Android SignApk)");

                if (certLineage != null) {
                   builder = builder.setSigningCertificateLineage(certLineage);
                }

                if (rotationMinSdkVersion != null) {
                   builder = builder.setMinSdkVersionForRotation(rotationMinSdkVersion);
                }

                try (ApkSignerEngine apkSigner = builder.build()) {
                    // We don't preserve the input APK's APK Signing Block (which contains v2
                    // signatures)
                    apkSigner.inputApkSigningBlock(null);

                    CountingOutputStream outputJarCounter =
                            new CountingOutputStream(outputFile);
                    JarOutputStream outputJar = new JarOutputStream(outputJarCounter);
                    // Use maximum compression for compressed entries because the APK lives forever
                    // on the system partition.
                    outputJar.setLevel(9);
                    copyFiles(inputJar, null, apkSigner, outputJar,
                              outputJarCounter, timestamp, alignment);
                    ApkSignerEngine.OutputJarSignatureRequest addV1SignatureRequest =
                            apkSigner.outputJarEntries();
                    if (addV1SignatureRequest != null) {
                        addV1Signature(apkSigner, addV1SignatureRequest, outputJar, timestamp);
                        addV1SignatureRequest.done();
                    }

                    // close output and switch to input mode
                    outputJar.close();
                    outputJar = null;
                    outputJarCounter = null;
                    outputFile = null;
                    RandomAccessFile v1SignedApk = new RandomAccessFile(outputFilename, "r");

                    ZipSections zipSections = findMainZipSections(DataSources.asDataSource(
                            v1SignedApk));

                    ByteBuffer eocd = ByteBuffer.allocate(zipSections.eocd.remaining());
                    eocd.put(zipSections.eocd);
                    eocd.flip();
                    eocd.order(ByteOrder.LITTLE_ENDIAN);

                    ByteBuffer[] outputChunks = new ByteBuffer[] {};

                    // This loop is supposed to be iterated twice at most.
                    // The second pass is to align the file size after amending EOCD comments
                    // with assumption that re-generated signing block would be the same size.
                    while (true) {
                        ApkSignerEngine.OutputApkSigningBlockRequest2 addV2SignatureRequest =
                                apkSigner.outputZipSections2(
                                        zipSections.beforeCentralDir,
                                        DataSources.asDataSource(zipSections.centralDir),
                                        DataSources.asDataSource(eocd));
                        if (addV2SignatureRequest == null) break;

                        // Need to insert the returned APK Signing Block before ZIP Central
                        // Directory.
                        int padding = addV2SignatureRequest.getPaddingSizeBeforeApkSigningBlock();
                        byte[] apkSigningBlock = addV2SignatureRequest.getApkSigningBlock();
                        // Because the APK Signing Block is inserted before the Central Directory,
                        // we need to adjust accordingly the offset of Central Directory inside the
                        // ZIP End of Central Directory (EoCD) record.
                        ByteBuffer modifiedEocd = ByteBuffer.allocate(eocd.remaining());
                        modifiedEocd.put(eocd);
                        modifiedEocd.flip();
                        modifiedEocd.order(ByteOrder.LITTLE_ENDIAN);
                        ApkUtils.setZipEocdCentralDirectoryOffset(
                                modifiedEocd,
                                zipSections.beforeCentralDir.size() + padding +
                                apkSigningBlock.length);
                        outputChunks =
                                new ByteBuffer[] {
                                        ByteBuffer.allocate(padding),
                                        ByteBuffer.wrap(apkSigningBlock),
                                        zipSections.centralDir,
                                        modifiedEocd};
                        addV2SignatureRequest.done();

                        // Exit the loop if we don't need to align the file size
                        if (!alignFileSize || alignment < 2) {
                            break;
                        }

                        // Calculate the file size
                        eocd = modifiedEocd;
                        long fileSize = zipSections.beforeCentralDirSize;
                        for (ByteBuffer buf : outputChunks) {
                            fileSize += buf.remaining();
                        }
                        // Exit the loop because the file size is aligned.
                        if (fileSize % alignment == 0) {
                            break;
                        }
                        // Pad EOCD comment to align the file size.
                        int commentLen = alignment - (int)(fileSize % alignment);
                        modifiedEocd = ByteBuffer.allocate(eocd.remaining() + commentLen);
                        modifiedEocd.put(eocd);
                        modifiedEocd.rewind();
                        modifiedEocd.order(ByteOrder.LITTLE_ENDIAN);
                        ApkUtils.updateZipEocdCommentLen(modifiedEocd);
                        // Since V2 signing block should cover modified EOCD,
                        // re-iterate the loop with modified EOCD.
                        eocd = modifiedEocd;
                    }

                    // close input and switch back to output mode
                    v1SignedApk.close();
                    v1SignedApk = null;
                    outputFile = new FileOutputStream(outputFilename, true);
                    outputFile.getChannel().truncate(zipSections.beforeCentralDirSize);

                    // This assumes outputChunks are array-backed. To avoid this assumption, the
                    // code could be rewritten to use FileChannel.
                    for (ByteBuffer outputChunk : outputChunks) {
                        outputFile.write(
                                outputChunk.array(),
                                outputChunk.arrayOffset() + outputChunk.position(),
                                outputChunk.remaining());
                        outputChunk.position(outputChunk.limit());
                    }

                    outputFile.close();
                    outputFile = null;
                    apkSigner.outputDone();

                    if (signUsingApkSignatureSchemeV4) {
                        final DataSource outputApkIn = DataSources.asDataSource(
                                new RandomAccessFile(new File(outputFilename), "r"));
                        final File outputV4File =  new File(outputV4Filename);
                        apkSigner.signV4(outputApkIn, outputV4File, false /* ignore failures */);
                    }
                }

                return;
            }
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        } finally {
            try {
                if (inputJar != null) inputJar.close();
                if (outputFile != null) outputFile.close();
            } catch (IOException e) {
                e.printStackTrace();
                System.exit(1);
            }
        }
    }
}
