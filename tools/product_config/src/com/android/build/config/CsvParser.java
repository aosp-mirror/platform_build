
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
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * A CSV parser.
 */
public class CsvParser {
    /**
     * Internal string buffer grows by this amount.
     */
    private static final int CHUNK_SIZE = 64 * 1024;

    /**
     * Error parsing.
     */
    public static class ParseException extends Exception {
        private int mLine;
        private int mColumn;

        public ParseException(int line, int column, String message) {
            super(message);
            mLine = line;
            mColumn = column;
        }

        /**
         * Line number in source file.
         */
        public int getLine() {
            return mLine;
        }

        /**
         * Column in source file.
         */
        public int getColumn() {
            return mColumn;
        }
    }

    public static class Line {
        private final int mLineNumber;
        private final List<String> mFields;

        Line(int lineno, List<String> fields) {
            mLineNumber = lineno;
            mFields = fields;
        }

        public int getLine() {
            return mLineNumber;
        }

        public List<String> getFields() {
            return mFields;
        }
    }

    // Parser States
    private static final int STATE_START_LINE = 0;
    private static final int STATE_START_FIELD = 1;
    private static final int STATE_INSIDE_QUOTED_FIELD = 2;
    private static final int STATE_FIRST_QUOTATION_MARK = 3;
    private static final int STATE_INSIDE_UNQUOTED_FIELD = 4;
    private static final int STATE_DONE = 5;

    // Parser Actions
    private static final int ACTION_APPEND_CHAR = 1;
    private static final int ACTION_FIELD_COMPLETE = 2;
    private static final int ACTION_LINE_COMPLETE = 4;

    /**
     * Constructor.
     */
    private CsvParser() {
    }

    /**
     * Reads CSV and returns a list of Line objects.
     *
     * Handles newlines inside fields quoted with double quotes (").
     *
     * Doesn't report blank lines, but does include empty fields.
     */
    public static List<Line> parse(Reader reader)
            throws ParseException, IOException {
        ArrayList<Line> result = new ArrayList();
        int line = 1;
        int column = 1;
        int pos = 0;
        char[] buf = new char[CHUNK_SIZE];
        HashMap<String,String> stringPool = new HashMap();
        ArrayList<String> fields = new ArrayList();

        int state = STATE_START_LINE;
        while (state != STATE_DONE) {
            int c = reader.read();
            int action = 0;

            if (state == STATE_START_LINE) {
                if (c <= 0) {
                    // No data, skip ACTION_LINE_COMPLETE.
                    state = STATE_DONE;
                } else if (c == '"') {
                    state = STATE_INSIDE_QUOTED_FIELD;
                } else if (c == ',') {
                    action = ACTION_FIELD_COMPLETE;
                    state = STATE_START_FIELD;
                } else if (c == '\n') {
                    // Consume the newline, state stays STATE_START_LINE.
                } else {
                    action = ACTION_APPEND_CHAR;
                    state = STATE_INSIDE_UNQUOTED_FIELD;
                }
            } else if (state == STATE_START_FIELD) {
                if (c <= 0) {
                    // Field will be empty
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_DONE;
                } else if (c == '"') {
                    state = STATE_INSIDE_QUOTED_FIELD;
                } else if (c == ',') {
                    action = ACTION_FIELD_COMPLETE;
                    state = STATE_START_FIELD;
                } else if (c == '\n') {
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_START_LINE;
                } else {
                    action = ACTION_APPEND_CHAR;
                    state = STATE_INSIDE_UNQUOTED_FIELD;
                }
            } else if (state == STATE_INSIDE_QUOTED_FIELD) {
                if (c <= 0) {
                    throw new ParseException(line, column,
                            "Bad input: End of input inside quoted field.");
                } else if (c == '"') {
                    state = STATE_FIRST_QUOTATION_MARK;
                } else {
                    action = ACTION_APPEND_CHAR;
                }
            } else if (state == STATE_FIRST_QUOTATION_MARK) {
                if (c <= 0) {
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_DONE;
                } else if (c == '"') {
                    action = ACTION_APPEND_CHAR;
                    state = STATE_INSIDE_QUOTED_FIELD;
                } else if (c == ',') {
                    action = ACTION_FIELD_COMPLETE;
                    state = STATE_START_FIELD;
                } else if (c == '\n') {
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_START_LINE;
                } else {
                    throw new ParseException(line, column,
                            "Bad input: Character after field ended or unquoted '\"'.");
                }
            } else if (state == STATE_INSIDE_UNQUOTED_FIELD) {
                if (c <= 0) {
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_DONE;
                } else if (c == ',') {
                    action = ACTION_FIELD_COMPLETE;
                    state = STATE_START_FIELD;
                } else if (c == '\n') {
                    action = ACTION_FIELD_COMPLETE | ACTION_LINE_COMPLETE;
                    state = STATE_START_LINE;
                } else {
                    action = ACTION_APPEND_CHAR;
                }
            }

            if ((action & ACTION_APPEND_CHAR) != 0) {
                // Reallocate buffer if necessary. Hopefully not often because CHUNK_SIZE is big.
                if (pos >= buf.length) {
                    char[] old = buf;
                    buf = new char[old.length + CHUNK_SIZE];
                    System.arraycopy(old, 0, buf, 0, old.length);
                }
                // Store the character
                buf[pos] = (char)c;
                pos++;
            }
            if ((action & ACTION_FIELD_COMPLETE) != 0) {
                // A lot of the strings are duplicated, so pool them to reduce peak memory
                // usage. This could be made slightly better by having a custom key class
                // that does the lookup without making a new String that gets immediately
                // thrown away.
                String field = new String(buf, 0, pos);
                final String cached = stringPool.get(field);
                if (cached == null) {
                    stringPool.put(field, field);
                } else {
                    field = cached;
                }
                fields.add(field);
                pos = 0;
            }
            if ((action & ACTION_LINE_COMPLETE) != 0) {
                // Only report lines with any contents
                if (fields.size() > 0) {
                    result.add(new Line(line, fields));
                    fields = new ArrayList();
                }
            }

            if (c == '\n') {
                line++;
                column = 1;
            } else {
                column++;
            }
        }

        return result;
    }
}
