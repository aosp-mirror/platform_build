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
import java.util.ArrayList;
import java.util.List;

/** @hide */
public class AconfigPackageImpl {
    private FlagTable mFlagTable;
    private FlagValueList mFlagValueList;
    private PackageTable.Node mPNode;

    /** @hide */
    public static AconfigPackageImpl load(String packageName, StorageFileProvider fileProvider) {
        AconfigPackageImpl aPackage = new AconfigPackageImpl();
        if (!aPackage.init(null, packageName, fileProvider)) {
            return null;
        }
        return aPackage;
    }

    /** @hide */
    public static AconfigPackageImpl load(
            String container, String packageName, StorageFileProvider fileProvider) {
        if (container == null) {
            return null;
        }
        AconfigPackageImpl aPackage = new AconfigPackageImpl();
        if (!aPackage.init(container, packageName, fileProvider)) {
            return null;
        }
        return aPackage;
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

    private boolean init(
            String containerName, String packageName, StorageFileProvider fileProvider) {
        StrictMode.ThreadPolicy oldPolicy = StrictMode.allowThreadDiskReads();
        String container = containerName;
        try {
            // for devices don't have new storage directly return
            if (!fileProvider.containerFileExists(null)) {
                return false;
            }
            PackageTable.Node pNode = null;

            if (container == null) {
                PackageTable pTable = null;
                // check if device has flag files on the system partition
                // if the device has then search system partition first
                container = "system";
                if (fileProvider.containerFileExists(container)) {
                    pTable = fileProvider.getPackageTable(container);
                    pNode = pTable.get(packageName);
                }
                List<Path> mapFiles = new ArrayList<>();
                if (pNode == null) {
                    mapFiles = fileProvider.listPackageMapFiles();
                    if (mapFiles.isEmpty()) return false;
                }

                for (Path p : mapFiles) {
                    pTable = StorageFileProvider.getPackageTable(p);
                    pNode = pTable.get(packageName);
                    if (pNode != null) {
                        container = pTable.getHeader().getContainer();
                        break;
                    }
                }
            } else {
                pNode = fileProvider.getPackageTable(container).get(packageName);
            }

            if (pNode == null) {
                // for the case package is not found in all container, return instead of throwing
                // error
                return false;
            }

            mFlagTable = fileProvider.getFlagTable(container);
            mFlagValueList = fileProvider.getFlagValueList(container);
            mPNode = pNode;
        } catch (Exception e) {
            throw new AconfigStorageException(
                    String.format(
                            "cannot load package %s, from container %s", packageName, container),
                    e);
        } finally {
            StrictMode.setThreadPolicy(oldPolicy);
        }
        return true;
    }
}
