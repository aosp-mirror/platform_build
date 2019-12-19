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

"""Warning patterns for clang-tidy."""

from severity import Severity


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


def analyzer_high(description, pattern_list):
  # Important clang analyzer warnings to be fixed ASAP.
  return {
      'category': 'C/C++',
      'severity': Severity.HIGH,
      'description': description,
      'patterns': pattern_list
  }


def analyzer_high_check(check):
  return analyzer_high(check, [r'.*: .+\[' + check + r'\]$'])


def analyzer_group_high(check):
  return analyzer_high(check, [r'.*: .+\[' + check + r'.+\]$'])


def analyzer_warn(description, pattern_list):
  return {
      'category': 'C/C++',
      'severity': Severity.ANALYZER,
      'description': description,
      'patterns': pattern_list
  }


def analyzer_warn_check(check):
  return analyzer_warn(check, [r'.*: .+\[' + check + r'\]$'])


def analyzer_group_check(check):
  return analyzer_warn(check, [r'.*: .+\[' + check + r'.+\]$'])


patterns = [
    # pylint:disable=line-too-long,g-inconsistent-quotes
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
]
