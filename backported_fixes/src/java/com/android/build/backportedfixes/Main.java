
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

import static java.nio.charset.StandardCharsets.UTF_8;

import com.android.build.backportedfixes.common.ClosableCollection;
import com.android.build.backportedfixes.common.Parser;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.converters.FileConverter;
import com.google.common.io.Files;

import java.io.File;
import java.io.PrintWriter;
import java.io.Writer;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

public final class Main {
    @Parameter(description = "BackportedFix proto binary files", converter = FileConverter.class,
            required = true)
    List<File> fixFiles;
    @Parameter(description = "The file to write the property value to.",
            names = {"--property_file", "-p"}, converter = FileConverter.class, required = true)
    File propertyFile;

    public static void main(String... argv) throws Exception {
        Main main = new Main();
        JCommander.newBuilder().addObject(main).build().parse(argv);
        main.run();
    }

    Main() {
    }

    private void run() throws Exception {
        try (var fixStreams = ClosableCollection.wrap(Parser.getFileInputStreams(fixFiles));
             var out = Files.newWriter(propertyFile, UTF_8)) {
            var fixes = Parser.parseBackportedFixes(fixStreams.getCollection());
            writeFixesAsAliasBitSet(fixes, out);
        }
    }

    static void writeFixesAsAliasBitSet(BackportedFixes fixes, Writer out) {
        PrintWriter printWriter = new PrintWriter(out);
        printWriter.println("# The following backported fixes have been applied");
        for (var f : fixes.getFixesList()) {
            printWriter.printf("# https://issuetracker.google.com/issues/%d with alias %d",
                    f.getKnownIssue(), f.getAlias());
            printWriter.println();
        }
        var bsArray = Parser.getBitSetArray(
                fixes.getFixesList().stream().mapToInt(BackportedFix::getAlias).toArray());
        String bsString = Arrays.stream(bsArray).mapToObj(Long::toString).collect(
                Collectors.joining(","));
        printWriter.printf("ro.build.backported_fixes.alias_bitset.long_list=%s", bsString);
        printWriter.println();
        if (printWriter.checkError()) {
            throw new RuntimeException("There was an error writing to " + out.toString());
        }
    }
}
