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

public class AconfigStorageReadException extends RuntimeException {

    /** Generic error code indicating an unspecified Aconfig Storage error. */
    public static final int ERROR_GENERIC = 0;

    /** Error code indicating that the Aconfig Storage system is not found on the device. */
    public static final int ERROR_STORAGE_SYSTEM_NOT_FOUND = 1;

    /** Error code indicating that the requested configuration package is not found. */
    public static final int ERROR_PACKAGE_NOT_FOUND = 2;

    /** Error code indicating that the specified container is not found. */
    public static final int ERROR_CONTAINER_NOT_FOUND = 3;

    /** Error code indicating that there was an error reading the Aconfig Storage file. */
    public static final int ERROR_CANNOT_READ_STORAGE_FILE = 4;

    public static final int ERROR_FILE_FINGERPRINT_MISMATCH = 5;

    public AconfigStorageReadException(int errorCode, String msg) {
        super(msg);
        throw new UnsupportedOperationException("Stub!");
    }

    public AconfigStorageReadException(int errorCode, String msg, Throwable cause) {
        super(msg, cause);
        throw new UnsupportedOperationException("Stub!");
    }

    public AconfigStorageReadException(int errorCode, Throwable cause) {
        super(cause);
        throw new UnsupportedOperationException("Stub!");
    }

    public int getErrorCode() {
        throw new UnsupportedOperationException("Stub!");
    }

    @Override
    public String getMessage() {
        throw new UnsupportedOperationException("Stub!");
    }
}
