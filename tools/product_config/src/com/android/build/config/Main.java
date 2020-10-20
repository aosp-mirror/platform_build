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

public class Main {
    private final Errors mErrors;
    private final Options mOptions;

    public Main(Errors errors, Options options) {
        mErrors = errors;
        mOptions = options;
    }

    void run() {
        System.out.println("Hello World");

        // TODO: Check the build environment to make sure we're running in a real
        // build environment, e.g. actually inside a source tree, with TARGET_PRODUCT
        // and TARGET_BUILD_VARIANT defined, etc.

        // TODO: Run kati and extract the variables and convert all that into starlark files.

        // TODO: Run starlark with all the generated ones and the hand written ones.

        // TODO: Get the variables that were defined in starlark and use that to write
        // out the make, soong and bazel input files.
    }

    public static void main(String[] args) {
        Errors errors = new Errors();

        Options options = Options.parse(errors, args);
        if (errors.hadError()) {
            Options.printHelp(System.err);
            System.err.println();
            errors.printErrors(System.err);
            System.exit(1);
        }

        switch (options.getAction()) {
            case DEFAULT:
                (new Main(errors, options)).run();
                errors.printErrors(System.err);
                return;
            case HELP:
                Options.printHelp(System.out);
                return;
        }
    }
}
