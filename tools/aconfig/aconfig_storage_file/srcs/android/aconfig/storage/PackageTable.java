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

import static java.nio.charset.StandardCharsets.UTF_8;

import java.nio.ByteBuffer;
import java.util.Objects;

public class PackageTable {

    private Header mHeader;
    private ByteBufferReader mReader;

    public static PackageTable fromBytes(ByteBuffer bytes) {
        PackageTable packageTable = new PackageTable();
        packageTable.mReader = new ByteBufferReader(bytes);
        packageTable.mHeader = Header.fromBytes(packageTable.mReader);

        return packageTable;
    }

    public Node get(String packageName) {

        int numBuckets = (mHeader.mNodeOffset - mHeader.mBucketOffset) / 4;
        int bucketIndex = TableUtils.getBucketIndex(packageName.getBytes(UTF_8), numBuckets);

        mReader.position(mHeader.mBucketOffset + bucketIndex * 4);
        int nodeIndex = mReader.readInt();

        while (nodeIndex != -1) {
            mReader.position(nodeIndex);
            Node node = Node.fromBytes(mReader);
            if (Objects.equals(packageName, node.mPackageName)) {
                return node;
            }
            nodeIndex = node.mNextOffset;
        }

        throw new AconfigStorageException("get cannot find package: " + packageName);
    }

    public Header getHeader() {
        return mHeader;
    }

    public static class Header {

        private int mVersion;
        private String mContainer;
        private FileType mFileType;
        private int mFileSize;
        private int mNumPackages;
        private int mBucketOffset;
        private int mNodeOffset;

        public static Header fromBytes(ByteBufferReader reader) {
            Header header = new Header();
            header.mVersion = reader.readInt();
            header.mContainer = reader.readString();
            header.mFileType = FileType.fromInt(reader.readByte());
            header.mFileSize = reader.readInt();
            header.mNumPackages = reader.readInt();
            header.mBucketOffset = reader.readInt();
            header.mNodeOffset = reader.readInt();

            if (header.mFileType != FileType.PACKAGE_MAP) {
                throw new AconfigStorageException("binary file is not a package map");
            }

            return header;
        }

        public int getVersion() {
            return mVersion;
        }

        public String getContainer() {
            return mContainer;
        }

        public FileType getFileType() {
            return mFileType;
        }

        public int getFileSize() {
            return mFileSize;
        }

        public int getNumPackages() {
            return mNumPackages;
        }

        public int getBucketOffset() {
            return mBucketOffset;
        }

        public int getNodeOffset() {
            return mNodeOffset;
        }
    }

    public static class Node {

        private String mPackageName;
        private int mPackageId;
        private int mBooleanStartIndex;
        private int mNextOffset;

        public static Node fromBytes(ByteBufferReader reader) {
            Node node = new Node();
            node.mPackageName = reader.readString();
            node.mPackageId = reader.readInt();
            node.mBooleanStartIndex = reader.readInt();
            node.mNextOffset = reader.readInt();
            node.mNextOffset = node.mNextOffset == 0 ? -1 : node.mNextOffset;
            return node;
        }

        @Override
        public int hashCode() {
            return Objects.hash(mPackageName, mPackageId, mBooleanStartIndex, mNextOffset);
        }

        @Override
        public boolean equals(Object obj) {
            if (this == obj) {
                return true;
            }

            if (obj == null || !(obj instanceof Node)) {
                return false;
            }

            Node other = (Node) obj;
            return Objects.equals(mPackageName, other.mPackageName)
                    && mPackageId == other.mPackageId
                    && mBooleanStartIndex == other.mBooleanStartIndex
                    && mNextOffset == other.mNextOffset;
        }

        public String getPackageName() {
            return mPackageName;
        }

        public int getPackageId() {
            return mPackageId;
        }

        public int getBooleanStartIndex() {
            return mBooleanStartIndex;
        }

        public int getNextOffset() {
            return mNextOffset;
        }
    }
}
