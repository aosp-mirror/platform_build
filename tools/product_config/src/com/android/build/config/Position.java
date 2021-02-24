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

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Position in a source file.
 */
public class Position implements Comparable<Position> {
    /**
     * Sentinel line number for when there is no known line number.
     */
    public static final int NO_LINE = -1;

    private static final Pattern REGEX = Pattern.compile("([^:]*)(?::(\\d)*)?:?\\s*");
    public static final String UNKNOWN = "<unknown>";

    private final String mFile;
    private final int mLine;

    public Position() {
        mFile = null;
        mLine = NO_LINE;
    }

    public Position(String file) {
        mFile = file;
        mLine = NO_LINE;
    }

    public Position(String file, int line) {
        if (line < NO_LINE) {
            throw new IllegalArgumentException("Negative line number. file=" + file
                    + " line=" + line);
        }
        mFile = file;
        mLine = line;
    }

    public int compareTo(Position that) {
        int result = mFile.compareTo(that.mFile);
        if (result != 0) {
            return result;
        }
        return mLine - that.mLine;
    }

    public String getFile() {
        return mFile;
    }

    public int getLine() {
        return mLine;
    }

    /**
     * Return a Position object from a string containing <filename>:<line>, or the default
     * Position(null, NO_LINE) if the string can't be parsed.
     */
    public static Position parse(String str) {
        final Matcher m = REGEX.matcher(str);
        if (!m.matches()) {
            return new Position();
        }
        String filename = m.group(1);
        if (filename.length() == 0 || UNKNOWN.equals(filename)) {
            filename = null;
        }
        String lineString = m.group(2);
        int line;
        if (lineString == null || lineString.length() == 0) {
            line = NO_LINE;
        } else {
            try {
                line = Integer.parseInt(lineString);
            } catch (NumberFormatException ex) {
                line = NO_LINE;
            }
        }
        return new Position(filename, line);
    }

    @Override
    public String toString() {
      if (mFile == null && mLine == NO_LINE) {
        return "";
      } else if (mFile == null && mLine != NO_LINE) {
        return UNKNOWN + ":" + mLine + ": ";
      } else if (mFile != null && mLine == NO_LINE) {
        return mFile + ": ";
      } else { // if (mFile != null && mLine != NO_LINE)
        return mFile + ':' + mLine + ": ";
      }
    }
}
