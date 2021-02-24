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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Pattern;

public class FlattenConfig {
    private static final Pattern RE_SPACE = Pattern.compile("\\p{Space}+");
    private static final String PRODUCTS_PREFIX = "PRODUCTS";

    private final Errors mErrors;
    private final GenericConfig mGenericConfig;
    private final Map<String, GenericConfig.ConfigFile> mGenericConfigs;
    private final FlatConfig mResult = new FlatConfig();
    private final Map<String, Value> mVariables;
    /**
     * Files that have been visited, to prevent infinite recursion. There are no
     * conditionals at this point in the processing, so we don't need a stack, just
     * a single set.
     */
    private final Set<Str> mStack = new HashSet();


    private FlattenConfig(Errors errors, GenericConfig genericConfig) {
        mErrors = errors;
        mGenericConfig = genericConfig;
        mGenericConfigs = genericConfig.getFiles();
        mVariables = mResult.getValues();

        // Base class fields
        mResult.copyFrom(genericConfig);
    }

    /**
     * Flatten a GenericConfig to a FlatConfig.
     *
     * Makes three passes through the genericConfig, one to flatten the single variables,
     * one to flatten the list variables, and one to flatten the unknown variables. Each
     * has a slightly different algorithm.
     */
    public static FlatConfig flatten(Errors errors, GenericConfig genericConfig) {
        final FlattenConfig flattener = new FlattenConfig(errors, genericConfig);
        return flattener.flattenImpl();
    }

    private FlatConfig flattenImpl() {
        final List<String> rootNodes = mGenericConfig.getRootNodes();
        if (rootNodes.size() == 0) {
            mErrors.ERROR_DUMPCONFIG.add("No root nodes in PRODUCTS phase.");
            return null;
        } else if (rootNodes.size() != 1) {
            final StringBuilder msg = new StringBuilder(
                    "Ignoring extra root nodes in PRODUCTS phase. All nodes are:");
            for (final String rn: rootNodes) {
                msg.append(' ');
                msg.append(rn);
            }
            mErrors.WARNING_DUMPCONFIG.add(msg.toString());
        }
        final String root = rootNodes.get(0);

        // TODO: Do we need to worry about the initial state of variables? Anything
        // that from the product config

        flattenListVars(root);
        flattenSingleVars(root);
        flattenUnknownVars(root);
        flattenInheritsFrom(root);

        setDefaultKnownVars();

        // TODO: This only supports the single product mode of import-nodes, which is all the
        // real build does. m product-graph and friends will have to be rewritten.
        mVariables.put("PRODUCTS", new Value(VarType.UNKNOWN, new Str(root)));

        return mResult;
    }

    interface AssignCallback {
        void onAssignStatement(GenericConfig.Assign assign);
    }

    interface InheritCallback {
        void onInheritStatement(GenericConfig.Inherit assign);
    }

    /**
     * Do a bunch of validity checks, and then iterate through each of the statements
     * in the given file.  For Assignments, the callback is only called for variables
     * matching varType.
     *
     * Adds makefiles which have been traversed to the 'seen' set, and will not traverse
     * into an inherit statement if its makefile has already been seen.
     */
    private void forEachStatement(Str filename, VarType varType, Set<String> seen,
            AssignCallback assigner, InheritCallback inheriter) {
        if (mStack.contains(filename)) {
            mErrors.ERROR_INFINITE_RECURSION.add(filename.getPosition(),
                    "File is already in the inherit-product stack: " + filename);
            return;
        }

        mStack.add(filename);
        try {
            final GenericConfig.ConfigFile genericFile = mGenericConfigs.get(filename.toString());

            if (genericFile == null) {
                mErrors.ERROR_MISSING_CONFIG_FILE.add(filename.getPosition(),
                        "Unable to find config file: " + filename);
                return;
            }

            for (final GenericConfig.Statement statement: genericFile.getStatements()) {
                if (statement instanceof GenericConfig.Assign) {
                    if (assigner != null) {
                        final GenericConfig.Assign assign = (GenericConfig.Assign)statement;
                        final String varName = assign.getName();

                        // Assert that we're not stomping on another variable, which
                        // really should be impossible at this point.
                        assertVarType(filename, varName);

                        if (mGenericConfig.getVarType(varName) == varType) {
                            assigner.onAssignStatement(assign);
                        }
                    }
                } else if (statement instanceof GenericConfig.Inherit) {
                    if (inheriter != null) {
                        final GenericConfig.Inherit inherit = (GenericConfig.Inherit)statement;
                        if (seen != null) {
                            if (seen.contains(inherit.getFilename().toString())) {
                                continue;
                            }
                            seen.add(inherit.getFilename().toString());
                        }
                        inheriter.onInheritStatement(inherit);
                    }
                }
            }
        } finally {
            // Also executes after return statements, so we always remove this.
            mStack.remove(filename);
        }
    }

