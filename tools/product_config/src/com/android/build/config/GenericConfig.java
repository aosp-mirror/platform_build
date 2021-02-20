/*
 * Copyright (C) 2020 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.build.config;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Language-agnostic representation of a configuration statement.
 */
public class GenericConfig extends ConfigBase {
    /**
     * The config files that were imported in this config pass.
     */
    protected final TreeMap<String, ConfigFile> mConfigFiles = new TreeMap();

    /**
     * A configuration file.
     */
    public static class ConfigFile {
        /**
         * The name of the file, relative to the tree root.
         */
        private final String mFilename;

        /**
         * Sections of variable definitions and import statements. Product config
         * files will always have at least one block.
         */
        private final ArrayList<Statement> mStatements = new ArrayList();

        public ConfigFile(String filename) {
            mFilename = filename;
        }

        public String getFilename() {
            return mFilename;
        }

        public void addStatement(Statement statement) {
            mStatements.add(statement);
        }

        public ArrayList<Statement> getStatements() {
            return mStatements;
        }
    }

    /**
     * Base class for statements that appear in config files.
     */
    public static class Statement {
    }

    /**
     * A variable assignment.
     */
    public static class Assign extends Statement {
        private final String mVarName;
        private final List<Str> mValue;

        /**
         * Assignment of a single value
         */
        public Assign(String varName, Str value) {
            mVarName = varName;
            mValue = new ArrayList();
            mValue.add(value);
        }

        /**
         * Assignment referencing a previous value.
         *   VAR := $(1) $(VAR) $(2) $(VAR) $(3)
         */
        public Assign(String varName, List<Str> value) {
            mVarName = varName;
            mValue = value;
        }

        public String getName() {
            return mVarName;
        }

        public List<Str> getValue() {
            return mValue;
        }
    }

    /**
     * An $(inherit-product FILENAME) statement
     */
    public static class Inherit extends Statement {
        private final Str mFilename;

        public Inherit(Str filename) {
            mFilename = filename;
        }

        public Str getFilename() {
            return mFilename;
        }
    }

    /**
     * Adds the given config file. Returns any one previously added, or null.
     */
    public ConfigFile addConfigFile(ConfigFile file) {
        return mConfigFiles.put(file.getFilename(), file);
    }

    public TreeMap<String, ConfigFile> getFiles() {
        return mConfigFiles;
    }
}
