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

import java.io.IOException;
import java.io.Reader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Parses the output of ckati building build/make/core/dumpconfig.mk.
 *
 * The format is as follows:
 *   - All processed lines are colon (':') separated fields.
 *   - Lines before the dumpconfig_version line are dropped for forward compatibility
 *   - Lines where the first field is config_var describe variables declared in makefiles
 *     (implemented by the dump-config-vals macro)
 *          Field   Description
 *          0       "config_var" row type
 *          1       Product makefile being processed
 *          2       The variable name
 *          3       The value of the variable
 *          4       The location of the variable, as best tracked by kati
 */
public class DumpConfigParser {
    private static final boolean DEBUG = false;

    private final Errors mErrors;
    private final String mFilename;
    private final Reader mReader;

    private final Map<String,MakeConfig> mResults = new HashMap();

    private static final Pattern LIST_SEPARATOR = Pattern.compile("\\s+");

    /**
     * Constructor.
     */
    private DumpConfigParser(Errors errors, String filename, Reader reader) {
        mErrors = errors;
        mFilename = filename;
        mReader = reader;
    }

    /**
     * Parse the text into a map of the phase names to MakeConfig objects.
     */
    public static Map<String,MakeConfig> parse(Errors errors, String filename, Reader reader)
            throws CsvParser.ParseException, IOException {
        DumpConfigParser parser = new DumpConfigParser(errors, filename, reader);
        parser.parseImpl();
        return parser.mResults;
    }

