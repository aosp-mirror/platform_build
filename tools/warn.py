#!/usr/bin/python
# Prefer python3 but work also with python2.

"""Grep warnings messages and output HTML tables or warning counts in CSV.

Default is to output warnings in HTML tables grouped by warning severity.
Use option --byproject to output tables grouped by source file projects.
Use option --gencsv to output warning counts in CSV format.
"""

# List of important data structures and functions in this script.
#
# To parse and keep warning message in the input file:
#   severity:                classification of message severity
#   severity.range           [0, 1, ... last_severity_level]
#   severity.colors          for header background
#   severity.column_headers  for the warning count table
#   severity.headers         for warning message tables
#   warn_patterns:
#   warn_patterns[w]['category']     tool that issued the warning, not used now
#   warn_patterns[w]['description']  table heading
#   warn_patterns[w]['members']      matched warnings from input
#   warn_patterns[w]['option']       compiler flag to control the warning
#   warn_patterns[w]['patterns']     regular expressions to match warnings
#   warn_patterns[w]['projects'][p]  number of warnings of pattern w in p
#   warn_patterns[w]['severity']     severity level
#   project_list[p][0]               project name
#   project_list[p][1]               regular expression to match a project path
#   project_patterns[p]              re.compile(project_list[p][1])
#   project_names[p]                 project_list[p][0]
#   warning_messages     array of each warning message, without source url
#   warning_records      array of [idx to warn_patterns,
#                                  idx to project_names,
#                                  idx to warning_messages]
#   android_root
#   platform_version
#   target_product
#   target_variant
#   compile_patterns, parse_input_file
#
# To emit html page of warning messages:
#   flags: --byproject, --url, --separator
# Old stuff for static html components:
#   html_script_style:  static html scripts and styles
#   htmlbig:
#   dump_stats, dump_html_prologue, dump_html_epilogue:
#   emit_buttons:
#   dump_fixed
#   sort_warnings:
#   emit_stats_by_project:
#   all_patterns,
#   findproject, classify_warning
#   dump_html
#
# New dynamic HTML page's static JavaScript data:
#   Some data are copied from Python to JavaScript, to generate HTML elements.
#   FlagURL                args.url
#   FlagSeparator          args.separator
#   SeverityColors:        severity.colors
#   SeverityHeaders:       severity.headers
#   SeverityColumnHeaders: severity.column_headers
#   ProjectNames:          project_names, or project_list[*][0]
#   WarnPatternsSeverity:     warn_patterns[*]['severity']
#   WarnPatternsDescription:  warn_patterns[*]['description']
#   WarnPatternsOption:       warn_patterns[*]['option']
#   WarningMessages:          warning_messages
#   Warnings:                 warning_records
#   StatsHeader:           warning count table header row
#   StatsRows:             array of warning count table rows
#
# New dynamic HTML page's dynamic JavaScript data:
#
# New dynamic HTML related function to emit data:
#   escape_string, strip_escape_string, emit_warning_arrays
#   emit_js_data():

from __future__ import print_function
import argparse
import cgi
import csv
import io
import multiprocessing
import os
import re
import signal
import sys

parser = argparse.ArgumentParser(description='Convert a build log into HTML')
parser.add_argument('--csvpath',
                    help='Save CSV warning file to the passed absolute path',
                    default=None)
parser.add_argument('--gencsv',
                    help='Generate a CSV file with number of various warnings',
                    action='store_true',
                    default=False)
parser.add_argument('--byproject',
                    help='Separate warnings in HTML output by project names',
                    action='store_true',
                    default=False)
parser.add_argument('--url',
                    help='Root URL of an Android source code tree prefixed '
                    'before files in warnings')
parser.add_argument('--separator',
                    help='Separator between the end of a URL and the line '
                    'number argument. e.g. #')
parser.add_argument('--processes',
                    type=int,
                    default=multiprocessing.cpu_count(),
                    help='Number of parallel processes to process warnings')
parser.add_argument(dest='buildlog', metavar='build.log',
                    help='Path to build.log file')
args = parser.parse_args()


class Severity(object):
  """Severity levels and attributes."""
  # numbered by dump order
  FIXMENOW = 0
  HIGH = 1
  MEDIUM = 2
  LOW = 3
  ANALYZER = 4
  TIDY = 5
  HARMLESS = 6
  UNKNOWN = 7
  SKIP = 8
  range = range(SKIP + 1)
  attributes = [
      # pylint:disable=bad-whitespace
      ['fuchsia',   'FixNow',    'Critical warnings, fix me now'],
      ['red',       'High',      'High severity warnings'],
      ['orange',    'Medium',    'Medium severity warnings'],
      ['yellow',    'Low',       'Low severity warnings'],
      ['hotpink',   'Analyzer',  'Clang-Analyzer warnings'],
      ['peachpuff', 'Tidy',      'Clang-Tidy warnings'],
      ['limegreen', 'Harmless',  'Harmless warnings'],
      ['lightblue', 'Unknown',   'Unknown warnings'],
      ['grey',      'Unhandled', 'Unhandled warnings']
  ]
  colors = [a[0] for a in attributes]
  column_headers = [a[1] for a in attributes]
  headers = [a[2] for a in attributes]


def tidy_warn_pattern(description, pattern):
  return {
      'category': 'C/C++',
      'severity': Severity.TIDY,
      'description': 'clang-tidy ' + description,
      'patterns': [r'.*: .+\[' + pattern + r'\]$']
  }


def simple_tidy_warn_pattern(description):
  return tidy_warn_pattern(description, description)


def group_tidy_warn_pattern(description):
  return tidy_warn_pattern(description, description + r'-.+')


def analyzer_high(description, patterns):
  # Important clang analyzer warnings to be fixed ASAP.
  return {
      'category': 'C/C++',
      'severity': Severity.HIGH,
      'description': description,
      'patterns': patterns
  }


def analyzer_high_check(check):
  return analyzer_high(check, [r'.*: .+\[' + check + r'\]$'])


def analyzer_group_high(check):
  return analyzer_high(check, [r'.*: .+\[' + check + r'.+\]$'])


def analyzer_warn(description, patterns):
  return {
      'category': 'C/C++',
      'severity': Severity.ANALYZER,
      'description': description,
      'patterns': patterns
  }


def analyzer_warn_check(check):
  return analyzer_warn(check, [r'.*: .+\[' + check + r'\]$'])


def analyzer_group_check(check):
  return analyzer_warn(check, [r'.*: .+\[' + check + r'.+\]$'])


def java_warn(severity, description, patterns):
  return {
      'category': 'Java',
      'severity': severity,
      'description': 'Java: ' + description,
      'patterns': patterns
  }


def java_high(description, patterns):
  return java_warn(Severity.HIGH, description, patterns)


def java_medium(description, patterns):
  return java_warn(Severity.MEDIUM, description, patterns)


def java_low(description, patterns):
  return java_warn(Severity.LOW, description, patterns)


