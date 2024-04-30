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

import android.aconfig.Aconfig
import android.aconfig.Aconfig.flag_state.DISABLED
import android.aconfig.Aconfig.flag_state.ENABLED
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

private val API_SIGNATURE =
    """
      // Signature format: 2.0
      package android {
        @FlaggedApi("android.flag.foo") public final class Clazz {
          ctor @FlaggedApi("android.flag.foo") public Clazz();
          field @FlaggedApi("android.flag.foo") public static final int FOO = 1; // 0x1
          method @FlaggedApi("android.flag.foo") public int getErrorCode();
        }
        @FlaggedApi("android.flag.bar") public static class Clazz.Builder {
        }
      }
"""
        .trim()

private val API_VERSIONS =
    """
      <?xml version="1.0" encoding="utf-8"?>
      <api version="3">
        <class name="android/Clazz" since="1">
          <method name="&lt;init>()V"/>
          <field name="FOO"/>
          <method name="getErrorCode()I"/>
        </class>
        <class name="android/Clazz${"$"}Builder" since="2">
        </class>
      </api>
"""
        .trim()

private fun generateFlagsProto(
    fooState: Aconfig.flag_state,
    barState: Aconfig.flag_state
): InputStream {
  val fooFlag =
      Aconfig.parsed_flag
          .newBuilder()
          .setPackage("android.flag")
          .setName("foo")
          .setState(fooState)
          .setPermission(Aconfig.flag_permission.READ_ONLY)
          .build()
  val barFlag =
      Aconfig.parsed_flag
          .newBuilder()
          .setPackage("android.flag")
          .setName("bar")
          .setState(barState)
          .setPermission(Aconfig.flag_permission.READ_ONLY)
          .build()
  val flags =
      Aconfig.parsed_flags.newBuilder().addParsedFlag(fooFlag).addParsedFlag(barFlag).build()
  val binaryProto = ByteArrayOutputStream()
  flags.writeTo(binaryProto)
  return ByteArrayInputStream(binaryProto.toByteArray())
}

@RunWith(JUnit4::class)
class CheckFlaggedApisTest {
  @Test
  fun testParseApiSignature() {
    val expected =
        setOf(
            Pair(Symbol("android.Clazz"), Flag("android.flag.foo")),
            Pair(Symbol("android.Clazz.Clazz()"), Flag("android.flag.foo")),
            Pair(Symbol("android.Clazz.FOO"), Flag("android.flag.foo")),
            Pair(Symbol("android.Clazz.getErrorCode()"), Flag("android.flag.foo")),
            Pair(Symbol("android.Clazz.Builder"), Flag("android.flag.bar")),
        )
    val actual = parseApiSignature("in-memory", API_SIGNATURE.byteInputStream())
    assertEquals(expected, actual)
  }

  @Test
  fun testParseFlagValues() {
    val expected: Map<Flag, Boolean> =
        mapOf(Flag("android.flag.foo") to true, Flag("android.flag.bar") to true)
    val actual = parseFlagValues(generateFlagsProto(ENABLED, ENABLED))
    assertEquals(expected, actual)
  }

  @Test
  fun testParseApiVersions() {
    val expected: Set<Symbol> =
        setOf(
            Symbol("android.Clazz"),
            Symbol("android.Clazz.Clazz()"),
            Symbol("android.Clazz.FOO"),
            Symbol("android.Clazz.getErrorCode()"),
            Symbol("android.Clazz.Builder"),
        )
    val actual = parseApiVersions(API_VERSIONS.byteInputStream())
    assertEquals(expected, actual)
  }

  @Test
  fun testFindErrorsNoErrors() {
    val expected = setOf<ApiError>()
    val actual =
        findErrors(
            parseApiSignature("in-memory", API_SIGNATURE.byteInputStream()),
            parseFlagValues(generateFlagsProto(ENABLED, ENABLED)),
            parseApiVersions(API_VERSIONS.byteInputStream()))
    assertEquals(expected, actual)
  }

  @Test
  fun testFindErrorsDisabledFlaggedApiIsPresent() {
    val expected =
        setOf<ApiError>(
            DisabledFlaggedApiIsPresentError(Symbol("android.Clazz"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol("android.Clazz.Clazz()"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(Symbol("android.Clazz.FOO"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol("android.Clazz.getErrorCode()"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol("android.Clazz.Builder"), Flag("android.flag.bar")),
        )
    val actual =
        findErrors(
            parseApiSignature("in-memory", API_SIGNATURE.byteInputStream()),
            parseFlagValues(generateFlagsProto(DISABLED, DISABLED)),
            parseApiVersions(API_VERSIONS.byteInputStream()))
    assertEquals(expected, actual)
  }
}
