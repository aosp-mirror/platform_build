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

import android.aconfig.storage.FileType;
import android.aconfig.storage.FlagTable;
import android.aconfig.storage.FlagType;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class FlagTableTest {

    @Test
    public void testFlagTable_rightHeader() throws Exception {
        FlagTable flagTable = FlagTable.fromBytes(TestDataUtils.getTestFlagMapByteBuffer());
        FlagTable.Header header = flagTable.getHeader();
        assertEquals(1, header.getVersion());
        assertEquals("mockup", header.getContainer());
        assertEquals(FileType.FLAG_MAP, header.getFileType());
        assertEquals(321, header.getFileSize());
        assertEquals(8, header.getNumFlags());
        assertEquals(31, header.getBucketOffset());
        assertEquals(99, header.getNodeOffset());
    }

    @Test
    public void testFlagTable_rightNode() throws Exception {
        FlagTable flagTable = FlagTable.fromBytes(TestDataUtils.getTestFlagMapByteBuffer());

        FlagTable.Node node1 = flagTable.get(0, "enabled_ro");
        FlagTable.Node node2 = flagTable.get(0, "enabled_rw");
        FlagTable.Node node3 = flagTable.get(2, "enabled_rw");
        FlagTable.Node node4 = flagTable.get(1, "disabled_rw");
        FlagTable.Node node5 = flagTable.get(1, "enabled_fixed_ro");
        FlagTable.Node node6 = flagTable.get(1, "enabled_ro");
        FlagTable.Node node7 = flagTable.get(2, "enabled_fixed_ro");
        FlagTable.Node node8 = flagTable.get(0, "disabled_rw");

        assertEquals("enabled_ro", node1.getFlagName());
        assertEquals("enabled_rw", node2.getFlagName());
        assertEquals("enabled_rw", node3.getFlagName());
        assertEquals("disabled_rw", node4.getFlagName());
        assertEquals("enabled_fixed_ro", node5.getFlagName());
        assertEquals("enabled_ro", node6.getFlagName());
        assertEquals("enabled_fixed_ro", node7.getFlagName());
        assertEquals("disabled_rw", node8.getFlagName());

        assertEquals(0, node1.getPackageId());
        assertEquals(0, node2.getPackageId());
        assertEquals(2, node3.getPackageId());
        assertEquals(1, node4.getPackageId());
        assertEquals(1, node5.getPackageId());
        assertEquals(1, node6.getPackageId());
        assertEquals(2, node7.getPackageId());
        assertEquals(0, node8.getPackageId());

        assertEquals(FlagType.ReadOnlyBoolean, node1.getFlagType());
        assertEquals(FlagType.ReadWriteBoolean, node2.getFlagType());
        assertEquals(FlagType.ReadWriteBoolean, node3.getFlagType());
        assertEquals(FlagType.ReadWriteBoolean, node4.getFlagType());
        assertEquals(FlagType.FixedReadOnlyBoolean, node5.getFlagType());
        assertEquals(FlagType.ReadOnlyBoolean, node6.getFlagType());
        assertEquals(FlagType.FixedReadOnlyBoolean, node7.getFlagType());
        assertEquals(FlagType.ReadWriteBoolean, node8.getFlagType());

        assertEquals(1, node1.getFlagIndex());
        assertEquals(2, node2.getFlagIndex());
        assertEquals(1, node3.getFlagIndex());
        assertEquals(0, node4.getFlagIndex());
        assertEquals(1, node5.getFlagIndex());
        assertEquals(2, node6.getFlagIndex());
        assertEquals(0, node7.getFlagIndex());
        assertEquals(0, node8.getFlagIndex());

        assertEquals(-1, node1.getNextOffset());
        assertEquals(151, node2.getNextOffset());
        assertEquals(-1, node3.getNextOffset());
        assertEquals(-1, node4.getNextOffset());
        assertEquals(236, node5.getNextOffset());
        assertEquals(-1, node6.getNextOffset());
        assertEquals(-1, node7.getNextOffset());
        assertEquals(-1, node8.getNextOffset());
    }
}
