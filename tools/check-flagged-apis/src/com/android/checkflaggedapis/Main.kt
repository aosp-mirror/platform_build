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

import android.aconfig.Aconfig
import com.android.tools.metalava.model.BaseItemVisitor
import com.android.tools.metalava.model.CallableItem
import com.android.tools.metalava.model.ClassItem
import com.android.tools.metalava.model.FieldItem
import com.android.tools.metalava.model.Item
import com.android.tools.metalava.model.text.ApiFile
import com.github.ajalt.clikt.core.CliktCommand
import com.github.ajalt.clikt.core.ProgramResult
import com.github.ajalt.clikt.core.subcommands
import com.github.ajalt.clikt.parameters.options.help
import com.github.ajalt.clikt.parameters.options.option
import com.github.ajalt.clikt.parameters.options.required
import com.github.ajalt.clikt.parameters.types.path
import java.io.InputStream
import javax.xml.parsers.DocumentBuilderFactory
import org.w3c.dom.Node

/**
 * Class representing the fully qualified name of a class, method or field.
 *
 * This tool reads a multitude of input formats all of which represents the fully qualified path to
 * a Java symbol slightly differently. To keep things consistent, all parsed APIs are converted to
 * Symbols.
 *
 * Symbols are encoded using the format similar to the one described in section 4.3.2 of the JVM
 * spec [1], that is, "package.class.inner-class.method(int, int[], android.util.Clazz)" is
 * represented as
 * <pre>
 *   package.class.inner-class.method(II[Landroid/util/Clazz;)
 * <pre>
 *
 * Where possible, the format has been simplified (to make translation of the
 * various input formats easier): for instance, only / is used as delimiter (#
 * and $ are never used).
 *
 * 1. https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html#jvms-4.3.2
 */
internal sealed class Symbol {
  companion object {
    private val FORBIDDEN_CHARS = listOf('#', '$', '.')

    fun createClass(clazz: String, superclass: String?, interfaces: Set<String>): Symbol {
      return ClassSymbol(
          toInternalFormat(clazz),
          superclass?.let { toInternalFormat(it) },
          interfaces.map { toInternalFormat(it) }.toSet())
    }

    fun createField(clazz: String, field: String): Symbol {
      require(!field.contains("(") && !field.contains(")"))
      return MemberSymbol(toInternalFormat(clazz), toInternalFormat(field))
    }

    fun createMethod(clazz: String, method: String): Symbol {
      return MemberSymbol(toInternalFormat(clazz), toInternalFormat(method))
    }

    protected fun toInternalFormat(name: String): String {
      var internalName = name
      for (ch in FORBIDDEN_CHARS) {
        internalName = internalName.replace(ch, '/')
      }
      return internalName
    }
  }

  abstract fun toPrettyString(): String
}

internal data class ClassSymbol(
    val clazz: String,
    val superclass: String?,
    val interfaces: Set<String>
) : Symbol() {
  override fun toPrettyString(): String = "$clazz"
}

internal data class MemberSymbol(val clazz: String, val member: String) : Symbol() {
  override fun toPrettyString(): String = "$clazz/$member"
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

internal sealed class ApiError {
  abstract val symbol: Symbol
  abstract val flag: Flag
}

internal data class EnabledFlaggedApiNotPresentError(
    override val symbol: Symbol,
    override val flag: Flag
) : ApiError() {
  override fun toString(): String {
    return "error: enabled @FlaggedApi not present in built artifact: symbol=${symbol.toPrettyString()} flag=$flag"
  }
}

internal data class DisabledFlaggedApiIsPresentError(
    override val symbol: Symbol,
    override val flag: Flag
) : ApiError() {
  override fun toString(): String {
    return "error: disabled @FlaggedApi is present in built artifact: symbol=${symbol.toPrettyString()} flag=$flag"
  }
}

internal data class UnknownFlagError(override val symbol: Symbol, override val flag: Flag) :
    ApiError() {
  override fun toString(): String {
    return "error: unknown flag: symbol=${symbol.toPrettyString()} flag=$flag"
  }
}

val ARG_API_SIGNATURE = "--api-signature"
val ARG_API_SIGNATURE_HELP =
    """
Path to API signature file.
Usually named *current.txt.
Tip: `m frameworks-base-api-current.txt` will generate a file that includes all platform and mainline APIs.
"""

val ARG_FLAG_VALUES = "--flag-values"
val ARG_FLAG_VALUES_HELP =
    """
Path to aconfig parsed_flags binary proto file.
Tip: `m all_aconfig_declarations` will generate a file that includes all information about all flags.
"""

val ARG_API_VERSIONS = "--api-versions"
val ARG_API_VERSIONS_HELP =
    """
Path to API versions XML file.
Usually named xml-versions.xml.
Tip: `m sdk dist` will generate a file that includes all platform and mainline APIs.
"""

class MainCommand : CliktCommand() {
  override fun run() {}
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
      option(ARG_API_SIGNATURE)
          .help(ARG_API_SIGNATURE_HELP)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()
  private val flagValuesPath by
      option(ARG_FLAG_VALUES)
          .help(ARG_FLAG_VALUES_HELP)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()
  private val apiVersionsPath by
      option(ARG_API_VERSIONS)
          .help(ARG_API_VERSIONS_HELP)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()

