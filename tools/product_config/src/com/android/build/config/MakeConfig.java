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

public class MakeConfig extends ConfigBase {
    /**
     * The config files that were imported in this config pass.
     */
    protected final ArrayList<ConfigFile> mConfigFiles = new ArrayList();

    public enum BlockType {
        UNSET,
        BEFORE,
        INHERIT,
        AFTER
    }

    public static class ConfigFile {
        /**
         * The name of the file, relative to the tree root.
         */
        private final String mFilename;

        /**
         * Sections of variable definitions and import statements. Product config
         * files will always have at least one block.
         */
        private final ArrayList<Block> mBlocks = new ArrayList();

        public ConfigFile(String filename) {
            mFilename = filename;
        }

        public String getFilename() {
            return mFilename;
        }

        public void addBlock(Block block) {
            mBlocks.add(block);
        }

        public ArrayList<Block> getBlocks() {
            return mBlocks;
        }
    }

    /**
     * A set of variables that were defined.
     */
    public static class Block {
        private final BlockType mBlockType;
        private final TreeMap<String, Str> mValues = new TreeMap();
        private Str mInheritedFile;

        public Block(BlockType blockType) {
            mBlockType = blockType;
        }

        public BlockType getBlockType() {
            return mBlockType;
        }

        public void addVar(String varName, Str varValue) {
            mValues.put(varName, varValue);
        }

        public Str getVar(String varName) {
            return mValues.get(varName);
        }

        public TreeMap<String, Str> getVars() {
            return mValues;
        }

        public void setInheritedFile(Str filename) {
            mInheritedFile = filename;
        }

        public Str getInheritedFile() {
            return mInheritedFile;
        }
    }

    /**
     * Adds the given config file. Returns any one previously added, or null.
     */
    public ConfigFile addConfigFile(ConfigFile file) {
        ConfigFile prev = null;
        for (ConfigFile f: mConfigFiles) {
            if (f.getFilename().equals(file.getFilename())) {
                prev = f;
                break;
            }
        }
        mConfigFiles.add(file);
        return prev;
    }

    public List<ConfigFile> getConfigFiles() {
        return mConfigFiles;
    }

    public void printToStream(PrintStream out) {
        out.println("MakeConfig {");
        out.println("  phase: " + mPhase);
        out.println("  rootNodes: " + mRootNodes);
        out.print("  singleVars: [ ");
        for (Map.Entry<String,VarType> entry: mProductVars.entrySet()) {
            if (entry.getValue() == VarType.SINGLE) {
                out.print(entry.getKey());
                out.print(" ");
            }
        }
        out.println("]");
        out.print("  listVars: [ ");
        for (Map.Entry<String,VarType> entry: mProductVars.entrySet()) {
            if (entry.getValue() == VarType.LIST) {
                out.print(entry.getKey());
                out.print(" ");
            }
        }
        out.println("]");
        out.println("  configFiles: [");
        for (final ConfigFile configFile: mConfigFiles) {
            out.println("    ConfigFile {");
            out.println("      filename: " + configFile.getFilename());
            out.println("      blocks: [");
            for (Block block: configFile.getBlocks()) {
                out.println("        Block {");
                out.println("          type: " + block.getBlockType());
                if (block.getBlockType() == BlockType.INHERIT) {
                    out.println("          inherited: " + block.getInheritedFile());
                }
                out.println("          values: {");
                for (Map.Entry<String,Str> var: block.getVars().entrySet()) {
                    if (!var.getKey().equals("PRODUCT_PACKAGES")) {
                        continue;
                    }
                    out.println("            " + var.getKey() + ": " + var.getValue());
                }
                out.println("          }");
                out.println("        }");
            }
            out.println("      ]");
            out.println("    }");
        }
        out.println("  ] // configFiles");
        out.println("} // MakeConfig");
    }
}
