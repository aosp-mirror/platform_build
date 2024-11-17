
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
package com.android.build.backportedfixes;

import com.google.common.truth.Truth;

import org.junit.Test;

import java.io.PrintWriter;
import java.io.StringWriter;

/** Tests for {@link Main}. */
public class MainTest {


    @Test
    public void writeFixesAsAliasBitSet_default() {
        BackportedFixes fixes = BackportedFixes.newBuilder().build();
        var result = new StringWriter();

        Main.writeFixesAsAliasBitSet(fixes, new PrintWriter(result));

        Truth.assertThat(result.toString())
                .isEqualTo("""
                        # The following backported fixes have been applied
                        ro.build.backported_fixes.alias_bitset.long_list=
                        """);
    }

    @Test
    public void writeFixesAsAliasBitSet_some() {
        BackportedFixes fixes = BackportedFixes.newBuilder()
                .addFixes(BackportedFix.newBuilder().setKnownIssue(1234L).setAlias(1))
                .addFixes(BackportedFix.newBuilder().setKnownIssue(3L).setAlias(65))
                .addFixes(BackportedFix.newBuilder().setKnownIssue(4L).setAlias(67))
                .build();
        var result = new StringWriter();

        Main.writeFixesAsAliasBitSet(fixes, new PrintWriter(result));

        Truth.assertThat(result.toString())
                .isEqualTo("""
                        # The following backported fixes have been applied
                        # https://issuetracker.google.com/issues/1234 with alias 1
                        # https://issuetracker.google.com/issues/3 with alias 65
                        # https://issuetracker.google.com/issues/4 with alias 67
                        ro.build.backported_fixes.alias_bitset.long_list=2,10
                        """);
    }
}
