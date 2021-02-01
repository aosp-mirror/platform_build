/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.build.config;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.io.UnsupportedEncodingException;
import java.nio.charset.StandardCharsets;

/**
 * Errors for testing.
 */
public class TestErrors extends ErrorReporter {

    public static final int ERROR_CODE = 1;

    public final Category ERROR = new Category(ERROR_CODE, true, Level.ERROR,
            "An error.");

    public static final int WARNING_CODE = 2;

    public final Category WARNING = new Category(WARNING_CODE, true, Level.WARNING,
            "A warning.");

    public static final int HIDDEN_CODE = 3;

    public final Category HIDDEN = new Category(HIDDEN_CODE, true, Level.HIDDEN,
            "A hidden warning.");

    public static final int ERROR_FIXED_CODE = 4;

    public final Category ERROR_FIXED = new Category(ERROR_FIXED_CODE, false, Level.ERROR,
            "An error that can't have its level changed.");

    public void assertHasEntry(Errors.Category category) {
        assertHasEntry(category, this);
    }

    public String getErrorMessages() {
        return getErrorMessages(this);
    }

    public static void assertHasEntry(Errors.Category category, ErrorReporter errors) {
        StringBuilder found = new StringBuilder();
        for (Errors.Entry entry: errors.getEntries()) {
            if (entry.getCategory() == category) {
                return;
            }
            found.append(' ');
            found.append(entry.getCategory().getCode());
        }
        throw new AssertionError("No error category " + category.getCode() + " found."
                + " Found category codes were:" + found);
    }

    public static String getErrorMessages(ErrorReporter errors) {
        final ByteArrayOutputStream stream = new ByteArrayOutputStream();
        try {
            errors.printErrors(new PrintStream(stream, true, StandardCharsets.UTF_8.name()));
        } catch (UnsupportedEncodingException ex) {
            // utf-8 is always supported
        }
        return new String(stream.toByteArray(), StandardCharsets.UTF_8);
    }
}

