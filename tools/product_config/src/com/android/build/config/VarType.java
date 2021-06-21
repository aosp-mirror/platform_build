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

/**
 * Whether a product config variable is a list or single-value variable.
 */
public enum VarType {
    /**
     * A product config variable that is a list of space separated strings.
     * These are defined by _product_single_value_vars in product.mk.
     */
    LIST,

    /**
     * A product config varaible that is a single string.
     * These are defined by _product_list_vars in product.mk.
     */
    SINGLE,

    /**
     * A variable that is given the special product config handling but is
     * nonetheless defined by product config makefiles.
     */
    UNKNOWN
}

