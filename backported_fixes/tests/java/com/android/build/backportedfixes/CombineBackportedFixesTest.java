
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

import java.io.ByteArrayOutputStream;
import java.io.IOException;

/** Tests for {@link CombineBackportedFixes}. */
public class CombineBackportedFixesTest {


    @Test
    public void writeBackportedFixes_default() throws IOException {
        // Not much of a test, but there is not much to test.
        BackportedFixes fixes = BackportedFixes.newBuilder()
                .addFixes(BackportedFix.newBuilder().setKnownIssue(123).build())
                .build();
        var result = new ByteArrayOutputStream();
        CombineBackportedFixes.writeBackportedFixes(fixes, result);
        Truth.assertThat(BackportedFixes.parseFrom(result.toByteArray()))
                .isEqualTo(fixes);
    }
}
