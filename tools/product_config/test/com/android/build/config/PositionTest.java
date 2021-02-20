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

import java.util.HashMap;

public class PositionTest {

    @Test
    public void testParseEmpty() {
        final Position pos = Position.parse("");

        Assert.assertEquals(null, pos.getFile());
        Assert.assertEquals(Position.NO_LINE, pos.getLine());
    }

    @Test
    public void testParseOnlyFile() {
        final Position pos = Position.parse("asdf");

        Assert.assertEquals("asdf", pos.getFile());
        Assert.assertEquals(Position.NO_LINE, pos.getLine());
    }

    @Test
    public void testParseBoth() {
        final Position pos = Position.parse("asdf:1");

        Assert.assertEquals("asdf", pos.getFile());
        Assert.assertEquals(1, pos.getLine());
    }

    @Test
    public void testParseEndsWithColon() {
        final Position pos = Position.parse("asdf:");

        Assert.assertEquals("asdf", pos.getFile());
        Assert.assertEquals(Position.NO_LINE, pos.getLine());
    }

    @Test
    public void testParseEndsWithSpace() {
        final Position pos = Position.parse("asdf: ");

        Assert.assertEquals("asdf", pos.getFile());
        Assert.assertEquals(Position.NO_LINE, pos.getLine());
    }


}

