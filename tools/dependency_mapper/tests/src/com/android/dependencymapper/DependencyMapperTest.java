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
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import org.junit.BeforeClass;
import org.junit.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

public class DependencyMapperTest {

    private static final List<JavaSourceData> mJavaSourceData = new ArrayList<>();
    private static final List<ClassDependencyData> mClassDependencyData = new ArrayList<>();

    private static Map<String, DependencyProto.FileDependency>  mFileDependencyMap;

    public static String AUDIO_CONS = "AUDIO_CONS";
    public static String AUDIO_CONS_PATH = "frameworks/base/audio/AudioPermission.java";
    public static String AUDIO_CONS_PACKAGE = "com.android.audio.AudioPermission";

    public static String AUDIO_TONE_CONS_1 = "AUDIO_TONE_CONS_1";
    public static String AUDIO_TONE_CONS_2 = "AUDIO_TONE_CONS_2";
    public static String AUDIO_TONE_CONS_PATH = "frameworks/base/audio/Audio$Tones.java";
    public static String AUDIO_TONE_CONS_PACKAGE = "com.android.audio.Audio$Tones";

    public static String ST_MANAGER_PATH = "frameworks/base/core/storage/StorageManager.java";
    public static String ST_MANAGER_PACKAGE = "com.android.storage.StorageManager";

    public static String CONST_OUTSIDE_SCOPE = "CONST_OUTSIDE_SCOPE";
    public static String PERM_MANAGER_PATH =  "frameworks/base/core/permission/PermissionManager.java";
    public static String PERM_MANAGER_PACKAGE =  "com.android.permission.PermissionManager";

    public static String SOURCE_ANNO_PATH = "frameworks/base/anno/SourceAnno.java";
    public static String SOURCE_ANNO_PACKAGE = "com.android.anno.SourceAnno";

    public static String PERM_SOURCE_PATH = "frameworks/base/core/permission/PermissionSources.java";
    public static String PERM_SOURCE_PACKAGE = "com.android.permission.PermissionSources";

    public static String PERM_DATA_PATH = "frameworks/base/core/permission/PermissionSources$Data.java";
    public static String PERM_DATA_PACKAGE = "com.android.permission.PermissionSources$Data";

    static {
        JavaSourceData audioConstants = new JavaSourceData(AUDIO_CONS_PATH, AUDIO_CONS_PACKAGE + ".java");
        JavaSourceData audioToneConstants =
                new JavaSourceData(AUDIO_TONE_CONS_PATH, AUDIO_TONE_CONS_PACKAGE + ".java"); //f2
        JavaSourceData stManager = new JavaSourceData( ST_MANAGER_PATH, ST_MANAGER_PACKAGE + ".java");
        JavaSourceData permManager = new JavaSourceData(PERM_MANAGER_PATH, PERM_MANAGER_PACKAGE + ".java");
        JavaSourceData permSource = new JavaSourceData(PERM_SOURCE_PATH, PERM_SOURCE_PACKAGE + ".java");
        JavaSourceData permSourceData = new JavaSourceData(PERM_DATA_PATH, PERM_DATA_PACKAGE + ".java");

        JavaSourceData sourceNotPresentInClass =
                new JavaSourceData(SOURCE_ANNO_PATH, SOURCE_ANNO_PACKAGE);

        mJavaSourceData.addAll(List.of(audioConstants, audioToneConstants, stManager,
                permManager, permSource, permSourceData, sourceNotPresentInClass));

        ClassDependencyData audioConstantsDeps =
                new ClassDependencyData(AUDIO_CONS_PACKAGE + ".java",
                        AUDIO_CONS_PACKAGE, new HashSet<>(), false,
                        new HashSet<>(List.of(AUDIO_CONS)), new HashSet<>());

        ClassDependencyData audioToneConstantsDeps =
                new ClassDependencyData(AUDIO_TONE_CONS_PACKAGE + ".java",
                        AUDIO_TONE_CONS_PACKAGE, new HashSet<>(), false,
                        new HashSet<>(List.of(AUDIO_TONE_CONS_1, AUDIO_TONE_CONS_2)),
                        new HashSet<>());

        ClassDependencyData stManagerDeps =
                new ClassDependencyData(ST_MANAGER_PACKAGE + ".java",
                        ST_MANAGER_PACKAGE, new HashSet<>(List.of(PERM_SOURCE_PACKAGE)), false,
                        new HashSet<>(), new HashSet<>(List.of(AUDIO_CONS, AUDIO_TONE_CONS_1)));

        ClassDependencyData permManagerDeps =
                new ClassDependencyData(PERM_MANAGER_PACKAGE + ".java", PERM_MANAGER_PACKAGE,
                        new HashSet<>(List.of(PERM_SOURCE_PACKAGE, PERM_DATA_PACKAGE)), false,
                        new HashSet<>(), new HashSet<>(List.of(CONST_OUTSIDE_SCOPE)));

        ClassDependencyData permSourceDeps =
                new ClassDependencyData(PERM_SOURCE_PACKAGE + ".java",
                        PERM_SOURCE_PACKAGE, new HashSet<>(), false,
                        new HashSet<>(), new HashSet<>());

        ClassDependencyData permSourceDataDeps =
                new ClassDependencyData(PERM_DATA_PACKAGE + ".java",
                        PERM_DATA_PACKAGE, new HashSet<>(), false,
                        new HashSet<>(), new HashSet<>());

        mClassDependencyData.addAll(List.of(audioConstantsDeps, audioToneConstantsDeps,
                stManagerDeps, permManagerDeps, permSourceDeps, permSourceDataDeps));
    }

