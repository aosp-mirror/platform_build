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

import static android.aconfig.nano.Aconfig.ENABLED;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import android.aconfig.DeviceProtos;
import android.aconfig.nano.Aconfig.parsed_flag;
import android.aconfig.storage.AconfigStorageException;
import android.aconfig.storage.FlagTable;
import android.aconfig.storage.FlagValueList;
import android.aconfig.storage.PackageTable;
import android.aconfig.storage.StorageFileProvider;
import android.os.flagging.PlatformAconfigPackageInternal;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@RunWith(JUnit4.class)
public class PlatformAconfigPackageInternalTest {

    private static final Set<String> PLATFORM_CONTAINERS = Set.of("system", "vendor", "product");

    @Test
    public void testAconfigPackageInternal_load() throws IOException {
        List<parsed_flag> flags = DeviceProtos.loadAndParseFlagProtos();
        Map<String, PlatformAconfigPackageInternal> readerMap = new HashMap<>();
        StorageFileProvider fp = StorageFileProvider.getDefaultProvider();

        for (parsed_flag flag : flags) {

            String container = flag.container;
            String packageName = flag.package_;
            String flagName = flag.name;
            if (!PLATFORM_CONTAINERS.contains(container)) continue;

            PackageTable pTable = fp.getPackageTable(container);
            PackageTable.Node pNode = pTable.get(packageName);
            FlagTable fTable = fp.getFlagTable(container);
            FlagTable.Node fNode = fTable.get(pNode.getPackageId(), flagName);
            FlagValueList fList = fp.getFlagValueList(container);

            int index = pNode.getBooleanStartIndex() + fNode.getFlagIndex();
            boolean rVal = fList.getBoolean(index);

            PlatformAconfigPackageInternal reader = readerMap.get(packageName);
            if (reader == null) {
                reader = PlatformAconfigPackageInternal.load(container, packageName);
                assertNull(reader.getException());
                readerMap.put(packageName, reader);
            }
            boolean jVal = reader.getBooleanFlagValue(flagName, !rVal);

            assertEquals(rVal, jVal);
        }
    }

    @Test
    public void testPlatformAconfigPackageInternal_load_with_fingerprint() throws IOException {
        List<parsed_flag> flags = DeviceProtos.loadAndParseFlagProtos();
        Map<String, PlatformAconfigPackageInternal> readerMap = new HashMap<>();
        StorageFileProvider fp = StorageFileProvider.getDefaultProvider();

        for (parsed_flag flag : flags) {

            String container = flag.container;
            String packageName = flag.package_;
            String flagName = flag.name;
            if (!PLATFORM_CONTAINERS.contains(container)) continue;

            PackageTable pTable = fp.getPackageTable(container);
            PackageTable.Node pNode = pTable.get(packageName);
            FlagTable fTable = fp.getFlagTable(container);
            FlagTable.Node fNode = fTable.get(pNode.getPackageId(), flagName);
            FlagValueList fList = fp.getFlagValueList(container);

            int index = pNode.getBooleanStartIndex() + fNode.getFlagIndex();
            boolean rVal = fList.getBoolean(index);

            long fingerprint = pNode.getPackageFingerprint();

            PlatformAconfigPackageInternal reader = readerMap.get(packageName);
            if (reader == null) {
                reader = PlatformAconfigPackageInternal.load(container, packageName, fingerprint);
                assertNull(reader.getException());
                readerMap.put(packageName, reader);
            }
            boolean jVal = reader.getBooleanFlagValue(fNode.getFlagIndex());

            assertEquals(rVal, jVal);
        }
    }

    @Test
    public void testAconfigPackage_load_withError() throws IOException {
        // container not found fake_container
        PlatformAconfigPackageInternal aPackage =
                PlatformAconfigPackageInternal.load("fake_container", "fake_package", 0);
        assertEquals(
                AconfigStorageException.ERROR_CANNOT_READ_STORAGE_FILE,
                aPackage.getException().getErrorCode());

        // package not found
        aPackage = PlatformAconfigPackageInternal.load("system", "fake_container", 0);
        assertEquals(
                AconfigStorageException.ERROR_PACKAGE_NOT_FOUND,
                aPackage.getException().getErrorCode());

        // fingerprint doesn't match
        List<parsed_flag> flags = DeviceProtos.loadAndParseFlagProtos();
        StorageFileProvider fp = StorageFileProvider.getDefaultProvider();

        parsed_flag flag = flags.get(0);

        String container = flag.container;
        String packageName = flag.package_;
        boolean value = flag.state == ENABLED;

        PackageTable pTable = fp.getPackageTable(container);
        PackageTable.Node pNode = pTable.get(packageName);

        if (pNode.hasPackageFingerprint()) {
            long fingerprint = pNode.getPackageFingerprint();
            aPackage = PlatformAconfigPackageInternal.load(container, packageName, fingerprint + 1);
            assertEquals(
                    // AconfigStorageException.ERROR_FILE_FINGERPRINT_MISMATCH,
                    5, aPackage.getException().getErrorCode());
            assertEquals(aPackage.getBooleanFlagValue(flag.name, !value), value);
        }
    }
}