warn_patterns = [
    # pylint:disable=line-too-long,g-inconsistent-quotes
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'make: overriding commands/ignoring old commands',
     'patterns': [r".*: warning: overriding commands for target .+",
                  r".*: warning: ignoring old commands for target .+"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'make: LOCAL_CLANG is false',
     'patterns': [r".*: warning: LOCAL_CLANG is set to false"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'SDK App using platform shared library',
     'patterns': [r".*: warning: .+ \(.*app:sdk.*\) should not link to .+ \(native:platform\)"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'System module linking to a vendor module',
     'patterns': [r".*: warning: .+ \(.+\) should not link to .+ \(partition:.+\)"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'Invalid SDK/NDK linking',
     'patterns': [r".*: warning: .+ \(.+\) should not link to .+ \(.+\)"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'Duplicate header copy',
     'patterns': [r".*: warning: Duplicate header copy: .+"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wimplicit-function-declaration',
     'description': 'Implicit function declaration',
     'patterns': [r".*: warning: implicit declaration of function .+",
                  r".*: warning: implicitly declaring library function"]},
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip, conflicting types for ...',
     'patterns': [r".*: warning: conflicting types for '.+'"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Wtype-limits',
     'description': 'Expression always evaluates to true or false',
     'patterns': [r".*: warning: comparison is always .+ due to limited range of data type",
                  r".*: warning: comparison of unsigned .*expression .+ is always true",
                  r".*: warning: comparison of unsigned .*expression .+ is always false"]},
    # {'category': 'C/C++', 'severity': Severity.HIGH,
    #  'description': 'Potential leak of memory, bad free, use after free',
    #  'patterns': [r".*: warning: Potential leak of memory",
    #               r".*: warning: Potential memory leak",
    #               r".*: warning: Memory allocated by alloca\(\) should not be deallocated",
    #               r".*: warning: Memory allocated by .+ should be deallocated by .+ not .+",
    #               r".*: warning: 'delete' applied to a pointer that was allocated",
    #               r".*: warning: Use of memory after it is freed",
    #               r".*: warning: Argument to .+ is the address of .+ variable",
    #               r".*: warning: Argument to free\(\) is offset by .+ of memory allocated by",
    #               r".*: warning: Attempt to .+ released memory"]},
    {'category': 'C/C++', 'severity': Severity.HIGH,
     'description': 'Use transient memory for control value',
     'patterns': [r".*: warning: .+Using such transient memory for the control value is .*dangerous."]},
    {'category': 'C/C++', 'severity': Severity.HIGH,
     'description': 'Return address of stack memory',
     'patterns': [r".*: warning: Address of stack memory .+ returned to caller",
                  r".*: warning: Address of stack memory .+ will be a dangling reference"]},
    # {'category': 'C/C++', 'severity': Severity.HIGH,
    #  'description': 'Problem with vfork',
    #  'patterns': [r".*: warning: This .+ is prohibited after a successful vfork",
    #               r".*: warning: Call to function '.+' is insecure "]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': 'infinite-recursion',
     'description': 'Infinite recursion',
     'patterns': [r".*: warning: all paths through this function will call itself"]},
    {'category': 'C/C++', 'severity': Severity.HIGH,
     'description': 'Potential buffer overflow',
     'patterns': [r".*: warning: Size argument is greater than .+ the destination buffer",
                  r".*: warning: Potential buffer overflow.",
                  r".*: warning: String copy function overflows destination buffer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Incompatible pointer types',
     'patterns': [r".*: warning: assignment from incompatible pointer type",
                  r".*: warning: return from incompatible pointer type",
                  r".*: warning: passing argument [0-9]+ of '.*' from incompatible pointer type",
                  r".*: warning: initialization from incompatible pointer type"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-fno-builtin',
     'description': 'Incompatible declaration of built in function',
     'patterns': [r".*: warning: incompatible implicit declaration of built-in function .+"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Wincompatible-library-redeclaration',
     'description': 'Incompatible redeclaration of library function',
     'patterns': [r".*: warning: incompatible redeclaration of library function .+"]},
    {'category': 'C/C++', 'severity': Severity.HIGH,
     'description': 'Null passed as non-null argument',
     'patterns': [r".*: warning: Null passed to a callee that requires a non-null"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunused-parameter',
     'description': 'Unused parameter',
     'patterns': [r".*: warning: unused parameter '.*'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunused',
     'description': 'Unused function, variable, label, comparison, etc.',
     'patterns': [r".*: warning: '.+' defined but not used",
                  r".*: warning: unused function '.+'",
                  r".*: warning: unused label '.+'",
                  r".*: warning: relational comparison result unused",
                  r".*: warning: lambda capture .* is not used",
                  r".*: warning: private field '.+' is not used",
                  r".*: warning: unused variable '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunused-value',
     'description': 'Statement with no effect or result unused',
     'patterns': [r".*: warning: statement with no effect",
                  r".*: warning: expression result unused"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunused-result',
     'description': 'Ignoreing return value of function',
     'patterns': [r".*: warning: ignoring return value of function .+Wunused-result"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmissing-field-initializers',
     'description': 'Missing initializer',
     'patterns': [r".*: warning: missing initializer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wdelete-non-virtual-dtor',
     'description': 'Need virtual destructor',
     'patterns': [r".*: warning: delete called .* has virtual functions but non-virtual destructor"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip, near initialization for ...',
     'patterns': [r".*: warning: \(near initialization for '.+'\)"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wdate-time',
     'description': 'Expansion of data or time macro',
     'patterns': [r".*: warning: expansion of date or time macro is not reproducible"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wexpansion-to-defined',
     'description': 'Macro expansion has undefined behavior',
     'patterns': [r".*: warning: macro expansion .* has undefined behavior"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wformat',
     'description': 'Format string does not match arguments',
     'patterns': [r".*: warning: format '.+' expects type '.+', but argument [0-9]+ has type '.+'",
                  r".*: warning: more '%' conversions than data arguments",
                  r".*: warning: data argument not used by format string",
                  r".*: warning: incomplete format specifier",
                  r".*: warning: unknown conversion type .* in format",
                  r".*: warning: format .+ expects .+ but argument .+Wformat=",
                  r".*: warning: field precision should have .+ but argument has .+Wformat",
                  r".*: warning: format specifies type .+ but the argument has .*type .+Wformat"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wformat-extra-args',
     'description': 'Too many arguments for format string',
     'patterns': [r".*: warning: too many arguments for format"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Too many arguments in call',
     'patterns': [r".*: warning: too many arguments in call to "]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wformat-invalid-specifier',
     'description': 'Invalid format specifier',
     'patterns': [r".*: warning: invalid .+ specifier '.+'.+format-invalid-specifier"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wsign-compare',
     'description': 'Comparison between signed and unsigned',
     'patterns': [r".*: warning: comparison between signed and unsigned",
                  r".*: warning: comparison of promoted \~unsigned with unsigned",
                  r".*: warning: signed and unsigned type in conditional expression"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Comparison between enum and non-enum',
     'patterns': [r".*: warning: enumeral and non-enumeral type in conditional expression"]},
    {'category': 'libpng', 'severity': Severity.MEDIUM,
     'description': 'libpng: zero area',
     'patterns': [r".*libpng warning: Ignoring attempt to set cHRM RGB triangle with zero area"]},
    {'category': 'aapt', 'severity': Severity.MEDIUM,
     'description': 'aapt: no comment for public symbol',
     'patterns': [r".*: warning: No comment for public symbol .+"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmissing-braces',
     'description': 'Missing braces around initializer',
     'patterns': [r".*: warning: missing braces around initializer.*"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'No newline at end of file',
     'patterns': [r".*: warning: no newline at end of file"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Missing space after macro name',
     'patterns': [r".*: warning: missing whitespace after the macro name"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wcast-align',
     'description': 'Cast increases required alignment',
     'patterns': [r".*: warning: cast from .* to .* increases required alignment .*"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wcast-qual',
     'description': 'Qualifier discarded',
     'patterns': [r".*: warning: passing argument [0-9]+ of '.+' discards qualifiers from pointer target type",
                  r".*: warning: assignment discards qualifiers from pointer target type",
                  r".*: warning: passing .+ to parameter of type .+ discards qualifiers",
                  r".*: warning: assigning to .+ from .+ discards qualifiers",
                  r".*: warning: initializing .+ discards qualifiers .+types-discards-qualifiers",
                  r".*: warning: return discards qualifiers from pointer target type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunknown-attributes',
     'description': 'Unknown attribute',
     'patterns': [r".*: warning: unknown attribute '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wignored-attributes',
     'description': 'Attribute ignored',
     'patterns': [r".*: warning: '_*packed_*' attribute ignored",
                  r".*: warning: attribute declaration must precede definition .+ignored-attributes"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wvisibility',
     'description': 'Visibility problem',
     'patterns': [r".*: warning: declaration of '.+' will not be visible outside of this function"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wattributes',
     'description': 'Visibility mismatch',
     'patterns': [r".*: warning: '.+' declared with greater visibility than the type of its field '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Shift count greater than width of type',
     'patterns': [r".*: warning: (left|right) shift count >= width of type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wextern-initializer',
     'description': 'extern &lt;foo&gt; is initialized',
     'patterns': [r".*: warning: '.+' initialized and declared 'extern'",
                  r".*: warning: 'extern' variable has an initializer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wold-style-declaration',
     'description': 'Old style declaration',
     'patterns': [r".*: warning: 'static' is not at beginning of declaration"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wreturn-type',
     'description': 'Missing return value',
     'patterns': [r".*: warning: control reaches end of non-void function"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wimplicit-int',
     'description': 'Implicit int type',
     'patterns': [r".*: warning: type specifier missing, defaults to 'int'",
                  r".*: warning: type defaults to 'int' in declaration of '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmain-return-type',
     'description': 'Main function should return int',
     'patterns': [r".*: warning: return type of 'main' is not 'int'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wuninitialized',
     'description': 'Variable may be used uninitialized',
     'patterns': [r".*: warning: '.+' may be used uninitialized in this function"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Wuninitialized',
     'description': 'Variable is used uninitialized',
     'patterns': [r".*: warning: '.+' is used uninitialized in this function",
                  r".*: warning: variable '.+' is uninitialized when used here"]},
    {'category': 'ld', 'severity': Severity.MEDIUM, 'option': '-fshort-enums',
     'description': 'ld: possible enum size mismatch',
     'patterns': [r".*: warning: .* uses variable-size enums yet the output is to use 32-bit enums; use of enum values across objects may fail"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wpointer-sign',
     'description': 'Pointer targets differ in signedness',
     'patterns': [r".*: warning: pointer targets in initialization differ in signedness",
                  r".*: warning: pointer targets in assignment differ in signedness",
                  r".*: warning: pointer targets in return differ in signedness",
                  r".*: warning: pointer targets in passing argument [0-9]+ of '.+' differ in signedness"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wstrict-overflow',
     'description': 'Assuming overflow does not occur',
     'patterns': [r".*: warning: assuming signed overflow does not occur when assuming that .* is always (true|false)"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wempty-body',
     'description': 'Suggest adding braces around empty body',
     'patterns': [r".*: warning: suggest braces around empty body in an 'if' statement",
                  r".*: warning: empty body in an if-statement",
                  r".*: warning: suggest braces around empty body in an 'else' statement",
                  r".*: warning: empty body in an else-statement"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wparentheses',
     'description': 'Suggest adding parentheses',
     'patterns': [r".*: warning: suggest explicit braces to avoid ambiguous 'else'",
                  r".*: warning: suggest parentheses around arithmetic in operand of '.+'",
                  r".*: warning: suggest parentheses around comparison in operand of '.+'",
                  r".*: warning: logical not is only applied to the left hand side of this comparison",
                  r".*: warning: using the result of an assignment as a condition without parentheses",
                  r".*: warning: .+ has lower precedence than .+ be evaluated first .+Wparentheses",
                  r".*: warning: suggest parentheses around '.+?' .+ '.+?'",
                  r".*: warning: suggest parentheses around assignment used as truth value"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Static variable used in non-static inline function',
     'patterns': [r".*: warning: '.+' is static but used in inline function '.+' which is not static"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wimplicit int',
     'description': 'No type or storage class (will default to int)',
     'patterns': [r".*: warning: data definition has no type or storage class"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Null pointer',
    #  'patterns': [r".*: warning: Dereference of null pointer",
    #               r".*: warning: Called .+ pointer is null",
    #               r".*: warning: Forming reference to null pointer",
    #               r".*: warning: Returning null reference",
    #               r".*: warning: Null pointer passed as an argument to a 'nonnull' parameter",
    #               r".*: warning: .+ results in a null pointer dereference",
    #               r".*: warning: Access to .+ results in a dereference of a null pointer",
    #               r".*: warning: Null pointer argument in"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip, parameter name (without types) in function declaration',
     'patterns': [r".*: warning: parameter names \(without types\) in function declaration"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wstrict-aliasing',
     'description': 'Dereferencing &lt;foo&gt; breaks strict aliasing rules',
     'patterns': [r".*: warning: dereferencing .* break strict-aliasing rules"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wpointer-to-int-cast',
     'description': 'Cast from pointer to integer of different size',
     'patterns': [r".*: warning: cast from pointer to integer of different size",
                  r".*: warning: initialization makes pointer from integer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wint-to-pointer-cast',
     'description': 'Cast to pointer from integer of different size',
     'patterns': [r".*: warning: cast to pointer from integer of different size"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Macro redefined',
     'patterns': [r".*: warning: '.+' macro redefined"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip, ... location of the previous definition',
     'patterns': [r".*: warning: this is the location of the previous definition"]},
    {'category': 'ld', 'severity': Severity.MEDIUM,
     'description': 'ld: type and size of dynamic symbol are not defined',
     'patterns': [r".*: warning: type and size of dynamic symbol `.+' are not defined"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Pointer from integer without cast',
     'patterns': [r".*: warning: assignment makes pointer from integer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Pointer from integer without cast',
     'patterns': [r".*: warning: passing argument [0-9]+ of '.+' makes pointer from integer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Integer from pointer without cast',
     'patterns': [r".*: warning: assignment makes integer from pointer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Integer from pointer without cast',
     'patterns': [r".*: warning: passing argument [0-9]+ of '.+' makes integer from pointer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Integer from pointer without cast',
     'patterns': [r".*: warning: return makes integer from pointer without a cast"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunknown-pragmas',
     'description': 'Ignoring pragma',
     'patterns': [r".*: warning: ignoring #pragma .+"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-W#pragma-messages',
     'description': 'Pragma warning messages',
     'patterns': [r".*: warning: .+W#pragma-messages"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wclobbered',
     'description': 'Variable might be clobbered by longjmp or vfork',
     'patterns': [r".*: warning: variable '.+' might be clobbered by 'longjmp' or 'vfork'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wclobbered',
     'description': 'Argument might be clobbered by longjmp or vfork',
     'patterns': [r".*: warning: argument '.+' might be clobbered by 'longjmp' or 'vfork'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wredundant-decls',
     'description': 'Redundant declaration',
     'patterns': [r".*: warning: redundant redeclaration of '.+'"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip, previous declaration ... was here',
     'patterns': [r".*: warning: previous declaration of '.+' was here"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Wswitch-enum',
     'description': 'Enum value not handled in switch',
     'patterns': [r".*: warning: .*enumeration value.* not handled in switch.+Wswitch"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wuser-defined-warnings',
     'description': 'User defined warnings',
     'patterns': [r".*: warning: .* \[-Wuser-defined-warnings\]$"]},

    # Java warnings
    java_medium('Non-ascii characters used, but ascii encoding specified',
                [r".*: warning: unmappable character for encoding ascii"]),
    java_medium('Non-varargs call of varargs method with inexact argument type for last parameter',
                [r".*: warning: non-varargs call of varargs method with inexact argument type for last parameter"]),
    java_medium('Unchecked method invocation',
                [r".*: warning: \[unchecked\] unchecked method invocation: .+ in class .+"]),
    java_medium('Unchecked conversion',
                [r".*: warning: \[unchecked\] unchecked conversion"]),
    java_medium('_ used as an identifier',
                [r".*: warning: '_' used as an identifier"]),
    java_medium('hidden superclass',
                [r".*: warning: .* stripped of .* superclass .* \[HiddenSuperclass\]"]),
    java_high('Use of internal proprietary API',
              [r".*: warning: .* is internal proprietary API and may be removed"]),

    # Warnings from Javac
    java_medium('Use of deprecated member',
                [r'.*: warning: \[deprecation\] .+']),
    java_medium('Unchecked conversion',
                [r'.*: warning: \[unchecked\] .+']),

    # Begin warnings generated by Error Prone
    java_low('Use parameter comments to document ambiguous literals',
             [r".*: warning: \[BooleanParameter\] .+"]),
    java_low('This class\'s name looks like a Type Parameter.',
             [r".*: warning: \[ClassNamedLikeTypeParameter\] .+"]),
    java_low('Field name is CONSTANT_CASE, but field is not static and final',
             [r".*: warning: \[ConstantField\] .+"]),
    java_low('@Multibinds is a more efficient and declarative mechanism for ensuring that a set multibinding is present in the graph.',
             [r".*: warning: \[EmptySetMultibindingContributions\] .+"]),
    java_low('Prefer assertThrows to ExpectedException',
             [r".*: warning: \[ExpectedExceptionRefactoring\] .+"]),
    java_low('This field is only assigned during initialization; consider making it final',
             [r".*: warning: \[FieldCanBeFinal\] .+"]),
    java_low('Fields that can be null should be annotated @Nullable',
             [r".*: warning: \[FieldMissingNullable\] .+"]),
    java_low('Refactors uses of the JSR 305 @Immutable to Error Prone\'s annotation',
             [r".*: warning: \[ImmutableRefactoring\] .+"]),
    java_low(u'Use Java\'s utility functional interfaces instead of Function\u003cA, B> for primitive types.',
             [r".*: warning: \[LambdaFunctionalInterface\] .+"]),
    java_low('A private method that does not reference the enclosing instance can be static',
             [r".*: warning: \[MethodCanBeStatic\] .+"]),
    java_low('C-style array declarations should not be used',
             [r".*: warning: \[MixedArrayDimensions\] .+"]),
    java_low('Variable declarations should declare only one variable',
             [r".*: warning: \[MultiVariableDeclaration\] .+"]),
    java_low('Source files should not contain multiple top-level class declarations',
             [r".*: warning: \[MultipleTopLevelClasses\] .+"]),
    java_low('Avoid having multiple unary operators acting on the same variable in a method call',
             [r".*: warning: \[MultipleUnaryOperatorsInMethodCall\] .+"]),
    java_low('Package names should match the directory they are declared in',
             [r".*: warning: \[PackageLocation\] .+"]),
    java_low('Non-standard parameter comment; prefer `/* paramName= */ arg`',
             [r".*: warning: \[ParameterComment\] .+"]),
    java_low('Method parameters that aren\'t checked for null shouldn\'t be annotated @Nullable',
             [r".*: warning: \[ParameterNotNullable\] .+"]),
    java_low('Add a private constructor to modules that will not be instantiated by Dagger.',
             [r".*: warning: \[PrivateConstructorForNoninstantiableModule\] .+"]),
    java_low('Utility classes (only static members) are not designed to be instantiated and should be made noninstantiable with a default constructor.',
             [r".*: warning: \[PrivateConstructorForUtilityClass\] .+"]),
    java_low('Unused imports',
             [r".*: warning: \[RemoveUnusedImports\] .+"]),
    java_low('Methods that can return null should be annotated @Nullable',
             [r".*: warning: \[ReturnMissingNullable\] .+"]),
    java_low('Scopes on modules have no function and will soon be an error.',
             [r".*: warning: \[ScopeOnModule\] .+"]),
    java_low('The default case of a switch should appear at the end of the last statement group',
             [r".*: warning: \[SwitchDefault\] .+"]),
    java_low('Prefer assertThrows to @Test(expected=...)',
             [r".*: warning: \[TestExceptionRefactoring\] .+"]),
    java_low('Unchecked exceptions do not need to be declared in the method signature.',
             [r".*: warning: \[ThrowsUncheckedException\] .+"]),
    java_low('Prefer assertThrows to try/fail',
             [r".*: warning: \[TryFailRefactoring\] .+"]),
    java_low('Type parameters must be a single letter with an optional numeric suffix, or an UpperCamelCase name followed by the letter \'T\'.',
             [r".*: warning: \[TypeParameterNaming\] .+"]),
    java_low('Constructors and methods with the same name should appear sequentially with no other code in between. Please re-order or re-name methods.',
             [r".*: warning: \[UngroupedOverloads\] .+"]),
    java_low('Unnecessary call to NullPointerTester#setDefault',
             [r".*: warning: \[UnnecessarySetDefault\] .+"]),
    java_low('Using static imports for types is unnecessary',
             [r".*: warning: \[UnnecessaryStaticImport\] .+"]),
    java_low('@Binds is a more efficient and declarative mechanism for delegating a binding.',
             [r".*: warning: \[UseBinds\] .+"]),
    java_low('Wildcard imports, static or otherwise, should not be used',
             [r".*: warning: \[WildcardImport\] .+"]),
    java_medium('Method reference is ambiguous',
                [r".*: warning: \[AmbiguousMethodReference\] .+"]),
    java_medium('This method passes a pair of parameters through to String.format, but the enclosing method wasn\'t annotated @FormatMethod. Doing so gives compile-time rather than run-time protection against malformed format strings.',
                [r".*: warning: \[AnnotateFormatMethod\] .+"]),
    java_medium('Annotations should be positioned after Javadocs, but before modifiers..',
                [r".*: warning: \[AnnotationPosition\] .+"]),
    java_medium('Arguments are in the wrong order or could be commented for clarity.',
                [r".*: warning: \[ArgumentSelectionDefectChecker\] .+"]),
    java_medium('Arrays do not override equals() or hashCode, so comparisons will be done on reference equality only. If neither deduplication nor lookup are needed, consider using a List instead. Otherwise, use IdentityHashMap/Set, a Map from a library that handles object arrays, or an Iterable/List of pairs.',
                [r".*: warning: \[ArrayAsKeyOfSetOrMap\] .+"]),
    java_medium('Arguments are swapped in assertEquals-like call',
                [r".*: warning: \[AssertEqualsArgumentOrderChecker\] .+"]),
    java_medium('Assertions may be disabled at runtime and do not guarantee that execution will halt here; consider throwing an exception instead',
                [r".*: warning: \[AssertFalse\] .+"]),
    java_medium('The lambda passed to assertThrows should contain exactly one statement',
                [r".*: warning: \[AssertThrowsMultipleStatements\] .+"]),
    java_medium('This assertion throws an AssertionError if it fails, which will be caught by an enclosing try block.',
                [r".*: warning: \[AssertionFailureIgnored\] .+"]),
    java_medium('@AssistedInject and @Inject should not be used on different constructors in the same class.',
                [r".*: warning: \[AssistedInjectAndInjectOnConstructors\] .+"]),
    java_medium('Make toString(), hashCode() and equals() final in AutoValue classes, so it is clear to readers that AutoValue is not overriding them',
                [r".*: warning: \[AutoValueFinalMethods\] .+"]),
    java_medium('Classes that implement Annotation must override equals and hashCode. Consider using AutoAnnotation instead of implementing Annotation by hand.',
                [r".*: warning: \[BadAnnotationImplementation\] .+"]),
    java_medium('Possible sign flip from narrowing conversion',
                [r".*: warning: \[BadComparable\] .+"]),
    java_medium('Importing nested classes/static methods/static fields with commonly-used names can make code harder to read, because it may not be clear from the context exactly which type is being referred to. Qualifying the name with that of the containing class can make the code clearer.',
                [r".*: warning: \[BadImport\] .+"]),
    java_medium('instanceof used in a way that is equivalent to a null check.',
                [r".*: warning: \[BadInstanceof\] .+"]),
    java_medium('BigDecimal#equals has surprising behavior: it also compares scale.',
                [r".*: warning: \[BigDecimalEquals\] .+"]),
    java_medium('new BigDecimal(double) loses precision in this case.',
                [r".*: warning: \[BigDecimalLiteralDouble\] .+"]),
    java_medium('A call to Binder.clearCallingIdentity() should be followed by Binder.restoreCallingIdentity() in a finally block. Otherwise the wrong Binder identity may be used by subsequent code.',
                [r".*: warning: \[BinderIdentityRestoredDangerously\] .+"]),
    java_medium('This code declares a binding for a common value type without a Qualifier annotation.',
                [r".*: warning: \[BindingToUnqualifiedCommonType\] .+"]),
    java_medium('valueOf or autoboxing provides better time and space performance',
                [r".*: warning: \[BoxedPrimitiveConstructor\] .+"]),
    java_medium('ByteBuffer.array() shouldn\'t be called unless ByteBuffer.arrayOffset() is used or if the ByteBuffer was initialized using ByteBuffer.wrap() or ByteBuffer.allocate().',
                [r".*: warning: \[ByteBufferBackingArray\] .+"]),
    java_medium('Mockito cannot mock final classes',
                [r".*: warning: \[CannotMockFinalClass\] .+"]),
    java_medium('Duration can be expressed more clearly with different units',
                [r".*: warning: \[CanonicalDuration\] .+"]),
    java_medium('Logging or rethrowing exceptions should usually be preferred to catching and calling printStackTrace',
                [r".*: warning: \[CatchAndPrintStackTrace\] .+"]),
    java_medium('Ignoring exceptions and calling fail() is unnecessary, and makes test output less useful',
                [r".*: warning: \[CatchFail\] .+"]),
    java_medium('Inner class is non-static but does not reference enclosing class',
                [r".*: warning: \[ClassCanBeStatic\] .+"]),
    java_medium('Class.newInstance() bypasses exception checking; prefer getDeclaredConstructor().newInstance()',
                [r".*: warning: \[ClassNewInstance\] .+"]),
    java_medium('Providing Closeable resources makes their lifecycle unclear',
                [r".*: warning: \[CloseableProvides\] .+"]),
    java_medium('The type of the array parameter of Collection.toArray needs to be compatible with the array type',
                [r".*: warning: \[CollectionToArraySafeParameter\] .+"]),
    java_medium('Collector.of() should not use state',
                [r".*: warning: \[CollectorShouldNotUseState\] .+"]),
    java_medium('Class should not implement both `Comparable` and `Comparator`',
                [r".*: warning: \[ComparableAndComparator\] .+"]),
    java_medium('Constructors should not invoke overridable methods.',
                [r".*: warning: \[ConstructorInvokesOverridable\] .+"]),
    java_medium('Constructors should not pass the \'this\' reference out in method invocations, since the object may not be fully constructed.',
                [r".*: warning: \[ConstructorLeaksThis\] .+"]),
    java_medium('DateFormat is not thread-safe, and should not be used as a constant field.',
                [r".*: warning: \[DateFormatConstant\] .+"]),
    java_medium('Implicit use of the platform default charset, which can result in differing behaviour between JVM executions or incorrect behavior if the encoding of the data source doesn\'t match expectations.',
                [r".*: warning: \[DefaultCharset\] .+"]),
    java_medium('Avoid deprecated Thread methods; read the method\'s javadoc for details.',
                [r".*: warning: \[DeprecatedThreadMethods\] .+"]),
    java_medium('Prefer collection factory methods or builders to the double-brace initialization pattern.',
                [r".*: warning: \[DoubleBraceInitialization\] .+"]),
    java_medium('Double-checked locking on non-volatile fields is unsafe',
                [r".*: warning: \[DoubleCheckedLocking\] .+"]),
    java_medium('Empty top-level type declaration',
                [r".*: warning: \[EmptyTopLevelDeclaration\] .+"]),
    java_medium('equals() implementation may throw NullPointerException when given null',
                [r".*: warning: \[EqualsBrokenForNull\] .+"]),
    java_medium('Overriding Object#equals in a non-final class by using getClass rather than instanceof breaks substitutability of subclasses.',
                [r".*: warning: \[EqualsGetClass\] .+"]),
    java_medium('Classes that override equals should also override hashCode.',
                [r".*: warning: \[EqualsHashCode\] .+"]),
    java_medium('An equality test between objects with incompatible types always returns false',
                [r".*: warning: \[EqualsIncompatibleType\] .+"]),
    java_medium('The contract of #equals states that it should return false for incompatible types, while this implementation may throw ClassCastException.',
                [r".*: warning: \[EqualsUnsafeCast\] .+"]),
    java_medium('Implementing #equals by just comparing hashCodes is fragile. Hashes collide frequently, and this will lead to false positives in #equals.',
                [r".*: warning: \[EqualsUsingHashCode\] .+"]),
    java_medium('Calls to ExpectedException#expect should always be followed by exactly one statement.',
                [r".*: warning: \[ExpectedExceptionChecker\] .+"]),
    java_medium('When only using JUnit Assert\'s static methods, you should import statically instead of extending.',
                [r".*: warning: \[ExtendingJUnitAssert\] .+"]),
    java_medium('Switch case may fall through',
                [r".*: warning: \[FallThrough\] .+"]),
    java_medium('If you return or throw from a finally, then values returned or thrown from the try-catch block will be ignored. Consider using try-with-resources instead.',
                [r".*: warning: \[Finally\] .+"]),
    java_medium('Use parentheses to make the precedence explicit',
                [r".*: warning: \[FloatCast\] .+"]),
    java_medium('This fuzzy equality check is using a tolerance less than the gap to the next number. You may want a less restrictive tolerance, or to assert equality.',
                [r".*: warning: \[FloatingPointAssertionWithinEpsilon\] .+"]),
    java_medium('Floating point literal loses precision',
                [r".*: warning: \[FloatingPointLiteralPrecision\] .+"]),
    java_medium('Classes extending PreferenceActivity must implement isValidFragment such that it does not unconditionally return true to prevent vulnerability to fragment injection attacks.',
                [r".*: warning: \[FragmentInjection\] .+"]),
    java_medium('Subclasses of Fragment must be instantiable via Class#newInstance(): the class must be public, static and have a public nullary constructor',
                [r".*: warning: \[FragmentNotInstantiable\] .+"]),
    java_medium('Overloads will be ambiguous when passing lambda arguments',
                [r".*: warning: \[FunctionalInterfaceClash\] .+"]),
    java_medium('Return value of methods returning Future must be checked. Ignoring returned Futures suppresses exceptions thrown from the code that completes the Future.',
                [r".*: warning: \[FutureReturnValueIgnored\] .+"]),
    java_medium('Calling getClass() on an enum may return a subclass of the enum type',
                [r".*: warning: \[GetClassOnEnum\] .+"]),
    java_medium('Hardcoded reference to /sdcard',
                [r".*: warning: \[HardCodedSdCardPath\] .+"]),
    java_medium('Hiding fields of superclasses may cause confusion and errors',
                [r".*: warning: \[HidingField\] .+"]),
    java_medium('Annotations should always be immutable',
                [r".*: warning: \[ImmutableAnnotationChecker\] .+"]),
    java_medium('Enums should always be immutable',
                [r".*: warning: \[ImmutableEnumChecker\] .+"]),
    java_medium('This annotation has incompatible modifiers as specified by its @IncompatibleModifiers annotation',
                [r".*: warning: \[IncompatibleModifiers\] .+"]),
    java_medium('It is confusing to have a field and a parameter under the same scope that differ only in capitalization.',
                [r".*: warning: \[InconsistentCapitalization\] .+"]),
    java_medium('Including fields in hashCode which are not compared in equals violates the contract of hashCode.',
                [r".*: warning: \[InconsistentHashCode\] .+"]),
    java_medium('The ordering of parameters in overloaded methods should be as consistent as possible (when viewed from left to right)',
                [r".*: warning: \[InconsistentOverloads\] .+"]),
    java_medium('This for loop increments the same variable in the header and in the body',
                [r".*: warning: \[IncrementInForLoopAndHeader\] .+"]),
    java_medium('Constructors on abstract classes are never directly @Injected, only the constructors of their subclasses can be @Inject\'ed.',
                [r".*: warning: \[InjectOnConstructorOfAbstractClass\] .+"]),
    java_medium('Please also override int read(byte[], int, int), otherwise multi-byte reads from this input stream are likely to be slow.',
                [r".*: warning: \[InputStreamSlowMultibyteRead\] .+"]),
    java_medium('Casting inside an if block should be plausibly consistent with the instanceof type',
                [r".*: warning: \[InstanceOfAndCastMatchWrongType\] .+"]),
    java_medium('Expression of type int may overflow before being assigned to a long',
                [r".*: warning: \[IntLongMath\] .+"]),
    java_medium('This @param tag doesn\'t refer to a parameter of the method.',
                [r".*: warning: \[InvalidParam\] .+"]),
    java_medium('This tag is invalid.',
                [r".*: warning: \[InvalidTag\] .+"]),
    java_medium('The documented method doesn\'t actually throw this checked exception.',
                [r".*: warning: \[InvalidThrows\] .+"]),
    java_medium('Class should not implement both `Iterable` and `Iterator`',
                [r".*: warning: \[IterableAndIterator\] .+"]),
    java_medium('Floating-point comparison without error tolerance',
                [r".*: warning: \[JUnit3FloatingPointComparisonWithoutDelta\] .+"]),
    java_medium('Some JUnit4 construct cannot be used in a JUnit3 context. Convert your class to JUnit4 style to use them.',
                [r".*: warning: \[JUnit4ClassUsedInJUnit3\] .+"]),
    java_medium('Test class inherits from JUnit 3\'s TestCase but has JUnit 4 @Test annotations.',
                [r".*: warning: \[JUnitAmbiguousTestClass\] .+"]),
    java_medium('Never reuse class names from java.lang',
                [r".*: warning: \[JavaLangClash\] .+"]),
    java_medium('Suggests alternatives to obsolete JDK classes.',
                [r".*: warning: \[JdkObsolete\] .+"]),
    java_medium('Calls to Lock#lock should be immediately followed by a try block which releases the lock.',
                [r".*: warning: \[LockNotBeforeTry\] .+"]),
    java_medium('Assignment where a boolean expression was expected; use == if this assignment wasn\'t expected or add parentheses for clarity.',
                [r".*: warning: \[LogicalAssignment\] .+"]),
    java_medium('Math.abs does not always give a positive result. Please consider other methods for positive random numbers.',
                [r".*: warning: \[MathAbsoluteRandom\] .+"]),
    java_medium('Switches on enum types should either handle all values, or have a default case.',
                [r".*: warning: \[MissingCasesInEnumSwitch\] .+"]),
    java_medium('The Google Java Style Guide requires that each switch statement includes a default statement group, even if it contains no code. (This requirement is lifted for any switch statement that covers all values of an enum.)',
                [r".*: warning: \[MissingDefault\] .+"]),
    java_medium('Not calling fail() when expecting an exception masks bugs',
                [r".*: warning: \[MissingFail\] .+"]),
    java_medium('method overrides method in supertype; expected @Override',
                [r".*: warning: \[MissingOverride\] .+"]),
    java_medium('A collection or proto builder was created, but its values were never accessed.',
                [r".*: warning: \[ModifiedButNotUsed\] .+"]),
    java_medium('Modifying a collection while iterating over it in a loop may cause a ConcurrentModificationException to be thrown.',
                [r".*: warning: \[ModifyCollectionInEnhancedForLoop\] .+"]),
    java_medium('Multiple calls to either parallel or sequential are unnecessary and cause confusion.',
                [r".*: warning: \[MultipleParallelOrSequentialCalls\] .+"]),
    java_medium('Constant field declarations should use the immutable type (such as ImmutableList) instead of the general collection interface type (such as List)',
                [r".*: warning: \[MutableConstantField\] .+"]),
    java_medium('Method return type should use the immutable type (such as ImmutableList) instead of the general collection interface type (such as List)',
                [r".*: warning: \[MutableMethodReturnType\] .+"]),
    java_medium('Compound assignments may hide dangerous casts',
                [r".*: warning: \[NarrowingCompoundAssignment\] .+"]),
    java_medium('Nested instanceOf conditions of disjoint types create blocks of code that never execute',
                [r".*: warning: \[NestedInstanceOfConditions\] .+"]),
    java_medium('Instead of returning a functional type, return the actual type that the returned function would return and use lambdas at use site.',
                [r".*: warning: \[NoFunctionalReturnType\] .+"]),
    java_medium('This update of a volatile variable is non-atomic',
                [r".*: warning: \[NonAtomicVolatileUpdate\] .+"]),
    java_medium('Static import of member uses non-canonical name',
                [r".*: warning: \[NonCanonicalStaticMemberImport\] .+"]),
    java_medium('equals method doesn\'t override Object.equals',
                [r".*: warning: \[NonOverridingEquals\] .+"]),
    java_medium('Constructors should not be annotated with @Nullable since they cannot return null',
                [r".*: warning: \[NullableConstructor\] .+"]),
    java_medium('Dereference of possibly-null value',
                [r".*: warning: \[NullableDereference\] .+"]),
    java_medium('@Nullable should not be used for primitive types since they cannot be null',
                [r".*: warning: \[NullablePrimitive\] .+"]),
    java_medium('void-returning methods should not be annotated with @Nullable, since they cannot return null',
                [r".*: warning: \[NullableVoid\] .+"]),
    java_medium('Calling toString on Objects that don\'t override toString() doesn\'t provide useful information',
                [r".*: warning: \[ObjectToString\] .+"]),
    java_medium('Objects.hashCode(Object o) should not be passed a primitive value',
                [r".*: warning: \[ObjectsHashCodePrimitive\] .+"]),
    java_medium('Use grouping parenthesis to make the operator precedence explicit',
                [r".*: warning: \[OperatorPrecedence\] .+"]),
    java_medium('One should not call optional.get() inside an if statement that checks !optional.isPresent',
                [r".*: warning: \[OptionalNotPresent\] .+"]),
    java_medium('String literal contains format specifiers, but is not passed to a format method',
                [r".*: warning: \[OrphanedFormatString\] .+"]),
    java_medium('To return a custom message with a Throwable class, one should override getMessage() instead of toString() for Throwable.',
                [r".*: warning: \[OverrideThrowableToString\] .+"]),
    java_medium('Varargs doesn\'t agree for overridden method',
                [r".*: warning: \[Overrides\] .+"]),
    java_medium('This method is not annotated with @Inject, but it overrides a method that is annotated with @com.google.inject.Inject. Guice will inject this method, and it is recommended to annotate it explicitly.',
                [r".*: warning: \[OverridesGuiceInjectableMethod\] .+"]),
    java_medium('Detects `/* name= */`-style comments on actual parameters where the name doesn\'t match the formal parameter',
                [r".*: warning: \[ParameterName\] .+"]),
    java_medium('Preconditions only accepts the %s placeholder in error message strings',
                [r".*: warning: \[PreconditionsInvalidPlaceholder\] .+"]),
    java_medium('Passing a primitive array to a varargs method is usually wrong',
                [r".*: warning: \[PrimitiveArrayPassedToVarargsMethod\] .+"]),
    java_medium('A field on a protocol buffer was set twice in the same chained expression.',
                [r".*: warning: \[ProtoRedundantSet\] .+"]),
    java_medium('Protos should not be used as a key to a map, in a set, or in a contains method on a descendant of a collection. Protos have non deterministic ordering and proto equality is deep, which is a performance issue.',
                [r".*: warning: \[ProtosAsKeyOfSetOrMap\] .+"]),
    java_medium('BugChecker has incorrect ProvidesFix tag, please update',
                [r".*: warning: \[ProvidesFix\] .+"]),
    java_medium('Qualifiers/Scope annotations on @Inject methods don\'t have any effect. Move the qualifier annotation to the binding location.',
                [r".*: warning: \[QualifierOrScopeOnInjectMethod\] .+"]),
    java_medium('Injection frameworks currently don\'t understand Qualifiers in TYPE_PARAMETER or TYPE_USE contexts.',
                [r".*: warning: \[QualifierWithTypeUse\] .+"]),
    java_medium('reachabilityFence should always be called inside a finally block',
                [r".*: warning: \[ReachabilityFenceUsage\] .+"]),
    java_medium('Thrown exception is a subtype of another',
                [r".*: warning: \[RedundantThrows\] .+"]),
    java_medium('Comparison using reference equality instead of value equality',
                [r".*: warning: \[ReferenceEquality\] .+"]),
    java_medium('This annotation is missing required modifiers as specified by its @RequiredModifiers annotation',
                [r".*: warning: \[RequiredModifiers\] .+"]),
    java_medium('Void methods should not have a @return tag.',
                [r".*: warning: \[ReturnFromVoid\] .+"]),
    java_medium(u'Prefer the short-circuiting boolean operators \u0026\u0026 and || to \u0026 and |.',
                [r".*: warning: \[ShortCircuitBoolean\] .+"]),
    java_medium('Writes to static fields should not be guarded by instance locks',
                [r".*: warning: \[StaticGuardedByInstance\] .+"]),
    java_medium('A static variable or method should be qualified with a class name, not expression',
                [r".*: warning: \[StaticQualifiedUsingExpression\] .+"]),
    java_medium('Streams that encapsulate a closeable resource should be closed using try-with-resources',
                [r".*: warning: \[StreamResourceLeak\] .+"]),
    java_medium('String comparison using reference equality instead of value equality',
                [r".*: warning: \[StringEquality\] .+"]),
    java_medium('String.split(String) has surprising behavior',
                [r".*: warning: \[StringSplitter\] .+"]),
    java_medium('SWIG generated code that can\'t call a C++ destructor will leak memory',
                [r".*: warning: \[SwigMemoryLeak\] .+"]),
    java_medium('Synchronizing on non-final fields is not safe: if the field is ever updated, different threads may end up locking on different objects.',
                [r".*: warning: \[SynchronizeOnNonFinalField\] .+"]),
    java_medium('Code that contains System.exit() is untestable.',
                [r".*: warning: \[SystemExitOutsideMain\] .+"]),
    java_medium('Using @Test(expected=...) is discouraged, since the test will pass if *any* statement in the test method throws the expected exception',
                [r".*: warning: \[TestExceptionChecker\] .+"]),
    java_medium('Thread.join needs to be surrounded by a loop until it succeeds, as in Uninterruptibles.joinUninterruptibly.',
                [r".*: warning: \[ThreadJoinLoop\] .+"]),
    java_medium('ThreadLocals should be stored in static fields',
                [r".*: warning: \[ThreadLocalUsage\] .+"]),
    java_medium('Relying on the thread scheduler is discouraged; see Effective Java Item 72 (2nd edition) / 84 (3rd edition).',
                [r".*: warning: \[ThreadPriorityCheck\] .+"]),
    java_medium('Three-letter time zone identifiers are deprecated, may be ambiguous, and might not do what you intend; the full IANA time zone ID should be used instead.',
                [r".*: warning: \[ThreeLetterTimeZoneID\] .+"]),
    java_medium('An implementation of Object.toString() should never return null.',
                [r".*: warning: \[ToStringReturnsNull\] .+"]),
    java_medium('The actual and expected values appear to be swapped, which results in poor assertion failure messages. The actual value should come first.',
                [r".*: warning: \[TruthAssertExpected\] .+"]),
    java_medium('Truth Library assert is called on a constant.',
                [r".*: warning: \[TruthConstantAsserts\] .+"]),
    java_medium('Argument is not compatible with the subject\'s type.',
                [r".*: warning: \[TruthIncompatibleType\] .+"]),
    java_medium('Type parameter declaration shadows another named type',
                [r".*: warning: \[TypeNameShadowing\] .+"]),
    java_medium('Type parameter declaration overrides another type parameter already declared',
                [r".*: warning: \[TypeParameterShadowing\] .+"]),
    java_medium('Declaring a type parameter that is only used in the return type is a misuse of generics: operations on the type parameter are unchecked, it hides unsafe casts at invocations of the method, and it interacts badly with method overload resolution.',
                [r".*: warning: \[TypeParameterUnusedInFormals\] .+"]),
    java_medium('Avoid hash-based containers of java.net.URL--the containers rely on equals() and hashCode(), which cause java.net.URL to make blocking internet connections.',
                [r".*: warning: \[URLEqualsHashCode\] .+"]),
    java_medium('Collection, Iterable, Multimap, and Queue do not have well-defined equals behavior',
                [r".*: warning: \[UndefinedEquals\] .+"]),
    java_medium('Switch handles all enum values: an explicit default case is unnecessary and defeats error checking for non-exhaustive switches.',
                [r".*: warning: \[UnnecessaryDefaultInEnumSwitch\] .+"]),
    java_medium('Unnecessary use of grouping parentheses',
                [r".*: warning: \[UnnecessaryParentheses\] .+"]),
    java_medium('Finalizer may run before native code finishes execution',
                [r".*: warning: \[UnsafeFinalization\] .+"]),
    java_medium('Prefer `asSubclass` instead of casting the result of `newInstance`, to detect classes of incorrect type before invoking their constructors.This way, if the class is of the incorrect type,it will throw an exception before invoking its constructor.',
                [r".*: warning: \[UnsafeReflectiveConstructionCast\] .+"]),
    java_medium('Unsynchronized method overrides a synchronized method.',
                [r".*: warning: \[UnsynchronizedOverridesSynchronized\] .+"]),
    java_medium('Unused.',
                [r".*: warning: \[Unused\] .+"]),
    java_medium('This catch block catches an exception and re-throws another, but swallows the caught exception rather than setting it as a cause. This can make debugging harder.',
                [r".*: warning: \[UnusedException\] .+"]),
    java_medium('Java assert is used in test. For testing purposes Assert.* matchers should be used.',
                [r".*: warning: \[UseCorrectAssertInTests\] .+"]),
    java_medium('Non-constant variable missing @Var annotation',
                [r".*: warning: \[Var\] .+"]),
    java_medium('variableName and type with the same name would refer to the static field instead of the class',
                [r".*: warning: \[VariableNameSameAsType\] .+"]),
    java_medium('Because of spurious wakeups, Object.wait() and Condition.await() must always be called in a loop',
                [r".*: warning: \[WaitNotInLoop\] .+"]),
    java_medium('A wakelock acquired with a timeout may be released by the system before calling `release`, even after checking `isHeld()`. If so, it will throw a RuntimeException. Please wrap in a try/catch block.',
                [r".*: warning: \[WakelockReleasedDangerously\] .+"]),
    java_high('AndroidInjection.inject() should always be invoked before calling super.lifecycleMethod()',
              [r".*: warning: \[AndroidInjectionBeforeSuper\] .+"]),
    java_high('Use of class, field, or method that is not compatible with legacy Android devices',
              [r".*: warning: \[AndroidJdkLibsChecker\] .+"]),
    java_high('Reference equality used to compare arrays',
              [r".*: warning: \[ArrayEquals\] .+"]),
    java_high('Arrays.fill(Object[], Object) called with incompatible types.',
              [r".*: warning: \[ArrayFillIncompatibleType\] .+"]),
    java_high('hashcode method on array does not hash array contents',
              [r".*: warning: \[ArrayHashCode\] .+"]),
    java_high('Calling toString on an array does not provide useful information',
              [r".*: warning: \[ArrayToString\] .+"]),
    java_high('Arrays.asList does not autobox primitive arrays, as one might expect.',
              [r".*: warning: \[ArraysAsListPrimitiveArray\] .+"]),
    java_high('@AssistedInject and @Inject cannot be used on the same constructor.',
              [r".*: warning: \[AssistedInjectAndInjectOnSameConstructor\] .+"]),
    java_high('AsyncCallable should not return a null Future, only a Future whose result is null.',
              [r".*: warning: \[AsyncCallableReturnsNull\] .+"]),
    java_high('AsyncFunction should not return a null Future, only a Future whose result is null.',
              [r".*: warning: \[AsyncFunctionReturnsNull\] .+"]),
    java_high('@AutoFactory and @Inject should not be used in the same type.',
              [r".*: warning: \[AutoFactoryAtInject\] .+"]),
    java_high('Arguments to AutoValue constructor are in the wrong order',
              [r".*: warning: \[AutoValueConstructorOrderChecker\] .+"]),
    java_high('Shift by an amount that is out of range',
              [r".*: warning: \[BadShiftAmount\] .+"]),
    java_high('Object serialized in Bundle may have been flattened to base type.',
              [r".*: warning: \[BundleDeserializationCast\] .+"]),
    java_high('The called constructor accepts a parameter with the same name and type as one of its caller\'s parameters, but its caller doesn\'t pass that parameter to it.  It\'s likely that it was intended to.',
              [r".*: warning: \[ChainingConstructorIgnoresParameter\] .+"]),
    java_high('Ignored return value of method that is annotated with @CheckReturnValue',
              [r".*: warning: \[CheckReturnValue\] .+"]),
    java_high('The source file name should match the name of the top-level class it contains',
              [r".*: warning: \[ClassName\] .+"]),
    java_high('Incompatible type as argument to Object-accepting Java collections method',
              [r".*: warning: \[CollectionIncompatibleType\] .+"]),
    java_high(u'Implementing \'Comparable\u003cT>\' where T is not compatible with the implementing class.',
              [r".*: warning: \[ComparableType\] .+"]),
    java_high('this == null is always false, this != null is always true',
              [r".*: warning: \[ComparingThisWithNull\] .+"]),
    java_high('This comparison method violates the contract',
              [r".*: warning: \[ComparisonContractViolated\] .+"]),
    java_high('Comparison to value that is out of range for the compared type',
              [r".*: warning: \[ComparisonOutOfRange\] .+"]),
    java_high('@CompatibleWith\'s value is not a type argument.',
              [r".*: warning: \[CompatibleWithAnnotationMisuse\] .+"]),
    java_high('Non-compile-time constant expression passed to parameter with @CompileTimeConstant type annotation.',
              [r".*: warning: \[CompileTimeConstant\] .+"]),
    java_high('Non-trivial compile time constant boolean expressions shouldn\'t be used.',
              [r".*: warning: \[ComplexBooleanConstant\] .+"]),
    java_high('A conditional expression with numeric operands of differing types will perform binary numeric promotion of the operands; when these operands are of reference types, the expression\'s result may not be of the expected type.',
              [r".*: warning: \[ConditionalExpressionNumericPromotion\] .+"]),
    java_high('Compile-time constant expression overflows',
              [r".*: warning: \[ConstantOverflow\] .+"]),
    java_high('Dagger @Provides methods may not return null unless annotated with @Nullable',
              [r".*: warning: \[DaggerProvidesNull\] .+"]),
    java_high('Exception created but not thrown',
              [r".*: warning: \[DeadException\] .+"]),
    java_high('Thread created but not started',
              [r".*: warning: \[DeadThread\] .+"]),
    java_high('Deprecated item is not annotated with @Deprecated',
              [r".*: warning: \[DepAnn\] .+"]),
    java_high('Division by integer literal zero',
              [r".*: warning: \[DivZero\] .+"]),
    java_high('This method should not be called.',
              [r".*: warning: \[DoNotCall\] .+"]),
    java_high('Empty statement after if',
              [r".*: warning: \[EmptyIf\] .+"]),
    java_high('== NaN always returns false; use the isNaN methods instead',
              [r".*: warning: \[EqualsNaN\] .+"]),
    java_high('== must be used in equals method to check equality to itself or an infinite loop will occur.',
              [r".*: warning: \[EqualsReference\] .+"]),
    java_high('Comparing different pairs of fields/getters in an equals implementation is probably a mistake.',
              [r".*: warning: \[EqualsWrongThing\] .+"]),
    java_high('Method annotated @ForOverride must be protected or package-private and only invoked from declaring class, or from an override of the method',
              [r".*: warning: \[ForOverride\] .+"]),
    java_high('Invalid printf-style format string',
              [r".*: warning: \[FormatString\] .+"]),
    java_high('Invalid format string passed to formatting method.',
              [r".*: warning: \[FormatStringAnnotation\] .+"]),
    java_high('Casting a lambda to this @FunctionalInterface can cause a behavior change from casting to a functional superinterface, which is surprising to users.  Prefer decorator methods to this surprising behavior.',
              [r".*: warning: \[FunctionalInterfaceMethodChanged\] .+"]),
    java_high('Futures.getChecked requires a checked exception type with a standard constructor.',
              [r".*: warning: \[FuturesGetCheckedIllegalExceptionType\] .+"]),
    java_high('DoubleMath.fuzzyEquals should never be used in an Object.equals() method',
              [r".*: warning: \[FuzzyEqualsShouldNotBeUsedInEqualsMethod\] .+"]),
    java_high('Calling getClass() on an annotation may return a proxy class',
              [r".*: warning: \[GetClassOnAnnotation\] .+"]),
    java_high('Calling getClass() on an object of type Class returns the Class object for java.lang.Class; you probably meant to operate on the object directly',
              [r".*: warning: \[GetClassOnClass\] .+"]),
    java_high('Checks for unguarded accesses to fields and methods with @GuardedBy annotations',
              [r".*: warning: \[GuardedBy\] .+"]),
    java_high('Scope annotation on implementation class of AssistedInject factory is not allowed',
              [r".*: warning: \[GuiceAssistedInjectScoping\] .+"]),
    java_high('A constructor cannot have two @Assisted parameters of the same type unless they are disambiguated with named @Assisted annotations.',
              [r".*: warning: \[GuiceAssistedParameters\] .+"]),
    java_high('Although Guice allows injecting final fields, doing so is disallowed because the injected value may not be visible to other threads.',
              [r".*: warning: \[GuiceInjectOnFinalField\] .+"]),
    java_high('contains() is a legacy method that is equivalent to containsValue()',
              [r".*: warning: \[HashtableContains\] .+"]),
    java_high('A binary expression where both operands are the same is usually incorrect.',
              [r".*: warning: \[IdentityBinaryExpression\] .+"]),
    java_high('Type declaration annotated with @Immutable is not immutable',
              [r".*: warning: \[Immutable\] .+"]),
    java_high('Modifying an immutable collection is guaranteed to throw an exception and leave the collection unmodified',
              [r".*: warning: \[ImmutableModification\] .+"]),
    java_high('Passing argument to a generic method with an incompatible type.',
              [r".*: warning: \[IncompatibleArgumentType\] .+"]),
    java_high('The first argument to indexOf is a Unicode code point, and the second is the index to start the search from',
              [r".*: warning: \[IndexOfChar\] .+"]),
    java_high('Conditional expression in varargs call contains array and non-array arguments',
              [r".*: warning: \[InexactVarargsConditional\] .+"]),
    java_high('This method always recurses, and will cause a StackOverflowError',
              [r".*: warning: \[InfiniteRecursion\] .+"]),
    java_high('A scoping annotation\'s Target should include TYPE and METHOD.',
              [r".*: warning: \[InjectInvalidTargetingOnScopingAnnotation\] .+"]),
    java_high('Using more than one qualifier annotation on the same element is not allowed.',
              [r".*: warning: \[InjectMoreThanOneQualifier\] .+"]),
    java_high('A class can be annotated with at most one scope annotation.',
              [r".*: warning: \[InjectMoreThanOneScopeAnnotationOnClass\] .+"]),
    java_high('Members shouldn\'t be annotated with @Inject if constructor is already annotated @Inject',
              [r".*: warning: \[InjectOnMemberAndConstructor\] .+"]),
    java_high('Scope annotation on an interface or abstact class is not allowed',
              [r".*: warning: \[InjectScopeAnnotationOnInterfaceOrAbstractClass\] .+"]),
    java_high('Scoping and qualifier annotations must have runtime retention.',
              [r".*: warning: \[InjectScopeOrQualifierAnnotationRetention\] .+"]),
    java_high('Injected constructors cannot be optional nor have binding annotations',
              [r".*: warning: \[InjectedConstructorAnnotations\] .+"]),
    java_high('A standard cryptographic operation is used in a mode that is prone to vulnerabilities',
              [r".*: warning: \[InsecureCryptoUsage\] .+"]),
    java_high('Invalid syntax used for a regular expression',
              [r".*: warning: \[InvalidPatternSyntax\] .+"]),
    java_high('Invalid time zone identifier. TimeZone.getTimeZone(String) will silently return GMT instead of the time zone you intended.',
              [r".*: warning: \[InvalidTimeZoneID\] .+"]),
    java_high('The argument to Class#isInstance(Object) should not be a Class',
              [r".*: warning: \[IsInstanceOfClass\] .+"]),
    java_high('Log tag too long, cannot exceed 23 characters.',
              [r".*: warning: \[IsLoggableTagLength\] .+"]),
    java_high(u'Path implements Iterable\u003cPath>; prefer Collection\u003cPath> for clarity',
              [r".*: warning: \[IterablePathParameter\] .+"]),
    java_high('jMock tests must have a @RunWith(JMock.class) annotation, or the Mockery field must have a @Rule JUnit annotation',
              [r".*: warning: \[JMockTestWithoutRunWithOrRuleAnnotation\] .+"]),
    java_high('Test method will not be run; please correct method signature (Should be public, non-static, and method name should begin with "test").',
              [r".*: warning: \[JUnit3TestNotRun\] .+"]),
    java_high('This method should be static',
              [r".*: warning: \[JUnit4ClassAnnotationNonStatic\] .+"]),
    java_high('setUp() method will not be run; please add JUnit\'s @Before annotation',
              [r".*: warning: \[JUnit4SetUpNotRun\] .+"]),
    java_high('tearDown() method will not be run; please add JUnit\'s @After annotation',
              [r".*: warning: \[JUnit4TearDownNotRun\] .+"]),
    java_high('This looks like a test method but is not run; please add @Test and @Ignore, or, if this is a helper method, reduce its visibility.',
              [r".*: warning: \[JUnit4TestNotRun\] .+"]),
    java_high('An object is tested for reference equality to itself using JUnit library.',
              [r".*: warning: \[JUnitAssertSameCheck\] .+"]),
    java_high('Use of class, field, or method that is not compatible with JDK 7',
              [r".*: warning: \[Java7ApiChecker\] .+"]),
    java_high('Abstract and default methods are not injectable with javax.inject.Inject',
              [r".*: warning: \[JavaxInjectOnAbstractMethod\] .+"]),
    java_high('@javax.inject.Inject cannot be put on a final field.',
              [r".*: warning: \[JavaxInjectOnFinalField\] .+"]),
    java_high('This pattern will silently corrupt certain byte sequences from the serialized protocol message. Use ByteString or byte[] directly',
              [r".*: warning: \[LiteByteStringUtf8\] .+"]),
    java_high('This method does not acquire the locks specified by its @LockMethod annotation',
              [r".*: warning: \[LockMethodChecker\] .+"]),
    java_high('Prefer \'L\' to \'l\' for the suffix to long literals',
              [r".*: warning: \[LongLiteralLowerCaseSuffix\] .+"]),
    java_high('Loop condition is never modified in loop body.',
              [r".*: warning: \[LoopConditionChecker\] .+"]),
    java_high('Math.round(Integer) results in truncation',
              [r".*: warning: \[MathRoundIntLong\] .+"]),
    java_high('Certain resources in `android.R.string` have names that do not match their content',
              [r".*: warning: \[MislabeledAndroidString\] .+"]),
    java_high('Overriding method is missing a call to overridden super method',
              [r".*: warning: \[MissingSuperCall\] .+"]),
    java_high('A terminating method call is required for a test helper to have any effect.',
              [r".*: warning: \[MissingTestCall\] .+"]),
    java_high('Use of "YYYY" (week year) in a date pattern without "ww" (week in year). You probably meant to use "yyyy" (year) instead.',
              [r".*: warning: \[MisusedWeekYear\] .+"]),
    java_high('A bug in Mockito will cause this test to fail at runtime with a ClassCastException',
              [r".*: warning: \[MockitoCast\] .+"]),
    java_high('Missing method call for verify(mock) here',
              [r".*: warning: \[MockitoUsage\] .+"]),
    java_high('Using a collection function with itself as the argument.',
              [r".*: warning: \[ModifyingCollectionWithItself\] .+"]),
    java_high('This class has more than one @Inject-annotated constructor. Please remove the @Inject annotation from all but one of them.',
              [r".*: warning: \[MoreThanOneInjectableConstructor\] .+"]),
    java_high('The result of this method must be closed.',
              [r".*: warning: \[MustBeClosedChecker\] .+"]),
    java_high('The first argument to nCopies is the number of copies, and the second is the item to copy',
              [r".*: warning: \[NCopiesOfChar\] .+"]),
    java_high('@NoAllocation was specified on this method, but something was found that would trigger an allocation',
              [r".*: warning: \[NoAllocation\] .+"]),
    java_high('Static import of type uses non-canonical name',
              [r".*: warning: \[NonCanonicalStaticImport\] .+"]),
    java_high('@CompileTimeConstant parameters should be final or effectively final',
              [r".*: warning: \[NonFinalCompileTimeConstant\] .+"]),
    java_high('Calling getAnnotation on an annotation that is not retained at runtime.',
              [r".*: warning: \[NonRuntimeAnnotation\] .+"]),
    java_high('This conditional expression may evaluate to null, which will result in an NPE when the result is unboxed.',
              [r".*: warning: \[NullTernary\] .+"]),
    java_high('Numeric comparison using reference equality instead of value equality',
              [r".*: warning: \[NumericEquality\] .+"]),
    java_high('Comparison using reference equality instead of value equality',
              [r".*: warning: \[OptionalEquality\] .+"]),
    java_high('Annotations cannot be both Scope annotations and Qualifier annotations: this causes confusion when trying to use them.',
              [r".*: warning: \[OverlappingQualifierAndScopeAnnotation\] .+"]),
    java_high('This method is not annotated with @Inject, but it overrides a method that is  annotated with @javax.inject.Inject. The method will not be Injected.',
              [r".*: warning: \[OverridesJavaxInjectableMethod\] .+"]),
    java_high('Declaring types inside package-info.java files is very bad form',
              [r".*: warning: \[PackageInfo\] .+"]),
    java_high('Method parameter has wrong package',
              [r".*: warning: \[ParameterPackage\] .+"]),
    java_high('Detects classes which implement Parcelable but don\'t have CREATOR',
              [r".*: warning: \[ParcelableCreator\] .+"]),
    java_high('Literal passed as first argument to Preconditions.checkNotNull() can never be null',
              [r".*: warning: \[PreconditionsCheckNotNull\] .+"]),
    java_high('First argument to `Preconditions.checkNotNull()` is a primitive rather than an object reference',
              [r".*: warning: \[PreconditionsCheckNotNullPrimitive\] .+"]),
    java_high('Using ::equals or ::isInstance as an incompatible Predicate; the predicate will always return false',
              [r".*: warning: \[PredicateIncompatibleType\] .+"]),
    java_high('Access to a private protocol buffer field is forbidden. This protocol buffer carries a security contract, and can only be created using an approved library. Direct access to the fields is forbidden.',
              [r".*: warning: \[PrivateSecurityContractProtoAccess\] .+"]),
    java_high('Protobuf fields cannot be null.',
              [r".*: warning: \[ProtoFieldNullComparison\] .+"]),
    java_high('Comparing protobuf fields of type String using reference equality',
              [r".*: warning: \[ProtoStringFieldReferenceEquality\] .+"]),
    java_high('To get the tag number of a protocol buffer enum, use getNumber() instead.',
              [r".*: warning: \[ProtocolBufferOrdinal\] .+"]),
    java_high('@Provides methods need to be declared in a Module to have any effect.',
              [r".*: warning: \[ProvidesMethodOutsideOfModule\] .+"]),
    java_high('Casting a random number in the range [0.0, 1.0) to an integer or long always results in 0.',
              [r".*: warning: \[RandomCast\] .+"]),
    java_high('Use Random.nextInt(int).  Random.nextInt() % n can have negative results',
              [r".*: warning: \[RandomModInteger\] .+"]),
    java_high('Return value of android.graphics.Rect.intersect() must be checked',
              [r".*: warning: \[RectIntersectReturnValueIgnored\] .+"]),
    java_high('Use of method or class annotated with @RestrictTo',
              [r".*: warning: \[RestrictTo\] .+"]),
    java_high(' Check for non-whitelisted callers to RestrictedApiChecker.',
              [r".*: warning: \[RestrictedApiChecker\] .+"]),
    java_high('Return value of this method must be used',
              [r".*: warning: \[ReturnValueIgnored\] .+"]),
    java_high('Variable assigned to itself',
              [r".*: warning: \[SelfAssignment\] .+"]),
    java_high('An object is compared to itself',
              [r".*: warning: \[SelfComparison\] .+"]),
    java_high('Testing an object for equality with itself will always be true.',
              [r".*: warning: \[SelfEquals\] .+"]),
    java_high('This method must be called with an even number of arguments.',
              [r".*: warning: \[ShouldHaveEvenArgs\] .+"]),
    java_high('Comparison of a size >= 0 is always true, did you intend to check for non-emptiness?',
              [r".*: warning: \[SizeGreaterThanOrEqualsZero\] .+"]),
    java_high('Static and default interface methods are not natively supported on older Android devices. ',
              [r".*: warning: \[StaticOrDefaultInterfaceMethod\] .+"]),
    java_high('Calling toString on a Stream does not provide useful information',
              [r".*: warning: \[StreamToString\] .+"]),
    java_high('StringBuilder does not have a char constructor; this invokes the int constructor.',
              [r".*: warning: \[StringBuilderInitWithChar\] .+"]),
    java_high('String.substring(0) returns the original String',
              [r".*: warning: \[SubstringOfZero\] .+"]),
    java_high('Suppressing "deprecated" is probably a typo for "deprecation"',
              [r".*: warning: \[SuppressWarningsDeprecated\] .+"]),
    java_high('throwIfUnchecked(knownCheckedException) is a no-op.',
              [r".*: warning: \[ThrowIfUncheckedKnownChecked\] .+"]),
    java_high('Throwing \'null\' always results in a NullPointerException being thrown.',
              [r".*: warning: \[ThrowNull\] .+"]),
    java_high('isEqualTo should not be used to test an object for equality with itself; the assertion will never fail.',
              [r".*: warning: \[TruthSelfEquals\] .+"]),
    java_high('Catching Throwable/Error masks failures from fail() or assert*() in the try block',
              [r".*: warning: \[TryFailThrowable\] .+"]),
    java_high('Type parameter used as type qualifier',
              [r".*: warning: \[TypeParameterQualifier\] .+"]),
    java_high('This method does not acquire the locks specified by its @UnlockMethod annotation',
              [r".*: warning: \[UnlockMethod\] .+"]),
    java_high('Non-generic methods should not be invoked with type arguments',
              [r".*: warning: \[UnnecessaryTypeArgument\] .+"]),
    java_high('Instance created but never used',
              [r".*: warning: \[UnusedAnonymousClass\] .+"]),
    java_high('Collection is modified in place, but the result is not used',
              [r".*: warning: \[UnusedCollectionModifiedInPlace\] .+"]),
    java_high('`var` should not be used as a type name.',
              [r".*: warning: \[VarTypeName\] .+"]),

    # End warnings generated by Error Prone

    java_warn(Severity.UNKNOWN,
              'Unclassified/unrecognized warnings',
              [r".*: warning: \[.+\] .+"]),  # TODO(chh) use more specific pattern

    # aapt warnings
    {'category': 'aapt', 'severity': Severity.MEDIUM,
     'description': 'aapt: No default translation',
     'patterns': [r".*: warning: string '.+' has no default translation in .*"]},
    {'category': 'aapt', 'severity': Severity.MEDIUM,
     'description': 'aapt: Missing default or required localization',
     'patterns': [r".*: warning: \*\*\*\* string '.+' has no default or required localization for '.+' in .+"]},
    {'category': 'aapt', 'severity': Severity.MEDIUM,
     'description': 'aapt: String marked untranslatable, but translation exists',
     'patterns': [r".*: warning: string '.+' in .* marked untranslatable but exists in locale '??_??'"]},
    {'category': 'aapt', 'severity': Severity.MEDIUM,
     'description': 'aapt: empty span in string',
     'patterns': [r".*: warning: empty '.+' span found in text '.+"]},

    # C/C++ warnings
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Taking address of temporary',
     'patterns': [r".*: warning: taking address of temporary"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Taking address of packed member',
     'patterns': [r".*: warning: taking address of packed member"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Possible broken line continuation',
     'patterns': [r".*: warning: backslash and newline separated by space"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wundefined-var-template',
     'description': 'Undefined variable template',
     'patterns': [r".*: warning: instantiation of variable .* no definition is available"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wundefined-inline',
     'description': 'Inline function is not defined',
     'patterns': [r".*: warning: inline function '.*' is not defined"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Warray-bounds',
    #  'description': 'Array subscript out of bounds',
    #  'patterns': [r".*: warning: array subscript is above array bounds",
    #               r".*: warning: Array subscript is undefined",
    #               r".*: warning: array subscript is below array bounds"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Excess elements in initializer',
     'patterns': [r".*: warning: excess elements in .+ initializer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Decimal constant is unsigned only in ISO C90',
     'patterns': [r".*: warning: this decimal constant is unsigned only in ISO C90"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmain',
     'description': 'main is usually a function',
     'patterns': [r".*: warning: 'main' is usually a function"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Typedef ignored',
     'patterns': [r".*: warning: 'typedef' was ignored in this declaration"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Waddress',
     'description': 'Address always evaluates to true',
     'patterns': [r".*: warning: the address of '.+' will always evaluate as 'true'"]},
    {'category': 'C/C++', 'severity': Severity.FIXMENOW,
     'description': 'Freeing a non-heap object',
     'patterns': [r".*: warning: attempt to free a non-heap object '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wchar-subscripts',
     'description': 'Array subscript has type char',
     'patterns': [r".*: warning: array subscript .+ type 'char'.+Wchar-subscripts"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Constant too large for type',
     'patterns': [r".*: warning: integer constant is too large for '.+' type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Woverflow',
     'description': 'Constant too large for type, truncated',
     'patterns': [r".*: warning: large integer implicitly truncated to unsigned type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Winteger-overflow',
     'description': 'Overflow in expression',
     'patterns': [r".*: warning: overflow in expression; .*Winteger-overflow"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Woverflow',
     'description': 'Overflow in implicit constant conversion',
     'patterns': [r".*: warning: overflow in implicit constant conversion"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Declaration does not declare anything',
     'patterns': [r".*: warning: declaration 'class .+' does not declare anything"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wreorder',
     'description': 'Initialization order will be different',
     'patterns': [r".*: warning: '.+' will be initialized after",
                  r".*: warning: field .+ will be initialized after .+Wreorder"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip,   ....',
     'patterns': [r".*: warning:   '.+'"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip,   base ...',
     'patterns': [r".*: warning:   base '.+'"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip,   when initialized here',
     'patterns': [r".*: warning:   when initialized here"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmissing-parameter-type',
     'description': 'Parameter type not specified',
     'patterns': [r".*: warning: type of '.+' defaults to 'int'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmissing-declarations',
     'description': 'Missing declarations',
     'patterns': [r".*: warning: declaration does not declare anything"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wmissing-noreturn',
     'description': 'Missing noreturn',
     'patterns': [r".*: warning: function '.*' could be declared with attribute 'noreturn'"]},
    # pylint:disable=anomalous-backslash-in-string
    # TODO(chh): fix the backslash pylint warning.
    {'category': 'gcc', 'severity': Severity.MEDIUM,
     'description': 'Invalid option for C file',
     'patterns': [r".*: warning: command line option "".+"" is valid for C\+\+\/ObjC\+\+ but not for C"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'User warning',
     'patterns': [r".*: warning: #warning "".+"""]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wvexing-parse',
     'description': 'Vexing parsing problem',
     'patterns': [r".*: warning: empty parentheses interpreted as a function declaration"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wextra',
     'description': 'Dereferencing void*',
     'patterns': [r".*: warning: dereferencing 'void \*' pointer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Comparison of pointer and integer',
     'patterns': [r".*: warning: ordered comparison of pointer with integer zero",
                  r".*: warning: .*comparison between pointer and integer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Use of error-prone unary operator',
     'patterns': [r".*: warning: use of unary operator that may be intended as compound assignment"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wwrite-strings',
     'description': 'Conversion of string constant to non-const char*',
     'patterns': [r".*: warning: deprecated conversion from string constant to '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wstrict-prototypes',
     'description': 'Function declaration isn''t a prototype',
     'patterns': [r".*: warning: function declaration isn't a prototype"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wignored-qualifiers',
     'description': 'Type qualifiers ignored on function return value',
     'patterns': [r".*: warning: type qualifiers ignored on function return type",
                  r".*: warning: .+ type qualifier .+ has no effect .+Wignored-qualifiers"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': '&lt;foo&gt; declared inside parameter list, scope limited to this definition',
     'patterns': [r".*: warning: '.+' declared inside parameter list"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip, its scope is only this ...',
     'patterns': [r".*: warning: its scope is only this definition or declaration, which is probably not what you want"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wcomment',
     'description': 'Line continuation inside comment',
     'patterns': [r".*: warning: multi-line comment"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wcomment',
     'description': 'Comment inside comment',
     'patterns': [r".*: warning: '.+' within block comment .*-Wcomment"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wdeprecated-declarations',
     'description': 'Deprecated declarations',
     'patterns': [r".*: warning: .+ is deprecated.+deprecated-declarations"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wdeprecated-register',
     'description': 'Deprecated register',
     'patterns': [r".*: warning: 'register' storage class specifier is deprecated"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wpointer-sign',
     'description': 'Converts between pointers to integer types with different sign',
     'patterns': [r".*: warning: .+ converts between pointers to integer types with different sign"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Extra tokens after #endif',
     'patterns': [r".*: warning: extra tokens at end of #endif directive"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wenum-compare',
     'description': 'Comparison between different enums',
     'patterns': [r".*: warning: comparison between '.+' and '.+'.+Wenum-compare",
                  r".*: warning: comparison of .* enumeration types .*-Wenum-compare-switch"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wconversion',
     'description': 'Conversion may change value',
     'patterns': [r".*: warning: converting negative value '.+' to '.+'",
                  r".*: warning: conversion to '.+' .+ may (alter|change)"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wconversion-null',
     'description': 'Converting to non-pointer type from NULL',
     'patterns': [r".*: warning: converting to non-pointer type '.+' from NULL"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wsign-conversion',
     'description': 'Implicit sign conversion',
     'patterns': [r".*: warning: implicit conversion changes signedness"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wnull-conversion',
     'description': 'Converting NULL to non-pointer type',
     'patterns': [r".*: warning: implicit conversion of NULL constant to '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wnon-literal-null-conversion',
     'description': 'Zero used as null pointer',
     'patterns': [r".*: warning: expression .* zero treated as a null pointer constant"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Implicit conversion changes value or loses precision',
     'patterns': [r".*: warning: implicit conversion .* changes value from .* to .*-conversion",
                  r".*: warning: implicit conversion loses integer precision:"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Passing NULL as non-pointer argument',
     'patterns': [r".*: warning: passing NULL to non-pointer argument [0-9]+ of '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wctor-dtor-privacy',
     'description': 'Class seems unusable because of private ctor/dtor',
     'patterns': [r".*: warning: all member functions in class '.+' are private"]},
    # skip this next one, because it only points out some RefBase-based classes where having a private destructor is perfectly fine
    {'category': 'C/C++', 'severity': Severity.SKIP, 'option': '-Wctor-dtor-privacy',
     'description': 'Class seems unusable because of private ctor/dtor',
     'patterns': [r".*: warning: 'class .+' only defines a private destructor and has no friends"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wctor-dtor-privacy',
     'description': 'Class seems unusable because of private ctor/dtor',
     'patterns': [r".*: warning: 'class .+' only defines private constructors and has no friends"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wgnu-static-float-init',
     'description': 'In-class initializer for static const float/double',
     'patterns': [r".*: warning: in-class initializer for static data member of .+const (float|double)"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wpointer-arith',
     'description': 'void* used in arithmetic',
     'patterns': [r".*: warning: pointer of type 'void \*' used in (arithmetic|subtraction)",
                  r".*: warning: arithmetic on .+ to void is a GNU extension.*Wpointer-arith",
                  r".*: warning: wrong type argument to increment"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wsign-promo',
     'description': 'Overload resolution chose to promote from unsigned or enum to signed type',
     'patterns': [r".*: warning: passing '.+' chooses '.+' over '.+'.*Wsign-promo"]},
    {'category': 'cont.', 'severity': Severity.SKIP,
     'description': 'skip,   in call to ...',
     'patterns': [r".*: warning:   in call to '.+'"]},
    {'category': 'C/C++', 'severity': Severity.HIGH, 'option': '-Wextra',
     'description': 'Base should be explicitly initialized in copy constructor',
     'patterns': [r".*: warning: base class '.+' should be explicitly initialized in the copy constructor"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'VLA has zero or negative size',
    #  'patterns': [r".*: warning: Declared variable-length array \(VLA\) has .+ size"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Return value from void function',
     'patterns': [r".*: warning: 'return' with a value, in function returning void"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'multichar',
     'description': 'Multi-character character constant',
     'patterns': [r".*: warning: multi-character character constant"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'writable-strings',
     'description': 'Conversion from string literal to char*',
     'patterns': [r".*: warning: .+ does not allow conversion from string literal to 'char \*'"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wextra-semi',
     'description': 'Extra \';\'',
     'patterns': [r".*: warning: extra ';' .+extra-semi"]},
    {'category': 'C/C++', 'severity': Severity.LOW,
     'description': 'Useless specifier',
     'patterns': [r".*: warning: useless storage class specifier in empty declaration"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wduplicate-decl-specifier',
     'description': 'Duplicate declaration specifier',
     'patterns': [r".*: warning: duplicate '.+' declaration specifier"]},
    {'category': 'logtags', 'severity': Severity.LOW,
     'description': 'Duplicate logtag',
     'patterns': [r".*: warning: tag \".+\" \(.+\) duplicated in .+"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'typedef-redefinition',
     'description': 'Typedef redefinition',
     'patterns': [r".*: warning: redefinition of typedef '.+' is a C11 feature"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'gnu-designator',
     'description': 'GNU old-style field designator',
     'patterns': [r".*: warning: use of GNU old-style field designator extension"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'missing-field-initializers',
     'description': 'Missing field initializers',
     'patterns': [r".*: warning: missing field '.+' initializer"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'missing-braces',
     'description': 'Missing braces',
     'patterns': [r".*: warning: suggest braces around initialization of",
                  r".*: warning: too many braces around scalar initializer .+Wmany-braces-around-scalar-init",
                  r".*: warning: braces around scalar initializer"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'sign-compare',
     'description': 'Comparison of integers of different signs',
     'patterns': [r".*: warning: comparison of integers of different signs.+sign-compare"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'dangling-else',
     'description': 'Add braces to avoid dangling else',
     'patterns': [r".*: warning: add explicit braces to avoid dangling else"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'initializer-overrides',
     'description': 'Initializer overrides prior initialization',
     'patterns': [r".*: warning: initializer overrides prior initialization of this subobject"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'self-assign',
     'description': 'Assigning value to self',
     'patterns': [r".*: warning: explicitly assigning value of .+ to itself"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'gnu-variable-sized-type-not-at-end',
     'description': 'GNU extension, variable sized type not at end',
     'patterns': [r".*: warning: field '.+' with variable sized type '.+' not at the end of a struct or class"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'tautological-constant-out-of-range-compare',
     'description': 'Comparison of constant is always false/true',
     'patterns': [r".*: comparison of .+ is always .+Wtautological-constant-out-of-range-compare"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'overloaded-virtual',
     'description': 'Hides overloaded virtual function',
     'patterns': [r".*: '.+' hides overloaded virtual function"]},
    {'category': 'logtags', 'severity': Severity.LOW,
     'description': 'Incompatible pointer types',
     'patterns': [r".*: warning: incompatible .*pointer types .*-Wincompatible-.*pointer-types"]},
    {'category': 'logtags', 'severity': Severity.LOW, 'option': 'asm-operand-widths',
     'description': 'ASM value size does not match register size',
     'patterns': [r".*: warning: value size does not match register size specified by the constraint and modifier"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': 'tautological-compare',
     'description': 'Comparison of self is always false',
     'patterns': [r".*: self-comparison always evaluates to false"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': 'constant-logical-operand',
     'description': 'Logical op with constant operand',
     'patterns': [r".*: use of logical '.+' with constant operand"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': 'literal-suffix',
     'description': 'Needs a space between literal and string macro',
     'patterns': [r".*: warning: invalid suffix on literal.+ requires a space .+Wliteral-suffix"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '#warnings',
     'description': 'Warnings from #warning',
     'patterns': [r".*: warning: .+-W#warnings"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': 'absolute-value',
     'description': 'Using float/int absolute value function with int/float argument',
     'patterns': [r".*: warning: using .+ absolute value function .+ when argument is .+ type .+Wabsolute-value",
                  r".*: warning: absolute value function '.+' given .+ which may cause truncation .+Wabsolute-value"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Wc++11-extensions',
     'description': 'Using C++11 extensions',
     'patterns': [r".*: warning: 'auto' type specifier is a C\+\+11 extension"]},
    {'category': 'C/C++', 'severity': Severity.LOW,
     'description': 'Refers to implicitly defined namespace',
     'patterns': [r".*: warning: using directive refers to implicitly-defined namespace .+"]},
    {'category': 'C/C++', 'severity': Severity.LOW, 'option': '-Winvalid-pp-token',
     'description': 'Invalid pp token',
     'patterns': [r".*: warning: missing .+Winvalid-pp-token"]},
    {'category': 'link', 'severity': Severity.LOW,
     'description': 'need glibc to link',
     'patterns': [r".*: warning: .* requires at runtime .* glibc .* for linking"]},

    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Operator new returns NULL',
     'patterns': [r".*: warning: 'operator new' must not return NULL unless it is declared 'throw\(\)' .+"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wnull-arithmetic',
     'description': 'NULL used in arithmetic',
     'patterns': [r".*: warning: NULL used in arithmetic",
                  r".*: warning: comparison between NULL and non-pointer"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'header-guard',
     'description': 'Misspelled header guard',
     'patterns': [r".*: warning: '.+' is used as a header guard .+ followed by .+ different macro"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'empty-body',
     'description': 'Empty loop body',
     'patterns': [r".*: warning: .+ loop has empty body"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'enum-conversion',
     'description': 'Implicit conversion from enumeration type',
     'patterns': [r".*: warning: implicit conversion from enumeration type '.+'"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': 'switch',
     'description': 'case value not in enumerated type',
     'patterns': [r".*: warning: case value not in enumerated type '.+'"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Undefined result',
    #  'patterns': [r".*: warning: The result of .+ is undefined",
    #               r".*: warning: passing an object that .+ has undefined behavior \[-Wvarargs\]",
    #               r".*: warning: 'this' pointer cannot be null in well-defined C\+\+ code;",
    #               r".*: warning: shifting a negative signed value is undefined"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Division by zero',
    #  'patterns': [r".*: warning: Division by zero"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Use of deprecated method',
     'patterns': [r".*: warning: '.+' is deprecated .+"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Use of garbage or uninitialized value',
     'patterns': [r".*: warning: .+ uninitialized .+\[-Wsometimes-uninitialized\]"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Use of garbage or uninitialized value',
    #  'patterns': [r".*: warning: .+ is a garbage value",
    #               r".*: warning: Function call argument is an uninitialized value",
    #               r".*: warning: Undefined or garbage value returned to caller",
    #               r".*: warning: Called .+ pointer is.+uninitialized",
    #               r".*: warning: Called .+ pointer is.+uninitalized",  # match a typo in compiler message
    #               r".*: warning: Use of zero-allocated memory",
    #               r".*: warning: Dereference of undefined pointer value",
    #               r".*: warning: Passed-by-value .+ contains uninitialized data",
    #               r".*: warning: Branch condition evaluates to a garbage value",
    #               r".*: warning: The .+ of .+ is an uninitialized value.",
    #               r".*: warning: .+ is used uninitialized whenever .+sometimes-uninitialized",
    #               r".*: warning: Assigned value is garbage or undefined"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Result of malloc type incompatible with sizeof operand type',
    #  'patterns': [r".*: warning: Result of '.+' is converted to .+ incompatible with sizeof operand type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wsizeof-array-argument',
     'description': 'Sizeof on array argument',
     'patterns': [r".*: warning: sizeof on array function parameter will return"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wsizeof-pointer-memacces',
     'description': 'Bad argument size of memory access functions',
     'patterns': [r".*: warning: .+\[-Wsizeof-pointer-memaccess\]"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Return value not checked',
     'patterns': [r".*: warning: The return value from .+ is not checked"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Possible heap pollution',
     'patterns': [r".*: warning: .*Possible heap pollution from .+ type .+"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Allocation size of 0 byte',
    #  'patterns': [r".*: warning: Call to .+ has an allocation size of 0 byte"]},
    # {'category': 'C/C++', 'severity': Severity.MEDIUM,
    #  'description': 'Result of malloc type incompatible with sizeof operand type',
    #  'patterns': [r".*: warning: Result of '.+' is converted to .+ incompatible with sizeof operand type"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wfor-loop-analysis',
     'description': 'Variable used in loop condition not modified in loop body',
     'patterns': [r".*: warning: variable '.+' used in loop condition.*Wfor-loop-analysis"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM,
     'description': 'Closing a previously closed file',
     'patterns': [r".*: warning: Closing a previously closed file"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wunnamed-type-template-args',
     'description': 'Unnamed template type argument',
     'patterns': [r".*: warning: template argument.+Wunnamed-type-template-args"]},
    {'category': 'C/C++', 'severity': Severity.MEDIUM, 'option': '-Wimplicit-fallthrough',
     'description': 'Unannotated fall-through between switch labels',
     'patterns': [r".*: warning: unannotated fall-through between switch labels.+Wimplicit-fallthrough"]},

    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Discarded qualifier from pointer target type',
     'patterns': [r".*: warning: .+ discards '.+' qualifier from pointer target type"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Use snprintf instead of sprintf',
     'patterns': [r".*: warning: .*sprintf is often misused; please use snprintf"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Unsupported optimizaton flag',
     'patterns': [r".*: warning: optimization flag '.+' is not supported"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS,
     'description': 'Extra or missing parentheses',
     'patterns': [r".*: warning: equality comparison with extraneous parentheses",
                  r".*: warning: .+ within .+Wlogical-op-parentheses"]},
    {'category': 'C/C++', 'severity': Severity.HARMLESS, 'option': 'mismatched-tags',
     'description': 'Mismatched class vs struct tags',
     'patterns': [r".*: warning: '.+' defined as a .+ here but previously declared as a .+mismatched-tags",
                  r".*: warning: .+ was previously declared as a .+mismatched-tags"]},
    {'category': 'FindEmulator', 'severity': Severity.HARMLESS,
     'description': 'FindEmulator: No such file or directory',
     'patterns': [r".*: warning: FindEmulator: .* No such file or directory"]},
    {'category': 'make', 'severity': Severity.HARMLESS,
     'description': 'make: unknown installed file',
     'patterns': [r".*: warning: .*_tests: Unknown installed file for module"]},
    {'category': 'make', 'severity': Severity.HARMLESS,
     'description': 'unusual tags debug eng',
     'patterns': [r".*: warning: .*: unusual tags debug eng"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'make: please convert to soong',
     'patterns': [r".*: warning: .* has been deprecated. Please convert to Soong."]},

    # these next ones are to deal with formatting problems resulting from the log being mixed up by 'make -j'
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip, ,',
     'patterns': [r".*: warning: ,$"]},
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip,',
     'patterns': [r".*: warning: $"]},
    {'category': 'C/C++', 'severity': Severity.SKIP,
     'description': 'skip, In file included from ...',
     'patterns': [r".*: warning: In file included from .+,"]},

    # warnings from clang-tidy
    group_tidy_warn_pattern('android'),
    simple_tidy_warn_pattern('abseil-string-find-startswith'),
    simple_tidy_warn_pattern('bugprone-argument-comment'),
    simple_tidy_warn_pattern('bugprone-copy-constructor-init'),
    simple_tidy_warn_pattern('bugprone-fold-init-type'),
    simple_tidy_warn_pattern('bugprone-forward-declaration-namespace'),
    simple_tidy_warn_pattern('bugprone-forwarding-reference-overload'),
    simple_tidy_warn_pattern('bugprone-inaccurate-erase'),
    simple_tidy_warn_pattern('bugprone-incorrect-roundings'),
    simple_tidy_warn_pattern('bugprone-integer-division'),
    simple_tidy_warn_pattern('bugprone-lambda-function-name'),
    simple_tidy_warn_pattern('bugprone-macro-parentheses'),
    simple_tidy_warn_pattern('bugprone-misplaced-widening-cast'),
    simple_tidy_warn_pattern('bugprone-move-forwarding-reference'),
    simple_tidy_warn_pattern('bugprone-sizeof-expression'),
    simple_tidy_warn_pattern('bugprone-string-constructor'),
    simple_tidy_warn_pattern('bugprone-string-integer-assignment'),
    simple_tidy_warn_pattern('bugprone-suspicious-enum-usage'),
    simple_tidy_warn_pattern('bugprone-suspicious-missing-comma'),
    simple_tidy_warn_pattern('bugprone-suspicious-string-compare'),
    simple_tidy_warn_pattern('bugprone-suspicious-semicolon'),
    simple_tidy_warn_pattern('bugprone-undefined-memory-manipulation'),
    simple_tidy_warn_pattern('bugprone-unused-raii'),
    simple_tidy_warn_pattern('bugprone-use-after-move'),
    group_tidy_warn_pattern('bugprone'),
    group_tidy_warn_pattern('cert'),
    group_tidy_warn_pattern('clang-diagnostic'),
    group_tidy_warn_pattern('cppcoreguidelines'),
    group_tidy_warn_pattern('llvm'),
    simple_tidy_warn_pattern('google-default-arguments'),
    simple_tidy_warn_pattern('google-runtime-int'),
    simple_tidy_warn_pattern('google-runtime-operator'),
    simple_tidy_warn_pattern('google-runtime-references'),
    group_tidy_warn_pattern('google-build'),
    group_tidy_warn_pattern('google-explicit'),
    group_tidy_warn_pattern('google-redability'),
    group_tidy_warn_pattern('google-global'),
    group_tidy_warn_pattern('google-redability'),
    group_tidy_warn_pattern('google-redability'),
    group_tidy_warn_pattern('google'),
    simple_tidy_warn_pattern('hicpp-explicit-conversions'),
    simple_tidy_warn_pattern('hicpp-function-size'),
    simple_tidy_warn_pattern('hicpp-invalid-access-moved'),
    simple_tidy_warn_pattern('hicpp-member-init'),
    simple_tidy_warn_pattern('hicpp-delete-operators'),
    simple_tidy_warn_pattern('hicpp-special-member-functions'),
    simple_tidy_warn_pattern('hicpp-use-equals-default'),
    simple_tidy_warn_pattern('hicpp-use-equals-delete'),
    simple_tidy_warn_pattern('hicpp-no-assembler'),
    simple_tidy_warn_pattern('hicpp-noexcept-move'),
    simple_tidy_warn_pattern('hicpp-use-override'),
    group_tidy_warn_pattern('hicpp'),
    group_tidy_warn_pattern('modernize'),
    group_tidy_warn_pattern('misc'),
    simple_tidy_warn_pattern('performance-faster-string-find'),
    simple_tidy_warn_pattern('performance-for-range-copy'),
    simple_tidy_warn_pattern('performance-implicit-cast-in-loop'),
    simple_tidy_warn_pattern('performance-inefficient-string-concatenation'),
    simple_tidy_warn_pattern('performance-type-promotion-in-math-fn'),
    simple_tidy_warn_pattern('performance-unnecessary-copy-initialization'),
    simple_tidy_warn_pattern('performance-unnecessary-value-param'),
    simple_tidy_warn_pattern('portability-simd-intrinsics'),
    group_tidy_warn_pattern('performance'),
    group_tidy_warn_pattern('readability'),

    # warnings from clang-tidy's clang-analyzer checks
    analyzer_high('clang-analyzer-core, null pointer',
                  [r".*: warning: .+ pointer is null .*\[clang-analyzer-core"]),
    analyzer_high('clang-analyzer-core, uninitialized value',
                  [r".*: warning: .+ uninitialized (value|data) .*\[clang-analyzer-core"]),
    analyzer_warn('clang-analyzer-optin.performance.Padding',
                  [r".*: warning: Excessive padding in '.*'"]),
    # analyzer_warn('clang-analyzer Unreachable code',
    #               [r".*: warning: This statement is never executed.*UnreachableCode"]),
    analyzer_warn('clang-analyzer Size of malloc may overflow',
                  [r".*: warning: .* size of .* may overflow .*MallocOverflow"]),
    analyzer_warn('clang-analyzer sozeof() on a pointer type',
                  [r".*: warning: .*calls sizeof.* on a pointer type.*SizeofPtr"]),
    analyzer_warn('clang-analyzer Pointer arithmetic on non-array variables',
                  [r".*: warning: Pointer arithmetic on non-array variables .*PointerArithm"]),
    analyzer_warn('clang-analyzer Subtraction of pointers of different memory chunks',
                  [r".*: warning: Subtraction of two pointers .*PointerSub"]),
    analyzer_warn('clang-analyzer Access out-of-bound array element',
                  [r".*: warning: Access out-of-bound array element .*ArrayBound"]),
    analyzer_warn('clang-analyzer Out of bound memory access',
                  [r".*: warning: Out of bound memory access .*ArrayBoundV2"]),
    analyzer_warn('clang-analyzer Possible lock order reversal',
                  [r".*: warning: .* Possible lock order reversal.*PthreadLock"]),
    analyzer_warn('clang-analyzer call path problems',
                  [r".*: warning: Call Path : .+"]),
    analyzer_warn_check('clang-analyzer-core.CallAndMessage'),
    analyzer_high_check('clang-analyzer-core.NonNullParamChecker'),
    analyzer_high_check('clang-analyzer-core.NullDereference'),
    analyzer_warn_check('clang-analyzer-core.UndefinedBinaryOperatorResult'),
    analyzer_warn_check('clang-analyzer-core.DivideZero'),
    analyzer_warn_check('clang-analyzer-core.VLASize'),
    analyzer_warn_check('clang-analyzer-core.uninitialized.ArraySubscript'),
    analyzer_warn_check('clang-analyzer-core.uninitialized.Assign'),
    analyzer_warn_check('clang-analyzer-core.uninitialized.UndefReturn'),
    analyzer_warn_check('clang-analyzer-cplusplus.Move'),
    analyzer_warn_check('clang-analyzer-deadcode.DeadStores'),
    analyzer_warn_check('clang-analyzer-optin.cplusplus.UninitializedObject'),
    analyzer_warn_check('clang-analyzer-optin.cplusplus.VirtualCall'),
    analyzer_warn_check('clang-analyzer-portability.UnixAPI'),
    analyzer_warn_check('clang-analyzer-unix.cstring.NullArg'),
    analyzer_high_check('clang-analyzer-unix.MallocSizeof'),
    analyzer_warn_check('clang-analyzer-valist.Uninitialized'),
    analyzer_warn_check('clang-analyzer-valist.Unterminated'),
    analyzer_group_check('clang-analyzer-core.uninitialized'),
    analyzer_group_check('clang-analyzer-deadcode'),
    analyzer_warn_check('clang-analyzer-security.insecureAPI.strcpy'),
    analyzer_group_high('clang-analyzer-security.insecureAPI'),
    analyzer_group_high('clang-analyzer-security'),
    analyzer_high_check('clang-analyzer-unix.Malloc'),
    analyzer_high_check('clang-analyzer-cplusplus.NewDeleteLeaks'),
    analyzer_high_check('clang-analyzer-cplusplus.NewDelete'),
    analyzer_group_check('clang-analyzer-unix'),
    analyzer_group_check('clang-analyzer'),  # catch al

    # Assembler warnings
    {'category': 'Asm', 'severity': Severity.MEDIUM,
     'description': 'Asm: IT instruction is deprecated',
     'patterns': [r".*: warning: applying IT instruction .* is deprecated"]},

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

    # rustc warnings
    {'category': 'Rust', 'severity': Severity.HIGH,
     'description': 'Rust: Does not derive Copy',
     'patterns': [r".*: warning: .+ does not derive Copy"]},
    {'category': 'Rust', 'severity': Severity.MEDIUM,
     'description': 'Rust: Deprecated range pattern',
     'patterns': [r".*: warning: .+ range patterns are deprecated"]},
    {'category': 'Rust', 'severity': Severity.MEDIUM,
     'description': 'Rust: Deprecated missing explicit \'dyn\'',
     'patterns': [r".*: warning: .+ without an explicit `dyn` are deprecated"]},

    # catch-all for warnings this script doesn't know about yet
    {'category': 'C/C++', 'severity': Severity.UNKNOWN,
     'description': 'Unclassified/unrecognized warnings',
     'patterns': [r".*: warning: .+"]},
]


def project_name_and_pattern(name, pattern):
  return [name, '(^|.*/)' + pattern + '/.*: warning:']


def simple_project_pattern(pattern):
  return project_name_and_pattern(pattern, pattern)


# A list of [project_name, file_path_pattern].
# project_name should not contain comma, to be used in CSV output.
project_list = [
    simple_project_pattern('art'),
    simple_project_pattern('bionic'),
    simple_project_pattern('bootable'),
    simple_project_pattern('build'),
    simple_project_pattern('cts'),
    simple_project_pattern('dalvik'),
    simple_project_pattern('developers'),
    simple_project_pattern('development'),
    simple_project_pattern('device'),
    simple_project_pattern('doc'),
    # match external/google* before external/
    project_name_and_pattern('external/google', 'external/google.*'),
    project_name_and_pattern('external/non-google', 'external'),
    simple_project_pattern('frameworks/av/camera'),
    simple_project_pattern('frameworks/av/cmds'),
    simple_project_pattern('frameworks/av/drm'),
    simple_project_pattern('frameworks/av/include'),
    simple_project_pattern('frameworks/av/media/img_utils'),
    simple_project_pattern('frameworks/av/media/libcpustats'),
    simple_project_pattern('frameworks/av/media/libeffects'),
    simple_project_pattern('frameworks/av/media/libmediaplayerservice'),
    simple_project_pattern('frameworks/av/media/libmedia'),
    simple_project_pattern('frameworks/av/media/libstagefright'),
    simple_project_pattern('frameworks/av/media/mtp'),
    simple_project_pattern('frameworks/av/media/ndk'),
    simple_project_pattern('frameworks/av/media/utils'),
    project_name_and_pattern('frameworks/av/media/Other',
                             'frameworks/av/media'),
    simple_project_pattern('frameworks/av/radio'),
    simple_project_pattern('frameworks/av/services'),
    simple_project_pattern('frameworks/av/soundtrigger'),
    project_name_and_pattern('frameworks/av/Other', 'frameworks/av'),
    simple_project_pattern('frameworks/base/cmds'),
    simple_project_pattern('frameworks/base/core'),
    simple_project_pattern('frameworks/base/drm'),
    simple_project_pattern('frameworks/base/media'),
    simple_project_pattern('frameworks/base/libs'),
    simple_project_pattern('frameworks/base/native'),
    simple_project_pattern('frameworks/base/packages'),
    simple_project_pattern('frameworks/base/rs'),
    simple_project_pattern('frameworks/base/services'),
    simple_project_pattern('frameworks/base/tests'),
    simple_project_pattern('frameworks/base/tools'),
    project_name_and_pattern('frameworks/base/Other', 'frameworks/base'),
    simple_project_pattern('frameworks/compile/libbcc'),
    simple_project_pattern('frameworks/compile/mclinker'),
    simple_project_pattern('frameworks/compile/slang'),
    project_name_and_pattern('frameworks/compile/Other', 'frameworks/compile'),
    simple_project_pattern('frameworks/minikin'),
    simple_project_pattern('frameworks/ml'),
    simple_project_pattern('frameworks/native/cmds'),
    simple_project_pattern('frameworks/native/include'),
    simple_project_pattern('frameworks/native/libs'),
    simple_project_pattern('frameworks/native/opengl'),
    simple_project_pattern('frameworks/native/services'),
    simple_project_pattern('frameworks/native/vulkan'),
    project_name_and_pattern('frameworks/native/Other', 'frameworks/native'),
    simple_project_pattern('frameworks/opt'),
    simple_project_pattern('frameworks/rs'),
    simple_project_pattern('frameworks/webview'),
    simple_project_pattern('frameworks/wilhelm'),
    project_name_and_pattern('frameworks/Other', 'frameworks'),
    simple_project_pattern('hardware/akm'),
    simple_project_pattern('hardware/broadcom'),
    simple_project_pattern('hardware/google'),
    simple_project_pattern('hardware/intel'),
    simple_project_pattern('hardware/interfaces'),
    simple_project_pattern('hardware/libhardware'),
    simple_project_pattern('hardware/libhardware_legacy'),
    simple_project_pattern('hardware/qcom'),
    simple_project_pattern('hardware/ril'),
    project_name_and_pattern('hardware/Other', 'hardware'),
    simple_project_pattern('kernel'),
    simple_project_pattern('libcore'),
    simple_project_pattern('libnativehelper'),
    simple_project_pattern('ndk'),
    # match vendor/unbungled_google/packages before other packages
    simple_project_pattern('unbundled_google'),
    simple_project_pattern('packages'),
    simple_project_pattern('pdk'),
    simple_project_pattern('prebuilts'),
    simple_project_pattern('system/bt'),
    simple_project_pattern('system/connectivity'),
    simple_project_pattern('system/core/adb'),
    simple_project_pattern('system/core/base'),
    simple_project_pattern('system/core/debuggerd'),
    simple_project_pattern('system/core/fastboot'),
    simple_project_pattern('system/core/fingerprintd'),
    simple_project_pattern('system/core/fs_mgr'),
    simple_project_pattern('system/core/gatekeeperd'),
    simple_project_pattern('system/core/healthd'),
    simple_project_pattern('system/core/include'),
    simple_project_pattern('system/core/init'),
    simple_project_pattern('system/core/libbacktrace'),
    simple_project_pattern('system/core/liblog'),
    simple_project_pattern('system/core/libpixelflinger'),
    simple_project_pattern('system/core/libprocessgroup'),
    simple_project_pattern('system/core/libsysutils'),
    simple_project_pattern('system/core/logcat'),
    simple_project_pattern('system/core/logd'),
    simple_project_pattern('system/core/run-as'),
    simple_project_pattern('system/core/sdcard'),
    simple_project_pattern('system/core/toolbox'),
    project_name_and_pattern('system/core/Other', 'system/core'),
    simple_project_pattern('system/extras/ANRdaemon'),
    simple_project_pattern('system/extras/cpustats'),
    simple_project_pattern('system/extras/crypto-perf'),
    simple_project_pattern('system/extras/ext4_utils'),
    simple_project_pattern('system/extras/f2fs_utils'),
    simple_project_pattern('system/extras/iotop'),
    simple_project_pattern('system/extras/libfec'),
    simple_project_pattern('system/extras/memory_replay'),
    simple_project_pattern('system/extras/mmap-perf'),
    simple_project_pattern('system/extras/multinetwork'),
    simple_project_pattern('system/extras/procrank'),
    simple_project_pattern('system/extras/runconuid'),
    simple_project_pattern('system/extras/showmap'),
    simple_project_pattern('system/extras/simpleperf'),
    simple_project_pattern('system/extras/su'),
    simple_project_pattern('system/extras/tests'),
    simple_project_pattern('system/extras/verity'),
    project_name_and_pattern('system/extras/Other', 'system/extras'),
    simple_project_pattern('system/gatekeeper'),
    simple_project_pattern('system/keymaster'),
    simple_project_pattern('system/libhidl'),
    simple_project_pattern('system/libhwbinder'),
    simple_project_pattern('system/media'),
    simple_project_pattern('system/netd'),
    simple_project_pattern('system/nvram'),
    simple_project_pattern('system/security'),
    simple_project_pattern('system/sepolicy'),
    simple_project_pattern('system/tools'),
    simple_project_pattern('system/update_engine'),
    simple_project_pattern('system/vold'),
    project_name_and_pattern('system/Other', 'system'),
    simple_project_pattern('toolchain'),
    simple_project_pattern('test'),
    simple_project_pattern('tools'),
    # match vendor/google* before vendor/
    project_name_and_pattern('vendor/google', 'vendor/google.*'),
    project_name_and_pattern('vendor/non-google', 'vendor'),
    # keep out/obj and other patterns at the end.
    ['out/obj',
     '.*/(gen|obj[^/]*)/(include|EXECUTABLES|SHARED_LIBRARIES|'
     'STATIC_LIBRARIES|NATIVE_TESTS)/.*: warning:'],
    ['other', '.*']  # all other unrecognized patterns
]

project_patterns = []
project_names = []
warning_messages = []
warning_records = []


def initialize_arrays():
  """Complete global arrays before they are used."""
  global project_names, project_patterns
  project_names = [p[0] for p in project_list]
  project_patterns = [re.compile(p[1]) for p in project_list]
  for w in warn_patterns:
    w['members'] = []
    if 'option' not in w:
      w['option'] = ''
    # Each warning pattern has a 'projects' dictionary, that
    # maps a project name to number of warnings in that project.
    w['projects'] = {}


initialize_arrays()


android_root = ''
platform_version = 'unknown'
target_product = 'unknown'
target_variant = 'unknown'


##### Data and functions to dump html file. ##################################

html_head_scripts = """\
  <script type="text/javascript">
  function expand(id) {
    var e = document.getElementById(id);
    var f = document.getElementById(id + "_mark");
    if (e.style.display == 'block') {
       e.style.display = 'none';
       f.innerHTML = '&#x2295';
    }
    else {
       e.style.display = 'block';
       f.innerHTML = '&#x2296';
    }
  };
  function expandCollapse(show) {
    for (var id = 1; ; id++) {
      var e = document.getElementById(id + "");
      var f = document.getElementById(id + "_mark");
      if (!e || !f) break;
      e.style.display = (show ? 'block' : 'none');
      f.innerHTML = (show ? '&#x2296' : '&#x2295');
    }
  };
  </script>
  <style type="text/css">
  th,td{border-collapse:collapse; border:1px solid black;}
  .button{color:blue;font-size:110%;font-weight:bolder;}
  .bt{color:black;background-color:transparent;border:none;outline:none;
      font-size:140%;font-weight:bolder;}
  .c0{background-color:#e0e0e0;}
  .c1{background-color:#d0d0d0;}
  .t1{border-collapse:collapse; width:100%; border:1px solid black;}
  </style>
  <script src="https://www.gstatic.com/charts/loader.js"></script>
"""


def html_big(param):
  return '<font size="+2">' + param + '</font>'


def dump_html_prologue(title):
  print('<html>\n<head>')
  print('<title>' + title + '</title>')
  print(html_head_scripts)
  emit_stats_by_project()
  print('</head>\n<body>')
  print(html_big(title))
  print('<p>')


def dump_html_epilogue():
  print('</body>\n</head>\n</html>')


def sort_warnings():
  for i in warn_patterns:
    i['members'] = sorted(set(i['members']))


def emit_stats_by_project():
  """Dump a google chart table of warnings per project and severity."""
  # warnings[p][s] is number of warnings in project p of severity s.
  # pylint:disable=g-complex-comprehension
  warnings = {p: {s: 0 for s in Severity.range} for p in project_names}
  for i in warn_patterns:
    s = i['severity']
    for p in i['projects']:
      warnings[p][s] += i['projects'][p]

  # total_by_project[p] is number of warnings in project p.
  total_by_project = {p: sum(warnings[p][s] for s in Severity.range)
                      for p in project_names}

  # total_by_severity[s] is number of warnings of severity s.
  total_by_severity = {s: sum(warnings[p][s] for p in project_names)
                       for s in Severity.range}

  # emit table header
  stats_header = ['Project']
  for s in Severity.range:
    if total_by_severity[s]:
      stats_header.append("<span style='background-color:{}'>{}</span>".
                          format(Severity.colors[s],
                                 Severity.column_headers[s]))
  stats_header.append('TOTAL')

  # emit a row of warning counts per project, skip no-warning projects
  total_all_projects = 0
  stats_rows = []
  for p in project_names:
    if total_by_project[p]:
      one_row = [p]
      for s in Severity.range:
        if total_by_severity[s]:
          one_row.append(warnings[p][s])
      one_row.append(total_by_project[p])
      stats_rows.append(one_row)
      total_all_projects += total_by_project[p]

  # emit a row of warning counts per severity
  total_all_severities = 0
  one_row = ['<b>TOTAL</b>']
  for s in Severity.range:
    if total_by_severity[s]:
      one_row.append(total_by_severity[s])
      total_all_severities += total_by_severity[s]
  one_row.append(total_all_projects)
  stats_rows.append(one_row)
  print('<script>')
  emit_const_string_array('StatsHeader', stats_header)
  emit_const_object_array('StatsRows', stats_rows)
  print(draw_table_javascript)
  print('</script>')


def dump_stats():
  """Dump some stats about total number of warnings and such."""
  known = 0
  skipped = 0
  unknown = 0
  sort_warnings()
  for i in warn_patterns:
    if i['severity'] == Severity.UNKNOWN:
      unknown += len(i['members'])
    elif i['severity'] == Severity.SKIP:
      skipped += len(i['members'])
    else:
      known += len(i['members'])
  print('Number of classified warnings: <b>' + str(known) + '</b><br>')
  print('Number of skipped warnings: <b>' + str(skipped) + '</b><br>')
  print('Number of unclassified warnings: <b>' + str(unknown) + '</b><br>')
  total = unknown + known + skipped
  extra_msg = ''
  if total < 1000:
    extra_msg = ' (low count may indicate incremental build)'
  print('Total number of warnings: <b>' + str(total) + '</b>' + extra_msg)


# New base table of warnings, [severity, warn_id, project, warning_message]
# Need buttons to show warnings in different grouping options.
# (1) Current, group by severity, id for each warning pattern
#     sort by severity, warn_id, warning_message
# (2) Current --byproject, group by severity,
#     id for each warning pattern + project name
#     sort by severity, warn_id, project, warning_message
# (3) New, group by project + severity,
#     id for each warning pattern
#     sort by project, severity, warn_id, warning_message
def emit_buttons():
  print('<button class="button" onclick="expandCollapse(1);">'
        'Expand all warnings</button>\n'
        '<button class="button" onclick="expandCollapse(0);">'
        'Collapse all warnings</button>\n'
        '<button class="button" onclick="groupBySeverity();">'
        'Group warnings by severity</button>\n'
        '<button class="button" onclick="groupByProject();">'
        'Group warnings by project</button><br>')


def all_patterns(category):
  patterns = ''
  for i in category['patterns']:
    patterns += i
    patterns += ' / '
  return patterns


def dump_fixed():
  """Show which warnings no longer occur."""
  anchor = 'fixed_warnings'
  mark = anchor + '_mark'
  print('\n<br><p style="background-color:lightblue"><b>'
        '<button id="' + mark + '" '
        'class="bt" onclick="expand(\'' + anchor + '\');">'
        '&#x2295</button> Fixed warnings. '
        'No more occurrences. Please consider turning these into '
        'errors if possible, before they are reintroduced in to the build'
        ':</b></p>')
  print('<blockquote>')
  fixed_patterns = []
  for i in warn_patterns:
    if not i['members']:
      fixed_patterns.append(i['description'] + ' (' +
                            all_patterns(i) + ')')
    if i['option']:
      fixed_patterns.append(' ' + i['option'])
  fixed_patterns = sorted(fixed_patterns)
  print('<div id="' + anchor + '" style="display:none;"><table>')
  cur_row_class = 0
  for text in fixed_patterns:
    cur_row_class = 1 - cur_row_class
    # remove last '\n'
    t = text[:-1] if text[-1] == '\n' else text
    print('<tr><td class="c' + str(cur_row_class) + '">' + t + '</td></tr>')
  print('</table></div>')
  print('</blockquote>')


def find_project_index(line):
  for p in range(len(project_patterns)):
    if project_patterns[p].match(line):
      return p
  return -1


def classify_one_warning(line, results):
  """Classify one warning line."""
  for i in range(len(warn_patterns)):
    w = warn_patterns[i]
    for cpat in w['compiled_patterns']:
      if cpat.match(line):
        p = find_project_index(line)
        results.append([line, i, p])
        return
      else:
        # If we end up here, there was a problem parsing the log
        # probably caused by 'make -j' mixing the output from
        # 2 or more concurrent compiles
        pass


def classify_warnings(lines):
  results = []
  for line in lines:
    classify_one_warning(line, results)
  # After the main work, ignore all other signals to a child process,
  # to avoid bad warning/error messages from the exit clean-up process.
  if args.processes > 1:
    signal.signal(signal.SIGTERM, lambda *args: sys.exit(-signal.SIGTERM))
  return results


def parallel_classify_warnings(warning_lines):
  """Classify all warning lines with num_cpu parallel processes."""
  compile_patterns()
  num_cpu = args.processes
  if num_cpu > 1:
    groups = [[] for x in range(num_cpu)]
    i = 0
    for x in warning_lines:
      groups[i].append(x)
      i = (i + 1) % num_cpu
    pool = multiprocessing.Pool(num_cpu)
    group_results = pool.map(classify_warnings, groups)
  else:
    group_results = [classify_warnings(warning_lines)]

  for result in group_results:
    for line, pattern_idx, project_idx in result:
      pattern = warn_patterns[pattern_idx]
      pattern['members'].append(line)
      message_idx = len(warning_messages)
      warning_messages.append(line)
      warning_records.append([pattern_idx, project_idx, message_idx])
      pname = '???' if project_idx < 0 else project_names[project_idx]
      # Count warnings by project.
      if pname in pattern['projects']:
        pattern['projects'][pname] += 1
      else:
        pattern['projects'][pname] = 1


def compile_patterns():
  """Precompiling every pattern speeds up parsing by about 30x."""
  for i in warn_patterns:
    i['compiled_patterns'] = []
    for pat in i['patterns']:
      i['compiled_patterns'].append(re.compile(pat))


def find_warn_py_and_android_root(path):
  """Set and return android_root path if it is found."""
  global android_root
  parts = path.split('/')
  for idx in reversed(range(2, len(parts))):
    root_path = '/'.join(parts[:idx])
    # Android root directory should contain this script.
    if os.path.exists(root_path + '/build/make/tools/warn.py'):
      android_root = root_path
      return True
  return False


def find_android_root():
  """Guess android_root from common prefix of file paths."""
  # Use the longest common prefix of the absolute file paths
  # of the first 10000 warning messages as the android_root.
  global android_root
  warning_lines = set()
  warning_pattern = re.compile('^/[^ ]*/[^ ]*: warning: .*')
  count = 0
  infile = io.open(args.buildlog, mode='r', encoding='utf-8')
  for line in infile:
    if warning_pattern.match(line):
      warning_lines.add(line)
      count += 1
      if count > 9999:
        break
      # Try to find warn.py and use its location to find
      # the source tree root.
      if count < 100:
        path = os.path.normpath(re.sub(':.*$', '', line))
        if find_warn_py_and_android_root(path):
          return
  # Do not use common prefix of a small number of paths.
  if count > 10:
    root_path = os.path.commonprefix(warning_lines)
    if len(root_path) > 2 and root_path[len(root_path) - 1] == '/':
      android_root = root_path[:-1]


def remove_android_root_prefix(path):
  """Remove android_root prefix from path if it is found."""
  if path.startswith(android_root):
    return path[1 + len(android_root):]
  else:
    return path


def normalize_path(path):
  """Normalize file path relative to android_root."""
  # If path is not an absolute path, just normalize it.
  path = os.path.normpath(path)
  # Remove known prefix of root path and normalize the suffix.
  if path[0] == '/' and android_root:
    return remove_android_root_prefix(path)
  return path


def normalize_warning_line(line):
  """Normalize file path relative to android_root in a warning line."""
  # replace fancy quotes with plain ol' quotes
  line = re.sub(u'[\u2018\u2019]', '\'', line)
  # replace non-ASCII chars to spaces
  line = re.sub(u'[^\x00-\x7f]', ' ', line)
  line = line.strip()
  first_column = line.find(':')
  if first_column > 0:
    return normalize_path(line[:first_column]) + line[first_column:]
  else:
    return line


def parse_input_file(infile):
  """Parse input file, collect parameters and warning lines."""
  global android_root
  global platform_version
  global target_product
  global target_variant
  line_counter = 0

  # rustc warning messages have two lines that should be combined:
  #     warning: description
  #        --> file_path:line_number:column_number
  # Some warning messages have no file name:
  #     warning: macro replacement list ... [bugprone-macro-parentheses]
  # Some makefile warning messages have no line number:
  #     some/path/file.mk: warning: description
  # C/C++ compiler warning messages have line and column numbers:
  #     some/path/file.c:line_number:column_number: warning: description
  warning_pattern = re.compile('(^[^ ]*/[^ ]*: warning: .*)|(^warning: .*)')
  warning_without_file = re.compile('^warning: .*')
  rustc_file_position = re.compile('^[ ]+--> [^ ]*/[^ ]*:[0-9]+:[0-9]+')

  # Collect all warnings into the warning_lines set.
  warning_lines = set()
  prev_warning = ''
  for line in infile:
    if prev_warning:
      if rustc_file_position.match(line):
        # must be a rustc warning, combine 2 lines into one warning
        line = line.strip().replace('--> ', '') + ': ' + prev_warning
        warning_lines.add(normalize_warning_line(line))
        prev_warning = ''
        continue
      # add prev_warning, and then process the current line
      prev_warning = 'unknown_source_file: ' + prev_warning
      warning_lines.add(normalize_warning_line(prev_warning))
      prev_warning = ''
    if warning_pattern.match(line):
      if warning_without_file.match(line):
        # save this line and combine it with the next line
        prev_warning = line
      else:
        warning_lines.add(normalize_warning_line(line))
      continue
    if line_counter < 100:
      # save a little bit of time by only doing this for the first few lines
      line_counter += 1
      m = re.search('(?<=^PLATFORM_VERSION=).*', line)
      if m is not None:
        platform_version = m.group(0)
      m = re.search('(?<=^TARGET_PRODUCT=).*', line)
      if m is not None:
        target_product = m.group(0)
      m = re.search('(?<=^TARGET_BUILD_VARIANT=).*', line)
      if m is not None:
        target_variant = m.group(0)
      m = re.search('.* TOP=([^ ]*) .*', line)
      if m is not None:
        android_root = m.group(1)
  return warning_lines


# Return s with escaped backslash and quotation characters.
def escape_string(s):
  return s.replace('\\', '\\\\').replace('"', '\\"')


# Return s without trailing '\n' and escape the quotation characters.
def strip_escape_string(s):
  if not s:
    return s
  s = s[:-1] if s[-1] == '\n' else s
  return escape_string(s)


def emit_warning_array(name):
  print('var warning_{} = ['.format(name))
  for i in range(len(warn_patterns)):
    print('{},'.format(warn_patterns[i][name]))
  print('];')


def emit_warning_arrays():
  emit_warning_array('severity')
  print('var warning_description = [')
  for i in range(len(warn_patterns)):
    if warn_patterns[i]['members']:
      print('"{}",'.format(escape_string(warn_patterns[i]['description'])))
    else:
      print('"",')  # no such warning
  print('];')


scripts_for_warning_groups = """
  function compareMessages(x1, x2) { // of the same warning type
    return (WarningMessages[x1[2]] <= WarningMessages[x2[2]]) ? -1 : 1;
  }
  function byMessageCount(x1, x2) {
    return x2[2] - x1[2];  // reversed order
  }
  function bySeverityMessageCount(x1, x2) {
    // orer by severity first
    if (x1[1] != x2[1])
      return  x1[1] - x2[1];
    return byMessageCount(x1, x2);
  }
  const ParseLinePattern = /^([^ :]+):(\\d+):(.+)/;
  function addURL(line) {
    if (FlagURL == "") return line;
    if (FlagSeparator == "") {
      return line.replace(ParseLinePattern,
        "<a target='_blank' href='" + FlagURL + "/$1'>$1</a>:$2:$3");
    }
    return line.replace(ParseLinePattern,
      "<a target='_blank' href='" + FlagURL + "/$1" + FlagSeparator +
        "$2'>$1:$2</a>:$3");
  }
  function createArrayOfDictionaries(n) {
    var result = [];
    for (var i=0; i<n; i++) result.push({});
    return result;
  }
  function groupWarningsBySeverity() {
    // groups is an array of dictionaries,
    // each dictionary maps from warning type to array of warning messages.
    var groups = createArrayOfDictionaries(SeverityColors.length);
    for (var i=0; i<Warnings.length; i++) {
      var w = Warnings[i][0];
      var s = WarnPatternsSeverity[w];
      var k = w.toString();
      if (!(k in groups[s]))
        groups[s][k] = [];
      groups[s][k].push(Warnings[i]);
    }
    return groups;
  }
  function groupWarningsByProject() {
    var groups = createArrayOfDictionaries(ProjectNames.length);
    for (var i=0; i<Warnings.length; i++) {
      var w = Warnings[i][0];
      var p = Warnings[i][1];
      var k = w.toString();
      if (!(k in groups[p]))
        groups[p][k] = [];
      groups[p][k].push(Warnings[i]);
    }
    return groups;
  }
  var GlobalAnchor = 0;
  function createWarningSection(header, color, group) {
    var result = "";
    var groupKeys = [];
    var totalMessages = 0;
    for (var k in group) {
       totalMessages += group[k].length;
       groupKeys.push([k, WarnPatternsSeverity[parseInt(k)], group[k].length]);
    }
    groupKeys.sort(bySeverityMessageCount);
    for (var idx=0; idx<groupKeys.length; idx++) {
      var k = groupKeys[idx][0];
      var messages = group[k];
      var w = parseInt(k);
      var wcolor = SeverityColors[WarnPatternsSeverity[w]];
      var description = WarnPatternsDescription[w];
      if (description.length == 0)
          description = "???";
      GlobalAnchor += 1;
      result += "<table class='t1'><tr bgcolor='" + wcolor + "'><td>" +
                "<button class='bt' id='" + GlobalAnchor + "_mark" +
                "' onclick='expand(\\"" + GlobalAnchor + "\\");'>" +
                "&#x2295</button> " +
                description + " (" + messages.length + ")</td></tr></table>";
      result += "<div id='" + GlobalAnchor +
                "' style='display:none;'><table class='t1'>";
      var c = 0;
      messages.sort(compareMessages);
      for (var i=0; i<messages.length; i++) {
        result += "<tr><td class='c" + c + "'>" +
                  addURL(WarningMessages[messages[i][2]]) + "</td></tr>";
        c = 1 - c;
      }
      result += "</table></div>";
    }
    if (result.length > 0) {
      return "<br><span style='background-color:" + color + "'><b>" +
             header + ": " + totalMessages +
             "</b></span><blockquote><table class='t1'>" +
             result + "</table></blockquote>";

    }
    return "";  // empty section
  }
  function generateSectionsBySeverity() {
    var result = "";
    var groups = groupWarningsBySeverity();
    for (s=0; s<SeverityColors.length; s++) {
      result += createWarningSection(SeverityHeaders[s], SeverityColors[s], groups[s]);
    }
    return result;
  }
  function generateSectionsByProject() {
    var result = "";
    var groups = groupWarningsByProject();
    for (i=0; i<groups.length; i++) {
      result += createWarningSection(ProjectNames[i], 'lightgrey', groups[i]);
    }
    return result;
  }
  function groupWarnings(generator) {
    GlobalAnchor = 0;
    var e = document.getElementById("warning_groups");
    e.innerHTML = generator();
  }
  function groupBySeverity() {
    groupWarnings(generateSectionsBySeverity);
  }
  function groupByProject() {
    groupWarnings(generateSectionsByProject);
  }
"""


# Emit a JavaScript const string
def emit_const_string(name, value):
  print('const ' + name + ' = "' + escape_string(value) + '";')


# Emit a JavaScript const integer array.
def emit_const_int_array(name, array):
  print('const ' + name + ' = [')
  for n in array:
    print(str(n) + ',')
  print('];')


# Emit a JavaScript const string array.
def emit_const_string_array(name, array):
  print('const ' + name + ' = [')
  for s in array:
    print('"' + strip_escape_string(s) + '",')
  print('];')


# Emit a JavaScript const string array for HTML.
def emit_const_html_string_array(name, array):
  print('const ' + name + ' = [')
  for s in array:
    # Not using html.escape yet, to work for both python 2 and 3,
    # until all users switch to python 3.
    # pylint:disable=deprecated-method
    print('"' + cgi.escape(strip_escape_string(s)) + '",')
  print('];')


# Emit a JavaScript const object array.
def emit_const_object_array(name, array):
  print('const ' + name + ' = [')
  for x in array:
    print(str(x) + ',')
  print('];')


def emit_js_data():
  """Dump dynamic HTML page's static JavaScript data."""
  emit_const_string('FlagURL', args.url if args.url else '')
  emit_const_string('FlagSeparator', args.separator if args.separator else '')
  emit_const_string_array('SeverityColors', Severity.colors)
  emit_const_string_array('SeverityHeaders', Severity.headers)
  emit_const_string_array('SeverityColumnHeaders', Severity.column_headers)
  emit_const_string_array('ProjectNames', project_names)
  emit_const_int_array('WarnPatternsSeverity',
                       [w['severity'] for w in warn_patterns])
  emit_const_html_string_array('WarnPatternsDescription',
                               [w['description'] for w in warn_patterns])
  emit_const_html_string_array('WarnPatternsOption',
                               [w['option'] for w in warn_patterns])
  emit_const_html_string_array('WarningMessages', warning_messages)
  emit_const_object_array('Warnings', warning_records)

draw_table_javascript = """
google.charts.load('current', {'packages':['table']});
google.charts.setOnLoadCallback(drawTable);
function drawTable() {
  var data = new google.visualization.DataTable();
  data.addColumn('string', StatsHeader[0]);
  for (var i=1; i<StatsHeader.length; i++) {
    data.addColumn('number', StatsHeader[i]);
  }
  data.addRows(StatsRows);
  for (var i=0; i<StatsRows.length; i++) {
    for (var j=0; j<StatsHeader.length; j++) {
      data.setProperty(i, j, 'style', 'border:1px solid black;');
    }
  }
  var table = new google.visualization.Table(document.getElementById('stats_table'));
  table.draw(data, {allowHtml: true, alternatingRowStyle: true});
}
"""


def dump_html():
  """Dump the html output to stdout."""
  dump_html_prologue('Warnings for ' + platform_version + ' - ' +
                     target_product + ' - ' + target_variant)
  dump_stats()
  print('<br><div id="stats_table"></div><br>')
  print('\n<script>')
  emit_js_data()
  print(scripts_for_warning_groups)
  print('</script>')
  emit_buttons()
  # Warning messages are grouped by severities or project names.
  print('<br><div id="warning_groups"></div>')
  if args.byproject:
    print('<script>groupByProject();</script>')
  else:
    print('<script>groupBySeverity();</script>')
  dump_fixed()
  dump_html_epilogue()


##### Functions to count warnings and dump csv file. #########################


def description_for_csv(category):
  if not category['description']:
    return '?'
  return category['description']


def count_severity(writer, sev, kind):
  """Count warnings of given severity."""
  total = 0
  for i in warn_patterns:
    if i['severity'] == sev and i['members']:
      n = len(i['members'])
      total += n
      warning = kind + ': ' + description_for_csv(i)
      writer.writerow([n, '', warning])
      # print number of warnings for each project, ordered by project name.
      projects = sorted(i['projects'].keys())
      for p in projects:
        writer.writerow([i['projects'][p], p, warning])
  writer.writerow([total, '', kind + ' warnings'])

  return total


# dump number of warnings in csv format to stdout
def dump_csv(writer):
  """Dump number of warnings in csv format to stdout."""
  sort_warnings()
  total = 0
  for s in Severity.range:
    total += count_severity(writer, s, Severity.column_headers[s])
  writer.writerow([total, '', 'All warnings'])


def main():
  find_android_root()
  # We must use 'utf-8' codec to parse some non-ASCII code in warnings.
  warning_lines = parse_input_file(
      io.open(args.buildlog, mode='r', encoding='utf-8'))
  parallel_classify_warnings(warning_lines)
  # If a user pases a csv path, save the fileoutput to the path
  # If the user also passed gencsv write the output to stdout
  # If the user did not pass gencsv flag dump the html report to stdout.
  if args.csvpath:
    with open(args.csvpath, 'w') as f:
      dump_csv(csv.writer(f, lineterminator='\n'))
  if args.gencsv:
    dump_csv(csv.writer(sys.stdout, lineterminator='\n'))
  else:
    dump_html()


# Run main function if warn.py is the main program.
if __name__ == '__main__':
  main()
