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
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import android.aconfig.DeviceProtosTestUtil;
import android.aconfig.nano.Aconfig;
import android.aconfig.nano.Aconfig.parsed_flag;
import android.aconfig.storage.FlagTable;
import android.aconfig.storage.FlagValueList;
import android.aconfig.storage.PackageTable;
import android.aconfig.storage.StorageFileProvider;
import android.os.flagging.PlatformAconfigPackage;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@RunWith(JUnit4.class)
public class PlatformAconfigPackageTest {

    private static final Set<String> PLATFORM_CONTAINERS =
            Set.of("system", "system_ext", "vendor", "product");

    @Test
    public void testPlatformAconfigPackage_StorageFilesCache() throws IOException {
        List<parsed_flag> flags = DeviceProtosTestUtil.loadAndParseFlagProtos();
        for (parsed_flag flag : flags) {
            if (flag.permission == Aconfig.READ_ONLY && flag.state == Aconfig.DISABLED) {
                continue;
            }
            String container = flag.container;
            String packageName = flag.package_;
            if (!PLATFORM_CONTAINERS.contains(container)) continue;
            assertNotNull(PlatformAconfigPackage.load(packageName));
        }
    }

    @Test
    public void testPlatformAconfigPackage_load() throws IOException {
        List<parsed_flag> flags = DeviceProtosTestUtil.loadAndParseFlagProtos();
        Map<String, PlatformAconfigPackage> readerMap = new HashMap<>();
        StorageFileProvider fp = StorageFileProvider.getDefaultProvider();

        for (parsed_flag flag : flags) {
            if (flag.permission == Aconfig.READ_ONLY && flag.state == Aconfig.DISABLED) {
                continue;
            }
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

            PlatformAconfigPackage reader = readerMap.get(packageName);
            if (reader == null) {
                reader = PlatformAconfigPackage.load(packageName);
                readerMap.put(packageName, reader);
            }
            boolean jVal = reader.getBooleanFlagValue(flagName, !rVal);

            assertEquals(rVal, jVal);
        }
    }

    @Test
    public void testPlatformAconfigPackage_load_withError() throws IOException {
        // package not found
        assertNull(PlatformAconfigPackage.load("fake_container"));
    }
}
