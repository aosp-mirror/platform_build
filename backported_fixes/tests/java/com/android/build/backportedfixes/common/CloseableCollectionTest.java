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

import com.google.common.collect.ImmutableSet;
import com.google.common.truth.Correspondence;
import com.google.common.truth.Truth;

import org.junit.Test;

/** Tests for {@link ClosableCollection}. */
public class CloseableCollectionTest {

    private static class FakeCloseable implements AutoCloseable {
        private final boolean throwOnClose;
        private final String name;


        private boolean isClosed = false;

        private FakeCloseable(String name, boolean throwOnClose) {
            this.name = name;
            this.throwOnClose = throwOnClose;

        }

        private static FakeCloseable named(String name) {
            return new FakeCloseable(name, false);
        }

        private static FakeCloseable failing(String name) {
            return new FakeCloseable(name, true);
        }

        public boolean isClosed() {
            return isClosed;
        }

        @Override
        public void close() throws Exception {
            if (throwOnClose) {
                throw new Exception(name + " close failed");
            }
            isClosed = true;
        }
    }


    @Test
    public void bothClosed() throws Exception {
        var c = ImmutableSet.of(FakeCloseable.named("foo"), FakeCloseable.named("bar"));
        try (var cc = ClosableCollection.wrap(c);) {
            Truth.assertThat(cc.getCollection()).isSameInstanceAs(c);
        }
        Truth.assertThat(c)
                .comparingElementsUsing(
                        Correspondence.transforming(FakeCloseable::isClosed, "is closed"))
                .containsExactly(true, true);
    }

    @Test
    public void bothFailed() {
        var c = ImmutableSet.of(FakeCloseable.failing("foo"), FakeCloseable.failing("bar"));

        try {
            try (var cc = ClosableCollection.wrap(c);) {
                Truth.assertThat(cc.getCollection()).isSameInstanceAs(c);
            }
        } catch (Exception e) {
            Truth.assertThat(e).hasMessageThat().isEqualTo("2 of 2 failed while closing");
            Truth.assertThat(e.getSuppressed())
                    .asList()
                    .comparingElementsUsing(
                            Correspondence.transforming(Exception::getMessage, "has a message of "))
                    .containsExactly("foo close failed", "bar close failed");
        }
    }
}
