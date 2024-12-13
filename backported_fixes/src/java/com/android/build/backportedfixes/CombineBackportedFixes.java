
/*
 * Copyright (C) 2024 The Android Open Source Project
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
package com.android.build.backportedfixes;

import com.android.build.backportedfixes.common.Parser;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.converters.FileConverter;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.List;


/** Creates a BackportedFixes binary proto file from a list of BackportedFix proto binary files. */
public final class CombineBackportedFixes {

    @Parameter(description = "BackportedFix proto binary files",
            converter = FileConverter.class,
            required = true)
    List<File> fixFiles;
    @Parameter(description = "Write the BackportedFixes proto binary to this file",
            names = {"--out","-o"},
            converter = FileConverter.class,
            required = true)
    File outFile;

    public static void main(String... argv) throws Exception {
        CombineBackportedFixes main = new CombineBackportedFixes();
        JCommander.newBuilder().addObject(main).build().parse(argv);
        main.run();
    }

    CombineBackportedFixes() {
    }

    private void run() throws Exception {
        try (var out = new FileOutputStream(outFile)) {
            var fixes = Parser.parseBackportedFixFiles(fixFiles);
            writeBackportedFixes(fixes, out);
        }
    }

    static void writeBackportedFixes(BackportedFixes fixes, OutputStream out)
            throws IOException {
        fixes.writeTo(out);
    }
}
