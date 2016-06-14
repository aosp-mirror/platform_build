/*
 * Copyright (C) 2016 The Android Open Source Project
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

package com.android.apksigner.core.internal.jar;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.jar.Attributes;

/**
 * JAR manifest and signature file parser.
 *
 * <p>These files consist of a main section followed by individual sections. Individual sections
 * are named, their names referring to JAR entries.
 *
 * @see <a href="https://docs.oracle.com/javase/8/docs/technotes/guides/jar/jar.html#JAR_Manifest">JAR Manifest format</a>
 */
public class ManifestParser {

    private final byte[] mManifest;
    private int mOffset;
    private int mEndOffset;

    private String mBufferedLine;

    /**
     * Constructs a new {@code ManifestParser} with the provided input.
     */
    public ManifestParser(byte[] data) {
        this(data, 0, data.length);
    }

    /**
     * Constructs a new {@code ManifestParser} with the provided input.
     */
    public ManifestParser(byte[] data, int offset, int length) {
        mManifest = data;
        mOffset = offset;
        mEndOffset = offset + length;
    }

    /**
     * Returns the remaining sections of this file.
     */
    public List<Section> readAllSections() {
        List<Section> sections = new ArrayList<>();
        Section section;
        while ((section = readSection()) != null) {
            sections.add(section);
        }
        return sections;
    }

    /**
     * Returns the next section from this file or {@code null} if end of file has been reached.
     */
    public Section readSection() {
        // Locate the first non-empty line
        int sectionStartOffset;
        String attr;
        do {
            sectionStartOffset = mOffset;
            attr = readAttribute();
            if (attr == null) {
                return null;
            }
        } while (attr.length() == 0);
        List<Attribute> attrs = new ArrayList<>();
        attrs.add(parseAttr(attr));

        // Read attributes until end of section reached
        while (true) {
            attr = readAttribute();
            if ((attr == null) || (attr.length() == 0)) {
                // End of section
                break;
            }
            attrs.add(parseAttr(attr));
        }

        int sectionEndOffset = mOffset;
        int sectionSizeBytes = sectionEndOffset - sectionStartOffset;

        return new Section(sectionStartOffset, sectionSizeBytes, attrs);
    }

    private static Attribute parseAttr(String attr) {
        int delimiterIndex = attr.indexOf(':');
        if (delimiterIndex == -1) {
            return new Attribute(attr.trim(), "");
        } else {
            return new Attribute(
                    attr.substring(0, delimiterIndex).trim(),
                    attr.substring(delimiterIndex + 1).trim());
        }
    }

    /**
     * Returns the next attribute or empty {@code String} if end of section has been reached or
     * {@code null} if end of input has been reached.
     */
    private String readAttribute() {
        // Check whether end of section was reached during previous invocation
        if ((mBufferedLine != null) && (mBufferedLine.length() == 0)) {
            mBufferedLine = null;
            return "";
        }

        // Read the next line
        String line = readLine();
        if (line == null) {
            // End of input
            if (mBufferedLine != null) {
                String result = mBufferedLine;
                mBufferedLine = null;
                return result;
            }
            return null;
        }

        // Consume the read line
        if (line.length() == 0) {
            // End of section
            if (mBufferedLine != null) {
                String result = mBufferedLine;
                mBufferedLine = "";
                return result;
            }
            return "";
        }
        StringBuilder attrLine;
        if (mBufferedLine == null) {
            attrLine = new StringBuilder(line);
        } else {
            if (!line.startsWith(" ")) {
                // The most common case: buffered line is a full attribute
                String result = mBufferedLine;
                mBufferedLine = line;
                return result;
            }
            attrLine = new StringBuilder(mBufferedLine);
            mBufferedLine = null;
            attrLine.append(line.substring(1));
        }

        // Everything's buffered in attrLine now. mBufferedLine is null

        // Read more lines
        while (true) {
            line = readLine();
            if (line == null) {
                // End of input
                return attrLine.toString();
            } else if (line.length() == 0) {
                // End of section
                mBufferedLine = ""; // make this method return "end of section" next time
                return attrLine.toString();
            }
            if (line.startsWith(" ")) {
                // Continuation line
                attrLine.append(line.substring(1));
            } else {
                // Next attribute
                mBufferedLine = line;
                return attrLine.toString();
            }
        }
    }

