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

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.aconfig.storage.StorageInternalReader;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class StorageInternalReaderTest {

    private String mStorageDir = "/data/local/tmp/aconfig_java_api_test";

    @Test
    public void testStorageInternalReader_getFlag() {

        String packageMapFile = mStorageDir + "/maps/mockup.package.map";
        String flagValueFile = mStorageDir + "/boot/mockup.val";

        StorageInternalReader reader =
                new StorageInternalReader(
                        "com.android.aconfig.storage.test_1", packageMapFile, flagValueFile);
        assertFalse(reader.getBooleanFlagValue(0));
        assertTrue(reader.getBooleanFlagValue(1));
    }
}
