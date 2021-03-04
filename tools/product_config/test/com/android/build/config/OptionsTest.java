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

public class OptionsTest {

    private Options parse(Errors errors, String[] args) {
        final HashMap<String, String> env = new HashMap();
        env.put("TARGET_PRODUCT", "test_product");
        env.put("TARGET_BUILD_VARIANT", "user");
        final Options.Parser parser = new Options.Parser(errors, args, env);
        parser.setSkipRequiredArgValidation();
        return parser.parse();
    }

    @Test
    public void testErrorMissingLast() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--error"
                });

        Assert.assertNotEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        TestErrors.assertHasEntry(errors.ERROR_COMMAND_LINE, errors);
    }

    @Test
    public void testErrorMissingNotLast() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--error", "--warning", "2"
                });

        Assert.assertNotEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        TestErrors.assertHasEntry(errors.ERROR_COMMAND_LINE, errors);
    }

    @Test
    public void testErrorNotNumeric() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--error", "notgood"
                });

        Assert.assertNotEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        TestErrors.assertHasEntry(errors.ERROR_COMMAND_LINE, errors);
    }

    @Test
    public void testErrorInvalidError() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--error", "50000"
                });

        Assert.assertEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        TestErrors.assertHasEntry(errors.WARNING_UNKNOWN_COMMAND_LINE_ERROR, errors);
    }

    @Test
    public void testErrorOne() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--error", "2"
                });

        Assert.assertEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        Assert.assertFalse(errors.hadWarningOrError());
    }

    @Test
    public void testWarningOne() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--warning", "2"
                });

        Assert.assertEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        Assert.assertFalse(errors.hadWarningOrError());
    }

    @Test
    public void testHideOne() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[] {
                    "--hide", "2"
                });

        Assert.assertEquals("", TestErrors.getErrorMessages(errors));
        Assert.assertEquals(Options.Action.DEFAULT, options.getAction());
        Assert.assertFalse(errors.hadWarningOrError());
    }

    @Test
    public void testEnv() {
        final Errors errors = new Errors();

        final Options options = parse(errors, new String[0]);

        Assert.assertEquals("test_product", options.getProduct());
        Assert.assertEquals("user", options.getVariant());
        Assert.assertFalse(errors.hadWarningOrError());
    }
}

