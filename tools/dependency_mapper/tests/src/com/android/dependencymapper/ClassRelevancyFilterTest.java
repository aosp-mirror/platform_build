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

import static com.android.dependencymapper.Utils.listClassesInJar;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;

import com.android.dependencymapper.ClassDependencyAnalyzer;
import com.android.dependencymapper.ClassDependencyData;
import com.android.dependencymapper.ClassRelevancyFilter;

import org.junit.Test;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Set;

public class ClassRelevancyFilterTest {

    private static final String CLASSES_JAR_PATH =
            "tests/res/testfiles/dependency-mapper-test-data.jar";

    @Test
    public void testClassRelevancyFilter() {
        Path path = Paths.get(CLASSES_JAR_PATH);
        Set<String> classesInJar = listClassesInJar(path);

        // Add a relevancy filter that skips a class.
        String skippedClass = "res.testdata.BaseClass";
        classesInJar.remove(skippedClass);

        // Perform dependency analysis.
        List<ClassDependencyData> classDependencyDataList =
                ClassDependencyAnalyzer.analyze(path, new ClassRelevancyFilter(classesInJar));

        // check that the skipped class is not present in classDepsList
        for (ClassDependencyData dep : classDependencyDataList) {
            assertNotEquals("SkippedClass " + skippedClass + " is present",
                    skippedClass, dep.getQualifiedName());
            assertFalse("SkippedClass " + skippedClass + " is present as dependency of " + dep,
                    dep.getClassDependencies().contains(skippedClass));
        }
    }
}
