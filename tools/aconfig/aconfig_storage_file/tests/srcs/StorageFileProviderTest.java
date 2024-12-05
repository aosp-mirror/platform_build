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
import static org.junit.Assert.assertTrue;

import android.aconfig.storage.FlagTable;
import android.aconfig.storage.FlagValueList;
import android.aconfig.storage.PackageTable;
import android.aconfig.storage.StorageFileProvider;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.nio.file.Paths;
import java.util.List;

@RunWith(JUnit4.class)
public class StorageFileProviderTest {

    @Test
    public void testlistContainers() throws Exception {
        StorageFileProvider p =
                new StorageFileProvider(TestDataUtils.TESTDATA_PATH, TestDataUtils.TESTDATA_PATH);
        String[] excludes = {};
        List<String> containers = p.listContainers(excludes);
        assertEquals(2, containers.size());

        excludes = new String[] {"mock.v1"};
        containers = p.listContainers(excludes);
        assertEquals(1, containers.size());

        p = new StorageFileProvider("fake/path/", "fake/path/");
        containers = p.listContainers(excludes);
        assertTrue(containers.isEmpty());
    }

    @Test
    public void testLoadFiles() throws Exception {
        StorageFileProvider p =
                new StorageFileProvider(TestDataUtils.TESTDATA_PATH, TestDataUtils.TESTDATA_PATH);
        PackageTable pt = p.getPackageTable("mock.v1");
        assertNotNull(pt);
        pt =
                StorageFileProvider.getPackageTable(
                        Paths.get(TestDataUtils.TESTDATA_PATH, "mock.v1.package.map"));
        assertNotNull(pt);
        FlagTable f = p.getFlagTable("mock.v1");
        assertNotNull(f);
        FlagValueList v = p.getFlagValueList("mock.v1");
        assertNotNull(v);
    }
}
