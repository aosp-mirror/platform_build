/*
 * Copyright (C) 2021 The Android Open Source Project
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

import java.util.regex.Pattern;

/**
 * Returns whether a string matches one of a set of presupplied regexes.
 */
public class RegexSet {
    private final Pattern[] mPatterns;

    public RegexSet(String... patterns) {
        mPatterns = new Pattern[patterns.length];
        for (int i = 0; i < patterns.length; i++) {
            mPatterns[i] = Pattern.compile(patterns[i]);
        }
    }

    public boolean matches(String s) {
        for (Pattern p: mPatterns) {
            if (p.matcher(s).matches()) {
                return true;
            }
        }
        return false;
    }
}

