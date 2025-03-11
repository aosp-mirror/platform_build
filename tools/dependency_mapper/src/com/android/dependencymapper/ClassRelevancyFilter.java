/*
 * Copyright (C) 2025 The Android Open Source Project
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
package com.android.dependencymapper;

import java.util.Set;
import java.util.function.Predicate;

/**
 * A filter representing the list of class files which are relevant for dependency analysis.
 */
public class ClassRelevancyFilter implements Predicate<String> {

    private final Set<String> mAllowlistedClassNames;

    public ClassRelevancyFilter(Set<String> allowlistedClassNames) {
        this.mAllowlistedClassNames = allowlistedClassNames;
    }

    @Override
    public boolean test(String className) {
        return mAllowlistedClassNames.contains(className);
    }
}