    /**
     * Call 'inheriter' for each child of 'filename' in alphabetical order.
     */
    private void forEachInheritAlpha(final Str filename, VarType varType, Set<String> seen,
            InheritCallback inheriter) {
        final TreeMap<Str, GenericConfig.Inherit> alpha = new TreeMap();
        forEachStatement(filename, varType, null, null,
                (inherit) -> {
                    alpha.put(inherit.getFilename(), inherit);
                });
        for (final GenericConfig.Inherit inherit: alpha.values()) {
            // Handle 'seen' here where we actaully call back, not before, so that
            // the proper traversal order is preserved.
            if (seen != null) {
                if (seen.contains(inherit.getFilename().toString())) {
                    continue;
                }
                seen.add(inherit.getFilename().toString());
            }
            inheriter.onInheritStatement(inherit);
        }
    }

    /**
     * Traverse the inheritance hierarchy, setting list-value product config variables.
     */
    private void flattenListVars(final String filename) {
        Map<String, Value> vars = flattenListVars(new Str(filename), new HashSet());
        // Add the result of the recursion to mVariables. We know there will be
        // no collisions because this function only handles list variables.
        for (Map.Entry<String, Value> entry: vars.entrySet()) {
            mVariables.put(entry.getKey(), entry.getValue());
        }
    }

    /**
     * Return the variables defined, recursively, by 'filename.' The 'seen' set
     * accumulates which nodes have been visited, as each is only done once.
     *
     * This convoluted algorithm isn't ideal, but it matches what is in node_fns.mk.
     */
    private Map<String, Value> flattenListVars(final Str filename, Set<String> seen) {
        Map<String, Value> result = new HashMap();

        // Recurse into our children first in alphabetical order, building a map of
        // that filename to its flattened values.  The order matters here because
        // we will only look at each child once, and when a file appears multiple
        // times, its variables must have the right set, based on whether it's been
        // seen before. This preserves the order from node_fns.mk.

        // Child filename --> { varname --> value }
        final Map<Str, Map<String, Value>> children = new HashMap();
        forEachInheritAlpha(filename, VarType.LIST, seen,
                (inherit) -> {
                    final Str child = inherit.getFilename();
                    children.put(child, flattenListVars(child, seen));
                });

        // Now, traverse the values again in the original source order to concatenate the values.
        // Note that the contcatenation order is *different* from the inherit order above.
        forEachStatement(filename, VarType.LIST, null,
                (assign) -> {
                    assignToListVar(result, assign.getName(), assign.getValue());
                },
                (inherit) -> {
                    final Map<String, Value> child = children.get(inherit.getFilename());
                    // child == null happens if this node has been visited before.
                    if (child != null) {
                        for (Map.Entry<String, Value> entry: child.entrySet()) {
                            final String varName = entry.getKey();
                            final Value varVal = entry.getValue();
                            appendToListVar(result, varName, varVal.getList());
                        }
                    }
                });

        return result;
    }

    /**
     * Traverse the inheritance hierarchy, setting single-value product config variables.
     */
    private void flattenSingleVars(final String filename) {
        flattenSingleVars(new Str(filename), new HashSet(), new HashSet());
    }

    private void flattenSingleVars(final Str filename, Set<String> seen1, Set<String> seen2) {
        // flattenSingleVars has two loops.  The first sets all variables that are
        // defined for *this* file.  The second traverses through the inheritance,
        // to fill in values that weren't defined in this file.  The first appearance of
        // the variable is the one that wins.

        forEachStatement(filename, VarType.SINGLE, seen1,
                (assign) -> {
                    final String varName = assign.getName();
                    Value v = mVariables.get(varName);
                    // Only take the first value that we see for single variables.
                    Value value = mVariables.get(varName);
                    if (!mVariables.containsKey(varName)) {
                        final List<Str> valueList = assign.getValue();
                        // There should never be more than one item in this list, because
                        // SINGLE values should never be appended to.
                        if (valueList.size() != 1) {
                            final StringBuilder positions = new StringBuilder("[");
                            for (Str s: valueList) {
                                positions.append(s.getPosition());
                            }
                            positions.append(" ]");
                            throw new RuntimeException("Value list found for SINGLE variable "
                                    + varName + " size=" + valueList.size()
                                    + "positions=" + positions.toString());
                        }
                        mVariables.put(varName,
                                new Value(VarType.SINGLE,
                                    valueList.get(0)));
                    }
                }, null);

        forEachInheritAlpha(filename, VarType.SINGLE, seen2,
                (inherit) -> {
                    flattenSingleVars(inherit.getFilename(), seen1, seen2);
                });
    }

    /**
     * Traverse the inheritance hierarchy and flatten the values
     */
    private void flattenUnknownVars(String filename) {
        flattenUnknownVars(new Str(filename), new HashSet());
    }

    private void flattenUnknownVars(final Str filename, Set<String> seen) {
        // flattenUnknownVars has two loops: First to attempt to set the variable from
        // this file, and then a second loop to handle the inheritance.  This is odd
        // but it matches the order the files are included in node_fns.mk. The last appearance
        // of the value is the one that wins.

        forEachStatement(filename, VarType.UNKNOWN, null,
                (assign) -> {
                    // Overwrite the current value with whatever is now in the file.
                    mVariables.put(assign.getName(),
                            new Value(VarType.UNKNOWN,
                                flattenAssignList(assign, new Str(""))));
                }, null);

        forEachInheritAlpha(filename, VarType.UNKNOWN, seen,
                (inherit) -> {
                    flattenUnknownVars(inherit.getFilename(), seen);
                });
    }

