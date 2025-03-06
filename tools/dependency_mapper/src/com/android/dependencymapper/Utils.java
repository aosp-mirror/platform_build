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

import com.android.dependencymapper.DependencyProto;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class Utils {

    public static String trimAndConvertToPackageBasedPath(String fileBasedPath) {
        // Remove ".class" from the fileBasedPath, then replace "/" with "."
        return fileBasedPath.replaceAll("\\..*", "").replaceAll("/", ".");
    }

    public static String buildPackagePrependedClassSource(String qualifiedClassPath,
            String classSource) {
        // Find the location of the start of classname in the qualifiedClassPath
        int classNameSt = qualifiedClassPath.lastIndexOf(".") + 1;
        // Replace the classname in qualifiedClassPath with classSource
        return qualifiedClassPath.substring(0, classNameSt) + classSource;
    }

    public static void writeContentsToJson(DependencyProto.FileDependencyList contents, Path jsonOut) {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        Map<String, Set<String>> jsonMap = new HashMap<>();
        for (DependencyProto.FileDependency fileDependency : contents.getFileDependencyList()) {
            jsonMap.putIfAbsent(fileDependency.getFilePath(),
                    Set.copyOf(fileDependency.getFileDependenciesList()));
        }
        String json = gson.toJson(jsonMap);
        try (FileWriter file = new FileWriter(jsonOut.toFile())) {
            file.write(json);
        } catch (IOException e) {
            System.err.println("Error writing json output to: " + jsonOut);
            throw new RuntimeException(e);
        }
    }

    public static void writeContentsToProto(DependencyProto.FileDependencyList usages, Path protoOut) {
        try {
            OutputStream outputStream = Files.newOutputStream(protoOut);
            usages.writeDelimitedTo(outputStream);
        } catch (IOException e) {
            System.err.println("Error writing proto output to: " + protoOut);
            throw new RuntimeException(e);
        }
    }

    public static Set<String> listClassesInJar(Path classesJarPath) {
        Set<String> classes = new HashSet<>();
        try (JarFile jarFile = new JarFile(classesJarPath.toFile())) {
            Enumeration<JarEntry> entries = jarFile.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                if (entry.getName().endsWith(".class")) {
                    String name = Utils.trimAndConvertToPackageBasedPath(entry.getName());
                    classes.add(name);
                }
            }
        } catch (IOException e) {
            System.err.println("Error reading the jar file at: " + classesJarPath);
            throw new RuntimeException(e);
        }
        return classes;
    }
}
