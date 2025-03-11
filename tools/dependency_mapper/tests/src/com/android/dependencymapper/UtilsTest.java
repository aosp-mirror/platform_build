/*
 * Copyright (C) 2025 The Android Open Source Project
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
package com.android.dependencymapper;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

import com.android.dependencymapper.Utils;

public class UtilsTest {

    @Test
    public void testTrimAndConvertToPackageBasedPath() {
        String testPath1 = "com/android/storage/StorageManager.class";
        String testPath2 = "com/android/package/PackageManager$Package.class";

        String expectedPackageBasedPath1 = "com.android.storage.StorageManager";
        String expectedPackageBasedPath2 = "com.android.package.PackageManager$Package";

        assertEquals("Package Based Path not constructed correctly",
                expectedPackageBasedPath1, Utils.trimAndConvertToPackageBasedPath(testPath1));
        assertEquals("Package Based Path not constructed correctly",
                expectedPackageBasedPath2, Utils.trimAndConvertToPackageBasedPath(testPath2));
    }

    @Test
    public void testBuildPackagePrependedClassSource() {
        String qualifiedClassPath1 = "com.android.storage.StorageManager";
        String sourcePath1 = "StorageManager.java";
        String qualifiedClassPath2 = "com.android.package.PackageManager$Package";
        String sourcePath2 = "PackageManager.java";
        String qualifiedClassPath3 = "com.android.storage.StorageManager$Storage";
        String sourcePath3 = "StorageManager$Storage.java";


        String expectedPackagePrependedPath1 = "com.android.storage.StorageManager.java";
        String expectedPackagePrependedPath2 = "com.android.package.PackageManager.java";
        String expectedPackagePrependedPath3 = "com.android.storage.StorageManager$Storage.java";

        assertEquals("Package Prepended Class Source not constructed correctly",
                expectedPackagePrependedPath1,
                Utils.buildPackagePrependedClassSource(qualifiedClassPath1, sourcePath1));
        assertEquals("Package Prepended Class Source not constructed correctly",
                expectedPackagePrependedPath2,
                Utils.buildPackagePrependedClassSource(qualifiedClassPath2, sourcePath2));
        assertEquals("Package Prepended Class Source not constructed correctly",
                expectedPackagePrependedPath3,
                Utils.buildPackagePrependedClassSource(qualifiedClassPath3, sourcePath3));
    }
}
