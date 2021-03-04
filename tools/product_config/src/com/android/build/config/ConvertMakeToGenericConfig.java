/*
 * Copyright (C) 2021 The Android Open Source Project
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

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Converts a MakeConfig into a Generic config by applying heuristics about
 * the types of variable assignments that we do.
 */
public class ConvertMakeToGenericConfig {
    private final Errors mErrors;

    public ConvertMakeToGenericConfig(Errors errors) {
        mErrors = errors;
    }

    public GenericConfig convert(Map<String, MakeConfig> make) {
        final GenericConfig result = new GenericConfig();

        final MakeConfig products = make.get("PRODUCTS");
        if (products == null) {
            mErrors.ERROR_DUMPCONFIG.add("Could not find PRODUCTS phase in dumpconfig output.");
            return null;
        }

        // Base class fields
        result.copyFrom(products);

        // Each file
        for (MakeConfig.ConfigFile f: products.getConfigFiles()) {
            final GenericConfig.ConfigFile genericFile
                    = new GenericConfig.ConfigFile(f.getFilename());
            result.addConfigFile(genericFile);

            final List<MakeConfig.Block> blocks = f.getBlocks();

            // Some assertions:
            // TODO: Include better context for these errors.
            // There should always be at least a BEGIN and an AFTER, so assert this.
            if (blocks.size() < 2) {
                throw new RuntimeException("expected at least blocks.size() >= 2. Actcual size: "
                        + blocks.size());
            }
            if (blocks.get(0).getBlockType() != MakeConfig.BlockType.BEFORE) {
                throw new RuntimeException("expected first block to be BEFORE");
            }
            if (blocks.get(blocks.size() - 1).getBlockType() != MakeConfig.BlockType.AFTER) {
                throw new RuntimeException("expected first block to be AFTER");
            }
            // Everything in between should be an INHERIT block.
            for (int index = 1; index < blocks.size() - 1; index++) {
                if (blocks.get(index).getBlockType() != MakeConfig.BlockType.INHERIT) {
                    throw new RuntimeException("expected INHERIT at block " + index);
                }
            }

            // Each block represents a snapshot of the interpreter variable state (minus a few big
            // sets of variables which we don't export because they're used in the internals
            // of node_fns.mk, so we know they're not necessary here). The first (BEFORE) one
            // is everything that is set before the file is included, so it forms the base
            // for everything else.
            MakeConfig.Block prevBlock = blocks.get(0);

            for (int index = 1; index < blocks.size(); index++) {
                final MakeConfig.Block block = blocks.get(index);
                for (final Map.Entry<String, Str> entry: block.getVars().entrySet()) {
                    final String varName = entry.getKey();
                    final GenericConfig.Assign assign = convertAssignment(block.getBlockType(),
                            block.getInheritedFile(), products.getVarType(varName), varName,
                            entry.getValue(), prevBlock.getVar(varName));
                    if (assign != null) {
                        genericFile.addStatement(assign);
                    }
                }
                // Handle variables that are in prevBlock but not block -- they were
                // deleted. Is this even possible, or do they show up as ""?  We will
                // treat them as positive assigments to empty string
                for (String prevName: prevBlock.getVars().keySet()) {
                    if (!block.getVars().containsKey(prevName)) {
                        genericFile.addStatement(
                                new GenericConfig.Assign(prevName, new Str("")));
                    }
                }
                if (block.getBlockType() == MakeConfig.BlockType.INHERIT) {
                    genericFile.addStatement(
                            new GenericConfig.Inherit(block.getInheritedFile()));
                }
                // For next iteration
                prevBlock = block;
            }
        }

        // Overwrite the final variables with the ones that come from the PRODUCTS-EXPAND phase.
        // Drop the ones that were newly defined between the two phases, but leave values
        // that were modified between.  We do need to reproduce that logic in this tool.
        final MakeConfig expand = make.get("PRODUCT-EXPAND");
        if (expand == null) {
            mErrors.ERROR_DUMPCONFIG.add("Could not find PRODUCT-EXPAND phase in dumpconfig"
                    + " output.");
            return null;
        }
        final Map<String, Str> productsFinal = products.getFinalVariables();
        final Map<String, Str> expandInitial = expand.getInitialVariables();
        final Map<String, Str> expandFinal = expand.getFinalVariables();
        final Map<String, Str> finalFinal = result.getFinalVariables();
        finalFinal.clear();
        for (Map.Entry<String, Str> var: expandFinal.entrySet()) {
            final String varName = var.getKey();
            if (expandInitial.containsKey(varName) && !productsFinal.containsKey(varName)) {
                continue;
            }
            finalFinal.put(varName, var.getValue());
        }

        return result;
    }

