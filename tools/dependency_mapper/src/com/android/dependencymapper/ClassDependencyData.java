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

/**
 * Represents the Class Dependency Data collected via ASM analysis.
 */
public class ClassDependencyData {
    private final String mPackagePrependedClassSource;
    private final String mQualifiedName;
    private final Set<String> mClassDependencies;
    private final boolean mIsDependencyToAll;
    private final Set<Object> mConstantsDefined;
    private final Set<Object> mInlinedUsages;

    public ClassDependencyData(String packagePrependedClassSource, String className,
            Set<String> classDependencies, boolean isDependencyToAll, Set<Object> constantsDefined,
            Set<Object> inlinedUsages) {
        this.mPackagePrependedClassSource = packagePrependedClassSource;
        this.mQualifiedName = className;
        this.mClassDependencies = classDependencies;
        this.mIsDependencyToAll = isDependencyToAll;
        this.mConstantsDefined = constantsDefined;
        this.mInlinedUsages = inlinedUsages;
    }

    public String getPackagePrependedClassSource() {
        return mPackagePrependedClassSource;
    }

    public String getQualifiedName() {
        return mQualifiedName;
    }

    public Set<String> getClassDependencies() {
        return mClassDependencies;
    }

    public Set<Object> getConstantsDefined() {
        return mConstantsDefined;
    }

    public Set<Object> inlinedUsages() {
        return mInlinedUsages;
    }

    public boolean isDependencyToAll() {
        return mIsDependencyToAll;
    }
}
