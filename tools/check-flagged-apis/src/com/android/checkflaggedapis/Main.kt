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
@file:JvmName("Main")

package com.android.checkflaggedapis

import com.android.tools.metalava.model.BaseItemVisitor
import com.android.tools.metalava.model.FieldItem
import com.android.tools.metalava.model.text.ApiFile
import com.github.ajalt.clikt.core.CliktCommand
import com.github.ajalt.clikt.core.ProgramResult
import com.github.ajalt.clikt.parameters.options.help
import com.github.ajalt.clikt.parameters.options.option
import com.github.ajalt.clikt.parameters.options.required
import com.github.ajalt.clikt.parameters.types.path
import java.io.InputStream

/**
 * Class representing the fully qualified name of a class, method or field.
 *
 * This tool reads a multitude of input formats all of which represents the fully qualified path to
 * a Java symbol slightly differently. To keep things consistent, all parsed APIs are converted to
 * Symbols.
 *
 * All parts of the fully qualified name of the Symbol are separated by a dot, e.g.:
 * <pre>
 *   package.class.inner-class.field
 * </pre>
 */
@JvmInline
internal value class Symbol(val name: String) {
  companion object {
    private val FORBIDDEN_CHARS = listOf('/', '#', '$')

    /** Create a new Symbol from a String that may include delimiters other than dot. */
    fun create(name: String): Symbol {
      var sanitizedName = name
      for (ch in FORBIDDEN_CHARS) {
        sanitizedName = sanitizedName.replace(ch, '.')
      }
      return Symbol(sanitizedName)
    }
  }

  init {
    require(!name.isEmpty()) { "empty string" }
    for (ch in FORBIDDEN_CHARS) {
      require(!name.contains(ch)) { "$name: contains $ch" }
    }
  }

  override fun toString(): String = name.toString()
}

/**
 * Class representing the fully qualified name of an aconfig flag.
 *
 * This includes both the flag's package and name, separated by a dot, e.g.:
 * <pre>
 *   com.android.aconfig.test.disabled_ro
 * <pre>
 */
@JvmInline
internal value class Flag(val name: String) {
  override fun toString(): String = name.toString()
}

class CheckCommand :
    CliktCommand(
        help =
            """
Check that all flagged APIs are used in the correct way.

This tool reads the API signature file and checks that all flagged APIs are used in the correct way.

The tool will exit with a non-zero exit code if any flagged APIs are found to be used in the incorrect way.
""") {
  private val apiSignaturePath by
      option("--api-signature")
          .help(
              """
              Path to API signature file.
              Usually named *current.txt.
              Tip: `m frameworks-base-api-current.txt` will generate a file that includes all platform and mainline APIs.
              """)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()

  override fun run() {
    @Suppress("UNUSED_VARIABLE")
    val flaggedSymbols =
        apiSignaturePath.toFile().inputStream().use {
          parseApiSignature(apiSignaturePath.toString(), it)
        }
    throw ProgramResult(0)
  }
}

internal fun parseApiSignature(path: String, input: InputStream): Set<Pair<Symbol, Flag>> {
  // TODO(334870672): add support for classes and metods
  val output = mutableSetOf<Pair<Symbol, Flag>>()
  val visitor =
      object : BaseItemVisitor() {
        override fun visitField(field: FieldItem) {
          val flag =
              field.modifiers
                  .findAnnotation("android.annotation.FlaggedApi")
                  ?.findAttribute("value")
                  ?.value
                  ?.value() as? String
          if (flag != null) {
            val symbol = Symbol.create(field.baselineElementId())
            output.add(Pair(symbol, Flag(flag)))
          }
        }
      }
  val codebase = ApiFile.parseApi(path, input)
  codebase.accept(visitor)
  return output
}

fun main(args: Array<String>) = CheckCommand().main(args)
