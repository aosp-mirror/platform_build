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

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class KatiImpl implements Kati {
    // Subdirectory inside out for config stuff.
    private static final String CONFIG_SUBDIR = "config";

    private final Errors mErrors;
    private final Options mOptions;
    private final KatiCommand mCommand;

    // TODO: Do we need to consider the whole or a greater subset of the
    // environment (or a hash of it?). In theory product-variant is enough, but we know
    // people use stuff from the environment, even though we're trying to get rid of that.
    private String getWorkDirPath() {
        return Paths.get(mOptions.getOutDir(), CONFIG_SUBDIR,
                mOptions.getProduct() + '-' + mOptions.getVariant()).toString();
    }

    private String getDumpConfigCsvPath() {
        return Paths.get(getWorkDirPath(), "dumpconfig.csv").toString();
    }

    public KatiImpl(Errors errors, Options options) {
        this(errors, options, new KatiCommandImpl(errors, options));
    }

    // VisibleForTesting
    public KatiImpl(Errors errors, Options options, KatiCommand command) {
        mErrors = errors;
        mOptions = options;
        mCommand = command;
    }

    @Override
    public Map<String, MakeConfig> loadProductConfig() {
        final String csvPath = getDumpConfigCsvPath();
        try {
            File workDir = new File(getWorkDirPath());

            if ((workDir.exists() && !workDir.isDirectory()) || !workDir.mkdirs()) {
                mErrors.ERROR_KATI.add("Unable to create directory: " + workDir);
                return null; // TODO: throw exception?
            }

            String out = mCommand.run(new String[] {
                    "-f", "build/make/core/dumpconfig.mk",
                    "DUMPCONFIG_FILE=" + csvPath
                });

            if (!out.contains("***DONE***")) {
                mErrors.ERROR_KATI.add(
                        "Unknown error with kati, but it didn't print ***DONE*** message");
                return null; // TODO: throw exception?
            }
            // TODO: Check that output was good.
        } catch (KatiCommand.KatiException ex) {
            mErrors.ERROR_KATI.add("Error running kati:\n" + ex.getStderr());
            return null;
        }

        if (!(new File(csvPath)).canRead()) {
            mErrors.ERROR_KATI.add("Kati ran but did not create " + csvPath);
            return null;
        }

        try (FileReader reader = new FileReader(csvPath)) {
            Map<String, MakeConfig> makeConfigs = DumpConfigParser.parse(mErrors, csvPath, reader);

            if (makeConfigs.size() == 0) {
                // TODO: Issue error?
                return null;
            }

            return makeConfigs;
        } catch (CsvParser.ParseException ex) {
            mErrors.ERROR_KATI.add(new Position(csvPath, ex.getLine()),
                    "Unable to parse output of dumpconfig.mk: " + ex.getMessage());
            return null; // TODO: throw exception?
        } catch (IOException ex) {
            System.out.println(ex);
            mErrors.ERROR_KATI.add("Unable to read " + csvPath + ": " + ex.getMessage());
            return null; // TODO: throw exception?
        }
    }
}
