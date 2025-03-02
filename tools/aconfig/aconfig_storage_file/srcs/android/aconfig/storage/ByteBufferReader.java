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
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.Objects;

public class ByteBufferReader {

    private ByteBuffer mByteBuffer;
    private int mPosition;

    public ByteBufferReader(ByteBuffer byteBuffer) {
        this.mByteBuffer = byteBuffer;
        this.mByteBuffer.order(ByteOrder.LITTLE_ENDIAN);
    }

    public int readByte() {
        return Byte.toUnsignedInt(mByteBuffer.get(nextGetIndex(1)));
    }

    public int readShort() {
        return Short.toUnsignedInt(mByteBuffer.getShort(nextGetIndex(2)));
    }

    public int readInt() {
        return this.mByteBuffer.getInt(nextGetIndex(4));
    }

    public long readLong() {
        return this.mByteBuffer.getLong(nextGetIndex(8));
    }

    public String readString() {
        int length = readInt();
        if (length > 1024) {
            throw new AconfigStorageException(
                    "String length exceeds maximum allowed size (1024 bytes): " + length);
        }
        byte[] bytes = new byte[length];
        getArray(nextGetIndex(length), bytes, 0, length);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    public int readByte(int i) {
        return Byte.toUnsignedInt(mByteBuffer.get(i));
    }

    public void position(int newPosition) {
        mPosition = newPosition;
    }

    public int position() {
        return mPosition;
    }

    private int nextGetIndex(int nb) {
        int p = mPosition;
        mPosition += nb;
        return p;
    }

    private void getArray(int index, byte[] dst, int offset, int length) {
        Objects.checkFromIndexSize(index, length, mByteBuffer.limit());
        Objects.checkFromIndexSize(offset, length, dst.length);

        int end = offset + length;
        for (int i = offset, j = index; i < end; i++, j++) {
            dst[i] = mByteBuffer.get(j);
        }
    }
}
