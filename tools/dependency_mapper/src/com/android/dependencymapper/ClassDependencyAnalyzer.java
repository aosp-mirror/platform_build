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

import org.objectweb.asm.ClassReader;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

/**
 * An utility class that reads each class file present in the classes jar, then analyzes the same,
 * collecting the dependencies in {@link List<ClassDependencyData>}
 */
public class ClassDependencyAnalyzer {

    public static List<ClassDependencyData> analyze(Path classJar, ClassRelevancyFilter classFilter) {
        List<ClassDependencyData> classAnalysisList = new ArrayList<>();
        try (JarFile jarFile = new JarFile(classJar.toFile())) {
            Enumeration<JarEntry> entries = jarFile.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                if (entry.getName().endsWith(".class")) {
                    try (InputStream inputStream = jarFile.getInputStream(entry)) {
                        String name = Utils.trimAndConvertToPackageBasedPath(entry.getName());
                        ClassDependencyData classAnalysis = ClassDependenciesVisitor.analyze(name,
                                new ClassReader(inputStream), classFilter);
                        classAnalysisList.add(classAnalysis);
                    }
                }
            }
        } catch (IOException e) {
            System.err.println("Error reading the jar file at: " + classJar);
            throw new RuntimeException(e);
        }
        return classAnalysisList;
    }
}
