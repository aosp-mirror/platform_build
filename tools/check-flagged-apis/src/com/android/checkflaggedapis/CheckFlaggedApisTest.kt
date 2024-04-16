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
package com.android.checkflaggedapis

import com.android.tradefed.testtype.DeviceJUnit4ClassRunner
import com.android.tradefed.testtype.junit4.BaseHostJUnit4Test
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

private val API_SIGNATURE =
    """
      // Signature format: 2.0
      package android {
        public final class Clazz {
          ctor public Clazz();
          field @FlaggedApi("android.flag.foo") public static final int FOO = 1; // 0x1
        }
      }
"""
        .trim()

@RunWith(DeviceJUnit4ClassRunner::class)
class CheckFlaggedApisTest : BaseHostJUnit4Test() {
  @Test
  fun testParseApiSignature() {
    val expected = setOf(Pair(Symbol("android.Clazz.FOO"), Flag("android.flag.foo")))
    val actual = parseApiSignature("in-memory", API_SIGNATURE.byteInputStream())
    assertEquals(expected, actual)
  }
}
