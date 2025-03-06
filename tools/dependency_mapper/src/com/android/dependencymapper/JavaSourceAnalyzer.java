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

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * An utility class that reads each java file present in the rsp content then analyzes the same,
 * collecting the analysis in {@link List<JavaSourceData>}
 */
public class JavaSourceAnalyzer {

    // Regex that matches against "package abc.xyz.lmn;" declarations in a java file.
    private static final String PACKAGE_REGEX = "^package\\s+([a-zA-Z_][a-zA-Z0-9_.]*);";

    public static List<JavaSourceData> analyze(Path srcRspFile) {
        List<JavaSourceData> javaSourceDataList = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new FileReader(srcRspFile.toFile()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                // Split the line by spaces, tabs, multiple java files can be on a single line.
                String[] files = line.trim().split("\\s+");
                for (String file : files) {
                    Path p = Paths.get("", file);
                    System.out.println(p.toAbsolutePath().toString());
                    javaSourceDataList
                            .add(new JavaSourceData(file, constructPackagePrependedFileName(file)));
                }
            }
        } catch (IOException e) {
            System.err.println("Error reading rsp file at: " + srcRspFile);
            throw new RuntimeException(e);
        }
        return javaSourceDataList;
    }

    private static String constructPackagePrependedFileName(String filePath) {
        String packageAppendedFileName = null;
        // if the file path is abc/def/ghi/JavaFile.java we extract JavaFile.java
        String javaFileName = filePath.substring(filePath.lastIndexOf("/") + 1);
        try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;
            // Process each line and match against the package regex pattern.
            while ((line = reader.readLine()) != null) {
                Pattern pattern = Pattern.compile(PACKAGE_REGEX);
                Matcher matcher = pattern.matcher(line);
                if (matcher.find()) {
                    packageAppendedFileName = matcher.group(1) + "." + javaFileName;
                    break;
                }
            }
        } catch (IOException e) {
            System.err.println("Error reading java file at: " + filePath);
            throw new RuntimeException(e);
        }
        // Should not be null
        assert packageAppendedFileName != null;
        return packageAppendedFileName;
    }
}
