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

import static org.junit.Assert.assertEquals;

import org.junit.BeforeClass;
import org.junit.Test;

import java.net.URISyntaxException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class JavaSourceAnalyzerTest {
    private static List<JavaSourceData> mJavaSourceDataList;

    private static final String SOURCES_RSP_PATH =
            "tests/res/testfiles/sources.rsp";

    @BeforeClass
    public static void beforeClass() throws URISyntaxException {
        Path path = Paths.get(SOURCES_RSP_PATH);
        // Perform source analysis.
        mJavaSourceDataList = JavaSourceAnalyzer.analyze(path);
    }

    @Test
    public void validateSourceData() {
        Map<String, String> expectedSourceData = expectedSourceData();
        int expectedFileCount = expectedSourceData.size();
        int actualFileCount = 0;
        for (JavaSourceData javaSourceData : mJavaSourceDataList) {
            String file =  javaSourceData.getFilePath();
            if (expectedSourceData.containsKey(file)) {
                actualFileCount++;
                assertEquals("Source Data not generated correctly for " + file,
                        expectedSourceData.get(file), javaSourceData.getPackagePrependedFileName());
            }
        }
        assertEquals("Not all source files processed", expectedFileCount, actualFileCount);
    }

    private Map<String, String> expectedSourceData() {
        Map<String, String> expectedSourceData = new HashMap<>();
        expectedSourceData.put("tests/res/testdata/annotation/AnnotationUsage.java",
                "res.testdata.annotation.AnnotationUsage.java");
        expectedSourceData.put("tests/res/testdata/constants/ConstantUsage.java",
                "res.testdata.constants.ConstantUsage.java");
        expectedSourceData.put("tests/res/testdata/inheritance/BaseClass.java",
                "res.testdata.inheritance.BaseClass.java");
        expectedSourceData.put("tests/res/testdata/methods/FieldUsage.java",
                "res.testdata.methods.FieldUsage.java");
        return expectedSourceData;
    }
}
