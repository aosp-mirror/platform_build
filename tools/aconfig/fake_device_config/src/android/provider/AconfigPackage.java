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

package android.provider;

/*
 * This class allows generated aconfig code to compile independently of the framework.
 */
public class AconfigPackage {

    /** Flag value is true */
    public static final int FLAG_BOOLEAN_VALUE_TRUE = 1;

    /** Flag value is false */
    public static final int FLAG_BOOLEAN_VALUE_FALSE = 0;

    /** Flag value doesn't exist */
    public static final int FLAG_BOOLEAN_VALUE_NOT_EXIST = 2;

    public static int getBooleanFlagValue(String packageName, String flagName) {
        return 0;
    }

    public AconfigPackage(String packageName) {}

    public int getBooleanFlagValue(String flagName) {
        return 0;
    }
}