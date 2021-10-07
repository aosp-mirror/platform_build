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
import java.util.List;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

/**
 * Class to hold the two types of variables we support, strings and lists of strings.
 */
public class Value {
    private static final Pattern SPACES = Pattern.compile("\\s+");

    private final VarType mVarType;
    private final Str mStr;
    private final ArrayList<Str> mList;

    /**
     * Construct an appropriately typed empty value.
     */
    public Value(VarType varType) {
        mVarType = varType;
        if (varType == VarType.LIST) {
            mStr = null;
            mList = new ArrayList();
            mList.add(new Str(""));
        } else {
            mStr = new Str("");
            mList = null;
        }
    }

    public Value(VarType varType, Str str) {
        mVarType = varType;
        mStr = str;
        mList = null;
    }

    public Value(List<Str> list) {
        mVarType = VarType.LIST;
        mStr = null;
        mList = new ArrayList(list);
    }

    public VarType getVarType() {
        return mVarType;
    }

    public Str getStr() {
        return mStr;
    }

    public List<Str> getList() {
        return mList;
    }

    /**
     * Normalize a string that is behaving as a list.
     */
    public static String normalize(String str) {
        if (str == null) {
            return null;
        }
        return SPACES.matcher(str.trim()).replaceAll(" ").trim();
    }

    /**
     * Normalize a string that is behaving as a list.
     */
    public static Str normalize(Str str) {
        if (str == null) {
            return null;
        }
        return new Str(str.getPosition(), normalize(str.toString()));
    }

    /**
     * Normalize a this Value into the same format as normalize(Str).
     */
    public static Str normalize(Value val) {
        if (val == null) {
            return null;
        }
        if (val.mStr != null) {
            return normalize(val.mStr);
        }

        if (val.mList.size() == 0) {
            return new Str("");
        }

        StringBuilder result = new StringBuilder();
        final int size = val.mList.size();
        boolean first = true;
        for (int i = 0; i < size; i++) {
            String s = val.mList.get(i).toString().trim();
            if (s.length() > 0) {
                if (!first) {
                    result.append(" ");
                } else {
                    first = false;
                }
                result.append(s);
            }
        }

        // Just use the first item's position.
        return new Str(val.mList.get(0).getPosition(), result.toString());
    }

    /**
     * Put each word in 'str' on its own line in make format. If 'val' is null,
     * 'nullValue' is returned.
     */
    public static String oneLinePerWord(Value val, String nullValue) {
        if (val == null) {
            return nullValue;
        }
        final String s = normalize(val).toString();
        final Matcher m = SPACES.matcher(s);
        final StringBuilder result = new StringBuilder();
        if (s.length() > 0 && (val.mVarType == VarType.LIST || m.find())) {
            result.append("\\\n  ");
        }
        result.append(m.replaceAll(" \\\\\n  "));
        return result.toString();
    }

    /**
     * Put each word in 'str' on its own line in make format. If 'str' is null,
     * nullValue is returned.
     */
    public static String oneLinePerWord(Str str, String nullValue) {
        if (str == null) {
            return nullValue;
        }
        final Matcher m = SPACES.matcher(normalize(str.toString()));
        final StringBuilder result = new StringBuilder();
        if (m.find()) {
            result.append("\\\n  ");
        }
        result.append(m.replaceAll(" \\\\\n  "));
        return result.toString();
    }

    /**
     * Return a string representing this value with detailed debugging information.
     */
    public static String debugString(Value val) {
        if (val == null) {
            return "null";
        }

        final StringBuilder str = new StringBuilder("Value(");
        if (val.mStr != null) {
            str.append("mStr=");
            str.append("\"");
            str.append(val.mStr.toString());
            str.append("\"");
            if (false) {
                str.append(" (");
                str.append(val.mStr.getPosition().toString());
                str.append(")");
            }
        }
        if (val.mList != null) {
            str.append("mList=");
            str.append("[");
            for (Str s: val.mList) {
                str.append(" \"");
                str.append(s.toString());
                if (false) {
                    str.append("\" (");
                    str.append(s.getPosition().toString());
                    str.append(")");
                } else {
                    str.append("\"");
                }
            }
            str.append(" ]");
        }
        str.append(")");
        return str.toString();
    }

    /**
     * Get the Positions of all of the parts of this Value.
     */
    public List<Position> getPositions() {
        List<Position> result = new ArrayList();
        if (mStr != null) {
            result.add(mStr.getPosition());
        }
        if (mList != null) {
            for (Str str: mList) {
                result.add(str.getPosition());
            }
        }
        return result;
    }
}

