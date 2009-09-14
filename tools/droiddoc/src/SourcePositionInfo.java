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

public class SourcePositionInfo implements Comparable
{
    public SourcePositionInfo() {
        this.file = "<unknown>";
        this.line = 0;
        this.column = 0;
    }

    public SourcePositionInfo(String file, int line, int column)
    {
        this.file = file;
        this.line = line;
        this.column = column;
    }

    public SourcePositionInfo(SourcePositionInfo that)
    {
        this.file = that.file;
        this.line = that.line;
        this.column = that.column;
    }

    /**
     * Given this position and str which occurs at that position, as well as str an index into str,
     * find the SourcePositionInfo.
     *
     * @throw StringIndexOutOfBoundsException if index &gt; str.length()
     */
    public static SourcePositionInfo add(SourcePositionInfo that, String str, int index)
    {
        if (that == null) {
            return null;
        }
        int line = that.line;
        char prev = 0;
        for (int i=0; i<index; i++) {
            char c = str.charAt(i);
            if (c == '\r' || (c == '\n' && prev != '\r')) {
                line++;
            }
            prev = c;
        }
        return new SourcePositionInfo(that.file, line, 0);
    }

    public static SourcePositionInfo findBeginning(SourcePositionInfo that, String str)
    {
        if (that == null) {
            return null;
        }
        int line = that.line-1; // -1 because, well, it seems to work
        int prev = 0;
        for (int i=str.length()-1; i>=0; i--) {
            char c = str.charAt(i);
            if ((c == '\r' && prev != '\n') || (c == '\n')) {
                line--;
            }
            prev = c;
        }
        return new SourcePositionInfo(that.file, line, 0);
    }

    @Override
    public String toString()
    {
        return file + ':' + line;
    }

    public int compareTo(Object o) {
        SourcePositionInfo that = (SourcePositionInfo)o;
        int r = this.file.compareTo(that.file);
        if (r != 0) return r;
        return this.line - that.line;
    }

    public String file;
    public int line;
    public int column;
}
