# python3
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Warning patterns from other tools."""

# No need of doc strings for trivial small functions.
# pylint:disable=missing-function-docstring

# pylint:disable=relative-beyond-top-level
from .cpp_warn_patterns import compile_patterns
from .severity import Severity


def warn(name, severity, description, pattern_list):
  return {
      'category': name,
      'severity': severity,
      'description': name + ': ' + description,
      'patterns': pattern_list
  }


def aapt(description, pattern_list):
  return warn('aapt', Severity.MEDIUM, description, pattern_list)


def misc(description, pattern_list):
  return warn('logtags', Severity.LOW, description, pattern_list)


def asm(description, pattern_list):
  return warn('asm', Severity.MEDIUM, description, pattern_list)


def kotlin(description, pattern):
  return warn('Kotlin', Severity.MEDIUM, description,
              [r'.*\.kt:.*: warning: ' + pattern])


def yacc(description, pattern_list):
  return warn('yacc', Severity.MEDIUM, description, pattern_list)


def rust(severity, description, pattern):
  return warn('Rust', severity, description,
              [r'.*\.rs:.*: warning: ' + pattern])


warn_patterns = [
    # pylint does not recognize g-inconsistent-quotes
    # pylint:disable=line-too-long,bad-option-value,g-inconsistent-quotes
    # aapt warnings
    aapt('No comment for public symbol',
         [r".*: warning: No comment for public symbol .+"]),
    aapt('No default translation',
         [r".*: warning: string '.+' has no default translation in .*"]),
    aapt('Missing default or required localization',
         [r".*: warning: \*\*\*\* string '.+' has no default or required localization for '.+' in .+"]),
    aapt('String marked untranslatable, but translation exists',
         [r".*: warning: string '.+' in .* marked untranslatable but exists in locale '??_??'"]),
    aapt('empty span in string',
         [r".*: warning: empty '.+' span found in text '.+"]),
    # misc warnings
    misc('Duplicate logtag',
         [r".*: warning: tag \".+\" \(.+\) duplicated in .+"]),
    # Assembler warnings
    asm('ASM value size does not match register size',
        [r".*: warning: value size does not match register size specified by the constraint and modifier"]),
    asm('IT instruction is deprecated',
        [r".*: warning: applying IT instruction .* is deprecated"]),
    asm('section flags ignored',
        [r".*: warning: section flags ignored on section redeclaration"]),
    asm('setjmp/longjmp/vfork changed binding',
        [r".*: warning: .*(setjmp|longjmp|vfork) changed binding to .*"]),
    # NDK warnings
    {'category': 'NDK', 'severity': Severity.HIGH,
     'description': 'NDK: Generate guard with empty availability, obsoleted',
     'patterns': [r".*: warning: .* generate guard with empty availability: obsoleted ="]},
    # Protoc warnings
    {'category': 'Protoc', 'severity': Severity.MEDIUM,
     'description': 'Proto: Enum name collision after strip',
     'patterns': [r".*: warning: Enum .* has the same name .* ignore case and strip"]},
    {'category': 'Protoc', 'severity': Severity.MEDIUM,
     'description': 'Proto: Import not used',
     'patterns': [r".*: warning: Import .*/.*\.proto but not used.$"]},
    # Kotlin warnings
    kotlin('never used parameter or variable', '.+ \'.*\' is never used'),
    kotlin('multiple labels', '.+ more than one label .+ in this scope'),
    kotlin('type mismatch', 'type mismatch: '),
    kotlin('is always true', '.+ is always \'true\''),
    kotlin('no effect', '.+ annotation has no effect for '),
    kotlin('no cast needed', 'no cast needed'),
    kotlin('accessor not generated', 'an accessor will not be generated '),
    kotlin('initializer is redundant', '.* initializer is redundant$'),
    kotlin('elvis operator always returns ...',
           'elvis operator (?:) always returns .+'),
    kotlin('shadowed name', 'name shadowed: .+'),
    kotlin('unchecked cast', 'unchecked cast: .* to .*$'),
    kotlin('unreachable code', 'unreachable code'),
    kotlin('unnecessary assertion', 'unnecessary .+ assertion .+'),
    kotlin('unnecessary safe call on a non-null receiver',
           'unnecessary safe call on a non-null receiver'),
    kotlin('Deprecated in Java',
           '\'.*\' is deprecated. Deprecated in Java'),
    kotlin('Replacing Handler for Executor',
           '.+ Replacing Handler for Executor in '),
    kotlin('library has Kotlin runtime',
           '.+ has Kotlin runtime (bundled|library)'),
    warn('Kotlin', Severity.MEDIUM, 'bundled Kotlin runtime',
         ['.*warning: .+ (has|have the) Kotlin (runtime|Runtime library) bundled']),
    kotlin('other warnings', '.+'),  # catch all other Kotlin warnings
    # Yacc warnings
    yacc('deprecate directive',
         [r".*\.yy?:.*: warning: deprecated directive: "]),
    yacc('reduce/reduce conflicts',
         [r".*\.yy?: warning: .+ reduce/reduce conflicts "]),
    yacc('shift/reduce conflicts',
         [r".*\.yy?: warning: .+ shift/reduce conflicts "]),
    {'category': 'yacc', 'severity': Severity.SKIP,
     'description': 'yacc: fix-its can be applied',
     'patterns': [r".*\.yy?: warning: fix-its can be applied."]},
    # Rust warnings
    rust(Severity.HIGH, 'Does not derive Copy', '.+ does not derive Copy'),
    rust(Severity.MEDIUM, '... are deprecated',
         ('(.+ are deprecated$|' +
          'use of deprecated item .* (use .* instead|is now preferred))')),
    rust(Severity.MEDIUM, 'never used', '.* is never used:'),
    rust(Severity.MEDIUM, 'unused import', 'unused import: '),
    rust(Severity.MEDIUM, 'unnecessary attribute',
         '.+ no longer requires an attribute'),
    rust(Severity.MEDIUM, 'unnecessary parentheses',
         'unnecessary parentheses around'),
    # Catch all RenderScript warnings
    {'category': 'RenderScript', 'severity': Severity.LOW,
     'description': 'RenderScript warnings',
     'patterns': [r'.*\.rscript:.*: warning: ']},
    {'category': 'RenderScript', 'severity': Severity.HIGH,
     'description': 'RenderScript is deprecated',
     'patterns': [r'.*: warning: Renderscript is deprecated:.+']},
    # Broken/partial warning messages will be skipped.
    {'category': 'Misc', 'severity': Severity.SKIP,
     'description': 'skip, ,',
     'patterns': [r".*: warning: ,?$"]},
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip, In file included from ...',
     'patterns': [r".*: warning: In file included from .+,"]},
    # catch-all for warnings this script doesn't know about yet
    {'category': 'C/C++', 'severity': Severity.UNMATCHED,
     'description': 'Unclassified/unrecognized warnings',
     'patterns': [r".*: warning: .+"]},
]


compile_patterns(warn_patterns)
