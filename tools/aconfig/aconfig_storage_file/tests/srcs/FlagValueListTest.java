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
import static org.junit.Assert.assertTrue;

import android.aconfig.storage.FileType;
import android.aconfig.storage.FlagTable;
import android.aconfig.storage.FlagValueList;
import android.aconfig.storage.PackageTable;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.util.Objects;
import java.util.concurrent.CyclicBarrier;

@RunWith(JUnit4.class)
public class FlagValueListTest {

    @Test
    public void testFlagValueList_rightHeader() throws Exception {
        FlagValueList flagValueList =
                FlagValueList.fromBytes(TestDataUtils.getTestFlagValByteBuffer(1));
        FlagValueList.Header header = flagValueList.getHeader();
        assertEquals(1, header.getVersion());
        assertEquals("mockup", header.getContainer());
        assertEquals(FileType.FLAG_VAL, header.getFileType());
        assertEquals(35, header.getFileSize());
        assertEquals(8, header.getNumFlags());
        assertEquals(27, header.getBooleanValueOffset());
    }

    @Test
    public void testFlagValueList_rightNode() throws Exception {
        FlagValueList flagValueList =
                FlagValueList.fromBytes(TestDataUtils.getTestFlagValByteBuffer(1));

        boolean[] expected = new boolean[] {false, true, true, false, true, true, true, true};
        assertEquals(expected.length, flagValueList.size());

        for (int i = 0; i < flagValueList.size(); i++) {
            assertEquals(expected[i], flagValueList.getBoolean(i));
        }
    }

    @Test
    public void testFlagValueList_getValue() throws Exception {
        PackageTable packageTable =
                PackageTable.fromBytes(TestDataUtils.getTestPackageMapByteBuffer(1));
        FlagTable flagTable = FlagTable.fromBytes(TestDataUtils.getTestFlagMapByteBuffer(1));

        FlagValueList flagValueList =
                FlagValueList.fromBytes(TestDataUtils.getTestFlagValByteBuffer(1));

        PackageTable.Node pNode = packageTable.get("com.android.aconfig.storage.test_1");
        FlagTable.Node fNode = flagTable.get(pNode.getPackageId(), "enabled_rw");
        assertTrue(flagValueList.getBoolean(pNode.getBooleanStartIndex() + fNode.getFlagIndex()));

        pNode = packageTable.get("com.android.aconfig.storage.test_4");
        fNode = flagTable.get(pNode.getPackageId(), "enabled_fixed_ro");
        assertTrue(flagValueList.getBoolean(pNode.getBooleanStartIndex() + fNode.getFlagIndex()));
    }

    @Test
    public void testFlagValueList_multithreadsRead() throws Exception {
        FlagValueList flagValueList =
                FlagValueList.fromBytes(TestDataUtils.getTestFlagValByteBuffer(2));

        int numberOfThreads = 8;
        Thread[] threads = new Thread[numberOfThreads];
        final CyclicBarrier gate = new CyclicBarrier(numberOfThreads + 1);
        boolean[] expects = {false, true, true, false, true, true, true, true};

        for (int i = 0; i < numberOfThreads; i++) {
            boolean expectRet = expects[i];
            int position = i;
            threads[i] =
                    new Thread() {
                        @Override
                        public void run() {
                            try {
                                gate.await();
                            } catch (Exception e) {
                            }
                            for (int j = 0; j < 10; j++) {
                                if (!Objects.equals(
                                        expectRet, flagValueList.getBoolean(position))) {
                                    throw new RuntimeException();
                                }
                            }
                        }
                    };
            threads[i].start();
        }

        gate.await();

        for (int i = 0; i < numberOfThreads; i++) {
            threads[i].join();
        }
    }
}
