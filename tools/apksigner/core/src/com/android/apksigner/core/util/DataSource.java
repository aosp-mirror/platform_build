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

import java.io.IOException;

/**
 * Abstract representation of a source of data.
 *
 * <p>This abstraction serves three purposes:
 * <ul>
 * <li>Transparent handling of different types of sources, such as {@code byte[]},
 *     {@link java.nio.ByteBuffer}, {@link java.io.RandomAccessFile}, memory-mapped file.</li>
 * <li>Support sources larger than 2 GB. If all sources were smaller than 2 GB, {@code ByteBuffer}
 *     may have worked as the unifying abstraction.</li>
 * <li>Support sources which do not fit into logical memory as a contiguous region.</li>
 * </ul>
 */
public interface DataSource {

    /**
     * Returns the amount of data (in bytes) contained in this data source.
     */
    long size();

    /**
     * Feeds the specified chunk from this data source into the provided sink.
     *
     * @param offset index (in bytes) at which the chunk starts inside data source
     * @param size size (in bytes) of the chunk
     */
    void feed(long offset, int size, DataSink sink) throws IOException;
}
