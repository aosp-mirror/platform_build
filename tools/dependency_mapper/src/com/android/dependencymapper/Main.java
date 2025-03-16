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

import com.android.dependencymapper.DependencyProto;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Set;

public class Main {

    public static void main(String[] args) throws IOException, InterruptedException {
        try {
            InputData input = parseAndValidateInput(args);
            generateDependencyMap(input);
        } catch (IllegalArgumentException e) {
            System.err.println("Error: " + e.getMessage());
            showUsage();
        }
    }

    private static class InputData {
        public Path srcList;
        public Path classesJar;
        public Path dependencyMapProto;

        public InputData(Path srcList, Path classesJar, Path dependencyMapProto) {
            this.srcList = srcList;
            this.classesJar = classesJar;
            this.dependencyMapProto = dependencyMapProto;
        }
    }

    private static InputData parseAndValidateInput(String[] args) {
        for (String arg : args) {
            if ("--help".equals(arg)) {
                showUsage();
                System.exit(0); // Indicate successful exit after showing help
            }
        }

        if (args.length != 6) { // Explicitly check for the correct number of arguments
            throw new IllegalArgumentException("Incorrect number of arguments");
        }

        Path srcList = null;
        Path classesJar = null;
        Path dependencyMapProto = null;

        for (int i = 0; i < args.length; i += 2) {
            String arg = args[i].trim();
            String argValue = args[i + 1].trim();

            switch (arg) {
                case "--src-path" -> srcList = Path.of(argValue);
                case "--jar-path" -> classesJar = Path.of(argValue);
                case "--dependency-map-path" -> dependencyMapProto = Path.of(argValue);
                default -> throw new IllegalArgumentException("Unknown argument: " + arg);
            }
        }

        // Validate file existence and readability
        validateFile(srcList, "--src-path");
        validateFile(classesJar, "--jar-path");

        return new InputData(srcList, classesJar, dependencyMapProto);
    }

    private static void validateFile(Path path, String argName) {
        if (path == null) {
            throw new IllegalArgumentException(argName + " is required");
        }
        if (!Files.exists(path)) {
            throw new IllegalArgumentException(argName + " does not exist: " + path);
        }
        if (!Files.isReadable(path)) {
            throw new IllegalArgumentException(argName + " is not readable: " + path);
        }
    }

    private static void generateDependencyMap(InputData input) {
        // First collect all classes in the jar.
        Set<String> classesInJar = listClassesInJar(input.classesJar);
        // Perform dependency analysis.
        List<ClassDependencyData> classDependencyDataList = ClassDependencyAnalyzer
                .analyze(input.classesJar, new ClassRelevancyFilter(classesInJar));
        // Perform java source analysis.
        List<JavaSourceData> javaSourceDataList = JavaSourceAnalyzer.analyze(input.srcList);
        // Collect all dependencies and map them as DependencyProto.FileDependencyList
        DependencyMapper dp = new DependencyMapper(classDependencyDataList, javaSourceDataList);
        DependencyProto.FileDependencyList dependencyList =  dp.buildDependencyMaps();

        // Write the proto to output file
        Utils.writeContentsToProto(dependencyList, input.dependencyMapProto);
    }

    private static void showUsage() {
        System.err.println(
                "Usage: dependency-mapper "
                        + "--src-path [src-list.rsp] "
                        + "--jar-path [classes.jar] "
                        + "--dependency-map-path [dependency-map.proto]");
    }

}