    /**
     * Returns the next line (without line delimiter characters) or {@code null} if end of input has
     * been reached.
     */
    private String readLine() {
        if (mOffset >= mEndOffset) {
            return null;
        }
        int startOffset = mOffset;
        int newlineStartOffset = -1;
        int newlineEndOffset = -1;
        for (int i = startOffset; i < mEndOffset; i++) {
            byte b = mManifest[i];
            if (b == '\r') {
                newlineStartOffset = i;
                int nextIndex = i + 1;
                if ((nextIndex < mEndOffset) && (mManifest[nextIndex] == '\n')) {
                    newlineEndOffset = nextIndex + 1;
                    break;
                }
                newlineEndOffset = nextIndex;
                break;
            } else if (b == '\n') {
                newlineStartOffset = i;
                newlineEndOffset = i + 1;
                break;
            }
        }
        if (newlineStartOffset == -1) {
            newlineStartOffset = mEndOffset;
            newlineEndOffset = mEndOffset;
        }
        mOffset = newlineEndOffset;

        int lineLengthBytes = newlineStartOffset - startOffset;
        if (lineLengthBytes == 0) {
            return "";
        }
        return new String(mManifest, startOffset, lineLengthBytes, StandardCharsets.UTF_8);
    }


    /**
     * Attribute.
     */
    public static class Attribute {
        private final String mName;
        private final String mValue;

        /**
         * Constructs a new {@code Attribute} with the provided name and value.
         */
        public Attribute(String name, String value) {
            mName = name;
            mValue = value;
        }

        /**
         * Returns this attribute's name.
         */
        public String getName() {
            return mName;
        }

        /**
         * Returns this attribute's value.
         */
        public String getValue() {
            return mValue;
        }
    }

    /**
     * Section.
     */
    public static class Section {
        private final int mStartOffset;
        private final int mSizeBytes;
        private final String mName;
        private final List<Attribute> mAttributes;

        /**
         * Constructs a new {@code Section}.
         *
         * @param startOffset start offset (in bytes) of the section in the input file
         * @param sizeBytes size (in bytes) of the section in the input file
         * @param attrs attributes contained in the section
         */
        public Section(int startOffset, int sizeBytes, List<Attribute> attrs) {
            mStartOffset = startOffset;
            mSizeBytes = sizeBytes;
            String sectionName = null;
            if (!attrs.isEmpty()) {
                Attribute firstAttr = attrs.get(0);
                if ("Name".equalsIgnoreCase(firstAttr.getName())) {
                    sectionName = firstAttr.getValue();
                }
            }
            mName = sectionName;
            mAttributes = Collections.unmodifiableList(new ArrayList<>(attrs));
        }

        public String getName() {
            return mName;
        }

        /**
         * Returns the offset (in bytes) at which this section starts in the input.
         */
        public int getStartOffset() {
            return mStartOffset;
        }

        /**
         * Returns the size (in bytes) of this section in the input.
         */
        public int getSizeBytes() {
            return mSizeBytes;
        }

        /**
         * Returns this section's attributes, in the order in which they appear in the input.
         */
        public List<Attribute> getAttributes() {
            return mAttributes;
        }

        /**
         * Returns the value of the specified attribute in this section or {@code null} if this
         * section does not contain a matching attribute.
         */
        public String getAttributeValue(Attributes.Name name) {
            return getAttributeValue(name.toString());
        }

        /**
         * Returns the value of the specified attribute in this section or {@code null} if this
         * section does not contain a matching attribute.
         *
         * @param name name of the attribute. Attribute names are case-insensitive.
         */
        public String getAttributeValue(String name) {
            for (Attribute attr : mAttributes) {
                if (attr.getName().equalsIgnoreCase(name)) {
                    return attr.getValue();
                }
            }
            return null;
        }
    }
}
