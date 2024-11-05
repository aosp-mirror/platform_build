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

    /** @hide */
    public static final int ERROR_NEW_STORAGE_SYSTEM_NOT_FOUND = 1;

    /** @hide */
    public static final int ERROR_PACKAGE_NOT_FOUND = 2;

    /** @hide */
    public static final int ERROR_CONTAINER_NOT_FOUND = 3;

    /** @hide */
    public AconfigPackageImpl() {}

    /** @hide */
    public int load(String packageName, StorageFileProvider fileProvider) {
        return init(null, packageName, fileProvider);
    }

    /** @hide */
    public int load(String container, String packageName, StorageFileProvider fileProvider) {
        if (container == null) {
            return ERROR_CONTAINER_NOT_FOUND;
        }

        return init(container, packageName, fileProvider);
    }

    /** @hide */
    public boolean getBooleanFlagValue(String flagName, boolean defaultValue) {
        FlagTable.Node fNode = mFlagTable.get(mPNode.getPackageId(), flagName);
        // no such flag in this package
        if (fNode == null) return defaultValue;
        int index = fNode.getFlagIndex() + mPNode.getBooleanStartIndex();
        return mFlagValueList.getBoolean(index);
    }

    /** @hide */
    public boolean getBooleanFlagValue(int index) {
        return mFlagValueList.getBoolean(index + mPNode.getBooleanStartIndex());
    }

    /** @hide */
    public long getPackageFingerprint() {
        return mPNode.getPackageFingerprint();
    }

    /** @hide */
    public boolean hasPackageFingerprint() {
        return mPNode.hasPackageFingerprint();
    }

    private int init(String containerName, String packageName, StorageFileProvider fileProvider) {
        StrictMode.ThreadPolicy oldPolicy = StrictMode.allowThreadDiskReads();
        String container = containerName;
        try {
            // for devices don't have new storage directly return
            if (!fileProvider.containerFileExists(null)) {
                return ERROR_NEW_STORAGE_SYSTEM_NOT_FOUND;
            }
            PackageTable.Node pNode = null;

            if (container == null) {
                // Check if the device has flag files on the system partition.
                // If the device does, search the system partition first.
                container = "system";
                if (fileProvider.containerFileExists(container)) {
                    pNode = fileProvider.getPackageTable(container).get(packageName);
                }

                if (pNode == null) {
                    // Search all package map files if not found in the system partition.
                    for (Path p : fileProvider.listPackageMapFiles()) {
                        PackageTable pTable = StorageFileProvider.getPackageTable(p);
                        pNode = pTable.get(packageName);
                        if (pNode != null) {
                            container = pTable.getHeader().getContainer();
                            break;
                        }
                    }
                }
            } else {
                if (!fileProvider.containerFileExists(container)) {
                    return ERROR_CONTAINER_NOT_FOUND;
                }
                pNode = fileProvider.getPackageTable(container).get(packageName);
            }

            if (pNode == null) {
                // for the case package is not found in all container, return instead of throwing
                // error
                return ERROR_PACKAGE_NOT_FOUND;
            }

            mFlagTable = fileProvider.getFlagTable(container);
            mFlagValueList = fileProvider.getFlagValueList(container);
            mPNode = pNode;
        } catch (Exception e) {
            throw e;
        } finally {
            StrictMode.setThreadPolicy(oldPolicy);
        }
        return 0;
    }
}
