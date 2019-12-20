#
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

from severity import Severity


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


patterns = [
    # pylint:disable=line-too-long,g-inconsistent-quotes
    # aapt warnings
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
    misc('Typedef redefinition',
         [r".*: warning: redefinition of typedef '.+' is a C11 feature"]),
    misc('GNU old-style field designator',
         [r".*: warning: use of GNU old-style field designator extension"]),
    misc('Missing field initializers',
         [r".*: warning: missing field '.+' initializer"]),
    misc('Missing braces',
         [r".*: warning: suggest braces around initialization of",
          r".*: warning: too many braces around scalar initializer .+Wmany-braces-around-scalar-init",
          r".*: warning: braces around scalar initializer"]),
    misc('Comparison of integers of different signs',
         [r".*: warning: comparison of integers of different signs.+sign-compare"]),
    misc('Add braces to avoid dangling else',
         [r".*: warning: add explicit braces to avoid dangling else"]),
    misc('Initializer overrides prior initialization',
         [r".*: warning: initializer overrides prior initialization of this subobject"]),
    misc('Assigning value to self',
         [r".*: warning: explicitly assigning value of .+ to itself"]),
    misc('GNU extension, variable sized type not at end',
         [r".*: warning: field '.+' with variable sized type '.+' not at the end of a struct or class"]),
    misc('Comparison of constant is always false/true',
         [r".*: comparison of .+ is always .+Wtautological-constant-out-of-range-compare"]),
    misc('Hides overloaded virtual function',
         [r".*: '.+' hides overloaded virtual function"]),
    misc('Incompatible pointer types',
         [r".*: warning: incompatible .*pointer types .*-Wincompatible-.*pointer-types"]),
    # Assembler warnings
    asm('ASM value size does not match register size',
        [r".*: warning: value size does not match register size specified by the constraint and modifier"]),
    asm('IT instruction is deprecated',
        [r".*: warning: applying IT instruction .* is deprecated"]),
    # NDK warnings
    {'category': 'NDK', 'severity': Severity.HIGH,
     'description': 'NDK: Generate guard with empty availability, obsoleted',
     'patterns': [r".*: warning: .* generate guard with empty availability: obsoleted ="]},
    # Protoc warnings
    {'category': 'Protoc', 'severity': Severity.MEDIUM,
     'description': 'Proto: Enum name colision after strip',
     'patterns': [r".*: warning: Enum .* has the same name .* ignore case and strip"]},
    {'category': 'Protoc', 'severity': Severity.MEDIUM,
     'description': 'Proto: Import not used',
     'patterns': [r".*: warning: Import .*/.*\.proto but not used.$"]},
    # Kotlin warnings
    {'category': 'Kotlin', 'severity': Severity.MEDIUM,
     'description': 'Kotlin: never used parameter or variable',
     'patterns': [r".*: warning: (parameter|variable) '.*' is never used$"]},
    {'category': 'Kotlin', 'severity': Severity.MEDIUM,
     'description': 'Kotlin: Deprecated in Java',
     'patterns': [r".*: warning: '.*' is deprecated. Deprecated in Java"]},
    {'category': 'Kotlin', 'severity': Severity.MEDIUM,
     'description': 'Kotlin: library has Kotlin runtime',
     'patterns': [r".*: warning: library has Kotlin runtime bundled into it",
                  r".*: warning: some JAR files .* have the Kotlin Runtime library"]},
    # Rust warnings
    {'category': 'Rust', 'severity': Severity.HIGH,
     'description': 'Rust: Does not derive Copy',
     'patterns': [r".*: warning: .+ does not derive Copy"]},
    {'category': 'Rust', 'severity': Severity.MEDIUM,
     'description': 'Rust: Deprecated range pattern',
     'patterns': [r".*: warning: .+ range patterns are deprecated"]},
    {'category': 'Rust', 'severity': Severity.MEDIUM,
     'description': 'Rust: Deprecated missing explicit \'dyn\'',
     'patterns': [r".*: warning: .+ without an explicit `dyn` are deprecated"]},
    # Broken/partial warning messages will be skipped.
    {'category': 'Misc', 'severity': Severity.SKIP,
     'description': 'skip, ,',
     'patterns': [r".*: warning: ,?$"]},
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip, In file included from ...',
     'patterns': [r".*: warning: In file included from .+,"]},
    # catch-all for warnings this script doesn't know about yet
    {'category': 'C/C++', 'severity': Severity.UNKNOWN,
     'description': 'Unclassified/unrecognized warnings',
     'patterns': [r".*: warning: .+"]},
]
