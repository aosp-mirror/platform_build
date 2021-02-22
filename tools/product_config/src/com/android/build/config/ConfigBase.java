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
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Common parts between MakeConfig and the to-be-added GenericConfig, BazelConfig and SoongConfig.
 */
public class ConfigBase {
    protected String mPhase;
    protected List<String> mRootNodes;

    /**
     * State of the make varaible environment from before the first config file.
     */
    protected Map<String, Str> mInitialVariables = new HashMap();

    /**
     * State of the make varaible environment from after the first config file.
     */
    protected Map<String, Str> mFinalVariables = new HashMap();


    /**
     * The variables that are handled specially.
     */
    protected final TreeMap<String, VarType> mProductVars = new TreeMap();

    public void setPhase(String phase) {
        mPhase = phase;
    }

    public String getPhase() {
        return mPhase;
    }

    public void setRootNodes(List<String> filenames) {
        mRootNodes = new ArrayList(filenames);
    }

    public List<String> getRootNodes() {
        return mRootNodes;
    }

    public void addProductVar(String name, VarType type) {
        mProductVars.put(name, type);
    }

    public TreeMap<String, VarType> getProductVars() {
        return mProductVars;
    }

    public VarType getVarType(String name) {
        final VarType t = mProductVars.get(name);
        if (t != null) {
            return t;
        } else {
            return VarType.UNKNOWN;
        }
    }

    public boolean isProductVar(String name) {
        return mProductVars.get(name) != null;
    }

    /**
     * Return the state the make variable environment from before the first config file.
     */
    public Map<String, Str> getInitialVariables() {
        return mInitialVariables;
    }

    /**
     * Return the state the make variable environment from before the first config file.
     */
    public Map<String, Str> getFinalVariables() {
        return mFinalVariables;
    }

    /**
     * Copy common base class fields from that to this.
     */
    public void copyFrom(ConfigBase that) {
        setPhase(that.getPhase());
        setRootNodes(that.getRootNodes());
        for (Map.Entry<String, VarType> entry: that.getProductVars().entrySet()) {
            addProductVar(entry.getKey(), entry.getValue());
        }
        mInitialVariables = new HashMap(that.getInitialVariables());
        mFinalVariables = new HashMap(that.getFinalVariables());
    }
}
