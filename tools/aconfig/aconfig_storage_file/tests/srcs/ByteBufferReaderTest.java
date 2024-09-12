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

import android.aconfig.storage.ByteBufferReader;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;

@RunWith(JUnit4.class)
public class ByteBufferReaderTest {

    @Test
    public void testReadByte() {
        ByteBuffer buffer = ByteBuffer.allocate(1);
        byte expect = 10;
        buffer.put(expect).rewind();

        ByteBufferReader reader = new ByteBufferReader(buffer);
        assertEquals(expect, reader.readByte());
    }

    @Test
    public void testReadShort() {
        ByteBuffer buffer = ByteBuffer.allocate(4);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
        short expect = Short.MAX_VALUE;
        buffer.putShort(expect).rewind();

        ByteBufferReader reader = new ByteBufferReader(buffer);
        assertEquals(expect, reader.readShort());
    }

    @Test
    public void testReadInt() {
        ByteBuffer buffer = ByteBuffer.allocate(4);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
        int expect = 10000;
        buffer.putInt(expect).rewind();

        ByteBufferReader reader = new ByteBufferReader(buffer);
        assertEquals(expect, reader.readInt());
    }

    @Test
    public void testReadString() {
        String expect = "test read string";
        byte[] bytes = expect.getBytes(StandardCharsets.UTF_8);

        ByteBuffer buffer = ByteBuffer.allocate(expect.length() * 2 + 4);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(expect.length()).put(bytes).rewind();

        ByteBufferReader reader = new ByteBufferReader(buffer);

        assertEquals(expect, reader.readString());
    }
}
