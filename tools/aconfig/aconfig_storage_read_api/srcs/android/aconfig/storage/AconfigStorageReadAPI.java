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

import dalvik.annotation.optimization.FastNative;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;

public class AconfigStorageReadAPI {

    // Storage file dir on device
    private static final String STORAGEDIR = "/metadata/aconfig";

    // Stoarge file type
    public enum StorageFileType {
        PACKAGE_MAP,
        FLAG_MAP,
        FLAG_VAL,
        FLAG_INFO
    }

    // Map a storage file given file path
    public static MappedByteBuffer mapStorageFile(String file) throws IOException {
        FileInputStream stream = new FileInputStream(file);
        FileChannel channel = stream.getChannel();
        return channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size());
    }

    // Map a storage file given container and file type
    public static MappedByteBuffer getMappedFile(String container, StorageFileType type)
            throws IOException {
        switch (type) {
            case PACKAGE_MAP:
                return mapStorageFile(STORAGEDIR + "/maps/" + container + ".package.map");
            case FLAG_MAP:
                return mapStorageFile(STORAGEDIR + "/maps/" + container + ".flag.map");
            case FLAG_VAL:
                return mapStorageFile(STORAGEDIR + "/boot/" + container + ".val");
            case FLAG_INFO:
                return mapStorageFile(STORAGEDIR + "/boot/" + container + ".info");
            default:
                throw new IOException("Invalid storage file type");
        }
    }

    // JNI interface to get package read context
    // @param mappedFile: memory mapped package map file
    // @param packageName: package name
    // @throws IOException if the passed in file is not a valid package map file
    @FastNative
    private static native ByteBuffer getPackageReadContextImpl(
            ByteBuffer mappedFile, String packageName) throws IOException;

    // API to get package read context
    // @param mappedFile: memory mapped package map file
    // @param packageName: package name
    // @throws IOException if the passed in file is not a valid package map file
    public static PackageReadContext getPackageReadContext(
            ByteBuffer mappedFile, String packageName) throws IOException {
        ByteBuffer buffer = getPackageReadContextImpl(mappedFile, packageName);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
        return new PackageReadContext(buffer.getInt(), buffer.getInt(4));
    }

    // JNI interface to get flag read context
    // @param mappedFile: memory mapped flag map file
    // @param packageId: package id to represent a specific package, obtained from
    // package map file
    // @param flagName: flag name
    // @throws IOException if the passed in file is not a valid flag map file
    @FastNative
    private static native ByteBuffer getFlagReadContextImpl(
            ByteBuffer mappedFile, int packageId, String flagName) throws IOException;

    // API to get flag read context
    // @param mappedFile: memory mapped flag map file
    // @param packageId: package id to represent a specific package, obtained from
    // package map file
    // @param flagName: flag name
    // @throws IOException if the passed in file is not a valid flag map file
    public static FlagReadContext getFlagReadContext(
            ByteBuffer mappedFile, int packageId, String flagName) throws IOException {
        ByteBuffer buffer = getFlagReadContextImpl(mappedFile, packageId, flagName);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
        return new FlagReadContext(buffer.getInt(), buffer.getInt(4));
    }

    // JNI interface to get boolean flag value
    // @param mappedFile: memory mapped flag value file
    // @param flagIndex: flag global index in the flag value array
    // @throws IOException if the passed in file is not a valid flag value file or the
    // flag index went over the file boundary.
    @FastNative
    public static native boolean getBooleanFlagValue(ByteBuffer mappedFile, int flagIndex)
            throws IOException;

    @FastNative
    public static native long hash(String packageName) throws IOException;

    static {
        System.loadLibrary("aconfig_storage_read_api_rust_jni");
    }
}
