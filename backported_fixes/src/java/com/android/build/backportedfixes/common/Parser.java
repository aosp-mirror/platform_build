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
package com.android.build.backportedfixes.common;

import static com.google.common.base.Preconditions.checkNotNull;

import com.android.build.backportedfixes.BackportedFix;
import com.android.build.backportedfixes.BackportedFixes;

import com.google.common.base.Throwables;
import com.google.common.collect.ImmutableList;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.BitSet;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collector;
import java.util.stream.Collectors;


/** Static utilities for working with {@link BackportedFixes}. */
public final class Parser {

    /** Creates list of FileInputStreams for a list of files. */
    public static ImmutableList<FileInputStream> getFileInputStreams(List<File> fixFiles) throws
            FileNotFoundException {
        var streams = ImmutableList.<FileInputStream>builder();
        for (var f : fixFiles) {
            streams.add(new FileInputStream(f));
        }
        return streams.build();
    }

    /** Converts a list of backported fix aliases into a long array representing a {@link BitSet} */
    public static long[] getBitSetArray(int[] aliases) {
        BitSet bs = new BitSet();
        for (int a : aliases) {
            bs.set(a);
        }
        return bs.toLongArray();
    }

    /**
     * Creates a {@link BackportedFixes} from a list of {@link BackportedFix} binary proto streams.
     */
    public static BackportedFixes parseBackportedFixFiles(List<File> fixFiles)
            throws IOException {
        try {
            return fixFiles.stream().map(Parser::tunelFileInputStream)
                    .map(Parser::tunnelParse)
                    .sorted(Comparator.comparing(BackportedFix::getKnownIssue))
                    .collect(fixCollector());

        } catch (TunnelException e) {
            throw e.rethrow(FileNotFoundException.class, IOException.class);
        }
    }


    private static Collector<BackportedFix, ?, BackportedFixes> fixCollector() {
        return Collectors.collectingAndThen(Collectors.toList(), fixList -> {
            var result = BackportedFixes.newBuilder();
            result.addAllFixes(fixList);
            return result.build();
        });
    }

    private static FileInputStream tunelFileInputStream(File file) throws TunnelException {
        try {
            return new FileInputStream(file);
        } catch (FileNotFoundException e) {
            throw new TunnelException(e);
        }
    }

    private static BackportedFix tunnelParse(InputStream s) throws TunnelException {
        try {
            var fix = BackportedFix.parseFrom(s);
            s.close();
            return fix;
        } catch (IOException e) {
            throw new TunnelException(e);
        }
    }

    private static class TunnelException extends RuntimeException {
        TunnelException(Exception cause) {
            super("If you see this TunnelException something went wrong.  It should always be rethrown as the cause.", cause);
        }

        <X extends Exception> RuntimeException rethrow(Class<X> exceptionClazz) throws X {
            checkNotNull(exceptionClazz);
            Throwables.throwIfInstanceOf(getCause(), exceptionClazz);
            throw exception(
                    getCause(),
                    "rethrow(%s) doesn't match underlying exception", exceptionClazz);
        }

        public <X1 extends Exception, X2 extends Exception> RuntimeException rethrow(
                Class<X1> exceptionClazz1, Class<X2> exceptionClazz2) throws X1, X2 {
            checkNotNull(exceptionClazz1);
            checkNotNull(exceptionClazz2);
            Throwables.throwIfInstanceOf(getCause(), exceptionClazz1);
            Throwables.throwIfInstanceOf(getCause(), exceptionClazz2);
            throw exception(
                    getCause(),
                    "rethrow(%s, %s) doesn't match underlying exception",
                    exceptionClazz1,
                    exceptionClazz2);
        }

        private static ClassCastException exception(
                Throwable cause, String message, Object... formatArgs) {
            ClassCastException result = new ClassCastException(String.format(message, formatArgs));
            result.initCause(cause);
            return result;
        }

    }

    private Parser() {
    }
}