    String prefix = "";

    /**
     * Sets the PRODUCTS.<filename>.INHERITS_FROM variables.
     */
    private void flattenInheritsFrom(final String filename) {
        flattenInheritsFrom(new Str(filename));
    }

    /**
     * This flatten function, unlike the others visits all of the nodes regardless
     * of whether they have been seen before, because that's what the make code does.
     */
    private void flattenInheritsFrom(final Str filename) {
        // Recurse, and gather the list our chlidren
        final TreeSet<Str> children = new TreeSet();
        forEachStatement(filename, VarType.LIST, null, null,
                (inherit) -> {
                    children.add(inherit.getFilename());
                    flattenInheritsFrom(inherit.getFilename());
                });

        final String varName = "PRODUCTS." + filename + ".INHERITS_FROM";
        if (children.size() > 0) {
            // Build the space separated list.
            boolean first = true;
            final StringBuilder val = new StringBuilder();
            for (Str child: children) {
                if (first) {
                    first = false;
                } else {
                    val.append(' ');
                }
                val.append(child);
            }
            mVariables.put(varName, new Value(VarType.UNKNOWN, new Str(val.toString())));
        } else {
            // Clear whatever flattenUnknownVars happened to have put in.
            mVariables.remove(varName);
        }
    }

    /**
     * Throw an exception if there's an existing variable with a different type.
     */
    private void assertVarType(Str filename, String varName) {
        if (mGenericConfig.getVarType(varName) == VarType.UNKNOWN) {
            final Value prevValue = mVariables.get(varName);
            if (prevValue != null
                    && prevValue.getVarType() != VarType.UNKNOWN) {
                throw new RuntimeException("Mismatched var types:"
                        + " filename=" + filename
                        + " varType=" + mGenericConfig.getVarType(varName)
                        + " varName=" + varName
                        + " prevValue=" + Value.debugString(prevValue));
            }
        }
    }

    /**
     * Depending on whether the assignment is prepending, appending, setting, etc.,
     * update the value.  We can infer which of those operations it is by the length
     * and contents of the values. Each value in the list was originally separated
     * by the previous value.
     */
    private void assignToListVar(Map<String, Value> vars, String varName, List<Str> items) {
        final Value value = vars.get(varName);
        final List<Str> orig = value == null ? new ArrayList() : value.getList();
        final List<Str> result = new ArrayList();
        if (items.size() > 0) {
            for (int i = 0; i < items.size(); i++) {
                if (i != 0) {
                    result.addAll(orig);
                }
                final Str item = items.get(i);
                addWords(result, item);
            }
        }
        vars.put(varName, new Value(result));
    }

    /**
     * Appends all of the words in in 'items' to an entry in vars keyed by 'varName',
     * creating one if necessary.
     */
    private static void appendToListVar(Map<String, Value> vars, String varName, List<Str> items) {
        Value value = vars.get(varName);
        if (value == null) {
            value = new Value(new ArrayList());
            vars.put(varName, value);
        }
        final List<Str> out = value.getList();
        for (Str item: items) {
            addWords(out, item);
        }
    }

    /**
     * Split 'item' on spaces, and add each of them as a word to 'out'.
     */
    private static void addWords(List<Str> out, Str item) {
        for (String word: RE_SPACE.split(item.toString().trim())) {
            if (word.length() > 0) {
                out.add(new Str(item.getPosition(), word));
            }
        }
    }

    /**
     * Flatten the list of strings in an Assign statement, using the previous value
     * as a separator.
     */
    private Str flattenAssignList(GenericConfig.Assign assign, Str previous) {
        final StringBuilder result = new StringBuilder();
        Position position = previous.getPosition();
        final List<Str> list = assign.getValue();
        final int size = list.size();
        for (int i = 0; i < size; i++) {
            final Str item = list.get(i);
            result.append(item.toString());
            if (i != size - 1) {
                result.append(previous);
            }
            final Position pos = item.getPosition();
            if (pos != null && pos.getFile() != null) {
                position = pos;
            }
        }
        return new Str(position, result.toString());
    }

    /**
     * Make sure that each of the product config variables has a default value.
     */
    private void setDefaultKnownVars() {
        for (Map.Entry<String, VarType> entry: mGenericConfig.getProductVars().entrySet()) {
            final String varName = entry.getKey();
            final VarType varType = entry.getValue();

            final Value val = mVariables.get(varName);
            if (val == null) {
                mVariables.put(varName, new Value(varType));
            }
        }


        // TODO: These two for now as well, until we can rewrite the enforce packages exist
        // handling.
        if (!mVariables.containsKey("PRODUCT_ENFORCE_PACKAGES_EXIST")) {
            mVariables.put("PRODUCT_ENFORCE_PACKAGES_EXIST", new Value(VarType.UNKNOWN));
        }
        if (!mVariables.containsKey("PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST")) {
            mVariables.put("PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST", new Value(VarType.UNKNOWN));
        }
    }
}
