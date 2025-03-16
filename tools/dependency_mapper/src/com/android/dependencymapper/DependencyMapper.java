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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * This class binds {@link List<ClassDependencyData>} and {@link List<JavaSourceData>} together as a
 * flat map, which represents dependency related attributes of a java file.
 */
public class DependencyMapper {
    private final List<ClassDependencyData> mClassAnalysisList;
    private final List<JavaSourceData> mJavaSourceDataList;
    private final Map<String, String> mClassToSourceMap = new HashMap<>();
    private final Map<String, Set<String>> mFileDependencies = new HashMap<>();
    private final Set<String> mDependencyToAll = new HashSet<>();
    private final Map<String, Set<String>> mSourceToClasses = new HashMap<>();

    public DependencyMapper(List<ClassDependencyData> classAnalysisList, List<JavaSourceData> javaSourceDataList) {
        this.mClassAnalysisList = classAnalysisList;
        this.mJavaSourceDataList = javaSourceDataList;
    }

    public DependencyProto.FileDependencyList buildDependencyMaps() {
        buildClassDependencyMaps();
        buildSourceToClassMap();
        return createFileDependencies();
    }

    private void buildClassDependencyMaps() {
        // Create a map between package appended file names and file paths.
        Map<String, String> sourcePaths = generateSourcePaths();
        // A map between qualified className and its dependencies
        Map<String, Set<String>> classDependencies = new HashMap<>();
        // A map between constant values and the their declarations.
        Map<Object, Set<String>> constantRegistry = new HashMap<>();
        // A map between constant values and the their inlined usages.
        Map<Object, Set<String>> inlinedUsages = new HashMap<>();

        for (ClassDependencyData analysis : mClassAnalysisList) {
            String className = analysis.getQualifiedName();

            // Compute qualified class name to source path map.
            String sourceKey = analysis.getPackagePrependedClassSource();
            String sourcePath = sourcePaths.get(sourceKey);
            mClassToSourceMap.put(className, sourcePath);

            // compute classDependencies
            classDependencies.computeIfAbsent(className, k ->
                    new HashSet<>()).addAll(analysis.getClassDependencies());

            // Compute constantRegistry
            analysis.getConstantsDefined().forEach(c ->
                    constantRegistry.computeIfAbsent(c, k -> new HashSet<>()).add(className));
            // Compute inlinedUsages map.
            analysis.inlinedUsages().forEach(u ->
                    inlinedUsages.computeIfAbsent(u, k -> new HashSet<>()).add(className));

            if (analysis.isDependencyToAll()) {
                mDependencyToAll.add(sourcePath);
            }
        }
        // Finally build file dependencies
        buildFileDependencies(
                combineDependencies(classDependencies, inlinedUsages, constantRegistry));
    }

    private Map<String, String> generateSourcePaths() {
        Map<String, String> sourcePaths = new HashMap<>();
        mJavaSourceDataList.forEach(data ->
                sourcePaths.put(data.getPackagePrependedFileName(), data.getFilePath()));
        return sourcePaths;
    }

    private Map<String, Set<String>> combineDependencies(Map<String, Set<String>> classDependencies,
            Map<Object, Set<String>> inlinedUsages,
            Map<Object, Set<String>> constantRegistry) {
        Map<String, Set<String>> combined = new HashMap<>(
                buildConstantDependencies(inlinedUsages, constantRegistry));
        classDependencies.forEach((k, v) ->
                combined.computeIfAbsent(k, key -> new HashSet<>()).addAll(v));
        return combined;
    }

    private Map<String, Set<String>> buildConstantDependencies(
            Map<Object, Set<String>> inlinedUsages, Map<Object, Set<String>> constantRegistry) {
        Map<String, Set<String>> constantDependencies = new HashMap<>();
        for (Map.Entry<Object, Set<String>> usageEntry : inlinedUsages.entrySet()) {
            Object usage = usageEntry.getKey();
            Set<String> usageClasses = usageEntry.getValue();
            if (constantRegistry.containsKey(usage)) {
                Set<String> declarationClasses = constantRegistry.get(usage);
                for (String usageClass : usageClasses) {
                    // Sometimes Usage and Declarations are in the same file, we remove such cases
                    // to prevent circular dependency.
                    declarationClasses.remove(usageClass);
                    constantDependencies.computeIfAbsent(usageClass, k ->
                            new HashSet<>()).addAll(declarationClasses);
                }
            }
        }

        return constantDependencies;
    }

    private void buildFileDependencies(Map<String, Set<String>> combinedClassDependencies) {
        combinedClassDependencies.forEach((className, dependencies) -> {
            String sourceFile = mClassToSourceMap.get(className);
            if (sourceFile == null) {
                throw new IllegalArgumentException("Class '" + className
                        + "' does not have a corresponding source file.");
            }
            mFileDependencies.computeIfAbsent(sourceFile, k -> new HashSet<>());
            dependencies.forEach(dependency -> {
                String dependencySource = mClassToSourceMap.get(dependency);
                if (dependencySource == null) {
                    throw new IllegalArgumentException("Dependency '" + dependency
                            + "' does not have a corresponding source file.");
                }
                mFileDependencies.get(sourceFile).add(dependencySource);
            });
        });
    }

    private void buildSourceToClassMap() {
        mClassToSourceMap.forEach((className, sourceFile) ->
                mSourceToClasses.computeIfAbsent(sourceFile, k ->
                        new HashSet<>()).add(className));
    }

    private DependencyProto.FileDependencyList createFileDependencies() {
        List<DependencyProto.FileDependency> fileDependencies = new ArrayList<>();
        mFileDependencies.forEach((file, dependencies) -> {
            DependencyProto.FileDependency dependency = DependencyProto.FileDependency.newBuilder()
                    .setFilePath(file)
                    .setIsDependencyToAll(mDependencyToAll.contains(file))
                    .addAllGeneratedClasses(mSourceToClasses.get(file))
                    .addAllFileDependencies(dependencies)
                    .build();
            fileDependencies.add(dependency);
        });
        return DependencyProto.FileDependencyList.newBuilder()
                .addAllFileDependency(fileDependencies).build();
    }
}
