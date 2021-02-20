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

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.util.ArrayList;
import java.nio.charset.StandardCharsets;

public class KatiCommandImpl implements KatiCommand {
    final Errors mErrors;
    final Options mOptions;

    /**
     * Runnable that consumes all of an InputStream until EOF, writes the contents
     * into a StringBuilder, and then closes the stream.
     */
    class OutputReader implements Runnable {
        private final InputStream mStream;
        private final StringBuilder mOutput;

        OutputReader(InputStream stream, StringBuilder output) {
            mStream = stream;
            mOutput = output;
        }

        @Override
        public void run() {
            final char[] buf = new char[16*1024];
            final InputStreamReader reader = new InputStreamReader(mStream, StandardCharsets.UTF_8);
            try {
                int amt;
                while ((amt = reader.read(buf, 0, buf.length)) >= 0) {
                    mOutput.append(buf, 0, amt);
                }
            } catch (IOException ex) {
                mErrors.ERROR_KATI.add("Error reading from kati: " + ex.getMessage());
            } finally {
                try {
                    reader.close();
                } catch (IOException ex) {
                    // Close doesn't throw
                }
            }
        }
    }

    public KatiCommandImpl(Errors errors, Options options) {
        mErrors = errors;
        mOptions = options;
    }

    /**
     * Run kati directly. Returns stdout data.
     *
     * @throws KatiException if there is an error. KatiException will contain
     * the stderr from the kati invocation.
     */
    public String run(String[] args) throws KatiException {
        final ArrayList<String> cmd = new ArrayList();
        cmd.add(mOptions.getCKatiBin());
        for (String arg: args) {
            cmd.add(arg);
        }

        final ProcessBuilder builder = new ProcessBuilder(cmd);
        builder.redirectOutput(ProcessBuilder.Redirect.PIPE);
        builder.redirectError(ProcessBuilder.Redirect.PIPE);

        Process process = null;

        try {
            process = builder.start();
        } catch (IOException ex) {
            throw new KatiException(cmd, "IOException running process: " + ex.getMessage());
        }

        final StringBuilder stdout = new StringBuilder();
        final Thread stdoutThread = new Thread(new OutputReader(process.getInputStream(), stdout),
                "kati_stdout_reader");
        stdoutThread.start();

        final StringBuilder stderr = new StringBuilder();
        final Thread stderrThread = new Thread(new OutputReader(process.getErrorStream(), stderr),
                "kati_stderr_reader");
        stderrThread.start();

        int returnCode = waitForProcess(process);
        joinThread(stdoutThread);
        joinThread(stderrThread);

        if (returnCode != 0) {
            throw new KatiException(cmd, stderr.toString());
        }

        return stdout.toString();
    }

    /**
     * Wrap Process.waitFor() because it throws InterruptedException.
     */
    private static int waitForProcess(Process proc) {
        while (true) {
            try {
                return proc.waitFor();
            } catch (InterruptedException ex) {
            }
        }
    }

    /**
     * Wrap Thread.join() because it throws InterruptedException.
     */
    private static void joinThread(Thread thread) {
        while (true) {
            try {
                thread.join();
                return;
            } catch (InterruptedException ex) {
            }
        }
    }
}

