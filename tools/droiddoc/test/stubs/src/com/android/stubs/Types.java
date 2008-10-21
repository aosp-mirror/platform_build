/*
 * Copyright (C) 2008 The Android Open Source Project
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

package com.android.stubs;

public class Types {
    public final boolean public_final_boolean;
    public final char public_final_char;
    public final short public_final_short;
    public final int public_final_int;
    public final long public_final_long;
    public final float public_final_float;
    public final double public_final_double;
    public final Object public_final_Object;

    public static final boolean public_static_final_boolean;
    public static final char public_static_final_char;
    public static final short public_static_final_short;
    public static final int public_static_final_int;
    public static final long public_static_final_long;
    public static final float public_static_final_float;
    public static final double public_static_final_double;
    public static final Object public_static_final_Object;

    /** @hide */
    public Types() {
        public_final_boolean = false;
        public_final_char = 0;
        public_final_short = 0;
        public_final_int = 0;
        public_final_long = 0;
        public_final_float = 0;
        public_final_double = 0;
        public_final_Object = null;
    }

    static {
        public_static_final_boolean = false;
        public_static_final_char = 0;
        public_static_final_short = 0;
        public_static_final_int = 0;
        public_static_final_long = 0;
        public_static_final_float = 0;
        public_static_final_double = 0;
        public_static_final_Object = null;
    }

    public interface Interface {
        public static final boolean public_static_final_boolean = false;
        public static final char public_static_final_char = 0;
        public static final short public_static_final_short = 0;
        public static final int public_static_final_int = 0;
        public static final long public_static_final_long = 0;
        public static final float public_static_final_float = 0;
        public static final double public_static_final_double = 0;
        public static final Object public_static_final_Object = null;
    }
}

