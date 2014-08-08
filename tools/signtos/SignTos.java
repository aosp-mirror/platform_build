/*
 * Copyright 2014 The Android Open Source Project
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

package com.android.signtos;

import org.bouncycastle.asn1.ASN1InputStream;
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo;
import org.bouncycastle.jce.provider.BouncyCastleProvider;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.lang.reflect.Constructor;
import java.security.GeneralSecurityException;
import java.security.Key;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.Provider;
import java.security.PublicKey;
import java.security.Security;
import java.security.Signature;
import java.security.interfaces.ECKey;
import java.security.interfaces.ECPublicKey;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Arrays;

import javax.crypto.Cipher;
import javax.crypto.EncryptedPrivateKeyInfo;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

/**
 * Signs Trusty images for use with operating systems that support it.
 */
public class SignTos {
    /** Size of the signature footer in bytes. */
    private static final int SIGNATURE_BLOCK_SIZE = 256;

    /** Current signature version code we use. */
    private static final int VERSION_CODE = 1;

    /** Size of the header on the file to skip. */
    private static final int HEADER_SIZE = 512;

    private static BouncyCastleProvider sBouncyCastleProvider;

    /**
     * Reads the password from stdin and returns it as a string.
     *
     * @param keyFile The file containing the private key.  Used to prompt the user.
     */
    private static String readPassword(File keyFile) {
        // TODO: use Console.readPassword() when it's available.
        System.out.print("Enter password for " + keyFile + " (password will not be hidden): ");
        System.out.flush();
        BufferedReader stdin = new BufferedReader(new InputStreamReader(System.in));
        try {
            return stdin.readLine();
        } catch (IOException ex) {
            return null;
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

        char[] password = readPassword(keyFile).toCharArray();

        SecretKeyFactory skFactory = SecretKeyFactory.getInstance(epkInfo.getAlgName());
        Key key = skFactory.generateSecret(new PBEKeySpec(password));

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
    private static PrivateKey readPrivateKey(File file) throws IOException,
            GeneralSecurityException {
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
            ASN1InputStream bIn = new ASN1InputStream(new ByteArrayInputStream(spec.getEncoded()));
            PrivateKeyInfo pki = PrivateKeyInfo.getInstance(bIn.readObject());
            String algOid = pki.getPrivateKeyAlgorithm().getAlgorithm().getId();

            return KeyFactory.getInstance(algOid).generatePrivate(spec);
        } finally {
            input.close();
        }
    }

    /**
     * Tries to load a JSE Provider by class name. This is for custom PrivateKey
     * types that might be stored in PKCS#11-like storage.
     */
    private static void loadProviderIfNecessary(String providerClassName) {
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

        Constructor<?> constructor = null;
        for (Constructor<?> c : klass.getConstructors()) {
            if (c.getParameterTypes().length == 0) {
                constructor = c;
                break;
            }
        }
        if (constructor == null) {
            System.err.println("No zero-arg constructor found for " + providerClassName);
            System.exit(1);
            return;
        }

        final Object o;
        try {
            o = constructor.newInstance();
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
            return;
        }
        if (!(o instanceof Provider)) {
            System.err.println("Not a Provider class: " + providerClassName);
            System.exit(1);
        }

        Security.insertProviderAt((Provider) o, 1);
    }

    private static String getSignatureAlgorithm(Key key) {
        if ("EC".equals(key.getAlgorithm())) {
            ECKey ecKey = (ECKey) key;
            int curveSize = ecKey.getParams().getOrder().bitLength();
            if (curveSize <= 256) {
                return "SHA256withECDSA";
            } else if (curveSize <= 384) {
                return "SHA384withECDSA";
            } else {
                return "SHA512withECDSA";
            }
        } else {
            throw new IllegalArgumentException("Unsupported key type " + key.getAlgorithm());
        }
    }

    /**
     * @param inputFilename
     * @param outputFilename
     */
    private static void signWholeFile(InputStream input, OutputStream output, PrivateKey signingKey)
            throws Exception {
        Signature sig = Signature.getInstance(getSignatureAlgorithm(signingKey));
        sig.initSign(signingKey);

        byte[] buffer = new byte[8192];

        /* Skip the header. */
        int skippedBytes = 0;
        while (skippedBytes != HEADER_SIZE) {
            int bytesRead = input.read(buffer, 0, HEADER_SIZE - skippedBytes);
            output.write(buffer, 0, bytesRead);
            skippedBytes += bytesRead;
        }

        int totalBytes = 0;
        for (;;) {
            int bytesRead = input.read(buffer);
            if (bytesRead == -1) {
                break;
            }
            totalBytes += bytesRead;
            sig.update(buffer, 0, bytesRead);
            output.write(buffer, 0, bytesRead);
        }

        byte[] sigBlock = new byte[SIGNATURE_BLOCK_SIZE];
        sigBlock[0] = VERSION_CODE;
        sig.sign(sigBlock, 1, sigBlock.length - 1);

        output.write(sigBlock);
    }

    private static void usage() {
        System.err.println("Usage: signtos " +
                           "[-providerClass <className>] " +
                           " privatekey.pk8 " +
                           "input.img output.img");
        System.exit(2);
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            usage();
        }

        String providerClass = null;
        String providerArg = null;

        int argstart = 0;
        while (argstart < args.length && args[argstart].startsWith("-")) {
            if ("-providerClass".equals(args[argstart])) {
                if (argstart + 1 >= args.length) {
                    usage();
                }
                providerClass = args[++argstart];
                ++argstart;
            } else {
                usage();
            }
        }

        /*
         * Should only be "<privatekey> <input> <output>" left.
         */
        if (argstart != args.length - 3) {
            usage();
        }

        sBouncyCastleProvider = new BouncyCastleProvider();
        Security.addProvider(sBouncyCastleProvider);

        loadProviderIfNecessary(providerClass);

        String keyFilename = args[args.length - 3];
        String inputFilename = args[args.length - 2];
        String outputFilename = args[args.length - 1];

        PrivateKey privateKey = readPrivateKey(new File(keyFilename));

        InputStream input = new BufferedInputStream(new FileInputStream(inputFilename));
        OutputStream output = new BufferedOutputStream(new FileOutputStream(outputFilename));
        try {
            SignTos.signWholeFile(input, output, privateKey);
        } finally {
            input.close();
            output.close();
        }

        System.out.println("Successfully signed: " + outputFilename);
    }
}
