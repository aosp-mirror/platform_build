/*
 * Copyright (C) 2018 The Android Open Source Project
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
package com.android.signapk;
import java.io.OutputStream;
import java.io.IOException;

class CountingOutputStream extends OutputStream {
    private final OutputStream mBase;
    private long mWrittenBytes;

    public CountingOutputStream(OutputStream base) {
        mBase = base;
    }

    @Override
    public void close() throws IOException {
        mBase.close();
    }

    @Override
    public void flush() throws IOException {
        mBase.flush();
    }

    @Override
    public void write(byte[] b) throws IOException {
        mBase.write(b);
        mWrittenBytes += b.length;
    }

    @Override
    public void write(byte[] b, int off, int len) throws IOException {
        mBase.write(b, off, len);
        mWrittenBytes += len;
    }

    @Override
    public void write(int b) throws IOException {
        mBase.write(b);
        mWrittenBytes += 1;
    }

    public long getWrittenBytes() {
        return mWrittenBytes;
    }
}
