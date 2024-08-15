package android.aconfig.storage;
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

public class FlagReadContext {
    public StoredFlagType mFlagType;
    public int mFlagIndex;

    public FlagReadContext(int flagType,
            int flagIndex) {
        mFlagType = StoredFlagType.fromInteger(flagType);
        mFlagIndex = flagIndex;
    }

    // Flag type enum, consistent with the definition in aconfig_storage_file/src/lib.rs
    public enum StoredFlagType {
        ReadWriteBoolean,
        ReadOnlyBoolean,
        FixedReadOnlyBoolean;

        public static StoredFlagType fromInteger(int x) {
            switch(x) {
                case 0:
                    return ReadWriteBoolean;
                case 1:
                    return ReadOnlyBoolean;
                case 2:
                    return FixedReadOnlyBoolean;
                default:
                    return null;
            }
        }
    }
}
