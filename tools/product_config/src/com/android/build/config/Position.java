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

/**
 * Position in a source file.
 */
public class Position implements Comparable<Position> {
    /**
     * Sentinel line number for when there is no known line number.
     */
    public static final int NO_LINE = -1;

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

    @Override
    public String toString() {
      if (mFile == null && mLine == NO_LINE) {
        return "";
      } else if (mFile == null && mLine != NO_LINE) {
        return "<unknown>:" + mLine + ": ";
      } else if (mFile != null && mLine == NO_LINE) {
        return mFile + ": ";
      } else { // if (mFile != null && mLine != NO_LINE)
        return mFile + ':' + mLine + ": ";
      }
    }
}
