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

import java.lang.reflect.Field;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Error constants and error reporting.
 * <p>
 * <b>Naming Convention:</b>
 * <ul>
 *  <li>ERROR_ for Categories with isLevelSettable false and Level.ERROR
 *  <li>WARNING_ for Categories with isLevelSettable true and default WARNING or HIDDEN
 *  <li>Don't have isLevelSettable true and not ERROR. (The constructor asserts this).
 * </ul>
 */
public class Errors extends ErrorReporter {

    public final Category ERROR_COMMAND_LINE = new Category(1, false, Level.ERROR,
            "Error on the command line.");

    public final Category WARNING_UNKNOWN_COMMAND_LINE_ERROR = new Category(2, true, Level.HIDDEN,
            "Passing unknown errors on the command line.  Hidden by default for\n"
            + "forward compatibility.");

    public final Category ERROR_KATI = new Category(3, false, Level.ERROR,
            "Error executing or reading from Kati.");

    public final Category WARNING_DUMPCONFIG = new Category(4, true, Level.WARNING,
            "Anomaly parsing the output of kati and dumpconfig.mk.");

    public final Category ERROR_DUMPCONFIG = new Category(5, false, Level.ERROR,
            "Error parsing the output of kati and dumpconfig.mk.");

    public final Category WARNING_VARIABLE_RECURSION = new Category(6, true, Level.WARNING,
            "Possible unsupported variable recursion.");

    // This could be a warning, but it's very likely that the data is corrupted somehow
    // if we're seeing this.
    public final Category ERROR_IMPROPER_PRODUCT_VAR_MARKER = new Category(7, true, Level.ERROR,
            "Bad input from dumpvars causing corrupted product variables.");

    public final Category ERROR_MISSING_CONFIG_FILE = new Category(8, true, Level.ERROR,
            "Unable to find config file.");

    public final Category ERROR_INFINITE_RECURSION = new Category(9, true, Level.ERROR,
            "A file tries to inherit-product from itself or its own inherited products.");

    // TODO: This will become obsolete when it is possible to have starlark-based product
    // config files.
    public final Category WARNING_DIFFERENT_FROM_KATI = new Category(1000, true, Level.WARNING,
            "The cross-check with the original kati implementation failed.");

}
