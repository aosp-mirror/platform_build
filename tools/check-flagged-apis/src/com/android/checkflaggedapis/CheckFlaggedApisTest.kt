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
          method @FlaggedApi("android.flag.foo") public boolean setData(int, int[][], @NonNull android.util.Utility<T, U>);
          method @FlaggedApi("android.flag.foo") public boolean setVariableData(int, android.util.Atom...);
          method @FlaggedApi("android.flag.foo") public boolean innerClassArg(android.Clazz.Builder);
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
          <extends name="java/lang/Object"/>
          <method name="&lt;init>()V"/>
          <field name="FOO"/>
          <method name="getErrorCode()I"/>
          <method name="setData(I[[ILandroid/util/Utility;)Z"/>
          <method name="setVariableData(I[Landroid/util/Atom;)Z"/>
          <method name="innerClassArg(Landroid/Clazz${"$"}Builder;)"/>
        </class>
        <class name="android/Clazz${"$"}Builder" since="2">
          <extends name="java/lang/Object"/>
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
            Pair(
                Symbol.createClass("android/Clazz", "java/lang/Object", setOf()),
                Flag("android.flag.foo")),
            Pair(Symbol.createMethod("android/Clazz", "Clazz()"), Flag("android.flag.foo")),
            Pair(Symbol.createField("android/Clazz", "FOO"), Flag("android.flag.foo")),
            Pair(Symbol.createMethod("android/Clazz", "getErrorCode()"), Flag("android.flag.foo")),
            Pair(
                Symbol.createMethod("android/Clazz", "setData(I[[ILandroid/util/Utility;)"),
                Flag("android.flag.foo")),
            Pair(
                Symbol.createMethod("android/Clazz", "setVariableData(I[Landroid/util/Atom;)"),
                Flag("android.flag.foo")),
            Pair(
                Symbol.createMethod("android/Clazz", "innerClassArg(Landroid/Clazz/Builder;)"),
                Flag("android.flag.foo")),
            Pair(
                Symbol.createClass("android/Clazz/Builder", "java/lang/Object", setOf()),
                Flag("android.flag.bar")),
        )
    val actual = parseApiSignature("in-memory", API_SIGNATURE.byteInputStream())
    assertEquals(expected, actual)
  }

  @Test
  fun testParseApiSignatureInterfacesInheritFromJavaLangObject() {
    val apiSignature =
        """
          // Signature format: 2.0
          package android {
            @FlaggedApi("android.flag.foo") public interface Interface {
            }
          }
        """
            .trim()
    val expected =
        setOf(
            Pair(
                Symbol.createClass("android/Interface", "java/lang/Object", setOf()),
                Flag("android.flag.foo")))
    val actual = parseApiSignature("in-memory", apiSignature.byteInputStream())
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
            Symbol.createClass("android/Clazz", "java/lang/Object", setOf()),
            Symbol.createMethod("android/Clazz", "Clazz()"),
            Symbol.createField("android/Clazz", "FOO"),
            Symbol.createMethod("android/Clazz", "getErrorCode()"),
            Symbol.createMethod("android/Clazz", "setData(I[[ILandroid/util/Utility;)"),
            Symbol.createMethod("android/Clazz", "setVariableData(I[Landroid/util/Atom;)"),
            Symbol.createMethod("android/Clazz", "innerClassArg(Landroid/Clazz/Builder;)"),
            Symbol.createClass("android/Clazz/Builder", "java/lang/Object", setOf()),
        )
    val actual = parseApiVersions(API_VERSIONS.byteInputStream())
    assertEquals(expected, actual)
  }

  @Test
  fun testParseApiVersionsNestedClasses() {
    val apiVersions =
        """
          <?xml version="1.0" encoding="utf-8"?>
          <api version="3">
            <class name="android/Clazz${'$'}Foo${'$'}Bar" since="1">
              <extends name="java/lang/Object"/>
              <method name="&lt;init>()V"/>
            </class>
          </api>
        """
            .trim()
    val expected: Set<Symbol> =
        setOf(
            Symbol.createClass("android/Clazz/Foo/Bar", "java/lang/Object", setOf()),
            Symbol.createMethod("android/Clazz/Foo/Bar", "Bar()"),
        )
    val actual = parseApiVersions(apiVersions.byteInputStream())
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
  fun testFindErrorsVerifyImplements() {
    val apiSignature =
        """
          // Signature format: 2.0
          package android {
            @FlaggedApi("android.flag.foo") public final class Clazz implements android.Interface {
              method @FlaggedApi("android.flag.foo") public boolean foo();
              method @FlaggedApi("android.flag.foo") public boolean bar();
            }
            public interface Interface {
              method public boolean bar();
            }
          }
        """
            .trim()

    val apiVersions =
        """
          <?xml version="1.0" encoding="utf-8"?>
          <api version="3">
            <class name="android/Clazz" since="1">
              <extends name="java/lang/Object"/>
              <implements name="android/Interface"/>
              <method name="foo()Z"/>
            </class>
            <class name="android/Interface" since="1">
              <method name="bar()Z"/>
            </class>
          </api>
        """
            .trim()

    val expected = setOf<ApiError>()
    val actual =
        findErrors(
            parseApiSignature("in-memory", apiSignature.byteInputStream()),
            parseFlagValues(generateFlagsProto(ENABLED, ENABLED)),
            parseApiVersions(apiVersions.byteInputStream()))
    assertEquals(expected, actual)
  }

  @Test
  fun testFindErrorsVerifySuperclass() {
    val apiSignature =
        """
          // Signature format: 2.0
          package android {
            @FlaggedApi("android.flag.foo") public final class C extends android.B {
              method @FlaggedApi("android.flag.foo") public boolean c();
              method @FlaggedApi("android.flag.foo") public boolean b();
              method @FlaggedApi("android.flag.foo") public boolean a();
            }
            public final class B extends android.A {
              method public boolean b();
            }
            public final class A {
              method public boolean a();
            }
          }
        """
            .trim()

    val apiVersions =
        """
          <?xml version="1.0" encoding="utf-8"?>
          <api version="3">
            <class name="android/C" since="1">
              <extends name="android/B"/>
              <method name="c()Z"/>
            </class>
            <class name="android/B" since="1">
              <extends name="android/A"/>
              <method name="b()Z"/>
            </class>
            <class name="android/A" since="1">
              <method name="a()Z"/>
            </class>
          </api>
        """
            .trim()

    val expected = setOf<ApiError>()
    val actual =
        findErrors(
            parseApiSignature("in-memory", apiSignature.byteInputStream()),
            parseFlagValues(generateFlagsProto(ENABLED, ENABLED)),
            parseApiVersions(apiVersions.byteInputStream()))
    assertEquals(expected, actual)
  }

  @Test
  fun testNestedFlagsOuterFlagWins() {
    val apiSignature =
        """
          // Signature format: 2.0
          package android {
            @FlaggedApi("android.flag.foo") public final class A {
              method @FlaggedApi("android.flag.bar") public boolean method();
            }
            @FlaggedApi("android.flag.bar") public final class B {
              method @FlaggedApi("android.flag.foo") public boolean method();
            }
          }
        """
            .trim()

    val apiVersions =
        """
          <?xml version="1.0" encoding="utf-8"?>
          <api version="3">
            <class name="android/B" since="1">
            <extends name="java/lang/Object"/>
            </class>
          </api>
        """
            .trim()

    val expected = setOf<ApiError>()
    val actual =
        findErrors(
            parseApiSignature("in-memory", apiSignature.byteInputStream()),
            parseFlagValues(generateFlagsProto(DISABLED, ENABLED)),
            parseApiVersions(apiVersions.byteInputStream()))
    assertEquals(expected, actual)
  }

  @Test
  fun testFindErrorsDisabledFlaggedApiIsPresent() {
    val expected =
        setOf<ApiError>(
            DisabledFlaggedApiIsPresentError(
                Symbol.createClass("android/Clazz", "java/lang/Object", setOf()),
                Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createMethod("android/Clazz", "Clazz()"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createField("android/Clazz", "FOO"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createMethod("android/Clazz", "getErrorCode()"), Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createMethod("android/Clazz", "setData(I[[ILandroid/util/Utility;)"),
                Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createMethod("android/Clazz", "setVariableData(I[Landroid/util/Atom;)"),
                Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createMethod("android/Clazz", "innerClassArg(Landroid/Clazz/Builder;)"),
                Flag("android.flag.foo")),
            DisabledFlaggedApiIsPresentError(
                Symbol.createClass("android/Clazz/Builder", "java/lang/Object", setOf()),
                Flag("android.flag.bar")),
        )
    val actual =
        findErrors(
            parseApiSignature("in-memory", API_SIGNATURE.byteInputStream()),
            parseFlagValues(generateFlagsProto(DISABLED, DISABLED)),
            parseApiVersions(API_VERSIONS.byteInputStream()))
    assertEquals(expected, actual)
  }

  @Test
  fun testListFlaggedApis() {
    val expected =
        listOf(
            "android.flag.bar DISABLED android/Clazz/Builder",
            "android.flag.foo ENABLED android/Clazz",
            "android.flag.foo ENABLED android/Clazz/Clazz()",
            "android.flag.foo ENABLED android/Clazz/FOO",
            "android.flag.foo ENABLED android/Clazz/getErrorCode()",
            "android.flag.foo ENABLED android/Clazz/innerClassArg(Landroid/Clazz/Builder;)",
            "android.flag.foo ENABLED android/Clazz/setData(I[[ILandroid/util/Utility;)",
            "android.flag.foo ENABLED android/Clazz/setVariableData(I[Landroid/util/Atom;)")
    val actual =
        listFlaggedApis(
            parseApiSignature("in-memory", API_SIGNATURE.byteInputStream()),
            parseFlagValues(generateFlagsProto(ENABLED, DISABLED)))
    assertEquals(expected, actual)
  }
}
