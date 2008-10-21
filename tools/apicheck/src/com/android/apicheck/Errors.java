/*
 * Copyright (C) 2008 The Android Open Source Project
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

package com.android.apicheck;

import java.lang.Comparable;
import java.util.TreeSet;

public class Errors
{
    public static boolean hadError = false;
    private static boolean warningsAreErrors = false;
    private static TreeSet<Message> allErrors = new TreeSet<Message>();

    private static class Message implements Comparable {
        SourcePositionInfo pos;
        String msg;

        Message(SourcePositionInfo p, String m) {
            pos = p;
            msg = m;
        }

        public int compareTo(Object o) {
            Message that = (Message)o;
            int r = this.pos.compareTo(that.pos);
            if (r != 0) return r;
            return this.msg.compareTo(that.msg);
        }

        public String toString() {
            return this.pos.toString() + this.msg;
        }
    }

    public static void error(Error error, SourcePositionInfo where, String text) {
        if (error.level == HIDDEN) {
            return;
        }

        String which = (!warningsAreErrors && error.level == WARNING) ? " warning " : " error ";
        String message = which + error.code + ": " + text;

        if (where == null) {
            where = new SourcePositionInfo("unknown", 0, 0);
        }

        allErrors.add(new Message(where, message));

        if (error.level == ERROR || (warningsAreErrors && error.level == WARNING)) {
            hadError = true;
        }
    }

    public static void printErrors() {
        for (Message m: allErrors) {
            System.err.println(m.toString());
        }
    }

    public static int HIDDEN = 0;
    public static int WARNING = 1;
    public static int ERROR = 2;

    public static void setWarningsAreErrors(boolean val) {
        warningsAreErrors = val;
    }

    public static class Error {
        public int code;
        public int level;

        public Error(int code, int level)
        {
            this.code = code;
            this.level = level;
        }
    }

    public static Error PARSE_ERROR = new Error(1, ERROR);
    public static Error ADDED_PACKAGE = new Error(2, WARNING);
    public static Error ADDED_CLASS = new Error(3, WARNING);
    public static Error ADDED_METHOD = new Error(4, WARNING);
    public static Error ADDED_FIELD = new Error(5, WARNING);
    public static Error ADDED_INTERFACE = new Error(6, WARNING);
    public static Error REMOVED_PACKAGE = new Error(7, WARNING);
    public static Error REMOVED_CLASS = new Error(8, WARNING);
    public static Error REMOVED_METHOD = new Error(9, WARNING);
    public static Error REMOVED_FIELD = new Error(10, WARNING);
    public static Error REMOVED_INTERFACE = new Error(11, WARNING);
    public static Error CHANGED_STATIC = new Error(12, WARNING);
    public static Error CHANGED_FINAL = new Error(13, WARNING);
    public static Error CHANGED_TRANSIENT = new Error(14, WARNING);
    public static Error CHANGED_VOLATILE = new Error(15, WARNING);
    public static Error CHANGED_TYPE = new Error(16, WARNING);
    public static Error CHANGED_VALUE = new Error(17, WARNING);
    public static Error CHANGED_SUPERCLASS = new Error(18, WARNING);
    public static Error CHANGED_SCOPE = new Error(19, WARNING);
    public static Error CHANGED_ABSTRACT = new Error(20, WARNING);
    public static Error CHANGED_THROWS = new Error(21, WARNING);
    public static Error CHANGED_NATIVE = new Error(22, HIDDEN);
    public static Error CHANGED_CLASS = new Error(23, WARNING);
    
    public static Error[] ERRORS = {
        PARSE_ERROR,
        ADDED_PACKAGE,
        ADDED_CLASS,
        ADDED_METHOD,
        ADDED_FIELD,
        ADDED_INTERFACE,
        REMOVED_PACKAGE,
        REMOVED_CLASS,
        REMOVED_METHOD,
        REMOVED_FIELD,
        REMOVED_INTERFACE,
        CHANGED_STATIC,
        CHANGED_FINAL,
        CHANGED_TRANSIENT,
        CHANGED_VOLATILE,
        CHANGED_TYPE,
        CHANGED_VALUE,
        CHANGED_SUPERCLASS,
        CHANGED_SCOPE,
        CHANGED_ABSTRACT,
        CHANGED_THROWS,
        CHANGED_NATIVE,
        };

    public static boolean setErrorLevel(int code, int level) {
        for (Error e: ERRORS) {
            if (e.code == code) {
                e.level = level;
                return true;
            }
        }
        return false;
    }
}
