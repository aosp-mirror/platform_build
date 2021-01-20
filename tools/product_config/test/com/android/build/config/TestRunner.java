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

import org.junit.runner.Description;
import org.junit.runner.JUnitCore;
import org.junit.runner.Result;
import org.junit.runner.notification.Failure;
import org.junit.runner.notification.RunListener;

public class TestRunner {
    public static void main(String[] args) {
        JUnitCore junit = new JUnitCore();

        junit.addListener(new RunListener() {
                    @Override
                    public void testStarted(Description description) {
                        System.out.println("\nSTARTING: " + description.getDisplayName());
                    }

                    @Override
                    public void testFailure(Failure failure) {
                        System.out.println("FAILED: "
                                + failure.getDescription().getDisplayName());
                        System.out.println(failure.getTrace());
                    }
                });
        Result result = junit.run(CsvParserTest.class,
                                  ErrorReporterTest.class,
                                  OptionsTest.class,
                                  PositionTest.class);
        if (!result.wasSuccessful()) {
            System.out.println("\n*** FAILED ***");
        }
    }
}

