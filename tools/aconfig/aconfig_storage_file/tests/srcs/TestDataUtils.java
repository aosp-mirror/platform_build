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

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;

public final class TestDataUtils {
    private static final String TEST_PACKAGE_MAP_PATH = "package.map";
    private static final String TEST_FLAG_MAP_PATH = "flag.map";
    private static final String TEST_FLAG_VAL_PATH = "flag.val";
    private static final String TEST_FLAG_INFO_PATH = "flag.info";

    private static final String TESTDATA_PATH =
            "/data/local/tmp/aconfig_storage_file_test_java/testdata/";

    public static ByteBuffer getTestPackageMapByteBuffer() throws Exception {
        return readFile(TESTDATA_PATH + TEST_PACKAGE_MAP_PATH);
    }

    public static ByteBuffer getTestFlagMapByteBuffer() throws Exception {
        return readFile(TESTDATA_PATH + TEST_FLAG_MAP_PATH);
    }

    public static ByteBuffer getTestFlagValByteBuffer() throws Exception {
        return readFile(TESTDATA_PATH + TEST_FLAG_VAL_PATH);
    }

    public static ByteBuffer getTestFlagInfoByteBuffer() throws Exception {
        return readFile(TESTDATA_PATH + TEST_FLAG_INFO_PATH);
    }

    private static ByteBuffer readFile(String fileName) throws Exception {
        InputStream input = new FileInputStream(fileName);
        return ByteBuffer.wrap(input.readAllBytes());
    }
}