    /**
     * Parse the input.
     */
    private void parseImpl() throws CsvParser.ParseException, IOException {
        final List<CsvParser.Line> lines = CsvParser.parse(mReader);
        final int lineCount = lines.size();
        int index = 0;

        int dumpconfigVersion = 0;

        // Ignore lines until until we get a dumpconfig_version line for forward compatibility.
        // In a previous life, this loop parsed from all of kati's stdout, not just the file
        // that dumpconfig.mk writes, but it's harmless to leave this loop in.  It gives us a
        // little bit of flexibility which we probably won't need anyway, this tool probably
        // won't diverge from dumpconfig.mk anyway.
        for (; index < lineCount; index++) {
            final CsvParser.Line line = lines.get(index);
            final List<String> fields = line.getFields();

            if (matchLineType(line, "dumpconfig_version", 1)) {
                try {
                    dumpconfigVersion = Integer.parseInt(fields.get(1));
                } catch (NumberFormatException ex) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "Couldn't parse dumpconfig_version: " + fields.get(1));
                }
                break;
            }
        }

        // If we never saw dumpconfig_version, there's a problem with the command, so stop.
        if (dumpconfigVersion == 0) {
            mErrors.ERROR_DUMPCONFIG.fatal(
                    new Position(mFilename),
                    "Never saw a valid dumpconfig_version line.");
        }

        // Any lines before the start signal will be dropped. We create garbage objects
        // here to avoid having to check for null everywhere.
        MakeConfig makeConfig = new MakeConfig();
        MakeConfig.ConfigFile configFile = new MakeConfig.ConfigFile("<ignored>");
        MakeConfig.Block block = new MakeConfig.Block(MakeConfig.BlockType.UNSET);
        Map<String, Str> initialVariables = new HashMap();
        Map<String, Str> finalVariables = new HashMap();

        // Number of "phases" we've seen so far.
        for (; index < lineCount; index++) {
            final CsvParser.Line line = lines.get(index);
            final List<String> fields = line.getFields();
            final String lineType = fields.get(0);

            if (matchLineType(line, "phase", 2)) {
                // Start the new one
                makeConfig = new MakeConfig();
                makeConfig.setPhase(fields.get(1));
                makeConfig.setRootNodes(splitList(fields.get(2)));
                // If there is a duplicate phase of the same name, continue parsing, but
                // don't add it.  Emit a warning.
                if (!mResults.containsKey(makeConfig.getPhase())) {
                    mResults.put(makeConfig.getPhase(), makeConfig);
                } else {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "Duplicate phase: " + makeConfig.getPhase()
                                + ". This one will be dropped.");
                }
                initialVariables = makeConfig.getInitialVariables();
                finalVariables = makeConfig.getFinalVariables();

                if (DEBUG) {
                    System.out.println("PHASE:");
                    System.out.println("  " + makeConfig.getPhase());
                    System.out.println("  " + makeConfig.getRootNodes());
                }
            } else if (matchLineType(line, "var", 2)) {
                final VarType type = "list".equals(fields.get(1)) ? VarType.LIST : VarType.SINGLE;
                makeConfig.addProductVar(fields.get(2), type);

                if (DEBUG) {
                    System.out.println("  VAR: " + type + " " + fields.get(2));
                }
            } else if (matchLineType(line, "import", 1)) {
                final List<String> importStack = splitList(fields.get(1));
                if (importStack.size() == 0) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "'import' line with empty include stack.");
                    continue;
                }

                // The beginning of importing a new file.
                configFile = new MakeConfig.ConfigFile(importStack.get(0));
                if (makeConfig.addConfigFile(configFile) != null) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "Duplicate file imported in section: " + configFile.getFilename());
                }
                // We expect a Variable block next.
                block = new MakeConfig.Block(MakeConfig.BlockType.BEFORE);
                configFile.addBlock(block);

                if (DEBUG) {
                    System.out.println("  IMPORT: " + configFile.getFilename());
                }
            } else if (matchLineType(line, "inherit", 2)) {
                final String currentFile = fields.get(1);
                final String inheritedFile = fields.get(2);
                if (!configFile.getFilename().equals(currentFile)) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "Unexpected current file in 'inherit' line '" + currentFile
                                + "' while processing '" + configFile.getFilename() + "'");
                    continue;
                }

                // There is already a file in progress, so add another var block to that.
                block = new MakeConfig.Block(MakeConfig.BlockType.INHERIT);
                // TODO: Make dumpconfig.mk also output a Position for inherit-product
                block.setInheritedFile(new Str(inheritedFile));
                configFile.addBlock(block);

                if (DEBUG) {
                    System.out.println("  INHERIT: " + inheritedFile);
                }
            } else if (matchLineType(line, "imported", 1)) {
                final List<String> importStack = splitList(fields.get(1));
                if (importStack.size() == 0) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "'imported' line with empty include stack.");
                    continue;
                }
                final String currentFile = importStack.get(0);
                if (!configFile.getFilename().equals(currentFile)) {
                    mErrors.WARNING_DUMPCONFIG.add(
                            new Position(mFilename, line.getLine()),
                            "Unexpected current file in 'imported' line '" + currentFile
                                + "' while processing '" + configFile.getFilename() + "'");
                    continue;
                }

                // There is already a file in progress, so add another var block to that.
                // This will be the last one, but will check that after parsing.
                block = new MakeConfig.Block(MakeConfig.BlockType.AFTER);
                configFile.addBlock(block);

                if (DEBUG) {
                    System.out.println("  AFTER: " + currentFile);
                }
            } else if (matchLineType(line, "val", 5)) {
                final String productMakefile = fields.get(1);
                final String blockTypeString = fields.get(2);
                final String varName = fields.get(3);
                final String varValue = fields.get(4);
                final Position pos = Position.parse(fields.get(5));
                final Str str = new Str(pos, varValue);

                if (blockTypeString.equals("initial")) {
                    initialVariables.put(varName, str);
                } else if (blockTypeString.equals("final")) {
                    finalVariables.put(varName, str);
                } else {
                    if (!productMakefile.equals(configFile.getFilename())) {
                        mErrors.WARNING_DUMPCONFIG.add(
                                new Position(mFilename, line.getLine()),
                                "Mismatched 'val' product makefile."
                                    + " Expected: " + configFile.getFilename()
                                    + " Saw: " + productMakefile);
                        continue;
                    }

                    final MakeConfig.BlockType blockType = parseBlockType(line, blockTypeString);
                    if (blockType == null) {
                        continue;
                    }
                    if (blockType != block.getBlockType()) {
                        mErrors.WARNING_DUMPCONFIG.add(
                                new Position(mFilename, line.getLine()),
                                "Mismatched 'val' block type."
                                    + " Expected: " + block.getBlockType()
                                    + " Saw: " + blockType);
                    }

                    // Add the variable to the block in progress
                    block.addVar(varName, str);
                }
            } else {
                if (DEBUG) {
                    System.out.print("# ");
                    for (int d = 0; d < fields.size(); d++) {
                        System.out.print(fields.get(d));
                        if (d != fields.size() - 1) {
                            System.out.print(",");
                        }
                    }
                    System.out.println();
                }
            }
        }
    }

    /**
     * Return true if the line type matches 'lineType' and there are at least 'fieldCount'
     * fields (not including the first field which is the line type).
     */
    private boolean matchLineType(CsvParser.Line line, String lineType, int fieldCount) {
        final List<String> fields = line.getFields();
        if (!lineType.equals(fields.get(0))) {
            return false;
        }
        if (fields.size() < (fieldCount + 1)) {
            mErrors.WARNING_DUMPCONFIG.add(new Position(mFilename, line.getLine()),
                    fields.get(0) + " line has " + fields.size() + " fields. Expected at least "
                    + (fieldCount + 1) + " fields.");
            return false;
        }
        return true;
    }

    /**
     * Split a string with space separated items (i.e. the make list format) into a List<String>.
     */
    private static List<String> splitList(String text) {
        // Arrays.asList returns a fixed-length List, so we copy it into an ArrayList to not
        // propagate that surprise detail downstream.
        return new ArrayList(Arrays.asList(LIST_SEPARATOR.split(text.trim())));
    }

    /**
     * Parse a BockType or issue a warning if it can't be parsed.
     */
    private MakeConfig.BlockType parseBlockType(CsvParser.Line line, String text) {
        if ("before".equals(text)) {
            return MakeConfig.BlockType.BEFORE;
        } else if ("inherit".equals(text)) {
            return MakeConfig.BlockType.INHERIT;
        } else if ("after".equals(text)) {
            return MakeConfig.BlockType.AFTER;
        } else {
            mErrors.WARNING_DUMPCONFIG.add(
                    new Position(mFilename, line.getLine()),
                    "Invalid block type: " + text);
            return null;
        }
    }
}
