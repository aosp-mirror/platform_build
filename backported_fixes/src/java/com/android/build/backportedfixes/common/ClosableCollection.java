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
package com.android.build.backportedfixes.common;

import com.google.common.collect.ImmutableList;

import java.util.ArrayList;
import java.util.Collection;

/** An AutoCloseable holder for a collection of AutoCloseables. */
public final class ClosableCollection<T extends AutoCloseable, C extends Collection<T>> implements
        AutoCloseable {
    C source;

    /** Makes the collection AutoCloseable. */
    public static <T extends AutoCloseable, C extends Collection<T>> ClosableCollection<T, C> wrap(
            C source) {
        return new ClosableCollection<>(source);
    }

    private ClosableCollection(C source) {
        this.source = source;
    }

    /** Get the source collection. */
    public C getCollection() {
        return source;
    }

    /**
     * Closes each item in the collection.
     *
     * @throws Exception if any close throws an an exception, a new exception is thrown with
     *                   all the exceptions thrown closing the streams added as a suppressed
     *                   exceptions.
     */
    @Override
    public void close() throws Exception {
        var failures = new ArrayList<Exception>();
        for (T t : source) {
            try {
                t.close();
            } catch (Exception e) {
                failures.add(e);
            }
        }
        if (!failures.isEmpty()) {
            Exception e = new Exception(
                    "%d of %d failed while closing".formatted(failures.size(), source.size()));
            failures.forEach(e::addSuppressed);
            throw e;
        }
    }
}
