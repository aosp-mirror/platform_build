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

import static com.google.common.truth.Truth.assertThat;
import static com.google.common.truth.extensions.proto.ProtoTruth.assertThat;

import com.android.build.backportedfixes.BackportedFix;
import com.android.build.backportedfixes.BackportedFixes;

import com.google.common.collect.ImmutableList;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;

/** Tests for {@link Parser}.*/
public class ParserTest {

    @Rule
    public TemporaryFolder mTempFolder = new TemporaryFolder();

    @Test
    public void getFileInputStreams() throws IOException {
        var results = Parser.getFileInputStreams(
                ImmutableList.of(Files.createTempFile("test", null).toFile()));
        assertThat(results).isNotEmpty();
    }


    @Test
    public void getBitSetArray_empty() {
        var results = Parser.getBitSetArray(new int[]{});
        assertThat(results).isEmpty();
    }

    @Test
    public void getBitSetArray_2_3_64() {
        var results = Parser.getBitSetArray(new int[]{2,3,64});
        assertThat(results).asList().containsExactly(12L,1L).inOrder();
    }

    @Test
    public void parseBackportedFixFiles_empty() throws IOException {
        var result = Parser.parseBackportedFixFiles(ImmutableList.of());
        assertThat(result).isEqualTo(BackportedFixes.getDefaultInstance());
    }


    @Test
    public void parseBackportedFixFiles_oneBlank() throws IOException {
        var result = Parser.parseBackportedFixFiles(ImmutableList.of(mTempFolder.newFile()));

        assertThat(result).isEqualTo(
                BackportedFixes.newBuilder()
                        .addFixes(BackportedFix.getDefaultInstance())
                        .build());
    }

    @Test
    public void parseBackportedFixFiles_two() throws IOException {
        BackportedFix ki123 = BackportedFix.newBuilder()
                .setKnownIssue(123)
                .setAlias(1)
                .build();
        BackportedFix ki456 = BackportedFix.newBuilder()
                .setKnownIssue(456)
                .setAlias(2)
                .build();
        var result = Parser.parseBackportedFixFiles(
                ImmutableList.of(tempFile(ki456), tempFile(ki123)));
        assertThat(result).isEqualTo(
                BackportedFixes.newBuilder()
                        .addFixes(ki123)
                        .addFixes(ki456)
                        .build());
    }

    private File tempFile(BackportedFix fix) throws IOException {
        File f = mTempFolder.newFile();
        try (FileOutputStream out = new FileOutputStream(f)) {
            fix.writeTo(out);
            return f;
        }
    }
}
