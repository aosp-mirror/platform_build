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

package android.aconfig.storage.test;

import static org.junit.Assert.assertEquals;
import static java.nio.charset.StandardCharsets.UTF_8;

import android.aconfig.storage.SipHasher13;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class SipHasher13Test {
    @Test
    public void testSipHash_hashString() throws Exception {
        String testStr = "com.google.android.test";
        long result = SipHasher13.hash(testStr.getBytes(UTF_8));
        assertEquals(0xF86572EFF9C4A0C1L, result);

        testStr = "abcdefg";
        result = SipHasher13.hash(testStr.getBytes(UTF_8));
        assertEquals(0x2295EF44BD078AE9L, result);

        testStr = "abcdefgh";
        result = SipHasher13.hash(testStr.getBytes(UTF_8));
        assertEquals(0x5CD7657FA7F96C16L, result);
    }
}
