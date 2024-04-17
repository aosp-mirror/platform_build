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

import com.github.ajalt.clikt.core.CliktCommand
import com.github.ajalt.clikt.core.ProgramResult

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

class CheckCommand : CliktCommand() {
  override fun run() {
    println("hello world")
    throw ProgramResult(0)
  }
}

fun main(args: Array<String>) = CheckCommand().main(args)
