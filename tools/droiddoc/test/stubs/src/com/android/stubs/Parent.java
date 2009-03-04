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

@Annot("asdf")
public class Parent {
    public static final byte public_static_final_byte = 42;
    public static final short public_static_final_short = 43;
    public static final int public_static_final_int = 44;
    public static final long public_static_final_long = 45;
    public static final char public_static_final_char = '\u1234';
    public static final float public_static_final_float = 42.1f;
    public static final double public_static_final_double = 42.2;
    public static int public_static_int = 1;
    public static final String public_static_final_String = "ps\u1234fS";
    public static String public_static_String = "psS";
    public static Parent public_static_Parent = new Parent();
    public static final Parent public_static_final_Parent = new Parent();
    public static final Parent public_static_final_Parent_null = null;

    public interface Interface {
        void method();
    }

    public Parent() {
    }

    public String methodString() {
        return "yo";
    }

    public int method(boolean b, char c, int i, long l, float f, double d) {
        return 1;
    }

    protected void protectedMethod() {
    }

    void packagePrivateMethod() {
    }

    /** @hide */
    public void hiddenMethod() {
    }
}

