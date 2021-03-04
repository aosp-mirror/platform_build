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

import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;

public class Main {
    private final Errors mErrors;
    private final Options mOptions;

    public Main(Errors errors, Options options) {
        mErrors = errors;
        mOptions = options;
    }

    void run() {
        // TODO: Check the build environment to make sure we're running in a real
        // build environment, e.g. actually inside a source tree, with TARGET_PRODUCT
        // and TARGET_BUILD_VARIANT defined, etc.
        Kati kati = new KatiImpl(mErrors, mOptions);
        Map<String, MakeConfig> makeConfigs = kati.loadProductConfig();
        if (makeConfigs == null || mErrors.hadError()) {
            return;
        }
        if (false) {
            for (MakeConfig makeConfig: (new TreeMap<String, MakeConfig>(makeConfigs)).values()) {
                System.out.println();
                System.out.println("=======================================");
                System.out.println("PRODUCT CONFIG FILES : " + makeConfig.getPhase());
                System.out.println("=======================================");
                makeConfig.printToStream(System.out);
            }
        }

        ConvertMakeToGenericConfig m2g = new ConvertMakeToGenericConfig(mErrors);
        GenericConfig generic = m2g.convert(makeConfigs);
        if (false) {
            System.out.println("======================");
            System.out.println("REGENERATED MAKE FILES");
            System.out.println("======================");
            MakeWriter.write(System.out, generic, 0);
        }

        // TODO: Lookup shortened name as used in PRODUCT_NAME / TARGET_PRODUCT
        FlatConfig flat = FlattenConfig.flatten(mErrors, generic);
        if (false) {
            System.out.println("=======================");
            System.out.println("FLATTENED VARIABLE LIST");
            System.out.println("=======================");
            MakeWriter.write(System.out, flat, 0);
        }

        OutputChecker checker = new OutputChecker(flat);
        checker.reportErrors(mErrors);

        // TODO: Run kati and extract the variables and convert all that into starlark files.

        // TODO: Run starlark with all the generated ones and the hand written ones.

        // TODO: Get the variables that were defined in starlark and use that to write
        // out the make, soong and bazel input files.
    }

    public static void main(String[] args) {
        Errors errors = new Errors();
        int exitCode = 0;

        try {
            Options options = Options.parse(errors, args, System.getenv());
            if (errors.hadError()) {
                Options.printHelp(System.err);
                System.err.println();
                throw new CommandException();
            }

            switch (options.getAction()) {
                case DEFAULT:
                    (new Main(errors, options)).run();
                    return;
                case HELP:
                    Options.printHelp(System.out);
                    return;
            }
        } catch (CommandException | Errors.FatalException ex) {
            // These are user errors, so don't show a stack trace
            exitCode = 1;
        } catch (Throwable ex) {
            // These are programming errors in the code of this tool, so print the exception.
            // We'll try to print this.  If it's something unrecoverable, then we'll hope
            // for the best. We will still print the errors below, because they can be useful
            // for debugging.
            ex.printStackTrace(System.err);
            System.err.println();
            exitCode = 1;
        } finally {
            // Print errors and warnings
            errors.printErrors(System.err);
            if (errors.hadError()) {
                exitCode = 1;
            }
            System.exit(exitCode);
        }
    }
}
