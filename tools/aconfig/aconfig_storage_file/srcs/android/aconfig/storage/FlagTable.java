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

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

public class FlagTable {

    private Header mHeader;
    private Map<String, Node> mNodeMap;

    public static FlagTable fromBytes(ByteBuffer bytes) {
        FlagTable flagTable = new FlagTable();
        ByteBufferReader reader = new ByteBufferReader(bytes);
        Header header = Header.fromBytes(reader);
        flagTable.mHeader = header;
        flagTable.mNodeMap = new HashMap(TableUtils.getTableSize(header.mNumFlags));
        reader.position(header.mNodeOffset);
        for (int i = 0; i < header.mNumFlags; i++) {
            Node node = Node.fromBytes(reader);
            flagTable.mNodeMap.put(makeKey(node.mPackageId, node.mFlagName), node);
        }
        return flagTable;
    }

    public Node get(int packageId, String flagName) {
        return mNodeMap.get(makeKey(packageId, flagName));
    }

    public Header getHeader() {
        return mHeader;
    }

    private static String makeKey(int packageId, String flagName) {
        StringBuilder ret = new StringBuilder();
        return ret.append(packageId).append('/').append(flagName).toString();
    }

    public static class Header {

        private int mVersion;
        private String mContainer;
        private FileType mFileType;
        private int mFileSize;
        private int mNumFlags;
        private int mBucketOffset;
        private int mNodeOffset;

        public static Header fromBytes(ByteBufferReader reader) {
            Header header = new Header();
            header.mVersion = reader.readInt();
            header.mContainer = reader.readString();
            header.mFileType = FileType.fromInt(reader.readByte());
            header.mFileSize = reader.readInt();
            header.mNumFlags = reader.readInt();
            header.mBucketOffset = reader.readInt();
            header.mNodeOffset = reader.readInt();

            if (header.mFileType != FileType.FLAG_MAP) {
                throw new AconfigStorageException("binary file is not a flag map");
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

        public int getNumFlags() {
            return mNumFlags;
        }

        public int getBucketOffset() {
            return mBucketOffset;
        }

        public int getNodeOffset() {
            return mNodeOffset;
        }
    }

    public static class Node {

        private String mFlagName;
        private FlagType mFlagType;
        private int mPackageId;
        private int mFlagIndex;
        private int mNextOffset;

        public static Node fromBytes(ByteBufferReader reader) {
            Node node = new Node();
            node.mPackageId = reader.readInt();
            node.mFlagName = reader.readString();
            node.mFlagType = FlagType.fromInt(reader.readShort());
            node.mFlagIndex = reader.readShort();
            node.mNextOffset = reader.readInt();
            node.mNextOffset = node.mNextOffset == 0 ? -1 : node.mNextOffset;
            return node;
        }

        @Override
        public int hashCode() {
            return Objects.hash(mFlagName, mFlagType, mPackageId, mFlagIndex, mNextOffset);
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
            return Objects.equals(mFlagName, other.mFlagName)
                    && Objects.equals(mFlagType, other.mFlagType)
                    && mPackageId == other.mPackageId
                    && mFlagIndex == other.mFlagIndex
                    && mNextOffset == other.mNextOffset;
        }

        public String getFlagName() {
            return mFlagName;
        }

        public FlagType getFlagType() {
            return mFlagType;
        }

        public int getPackageId() {
            return mPackageId;
        }

        public int getFlagIndex() {
            return mFlagIndex;
        }

        public int getNextOffset() {
            return mNextOffset;
        }
    }
}
