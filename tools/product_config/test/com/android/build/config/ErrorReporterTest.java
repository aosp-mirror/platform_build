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

import java.util.HashSet;
import java.util.List;

public class ErrorReporterTest {
    /**
     * Test that errors can be recorded and retrieved.
     */
    @Test
    public void testAdding() {
        TestErrors errors = new TestErrors();

        errors.ERROR.add(new Position("a", 12), "Errrororrrr");

        Assert.assertTrue(errors.hadWarningOrError());
        Assert.assertTrue(errors.hadError());

        List<TestErrors.Entry> entries = errors.getEntries();
        Assert.assertEquals(1, entries.size());

        TestErrors.Entry entry = entries.get(0);
        Assert.assertEquals(errors.ERROR, entry.getCategory());
        Assert.assertEquals("a", entry.getPosition().getFile());
        Assert.assertEquals(12, entry.getPosition().getLine());
        Assert.assertEquals("Errrororrrr", entry.getMessage());

        Assert.assertNotEquals("", errors.getErrorMessages());
    }

    /**
     * Test that not adding an error doesn't record errors.
     */
    @Test
    public void testNoError() {
        TestErrors errors = new TestErrors();

        Assert.assertFalse(errors.hadWarningOrError());
        Assert.assertFalse(errors.hadError());
        Assert.assertEquals("", errors.getErrorMessages());
    }

    /**
     * Test that not adding a warning doesn't record errors.
     */
    @Test
    public void testWarning() {
        TestErrors errors = new TestErrors();

        errors.WARNING.add("Waaaaarninggggg");

        Assert.assertTrue(errors.hadWarningOrError());
        Assert.assertFalse(errors.hadError());
        Assert.assertNotEquals("", errors.getErrorMessages());
    }

    /**
     * Test that hidden warnings don't report.
     */
    @Test
    public void testHidden() {
        TestErrors errors = new TestErrors();

        errors.HIDDEN.add("Hidddeennn");

        Assert.assertFalse(errors.hadWarningOrError());
        Assert.assertFalse(errors.hadError());
        Assert.assertEquals("", errors.getErrorMessages());
    }

    /**
     * Test changing an error level.
     */
    @Test
    public void testSetLevel() {
        TestErrors errors = new TestErrors();
        Assert.assertEquals(TestErrors.Level.ERROR, errors.ERROR.getLevel());

        errors.ERROR.setLevel(TestErrors.Level.WARNING);

        Assert.assertEquals(TestErrors.Level.WARNING, errors.ERROR.getLevel());
    }

    /**
     * Test that changing a fixed error fails.
     */
    @Test
    public void testSetLevelFails() {
        TestErrors errors = new TestErrors();
        Assert.assertEquals(TestErrors.Level.ERROR, errors.ERROR_FIXED.getLevel());

        boolean exceptionThrown = false;
        try {
            errors.ERROR_FIXED.setLevel(TestErrors.Level.WARNING);
        } catch (RuntimeException ex) {
            exceptionThrown = true;
        }

        Assert.assertTrue(exceptionThrown);
        Assert.assertEquals(TestErrors.Level.ERROR, errors.ERROR_FIXED.getLevel());
    }
}
