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

package android.aconfig.storage;

import android.compat.annotation.UnsupportedAppUsage;

import java.io.FileInputStream;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;

/** @hide */
public class StorageInternalReader {

    private static final String MAP_PATH = "/metadata/aconfig/maps/";
    private static final String BOOT_PATH = "/metadata/aconfig/boot/";

    private PackageTable mPackageTable;
    private FlagValueList mFlagValueList;

    private int mPackageBooleanStartOffset;

    @UnsupportedAppUsage
    public StorageInternalReader(String container, String packageName) {
        this(packageName, MAP_PATH + container + ".package.map", BOOT_PATH + container + ".val");
    }

    @UnsupportedAppUsage
    public StorageInternalReader(String packageName, String packageMapFile, String flagValueFile) {
        mPackageTable = PackageTable.fromBytes(mapStorageFile(packageMapFile));
        mFlagValueList = FlagValueList.fromBytes(mapStorageFile(flagValueFile));
        mPackageBooleanStartOffset = getPackageBooleanStartOffset(packageName);
    }

    @UnsupportedAppUsage
    public boolean getBooleanFlagValue(int index) {
        index += mPackageBooleanStartOffset;
        if (index >= mFlagValueList.size()) {
            throw new AconfigStorageException("Fail to get boolean flag value");
        }
        return mFlagValueList.get(index);
    }

    private int getPackageBooleanStartOffset(String packageName) {
        PackageTable.Node pNode = mPackageTable.get(packageName);
        if (pNode == null) {
            PackageTable.Header header = mPackageTable.getHeader();
            throw new AconfigStorageException(
                    String.format(
                            "Fail to get package %s from container %s",
                            packageName, header.getContainer()));
        }
        return pNode.getBooleanStartIndex();
    }

    // Map a storage file given file path
    private static MappedByteBuffer mapStorageFile(String file) {
        try {
            FileInputStream stream = new FileInputStream(file);
            FileChannel channel = stream.getChannel();
            return channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size());
        } catch (Exception e) {
            throw new AconfigStorageException(
                    String.format("Fail to mmap storage file %s", file), e);
        }
    }
}
