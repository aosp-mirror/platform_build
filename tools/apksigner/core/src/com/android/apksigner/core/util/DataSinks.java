/*
 * Copyright (C) 2016 The Android Open Source Project
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

package com.android.apksigner.core.util;

import java.io.OutputStream;
import java.io.RandomAccessFile;

import com.android.apksigner.core.internal.util.OutputStreamDataSink;
import com.android.apksigner.core.internal.util.RandomAccessFileDataSink;

/**
 * Utility methods for working with {@link DataSink} abstraction.
 */
public abstract class DataSinks {
    private DataSinks() {}

    /**
     * Returns a {@link DataSink} which outputs received data into the provided
     * {@link OutputStream}.
     */
    public static DataSink asDataSink(OutputStream out) {
        return new OutputStreamDataSink(out);
    }

    /**
     * Returns a {@link DataSink} which outputs received data into the provided file, sequentially,
     * starting at the beginning of the file.
     */
    public static DataSink asDataSink(RandomAccessFile file) {
        return new RandomAccessFileDataSink(file);
    }
}