    @BeforeClass
    public static void beforeAll(){
        mFileDependencyMap = buildActualDepsMap(
                new DependencyMapper(mClassDependencyData, mJavaSourceData).buildDependencyMaps());
    }

    @Test
    public void testFileDependencies() {
        // Test for AUDIO_CONS_PATH
        DependencyProto.FileDependency audioDepsActual = mFileDependencyMap.get(AUDIO_CONS_PATH);
        assertNotNull(AUDIO_CONS_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 0 dependencies.
        validateDependencies(audioDepsActual, AUDIO_CONS_PATH, 0, new ArrayList<>());

        // Test for AUDIO_TONE_CONS_PATH
        DependencyProto.FileDependency audioToneDepsActual =
                mFileDependencyMap.get(AUDIO_TONE_CONS_PATH);
        assertNotNull(AUDIO_TONE_CONS_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 0 dependencies.
        validateDependencies(audioToneDepsActual, AUDIO_TONE_CONS_PATH, 0, new ArrayList<>());

        // Test for ST_MANAGER_PATH
        DependencyProto.FileDependency stManagerDepsActual =
                mFileDependencyMap.get(ST_MANAGER_PATH);
        assertNotNull(ST_MANAGER_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 3 dependencies.
        validateDependencies(stManagerDepsActual, ST_MANAGER_PATH, 3,
                new ArrayList<>(List.of(AUDIO_CONS_PATH, AUDIO_TONE_CONS_PATH, PERM_SOURCE_PATH)));

        // Test for PERM_MANAGER_PATH
        DependencyProto.FileDependency permManagerDepsActual =
                mFileDependencyMap.get(PERM_MANAGER_PATH);
        assertNotNull(PERM_MANAGER_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 2 dependencies.
        validateDependencies(permManagerDepsActual, PERM_MANAGER_PATH, 2,
                new ArrayList<>(List.of(PERM_SOURCE_PATH, PERM_DATA_PATH)));

        // Test for PERM_SOURCE_PATH
        DependencyProto.FileDependency permSourceDepsActual =
                mFileDependencyMap.get(PERM_SOURCE_PATH);
        assertNotNull(PERM_SOURCE_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 0 dependencies.
        validateDependencies(permSourceDepsActual, PERM_SOURCE_PATH, 0, new ArrayList<>());

        // Test for PERM_DATA_PATH
        DependencyProto.FileDependency permDataDepsActual =
                mFileDependencyMap.get(PERM_DATA_PATH);
        assertNotNull(PERM_DATA_PATH + " not found in dependencyList", audioDepsActual);
        // This file should have 0 dependencies.
        validateDependencies(permDataDepsActual, PERM_DATA_PATH, 0, new ArrayList<>());
    }

    private void validateDependencies(DependencyProto.FileDependency dependency, String fileName, int fileDepsCount, List<String> fileDeps) {
        assertEquals(fileName + " does not have expected dependencies", fileDepsCount, dependency.getFileDependenciesCount());
        assertTrue(fileName + " does not have expected dependencies", dependency.getFileDependenciesList().containsAll(fileDeps));
    }

    private static Map<String, DependencyProto.FileDependency> buildActualDepsMap(
            DependencyProto.FileDependencyList fileDependencyList) {
        Map<String, DependencyProto.FileDependency> dependencyMap = new HashMap<>();
        for (DependencyProto.FileDependency fileDependency : fileDependencyList.getFileDependencyList()) {
            if (fileDependency.getFilePath().equals(AUDIO_CONS_PATH)) {
                dependencyMap.put(AUDIO_CONS_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(AUDIO_TONE_CONS_PATH)) {
                dependencyMap.put(AUDIO_TONE_CONS_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(ST_MANAGER_PATH)) {
                dependencyMap.put(ST_MANAGER_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(PERM_MANAGER_PATH)) {
                dependencyMap.put(PERM_MANAGER_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(PERM_SOURCE_PATH)) {
                dependencyMap.put(PERM_SOURCE_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(PERM_DATA_PATH)) {
                dependencyMap.put(PERM_DATA_PATH, fileDependency);
            }
            if (fileDependency.getFilePath().equals(SOURCE_ANNO_PATH)) {
                dependencyMap.put(SOURCE_ANNO_PATH, fileDependency);
            }
        }
        assertFalse(SOURCE_ANNO_PATH + " found in dependencyList",
                dependencyMap.containsKey(SOURCE_ANNO_PATH));
        return dependencyMap;
    }
}
