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

package android.os.flagging;

/*
 * This class allows generated aconfig code to compile independently of the framework.
 */
public class PlatformAconfigPackageInternal {

    public static PlatformAconfigPackageInternal load(String container, String packageName) {
        throw new UnsupportedOperationException("Stub!");
    }

    public static PlatformAconfigPackageInternal load(
            String container, String packageName, long packageFingerprint) {
        throw new UnsupportedOperationException("Stub!");
    }

    public boolean getBooleanFlagValue(int index) {
        throw new UnsupportedOperationException("Stub!");
    }

    public boolean getBooleanFlagValue(String flagName, boolean defaultValue) {
        throw new UnsupportedOperationException("Stub!");
    }

    public AconfigStorageReadException getException() {
        throw new UnsupportedOperationException("Stub!");
    }
}