    /**
     * Converts one variable from a MakeConfig Block into a GenericConfig Assignment.
     */
    GenericConfig.Assign convertAssignment(MakeConfig.BlockType blockType, Str inheritedFile,
            VarType varType, String varName, Str varVal, Str prevVal) {
        if (prevVal == null) {
            // New variable.
            return new GenericConfig.Assign(varName, varVal);
        } else if (!varVal.equals(prevVal)) {
            // The value changed from the last block.
            if (varVal.length() == 0) {
                // It was set to empty
                return new GenericConfig.Assign(varName, varVal);
            } else {
                // Product vars have the @inherit processing. Other vars we
                // will just ignore and put in one section at the end, based
                // on the difference between the BEFORE and AFTER blocks.
                if (varType == VarType.UNKNOWN) {
                    if (blockType == MakeConfig.BlockType.AFTER) {
                        // For UNKNOWN variables, we don't worry about the
                        // intermediate steps, just take the final value.
                        return new GenericConfig.Assign(varName, varVal);
                    } else {
                        return null;
                    }
                } else {
                    return convertInheritedVar(blockType, inheritedFile,
                            varName, varVal, prevVal);
                }
            }
        } else {
            // Variable not touched
            return null;
        }
    }

    /**
     * Handle the special inherited values, where the inherit-product puts in the
     * @inherit:... markers, adding Statements to the ConfigFile.
     */
    GenericConfig.Assign convertInheritedVar(MakeConfig.BlockType blockType, Str inheritedFile,
            String varName, Str varVal, Str prevVal) {
        String varText = varVal.toString();
        String prevText = prevVal.toString().trim();
        if (blockType == MakeConfig.BlockType.INHERIT) {
            // inherit-product appends @inherit:... so drop that.
            final String marker = "@inherit:" + inheritedFile;
            if (varText.endsWith(marker)) {
                varText = varText.substring(0, varText.length() - marker.length()).trim();
            } else {
                mErrors.ERROR_IMPROPER_PRODUCT_VAR_MARKER.add(varVal.getPosition(),
                        "Variable didn't end with marker \"" + marker + "\": " + varText);
            }
        }

        if (!varText.equals(prevText)) {
            // If the variable value was actually changed.
            final ArrayList<String> words = split(varText, prevText);
            if (words.size() == 0) {
                // Pure Assignment, none of the previous value is present.
                return new GenericConfig.Assign(varName, new Str(varVal.getPosition(), varText));
            } else {
                // Self referential value (prepend, append, both).
                if (words.size() > 2) {
                    // This is indicative of a construction that might not be quite
                    // what we want.  The above code will do something that works if it was
                    // of the form "VAR := a $(VAR) b $(VAR) c", but if the original code
                    // something else this won't work. This doesn't happen in AOSP, but
                    // it's a theoretically possibility, so someone might do it.
                    mErrors.WARNING_VARIABLE_RECURSION.add(varVal.getPosition(),
                            "Possible unsupported variable recursion: "
                                + varName + " = " + varVal + " (prev=" + prevVal + ")");
                }
                return new GenericConfig.Assign(varName, Str.toList(varVal.getPosition(), words));
            }
        } else {
            // Variable not touched
            return null;
        }
    }

    /**
     * Split 'haystack' on occurrences of 'needle'. Trims each string of whitespace
     * to preserve make list semantics.
     */
    private static ArrayList<String> split(String haystack, String needle) {
        final ArrayList<String> result = new ArrayList();
        final int needleLen = needle.length();
        if (needleLen == 0) {
            return result;
        }
        int start = 0;
        int end;
        while ((end = haystack.indexOf(needle, start)) >= 0) {
            result.add(haystack.substring(start, end).trim());
            start = end + needleLen;
        }
        result.add(haystack.substring(start).trim());
        return result;
    }
}
