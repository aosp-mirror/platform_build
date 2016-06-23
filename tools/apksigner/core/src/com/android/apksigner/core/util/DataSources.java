package com.android.apksigner.core.util;

import com.android.apksigner.core.internal.util.ByteBufferDataSource;
import com.android.apksigner.core.internal.util.RandomAccessFileDataSource;

import java.io.RandomAccessFile;
import java.nio.ByteBuffer;

/**
 * Utility methods for working with {@link DataSource} abstraction.
 */
public abstract class DataSources {
    private DataSources() {}

    /**
     * Returns a {@link DataSource} backed by the provided {@link ByteBuffer}. The data source
     * represents the data contained between the position and limit of the buffer. Changes to the
     * buffer's contents will be visible in the data source.
     */
    public static DataSource asDataSource(ByteBuffer buffer) {
        if (buffer == null) {
            throw new NullPointerException();
        }
        return new ByteBufferDataSource(buffer);
    }

    /**
     * Returns a {@link DataSource} backed by the provided {@link RandomAccessFile}. Changes to the
     * file, including changes to size of file, will be visible in the data source.
     */
    public static DataSource asDataSource(RandomAccessFile file) {
        if (file == null) {
            throw new NullPointerException();
        }
        return new RandomAccessFileDataSource(file);
    }

    /**
     * Returns a {@link DataSource} backed by the provided region of the {@link RandomAccessFile}.
     * Changes to the file will be visible in the data source.
     */
    public static DataSource asDataSource(RandomAccessFile file, long offset, long size) {
        if (file == null) {
            throw new NullPointerException();
        }
        return new RandomAccessFileDataSource(file, offset, size);
    }
}