  override fun run() {
    val flaggedSymbols =
        apiSignaturePath.toFile().inputStream().use {
          parseApiSignature(apiSignaturePath.toString(), it)
        }
    val flags = flagValuesPath.toFile().inputStream().use { parseFlagValues(it) }
    val exportedSymbols = apiVersionsPath.toFile().inputStream().use { parseApiVersions(it) }
    val errors = findErrors(flaggedSymbols, flags, exportedSymbols)
    for (e in errors) {
      println(e)
    }
    throw ProgramResult(errors.size)
  }
}

class ListCommand :
    CliktCommand(
        help =
            """
List all flagged APIs and corresponding flags.

The output format is "<fully-qualified-name-of-flag> <state-of-flag> <API>", one line per API.

The output can be post-processed by e.g. piping it to grep to filter out only enabled APIs, or all APIs guarded by a given flag.
""") {
  private val apiSignaturePath by
      option(ARG_API_SIGNATURE)
          .help(ARG_API_SIGNATURE_HELP)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()
  private val flagValuesPath by
      option(ARG_FLAG_VALUES)
          .help(ARG_FLAG_VALUES_HELP)
          .path(mustExist = true, canBeDir = false, mustBeReadable = true)
          .required()

  override fun run() {
    val flaggedSymbols =
        apiSignaturePath.toFile().inputStream().use {
          parseApiSignature(apiSignaturePath.toString(), it)
        }
    val flags = flagValuesPath.toFile().inputStream().use { parseFlagValues(it) }
    val output = listFlaggedApis(flaggedSymbols, flags)
    if (output.isNotEmpty()) {
      println(output.joinToString("\n"))
    }
  }
}

internal fun parseApiSignature(path: String, input: InputStream): Set<Pair<Symbol, Flag>> {
  val output = mutableSetOf<Pair<Symbol, Flag>>()
  val visitor =
      object : BaseItemVisitor() {
        override fun visitClass(cls: ClassItem) {
          getFlagOrNull(cls)?.let { flag ->
            val symbol =
                Symbol.createClass(
                    cls.baselineElementId(),
                    if (cls.isInterface()) {
                      "java/lang/Object"
                    } else {
                      cls.superClass()?.baselineElementId()
                    },
                    cls.allInterfaces()
                        .map { it.baselineElementId() }
                        .filter { it != cls.baselineElementId() }
                        .toSet())
            output.add(Pair(symbol, flag))
          }
        }

        override fun visitField(field: FieldItem) {
          getFlagOrNull(field)?.let { flag ->
            val symbol =
                Symbol.createField(field.containingClass().baselineElementId(), field.name())
            output.add(Pair(symbol, flag))
          }
        }

        override fun visitCallable(callable: CallableItem) {
          getFlagOrNull(callable)?.let { flag ->
            val callableSignature = buildString {
              append(callable.name())
              append("(")
              callable.parameters().joinTo(this, separator = "") { it.type().internalName() }
              append(")")
            }
            val symbol = Symbol.createMethod(callable.containingClass().qualifiedName(), callableSignature)
            output.add(Pair(symbol, flag))
          }
        }

        private fun getFlagOrNull(item: Item): Flag? {
          return item.modifiers
              .findAnnotation("android.annotation.FlaggedApi")
              ?.findAttribute("value")
              ?.value
              ?.let { Flag(it.value() as String) }
        }
      }
  val codebase = ApiFile.parseApi(path, input)
  codebase.accept(visitor)
  return output
}

internal fun parseFlagValues(input: InputStream): Map<Flag, Boolean> {
  val parsedFlags = Aconfig.parsed_flags.parseFrom(input).getParsedFlagList()
  return parsedFlags.associateBy(
      { Flag("${it.getPackage()}.${it.getName()}") },
      { it.getState() == Aconfig.flag_state.ENABLED })
}

internal fun parseApiVersions(input: InputStream): Set<Symbol> {
  fun Node.getAttribute(name: String): String? = getAttributes()?.getNamedItem(name)?.getNodeValue()

  val output = mutableSetOf<Symbol>()
  val factory = DocumentBuilderFactory.newInstance()
  val parser = factory.newDocumentBuilder()
  val document = parser.parse(input)

  val classes = document.getElementsByTagName("class")
  // ktfmt doesn't understand the `..<` range syntax; explicitly call .rangeUntil instead
  for (i in 0.rangeUntil(classes.getLength())) {
    val cls = classes.item(i)
    val className =
        requireNotNull(cls.getAttribute("name")) {
          "Bad XML: <class> element without name attribute"
        }
    var superclass: String? = null
    val interfaces = mutableSetOf<String>()
    val children = cls.getChildNodes()
    for (j in 0.rangeUntil(children.getLength())) {
      val child = children.item(j)
      when (child.getNodeName()) {
        "extends" -> {
          superclass =
              requireNotNull(child.getAttribute("name")) {
                "Bad XML: <extends> element without name attribute"
              }
        }
        "implements" -> {
          val interfaceName =
              requireNotNull(child.getAttribute("name")) {
                "Bad XML: <implements> element without name attribute"
              }
          interfaces.add(interfaceName)
        }
      }
    }
    output.add(Symbol.createClass(className, superclass, interfaces))
  }

  val fields = document.getElementsByTagName("field")
  // ktfmt doesn't understand the `..<` range syntax; explicitly call .rangeUntil instead
  for (i in 0.rangeUntil(fields.getLength())) {
    val field = fields.item(i)
    val fieldName =
        requireNotNull(field.getAttribute("name")) {
          "Bad XML: <field> element without name attribute"
        }
    val className =
        requireNotNull(field.getParentNode()?.getAttribute("name")) {
          "Bad XML: top level <field> element"
        }
    output.add(Symbol.createField(className, fieldName))
  }

  val methods = document.getElementsByTagName("method")
  // ktfmt doesn't understand the `..<` range syntax; explicitly call .rangeUntil instead
  for (i in 0.rangeUntil(methods.getLength())) {
    val method = methods.item(i)
    val methodSignature =
        requireNotNull(method.getAttribute("name")) {
          "Bad XML: <method> element without name attribute"
        }
    val methodSignatureParts = methodSignature.split(Regex("\\(|\\)"))
    if (methodSignatureParts.size != 3) {
      throw Exception("Bad XML: method signature '$methodSignature'")
    }
    var (methodName, methodArgs, _) = methodSignatureParts
    val packageAndClassName =
        requireNotNull(method.getParentNode()?.getAttribute("name")) {
              "Bad XML: top level <method> element, or <class> element missing name attribute"
            }
            .replace("$", "/")
    if (methodName == "<init>") {
      methodName = packageAndClassName.split("/").last()
    }
    output.add(Symbol.createMethod(packageAndClassName, "$methodName($methodArgs)"))
  }

  return output
}

/**
 * Find errors in the given data.
 *
 * @param flaggedSymbolsInSource the set of symbols that are flagged in the source code
 * @param flags the set of flags and their values
 * @param symbolsInOutput the set of symbols that are present in the output
 * @return the set of errors found
 */
internal fun findErrors(
    flaggedSymbolsInSource: Set<Pair<Symbol, Flag>>,
    flags: Map<Flag, Boolean>,
    symbolsInOutput: Set<Symbol>
): Set<ApiError> {
  fun Set<Symbol>.containsSymbol(symbol: Symbol): Boolean {
    // trivial case: the symbol is explicitly listed in api-versions.xml
    if (contains(symbol)) {
      return true
    }

    // non-trivial case: the symbol could be part of the surrounding class'
    // super class or interfaces
    val (className, memberName) =
        when (symbol) {
          is ClassSymbol -> return false
          is MemberSymbol -> {
            Pair(symbol.clazz, symbol.member)
          }
        }
    val clazz = find { it is ClassSymbol && it.clazz == className } as? ClassSymbol?
    if (clazz == null) {
      return false
    }

    for (interfaceName in clazz.interfaces) {
      // createMethod is the same as createField, except it allows parenthesis
      val interfaceSymbol = Symbol.createMethod(interfaceName, memberName)
      if (contains(interfaceSymbol)) {
        return true
      }
    }

    if (clazz.superclass != null) {
      val superclassSymbol = Symbol.createMethod(clazz.superclass, memberName)
      return containsSymbol(superclassSymbol)
    }

    return false
  }

  /**
   * Returns whether the given flag is enabled for the given symbol.
   *
   * A flagged member inside a flagged class is ignored (and the flag value considered disabled) if
   * the class' flag is disabled.
   *
   * @param symbol the symbol to check
   * @param flag the flag to check
   * @return whether the flag is enabled for the given symbol
   */
  fun isFlagEnabledForSymbol(symbol: Symbol, flag: Flag): Boolean {
    when (symbol) {
      is ClassSymbol -> return flags.getValue(flag)
      is MemberSymbol -> {
        val memberFlagValue = flags.getValue(flag)
        if (!memberFlagValue) {
          return false
        }
        // Special case: if the MemberSymbol's flag is enabled, but the outer
        // ClassSymbol's flag (if the class is flagged) is disabled, consider
        // the MemberSymbol's flag as disabled:
        //
        //   @FlaggedApi(this-flag-is-disabled) Clazz {
        //       @FlaggedApi(this-flag-is-enabled) method(); // The Clazz' flag "wins"
        //   }
        //
        // Note: the current implementation does not handle nested classes.
        val classFlagValue =
            flaggedSymbolsInSource
                .find { it.first.toPrettyString() == symbol.clazz }
                ?.let { flags.getValue(it.second) }
                ?: true
        return classFlagValue
      }
    }
  }

  val errors = mutableSetOf<ApiError>()
  for ((symbol, flag) in flaggedSymbolsInSource) {
    try {
      if (isFlagEnabledForSymbol(symbol, flag)) {
        if (!symbolsInOutput.containsSymbol(symbol)) {
          errors.add(EnabledFlaggedApiNotPresentError(symbol, flag))
        }
      } else {
        if (symbolsInOutput.containsSymbol(symbol)) {
          errors.add(DisabledFlaggedApiIsPresentError(symbol, flag))
        }
      }
    } catch (e: NoSuchElementException) {
      errors.add(UnknownFlagError(symbol, flag))
    }
  }
  return errors
}

/**
 * Collect all known info about all @FlaggedApi annotated APIs.
 *
 * Each API will be represented as a String, on the format
 * <pre>
 *   &lt;fully-qualified-name-of-flag&lt; &lt;state-of-flag&lt; &lt;API&lt;
 * </pre>
 *
 * @param flaggedSymbolsInSource the set of symbols that are flagged in the source code
 * @param flags the set of flags and their values
 * @return a list of Strings encoding API data using the format described above, sorted
 *   alphabetically
 */
internal fun listFlaggedApis(
    flaggedSymbolsInSource: Set<Pair<Symbol, Flag>>,
    flags: Map<Flag, Boolean>
): List<String> {
  val output = mutableListOf<String>()
  for ((symbol, flag) in flaggedSymbolsInSource) {
    val flagState =
        when (flags.get(flag)) {
          true -> "ENABLED"
          false -> "DISABLED"
          null -> "UNKNOWN"
        }
    output.add("$flag $flagState ${symbol.toPrettyString()}")
  }
  output.sort()
  return output
}

fun main(args: Array<String>) = MainCommand().subcommands(CheckCommand(), ListCommand()).main(args)
