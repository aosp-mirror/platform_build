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

import com.android.build.backportedfixes.BackportedFix;
import com.android.build.backportedfixes.BackportedFixes;

import com.google.common.collect.ImmutableList;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.BitSet;
import java.util.List;


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
    public static BackportedFixes parseBackportedFixes(List<? extends InputStream> fixStreams)
            throws
            IOException {
        var fixes = BackportedFixes.newBuilder();
        for (var s : fixStreams) {
            BackportedFix fix = BackportedFix.parseFrom(s);
            fixes.addFixes(fix);
            s.close();
        }
        return fixes.build();
    }

    private Parser() {
    }
}
