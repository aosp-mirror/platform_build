
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

import org.junit.Assert;
import org.junit.Test;

import java.io.StringReader;
import java.util.Arrays;
import java.util.List;

/**
 * Test for CSV parser class.
 */
public class CsvParserTest {
    public String listsToStrings(String[] expected, List<String> actual) {
        return "expected=" + Arrays.toString(expected)
                + " actual=" + Arrays.toString(actual.toArray());
    }

    public void assertLineEquals(CsvParser.Line actual, int lineno, String... fields) {
        if (actual.getLine() != lineno) {
            throw new RuntimeException("lineno mismatch: expected=" + lineno
                    + " actual=" + actual.getLine());
        }
        if (fields.length != actual.getFields().size()) {
            throw new RuntimeException("getFields().size() mismatch: expected=" + fields.length
                    + " actual=" + actual.getFields().size()
                    + " values: " + listsToStrings(fields, actual.getFields()));
        }
        for (int i = 0; i < fields.length; i++) {
            if (!fields[i].equals(actual.getFields().get(i))) {
                throw new RuntimeException("getFields().get(" + i + ") mismatch: expected="
                        + fields[i] + " actual=" + actual.getFields().get(i)
                        + " values: " + listsToStrings(fields, actual.getFields()));

            }
        }
    }

    @Test
    public void testEmptyString() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    ""));

        Assert.assertEquals(0, lines.size());
    }

    @Test
    public void testLexerOneCharacter() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    "a"));

        Assert.assertEquals(1, lines.size());
        assertLineEquals(lines.get(0), 1, "a");
    }

    @Test
    public void testLexerTwoFieldsNoNewline() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    "a,b"));

        Assert.assertEquals(1, lines.size());
        assertLineEquals(lines.get(0), 1, "a", "b");
    }

    @Test
    public void testLexerTwoFieldsNewline() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    "a,b\n"));

        Assert.assertEquals(1, lines.size());
        assertLineEquals(lines.get(0), 1, "a", "b");
    }

    @Test
    public void testEndsWithTwoNewlines() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    "a,b\n\n"));

        Assert.assertEquals(1, lines.size());
        assertLineEquals(lines.get(0), 1, "a", "b");
    }

    @Test
    public void testOnlyNewlines() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    "\n\n\n\n"));

        Assert.assertEquals(0, lines.size());
    }


    @Test
    public void testLexerComplex() throws Exception {
        List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                    ",\"ab\"\"\nc\",,de\n"
                    + "fg,\n"
                    + "\n"
                    + ",\n"
                    + "hijk"));

        Assert.assertEquals(4, lines.size());
        assertLineEquals(lines.get(0), 2, "", "ab\"\nc", "", "de");
        assertLineEquals(lines.get(1), 3, "fg", "");
        assertLineEquals(lines.get(2), 5, "", "");
        assertLineEquals(lines.get(3), 6, "hijk");
    }

    @Test
    public void testEndInsideQuoted() throws Exception {
        try {
            List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                        "\"asd"));
            throw new RuntimeException("Didn't throw ParseException");
        } catch (CsvParser.ParseException ex) {
            System.out.println("Caught: " + ex);
        }
    }

    @Test
    public void testCharacterAfterQuotedField() throws Exception {
        try {
            List<CsvParser.Line> lines = CsvParser.parse(new StringReader(
                        "\"\"a"));
            throw new RuntimeException("Didn't throw ParseException");
        } catch (CsvParser.ParseException ex) {
            System.out.println("Caught: " + ex);
        }
    }
}

