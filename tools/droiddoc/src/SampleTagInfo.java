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

import org.clearsilver.HDF;
import org.clearsilver.CS;

import java.io.Reader;
import java.io.IOException;
import java.io.FileReader;
import java.io.LineNumberReader;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

/*
 * SampleTagInfo copies text from a given file into the javadoc comment.
 *
 * The @include tag copies the text verbatim from the given file.
 *
 * The @sample tag copies the text from the given file, stripping leading and
 * trailing whitespace, and reducing the indent level of the text to the indent
 * level of the first non-whitespace line.
 *
 * Both tags accept either a filename and an id or just a filename.  If no id
 * is provided, the entire file is copied.  If an id is provided, the lines
 * in the given file between the first two lines containing BEGIN_INCLUDE(id)
 * and END_INCLUDE(id), for the given id, are copied.  The id may be only 
 * letters, numbers and underscore (_).
 *
 * Four examples:
 * {@include samples/ApiDemos/src/com/google/app/Notification1.java}
 * {@sample samples/ApiDemos/src/com/google/app/Notification1.java}
 * {@include samples/ApiDemos/src/com/google/app/Notification1.java Bleh}
 * {@sample samples/ApiDemos/src/com/google/app/Notification1.java Bleh}
 *
 */
public class SampleTagInfo extends TagInfo
{
    static final int STATE_BEGIN = 0;
    static final int STATE_MATCHING = 1;

    static final Pattern TEXT = Pattern.compile(
                "[\r\n \t]*([^\r\n \t]*)[\r\n \t]*([0-9A-Za-z_]*)[\r\n \t]*",
                Pattern.DOTALL);

    private static final String BEGIN_INCLUDE = "BEGIN_INCLUDE";
    private static final String END_INCLUDE = "END_INCLUDE";

    private ContainerInfo mBase;
    private String mIncluded;

    public static String escapeHtml(String str) {
        return str.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    private static boolean isIncludeLine(String str) {
        return str.indexOf(BEGIN_INCLUDE)>=0 || str.indexOf(END_INCLUDE)>=0;
    }

    SampleTagInfo(String name, String kind, String text, ContainerInfo base,
            SourcePositionInfo position)
    {
        super(name, kind, text, position);
        mBase = base;

        Matcher m = TEXT.matcher(text);
        if (!m.matches()) {
            Errors.error(Errors.BAD_INCLUDE_TAG, position, "Bad @include tag: "
                    + text);
            return;
        }
        String filename = m.group(1);
        String id = m.group(2);
        boolean trim = "@sample".equals(name);

        if (id == null || "".equals(id)) {
            mIncluded = readFile(position, filename, id, trim, true, false);
        } else {
            mIncluded = loadInclude(position, filename, id, trim);
        }

        if (mIncluded == null) {
            Errors.error(Errors.BAD_INCLUDE_TAG, position, "include tag '" + id
                    + "' not found in file: " + filename);
        }
    }

    static String getTrimString(String line)
    {
        int i = 0;
        int len = line.length();
        for (; i<len; i++) {
            char c = line.charAt(i);
            if (c != ' ' && c != '\t') {
                break;
            }
        }
        if (i == len) {
            return null;
        } else {
            return line.substring(0, i);
        }
    }

    static String loadInclude(SourcePositionInfo pos, String filename,
                                String id, boolean trim)
    {
        Reader input = null;
        StringBuilder result = new StringBuilder();

        String begin = BEGIN_INCLUDE + "(" + id + ")";
        String end = END_INCLUDE + "(" + id + ")";

        try {
            input = new FileReader(filename);
            LineNumberReader lines = new LineNumberReader(input);

            int state = STATE_BEGIN;

            int trimLength = -1;
            String trimString = null;
            int trailing = 0;

            while (true) {
                String line = lines.readLine();
                if (line == null) {
                    return null;
                }
                switch (state) {
                case STATE_BEGIN:
                    if (line.indexOf(begin) >= 0) {
                        state = STATE_MATCHING;
                    }
                    break;
                case STATE_MATCHING:
                    if (line.indexOf(end) >= 0) {
                        return result.substring(0);
                    } else {
                        boolean empty = "".equals(line.trim());
                        if (trim) {
                            if (isIncludeLine(line)) {
                                continue;
                            }
                            if (trimLength < 0 && !empty) {
                                trimString = getTrimString(line);
                                if (trimString != null) {
                                    trimLength = trimString.length();
                                }
                            }
                            if (trimLength >= 0 && line.length() > trimLength) {
                                boolean trimThisLine = true;
                                for (int i=0; i<trimLength; i++) {
                                    if (line.charAt(i) != trimString.charAt(i)){
                                        trimThisLine = false;
                                        break;
                                    }
                                }
                                if (trimThisLine) {
                                    line = line.substring(trimLength);
                                }
                            }
                            if (trimLength >= 0) {
                                if (!empty) {
                                    for (int i=0; i<trailing; i++) {
                                        result.append('\n');
                                    }
                                    line = escapeHtml(line);
                                    result.append(line);
                                    trailing = 1;  // add \n next time, maybe
                                } else {
                                    trailing++;
                                }
                            }
                        } else {
                            result.append(line);
                            result.append('\n');
                        }
                    }
                    break;
                }
            }
        }
        catch (IOException e) {
            Errors.error(Errors.BAD_INCLUDE_TAG, pos, "Error reading file for"
                    + " include \"" + id + "\" " + filename);
        }
        finally {
            if (input != null) {
                try {
                    input.close();
                }
                catch (IOException ex) {
                }
            }
        }
        Errors.error(Errors.BAD_INCLUDE_TAG, pos, "Did not find " + end
                + " in file " + filename);
        return null;
    }

    static String readFile(SourcePositionInfo pos, String filename,
                                String id, boolean trim, boolean escape,
                                boolean errorOk)
    {
        Reader input = null;
        StringBuilder result = new StringBuilder();
        int trailing = 0;
        boolean started = false;
        try {
            input = new FileReader(filename);
            LineNumberReader lines = new LineNumberReader(input);

            while (true) {
                String line = lines.readLine();
                if (line == null) {
                    break;
                }
                if (trim) {
                    if (isIncludeLine(line)) {
                        continue;
                    }
                    if (!"".equals(line.trim())) {
                        if (started) {
                            for (int i=0; i<trailing; i++) {
                                result.append('\n');
                            }
                        }
                        if (escape) {
                            line = escapeHtml(line);
                        }
                        result.append(line);
                        trailing = 1;  // add \n next time, maybe
                        started = true;
                    } else {
                        if (started) {
                            trailing++;
                        }
                    }
                } else {
                    result.append(line);
                    result.append('\n');
                }
            }
        }
        catch (IOException e) {
            if (errorOk) {
                return null;
            } else {
                Errors.error(Errors.BAD_INCLUDE_TAG, pos, "Error reading file for"
                        + " include \"" + id + "\" " + filename);
            }
        }
        finally {
            if (input != null) {
                try {
                    input.close();
                }
                catch (IOException ex) {
                }
            }
        }
        return result.substring(0);
    }

    public void makeHDF(HDF data, String base)
    {
        data.setValue(base + ".name", name());
        data.setValue(base + ".kind", kind());
        if (mIncluded != null) {
            data.setValue(base + ".text", mIncluded);
        } else {
            data.setValue(base + ".text", "INCLUDE_ERROR");
        }
    }
}

