/*
 * Copyright (C) 2024 The Android Open Source Project
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

package android.aconfig.storage.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.aconfig.storage.AconfigStorageException;
import android.aconfig.storage.PackageTable;
import android.aconfig.storage.StorageFileProvider;
import android.os.flagging.PlatformAconfigPackageInternal;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class PlatformAconfigPackageInternalTest {

    public static final String TESTDATA_PATH =
            "/data/local/tmp/aconfig_storage_read_unit/testdata/";

    private StorageFileProvider pr;

    @Before
    public void setup() {
        pr = new StorageFileProvider(TESTDATA_PATH, TESTDATA_PATH);
    }

    @Test
    public void testLoad_container_package() throws Exception {
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", pr);
        assertNull(p.getException());
    }

    @Test
    public void testLoad_container_package_error() throws Exception {
        // cannot find package
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_10", pr);

        assertEquals(
                AconfigStorageException.ERROR_PACKAGE_NOT_FOUND,
                ((AconfigStorageException) p.getException()).getErrorCode());

        // cannot find container
        p = PlatformAconfigPackageInternal.load(null, "com.android.aconfig.storage.test_1", pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());
        p = PlatformAconfigPackageInternal.load("test", "com.android.aconfig.storage.test_1", pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());

        // new storage doesn't exist
        pr = new StorageFileProvider("fake/path/", "fake/path/");
        p = PlatformAconfigPackageInternal.load("mockup", "com.android.aconfig.storage.test_1", pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());

        // file read issue
        pr = new StorageFileProvider(TESTDATA_PATH, "fake/path/");
        p = PlatformAconfigPackageInternal.load("mockup", "com.android.aconfig.storage.test_1", pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());
    }

    @Test
    public void testLoad_container_package_fingerprint() throws Exception {
        PackageTable packageTable = pr.getPackageTable("mockup");

        PackageTable.Node node1 = packageTable.get("com.android.aconfig.storage.test_1");

        long fingerprint = node1.getPackageFingerprint();
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertNull(p.getException());
    }

    @Test
    public void testLoad_container_package_fingerprint_error() throws Exception {

        PackageTable packageTable = pr.getPackageTable("mockup");

        PackageTable.Node node1 = packageTable.get("com.android.aconfig.storage.test_1");

        long fingerprint = node1.getPackageFingerprint();

        // cannot find package
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_10", fingerprint, pr);

        assertEquals(
                AconfigStorageException.ERROR_PACKAGE_NOT_FOUND,
                ((AconfigStorageException) p.getException()).getErrorCode());

        // cannot find container
        p =
                PlatformAconfigPackageInternal.load(
                        null, "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());
        p =
                PlatformAconfigPackageInternal.load(
                        "test", "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());
        // fingerprint doesn't match
        p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", fingerprint + 1, pr);
        assertEquals(
                // AconfigStorageException.ERROR_FILE_FINGERPRINT_MISMATCH,
                5, ((AconfigStorageException) p.getException()).getErrorCode());

        // new storage doesn't exist
        pr = new StorageFileProvider("fake/path/", "fake/path/");
        p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());

        // file read issue
        pr = new StorageFileProvider(TESTDATA_PATH, "fake/path/");
        p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                ((AconfigStorageException) p.getException()).getErrorCode());
    }

    @Test
    public void testGetBooleanFlagValue_flagName() throws Exception {
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", pr);
        assertFalse(p.getBooleanFlagValue("disabled_rw", true));
        assertTrue(p.getBooleanFlagValue("enabled_ro", false));
        assertTrue(p.getBooleanFlagValue("enabled_rw", false));
        assertFalse(p.getBooleanFlagValue("fake", false));
    }

    @Test
    public void testGetBooleanFlagValue_index() throws Exception {

        PackageTable packageTable = pr.getPackageTable("mockup");

        PackageTable.Node node1 = packageTable.get("com.android.aconfig.storage.test_1");

        long fingerprint = node1.getPackageFingerprint();
        PlatformAconfigPackageInternal p =
                PlatformAconfigPackageInternal.load(
                        "mockup", "com.android.aconfig.storage.test_1", fingerprint, pr);
        assertFalse(p.getBooleanFlagValue(0));
        assertTrue(p.getBooleanFlagValue(1));
        assertTrue(p.getBooleanFlagValue(2));
    }
}
