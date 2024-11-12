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

import android.os.StrictMode;

import java.nio.file.Path;

/** @hide */
public class AconfigPackageImpl {
    private FlagTable mFlagTable;
    private FlagValueList mFlagValueList;
    private PackageTable.Node mPNode;
    private final int mPackageId;
    private final int mBooleanStartIndex;

    private AconfigPackageImpl(
            FlagTable flagTable,
            FlagValueList flagValueList,
            int packageId,
            int booleanStartIndex) {
        this.mFlagTable = flagTable;
        this.mFlagValueList = flagValueList;
        this.mPackageId = packageId;
        this.mBooleanStartIndex = booleanStartIndex;
    }

    public static AconfigPackageImpl load(String packageName, StorageFileProvider fileProvider) {
        StrictMode.ThreadPolicy oldPolicy = StrictMode.allowThreadDiskReads();
        PackageTable.Node pNode = null;
        try {
            // First try to find the package in the "system" container.
            pNode = fileProvider.getPackageTable("system").get(packageName);
        } catch (Exception e) {
            //
        }
        try {
            if (pNode != null) {
                return new AconfigPackageImpl(
                        fileProvider.getFlagTable("system"),
                        fileProvider.getFlagValueList("system"),
                        pNode.getPackageId(),
                        pNode.getBooleanStartIndex());
            }

            // If not found in "system", search all package map files.
            for (Path p : fileProvider.listPackageMapFiles()) {
                PackageTable pTable = fileProvider.getPackageTable(p);
                pNode = pTable.get(packageName);
                if (pNode != null) {
                    return new AconfigPackageImpl(
                            fileProvider.getFlagTable(pTable.getHeader().getContainer()),
                            fileProvider.getFlagValueList(pTable.getHeader().getContainer()),
                            pNode.getPackageId(),
                            pNode.getBooleanStartIndex());
                }
            }
        } catch (AconfigStorageException e) {
            // Consider logging the exception.
            throw e;
        } finally {
            StrictMode.setThreadPolicy(oldPolicy);
        }
        // Package not found.
        throw new AconfigStorageException(
                AconfigStorageException.ERROR_PACKAGE_NOT_FOUND,
                "Package " + packageName + " not found.");
    }

    public static AconfigPackageImpl load(
            String container, String packageName, StorageFileProvider fileProvider) {

        StrictMode.ThreadPolicy oldPolicy = StrictMode.allowThreadDiskReads();
        try {
            PackageTable.Node pNode = fileProvider.getPackageTable(container).get(packageName);
            if (pNode != null) {
                return new AconfigPackageImpl(
                        fileProvider.getFlagTable(container),
                        fileProvider.getFlagValueList(container),
                        pNode.getPackageId(),
                        pNode.getBooleanStartIndex());
            }
        } catch (AconfigStorageException e) {
            // Consider logging the exception.
            throw e;
        } finally {
            StrictMode.setThreadPolicy(oldPolicy);
        }

        throw new AconfigStorageException(
                AconfigStorageException.ERROR_PACKAGE_NOT_FOUND,
                "package "
                        + packageName
                        + " in container "
                        + container
                        + " cannot be found on the device");
    }

    public boolean getBooleanFlagValue(String flagName, boolean defaultValue) {
        FlagTable.Node fNode = mFlagTable.get(mPackageId, flagName);
        if (fNode == null) return defaultValue;
        return mFlagValueList.getBoolean(fNode.getFlagIndex() + mBooleanStartIndex);
    }

    public boolean getBooleanFlagValue(int index) {
        return mFlagValueList.getBoolean(index + mBooleanStartIndex);
    }
}
