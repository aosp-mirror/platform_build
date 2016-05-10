#!/usr/bin/env python
# This file uses the following encoding: utf-8

import sys
import re

if len(sys.argv) == 1:
    print 'usage: ' + sys.argv[0] + ' <build.log>'
    sys.exit()

# if you add another level, don't forget to give it a color below
class severity:
    UNKNOWN=0
    SKIP=100
    FIXMENOW=1
    HIGH=2
    MEDIUM=3
    LOW=4
    TIDY=5
    HARMLESS=6

def colorforseverity(sev):
    if sev == severity.FIXMENOW:
        return 'fuchsia'
    if sev == severity.HIGH:
        return 'red'
    if sev == severity.MEDIUM:
        return 'orange'
    if sev == severity.LOW:
        return 'yellow'
    if sev == severity.TIDY:
        return 'peachpuff'
    if sev == severity.HARMLESS:
        return 'limegreen'
    if sev == severity.UNKNOWN:
        return 'lightblue'
    return 'grey'

def headerforseverity(sev):
    if sev == severity.FIXMENOW:
        return 'Critical warnings, fix me now'
    if sev == severity.HIGH:
        return 'High severity warnings'
    if sev == severity.MEDIUM:
        return 'Medium severity warnings'
    if sev == severity.LOW:
        return 'Low severity warnings'
    if sev == severity.HARMLESS:
        return 'Harmless warnings'
    if sev == severity.TIDY:
        return 'Clang-Tidy warnings'
    if sev == severity.UNKNOWN:
        return 'Unknown warnings'
    return 'Unhandled warnings'

warnpatterns = [
    { 'category':'make',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'make: overriding commands/ignoring old commands',
        'patterns':[r".*: warning: overriding commands for target .+",
                    r".*: warning: ignoring old commands for target .+"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-Wimplicit-function-declaration',
        'description':'Implicit function declaration',
        'patterns':[r".*: warning: implicit declaration of function .+"] },
    { 'category':'C/C++',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: conflicting types for '.+'"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-Wtype-limits',
        'description':'Expression always evaluates to true or false',
        'patterns':[r".*: warning: comparison is always .+ due to limited range of data type",
                    r".*: warning: comparison of unsigned .*expression .+ is always true",
                    r".*: warning: comparison of unsigned .*expression .+ is always false"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'',
        'description':'Potential leak of memory, bad free, use after free',
        'patterns':[r".*: warning: Potential leak of memory",
                    r".*: warning: Potential memory leak",
                    r".*: warning: Memory allocated by .+ should be deallocated by .+ not .+",
                    r".*: warning: 'delete' applied to a pointer that was allocated",
                    r".*: warning: Use of memory after it is freed",
                    r".*: warning: Argument to .+ is the address of .+ variable",
                    r".*: warning: Argument to free\(\) is offset by .+ of memory allocated by",
                    r".*: warning: Attempt to .+ released memory"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'',
        'description':'Return address of stack memory',
        'patterns':[r".*: warning: Address of stack memory .+ returned to caller",
                    r".*: warning: Address of stack memory .+ will be a dangling reference"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'',
        'description':'Problem with vfork',
        'patterns':[r".*: warning: This .+ is prohibited after a successful vfork",
                    r".*: warning: Call to function 'vfork' is insecure "] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'infinite-recursion',
        'description':'Infinite recursion',
        'patterns':[r".*: warning: all paths through this function will call itself"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'',
        'description':'Potential buffer overflow',
        'patterns':[r".*: warning: Size argument is greater than .+ the destination buffer",
                    r".*: warning: Potential buffer overflow.",
                    r".*: warning: String copy function overflows destination buffer"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Incompatible pointer types',
        'patterns':[r".*: warning: assignment from incompatible pointer type",
                    r".*: warning: return from incompatible pointer type",
                    r".*: warning: passing argument [0-9]+ of '.*' from incompatible pointer type",
                    r".*: warning: initialization from incompatible pointer type"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-fno-builtin',
        'description':'Incompatible declaration of built in function',
        'patterns':[r".*: warning: incompatible implicit declaration of built-in function .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunused-parameter',
        'description':'Unused parameter',
        'patterns':[r".*: warning: unused parameter '.*'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunused',
        'description':'Unused function, variable or label',
        'patterns':[r".*: warning: '.+' defined but not used",
                    r".*: warning: unused function '.+'",
                    r".*: warning: private field '.+' is not used",
                    r".*: warning: unused variable '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunused-value',
        'description':'Statement with no effect or result unused',
        'patterns':[r".*: warning: statement with no effect",
                    r".*: warning: expression result unused"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunused-result',
        'description':'Ignoreing return value of function',
        'patterns':[r".*: warning: ignoring return value of function .+Wunused-result"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wmissing-field-initializers',
        'description':'Missing initializer',
        'patterns':[r".*: warning: missing initializer"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: \(near initialization for '.+'\)"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wformat',
        'description':'Format string does not match arguments',
        'patterns':[r".*: warning: format '.+' expects type '.+', but argument [0-9]+ has type '.+'",
                    r".*: warning: more '%' conversions than data arguments",
                    r".*: warning: data argument not used by format string",
                    r".*: warning: incomplete format specifier",
                    r".*: warning: format .+ expects .+ but argument .+Wformat=",
                    r".*: warning: field precision should have .+ but argument has .+Wformat",
                    r".*: warning: format specifies type .+ but the argument has .*type .+Wformat"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wformat-extra-args',
        'description':'Too many arguments for format string',
        'patterns':[r".*: warning: too many arguments for format"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wformat-invalid-specifier',
        'description':'Invalid format specifier',
        'patterns':[r".*: warning: invalid .+ specifier '.+'.+format-invalid-specifier"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wsign-compare',
        'description':'Comparison between signed and unsigned',
        'patterns':[r".*: warning: comparison between signed and unsigned",
                    r".*: warning: comparison of promoted \~unsigned with unsigned",
                    r".*: warning: signed and unsigned type in conditional expression"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Comparison between enum and non-enum',
        'patterns':[r".*: warning: enumeral and non-enumeral type in conditional expression"] },
    { 'category':'libpng',  'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'libpng: zero area',
        'patterns':[r".*libpng warning: Ignoring attempt to set cHRM RGB triangle with zero area"] },
    { 'category':'aapt',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'aapt: no comment for public symbol',
        'patterns':[r".*: warning: No comment for public symbol .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wmissing-braces',
        'description':'Missing braces around initializer',
        'patterns':[r".*: warning: missing braces around initializer.*"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS, 'members':[], 'option':'',
        'description':'No newline at end of file',
        'patterns':[r".*: warning: no newline at end of file"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wcast-qual',
        'description':'Qualifier discarded',
        'patterns':[r".*: warning: passing argument [0-9]+ of '.+' discards qualifiers from pointer target type",
                    r".*: warning: assignment discards qualifiers from pointer target type",
                    r".*: warning: passing .+ to parameter of type .+ discards qualifiers",
                    r".*: warning: assigning to .+ from .+ discards qualifiers",
                    r".*: warning: return discards qualifiers from pointer target type"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wattributes',
        'description':'Attribute ignored',
        'patterns':[r".*: warning: '_*packed_*' attribute ignored"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wattributes',
        'description':'Visibility mismatch',
        'patterns':[r".*: warning: '.+' declared with greater visibility than the type of its field '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Shift count greater than width of type',
        'patterns':[r".*: warning: (left|right) shift count >= width of type"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'extern &lt;foo&gt; is initialized',
        'patterns':[r".*: warning: '.+' initialized and declared 'extern'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wold-style-declaration',
        'description':'Old style declaration',
        'patterns':[r".*: warning: 'static' is not at beginning of declaration"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wuninitialized',
        'description':'Variable may be used uninitialized',
        'patterns':[r".*: warning: '.+' may be used uninitialized in this function"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-Wuninitialized',
        'description':'Variable is used uninitialized',
        'patterns':[r".*: warning: '.+' is used uninitialized in this function",
                    r".*: warning: variable '.+' is uninitialized when used here"] },
    { 'category':'ld',      'severity':severity.MEDIUM,   'members':[], 'option':'-fshort-enums',
        'description':'ld: possible enum size mismatch',
        'patterns':[r".*: warning: .* uses variable-size enums yet the output is to use 32-bit enums; use of enum values across objects may fail"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wpointer-sign',
        'description':'Pointer targets differ in signedness',
        'patterns':[r".*: warning: pointer targets in initialization differ in signedness",
                    r".*: warning: pointer targets in assignment differ in signedness",
                    r".*: warning: pointer targets in return differ in signedness",
                    r".*: warning: pointer targets in passing argument [0-9]+ of '.+' differ in signedness"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wstrict-overflow',
        'description':'Assuming overflow does not occur',
        'patterns':[r".*: warning: assuming signed overflow does not occur when assuming that .* is always (true|false)"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wempty-body',
        'description':'Suggest adding braces around empty body',
        'patterns':[r".*: warning: suggest braces around empty body in an 'if' statement",
                    r".*: warning: empty body in an if-statement",
                    r".*: warning: suggest braces around empty body in an 'else' statement",
                    r".*: warning: empty body in an else-statement"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wparentheses',
        'description':'Suggest adding parentheses',
        'patterns':[r".*: warning: suggest explicit braces to avoid ambiguous 'else'",
                    r".*: warning: suggest parentheses around arithmetic in operand of '.+'",
                    r".*: warning: suggest parentheses around comparison in operand of '.+'",
                    r".*: warning: logical not is only applied to the left hand side of this comparison",
                    r".*: warning: using the result of an assignment as a condition without parentheses",
                    r".*: warning: .+ has lower precedence than .+ be evaluated first .+Wparentheses",
                    r".*: warning: suggest parentheses around '.+?' .+ '.+?'",
                    r".*: warning: suggest parentheses around assignment used as truth value"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Static variable used in non-static inline function',
        'patterns':[r".*: warning: '.+' is static but used in inline function '.+' which is not static"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wimplicit int',
        'description':'No type or storage class (will default to int)',
        'patterns':[r".*: warning: data definition has no type or storage class"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Null pointer',
        'patterns':[r".*: warning: Dereference of null pointer",
                    r".*: warning: Called .+ pointer is null",
                    r".*: warning: Forming reference to null pointer",
                    r".*: warning: Returning null reference",
                    r".*: warning: Null pointer passed as an argument to a 'nonnull' parameter",
                    r".*: warning: .+ results in a null pointer dereference",
                    r".*: warning: Access to .+ results in a dereference of a null pointer",
                    r".*: warning: Null pointer argument in"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: type defaults to 'int' in declaration of '.+'"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: parameter names \(without types\) in function declaration"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wstrict-aliasing',
        'description':'Dereferencing &lt;foo&gt; breaks strict aliasing rules',
        'patterns':[r".*: warning: dereferencing .* break strict-aliasing rules"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wpointer-to-int-cast',
        'description':'Cast from pointer to integer of different size',
        'patterns':[r".*: warning: cast from pointer to integer of different size"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wint-to-pointer-cast',
        'description':'Cast to pointer from integer of different size',
        'patterns':[r".*: warning: cast to pointer from integer of different size"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Symbol redefined',
        'patterns':[r".*: warning: "".+"" redefined"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: this is the location of the previous definition"] },
    { 'category':'ld',      'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'ld: type and size of dynamic symbol are not defined',
        'patterns':[r".*: warning: type and size of dynamic symbol `.+' are not defined"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Pointer from integer without cast',
        'patterns':[r".*: warning: assignment makes pointer from integer without a cast"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Pointer from integer without cast',
        'patterns':[r".*: warning: passing argument [0-9]+ of '.+' makes pointer from integer without a cast"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Integer from pointer without cast',
        'patterns':[r".*: warning: assignment makes integer from pointer without a cast"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Integer from pointer without cast',
        'patterns':[r".*: warning: passing argument [0-9]+ of '.+' makes integer from pointer without a cast"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Integer from pointer without cast',
        'patterns':[r".*: warning: return makes integer from pointer without a cast"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunknown-pragmas',
        'description':'Ignoring pragma',
        'patterns':[r".*: warning: ignoring #pragma .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wclobbered',
        'description':'Variable might be clobbered by longjmp or vfork',
        'patterns':[r".*: warning: variable '.+' might be clobbered by 'longjmp' or 'vfork'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wclobbered',
        'description':'Argument might be clobbered by longjmp or vfork',
        'patterns':[r".*: warning: argument '.+' might be clobbered by 'longjmp' or 'vfork'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wredundant-decls',
        'description':'Redundant declaration',
        'patterns':[r".*: warning: redundant redeclaration of '.+'"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: previous declaration of '.+' was here"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wswitch-enum',
        'description':'Enum value not handled in switch',
        'patterns':[r".*: warning: .*enumeration value.* not handled in switch.+Wswitch"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'-encoding',
        'description':'Java: Non-ascii characters used, but ascii encoding specified',
        'patterns':[r".*: warning: unmappable character for encoding ascii"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Non-varargs call of varargs method with inexact argument type for last parameter',
        'patterns':[r".*: warning: non-varargs call of varargs method with inexact argument type for last parameter"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Unchecked method invocation',
        'patterns':[r".*: warning: \[unchecked\] unchecked method invocation: .+ in class .+"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Unchecked conversion',
        'patterns':[r".*: warning: \[unchecked\] unchecked conversion"] },

    # Warnings from error prone.
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Long literal suffix',
        'patterns':[r".*: warning: \[LongLiteralLowerCaseSuffix\] Prefer 'L' to 'l' for the suffix to long literal"] },
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Missing @Deprecated',
        'patterns':[r".*: warning: \[DepAnn\] Deprecated item is not annotated with @Deprecated"] },
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Use of deprecated member',
        'patterns':[r".*: warning: \[deprecation\] .+ in .+ has been deprecated"] },
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Missing hashCode method',
        'patterns':[r".*: warning: \[EqualsHashCode\] Classes that override equals should also override hashCode."] },
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Hashtable contains is a legacy method',
        'patterns':[r".*: warning: \[HashtableContains\] contains\(\) is a legacy method that is equivalent to containsValue\(\)"] },
    { 'category':'java',    'severity':severity.LOW,   'members':[], 'option':'',
        'description':'Java: Type parameter used only for return type',
        'patterns':[r".*: warning: \[TypeParameterUnusedInFormals\] Declaring a type parameter that is only used in the return type is a misuse of generics: operations on the type parameter are unchecked, it hides unsafe casts at invocations of the method, and it interacts badly with method overload resolution."] },

    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: reference equality used on arrays',
        'patterns':[r".*: warning: \[ArrayEquals\] Reference equality used to compare arrays"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: hashcode used on array',
        'patterns':[r".*: warning: \[ArrayHashCode\] hashcode method on array does not hash array contents"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: toString used on an array',
        'patterns':[r".*: warning: \[ArrayToStringConcatenation\] Implicit toString used on an array \(String \+ Array\)",
                    r".*: warning: \[ArrayToString\] Calling toString on an array does not provide useful information"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Exception created but not thrown',
        'patterns':[r".*: warning: \[DeadException\] Exception created but not thrown"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Return or throw from a finally',
        'patterns':[r".*: warning: \[Finally\] If you return or throw from a finally, then values returned or thrown from the try-catch block will be ignored. Consider using try-with-resources instead."] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Erroneous use of @GuardedBy',
        'patterns':[r".*: warning: \[GuardedByChecker\] This access should be guarded by '.+'; instead found: '.+'",
                    r".*: warning: \[GuardedByChecker\] This access should be guarded by '.+', which is not currently held"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Mislabeled Android string',
        'patterns':[r".*: warning: \[MislabeledAndroidString\] .+ is not \".+\" but \".+\"; prefer .+ for clarity"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Missing cases in enum switch',
        'patterns':[r".*: warning: \[MissingCasesInEnumSwitch\] Non-exhaustive switch, expected cases for: .+"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Multiple top-level classes (inhibits bug analysis)',
        'patterns':[r".*: warning: \[MultipleTopLevelClasses\] Expected at most one top-level class declaration, instead found: .+"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: equals method doesn\'t override Object.equals',
        'patterns':[r".*: warning: \[NonOverridingEquals\] equals method doesn't override Object\.equals.*"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Update of a volatile variable is non-atomic',
        'patterns':[r".*: warning: \[NonAtomicVolatileUpdate\] This update of a volatile variable is non-atomic"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Return value ignored',
        'patterns':[r".*: warning: \[ReturnValueIgnored\] Return value of this method must be used",
                    r".*: warning: \[RectIntersectReturnValueIgnored\] Return value of android.graphics.Rect.intersect\(\) must be checked"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Static variable accessed from an object instance',
        'patterns':[r".*: warning: \[StaticAccessedFromInstance\] Static (method|variable) .+ should not be accessed from an object instance; instead use .+"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Static guarded by instance',
        'patterns':[r".*: warning: \[StaticGuardedByInstance\] Write to static variable should not be guarded by instance lock '.+'"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: String reference equality',
        'patterns':[r".*: warning: \[StringEquality\] String comparison using reference equality instead of value equality"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Synchronization on non-final field',
        'patterns':[r".*: warning: \[SynchronizeOnNonFinalField\] Synchronizing on non-final fields is not safe: if the field is ever updated, different threads may end up locking on different objects."] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Catch masks fail or assert',
        'patterns':[r".*: warning: \[TryFailThrowable\] Catching Throwable/Error masks failures from fail\(\) or assert\*\(\) in the try block"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Wait not in a loop',
        'patterns':[r".*: warning: \[WaitNotInLoop\] Because of spurious wakeups, a?wait.*\(.*\) must always be called in a loop"] },

    { 'category':'java',    'severity':severity.UNKNOWN,   'members':[], 'option':'',
        'description':'Java: Unclassified/unrecognized warnings',
        'patterns':[r".*: warning: \[.+\] .+"] },

    { 'category':'aapt',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'aapt: No default translation',
        'patterns':[r".*: warning: string '.+' has no default translation in .*"] },
    { 'category':'aapt',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'aapt: Missing default or required localization',
        'patterns':[r".*: warning: \*\*\*\* string '.+' has no default or required localization for '.+' in .+"] },
    { 'category':'aapt',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'aapt: String marked untranslatable, but translation exists',
        'patterns':[r".*: warning: string '.+' in .* marked untranslatable but exists in locale '??_??'"] },
    { 'category':'aapt',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'aapt: empty span in string',
        'patterns':[r".*: warning: empty '.+' span found in text '.+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Taking address of temporary',
        'patterns':[r".*: warning: taking address of temporary"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Possible broken line continuation',
        'patterns':[r".*: warning: backslash and newline separated by space"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Warray-bounds',
        'description':'Array subscript out of bounds',
        'patterns':[r".*: warning: array subscript is above array bounds",
                    r".*: warning: Array subscript is undefined",
                    r".*: warning: array subscript is below array bounds"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Excess elements in initializer',
        'patterns':[r".*: warning: excess elements in .+ initializer"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Decimal constant is unsigned only in ISO C90',
        'patterns':[r".*: warning: this decimal constant is unsigned only in ISO C90"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wmain',
        'description':'main is usually a function',
        'patterns':[r".*: warning: 'main' is usually a function"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Typedef ignored',
        'patterns':[r".*: warning: 'typedef' was ignored in this declaration"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-Waddress',
        'description':'Address always evaluates to true',
        'patterns':[r".*: warning: the address of '.+' will always evaluate as 'true'"] },
    { 'category':'C/C++',   'severity':severity.FIXMENOW, 'members':[], 'option':'',
        'description':'Freeing a non-heap object',
        'patterns':[r".*: warning: attempt to free a non-heap object '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wchar-subscripts',
        'description':'Array subscript has type char',
        'patterns':[r".*: warning: array subscript .+ type 'char'.+Wchar-subscripts"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Constant too large for type',
        'patterns':[r".*: warning: integer constant is too large for '.+' type"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Woverflow',
        'description':'Constant too large for type, truncated',
        'patterns':[r".*: warning: large integer implicitly truncated to unsigned type"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Woverflow',
        'description':'Overflow in implicit constant conversion',
        'patterns':[r".*: warning: overflow in implicit constant conversion"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Declaration does not declare anything',
        'patterns':[r".*: warning: declaration 'class .+' does not declare anything"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wreorder',
        'description':'Initialization order will be different',
        'patterns':[r".*: warning: '.+' will be initialized after",
                    r".*: warning: field .+ will be initialized after .+Wreorder"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning:   '.+'"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning:   base '.+'"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning:   when initialized here"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wmissing-parameter-type',
        'description':'Parameter type not specified',
        'patterns':[r".*: warning: type of '.+' defaults to 'int'"] },
    { 'category':'gcc',     'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Invalid option for C file',
        'patterns':[r".*: warning: command line option "".+"" is valid for C\+\+\/ObjC\+\+ but not for C"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'User warning',
        'patterns':[r".*: warning: #warning "".+"""] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wextra',
        'description':'Dereferencing void*',
        'patterns':[r".*: warning: dereferencing 'void \*' pointer"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wextra',
        'description':'Comparison of pointer to zero',
        'patterns':[r".*: warning: ordered comparison of pointer with integer zero"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wwrite-strings',
        'description':'Conversion of string constant to non-const char*',
        'patterns':[r".*: warning: deprecated conversion from string constant to '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wstrict-prototypes',
        'description':'Function declaration isn''t a prototype',
        'patterns':[r".*: warning: function declaration isn't a prototype"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wignored-qualifiers',
        'description':'Type qualifiers ignored on function return value',
        'patterns':[r".*: warning: type qualifiers ignored on function return type",
                    r".*: warning: .+ type qualifier .+ has no effect .+Wignored-qualifiers"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'&lt;foo&gt; declared inside parameter list, scope limited to this definition',
        'patterns':[r".*: warning: '.+' declared inside parameter list"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: its scope is only this definition or declaration, which is probably not what you want"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'-Wcomment',
        'description':'Line continuation inside comment',
        'patterns':[r".*: warning: multi-line comment"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'-Wcomment',
        'description':'Comment inside comment',
        'patterns':[r".*: warning: "".+"" within comment"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'',
        'description':'Value stored is never read',
        'patterns':[r".*: warning: Value stored to .+ is never read"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'-Wdeprecated-declarations',
        'description':'Deprecated declarations',
        'patterns':[r".*: warning: .+ is deprecated.+deprecated-declarations"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'-Wdeprecated-register',
        'description':'Deprecated register',
        'patterns':[r".*: warning: 'register' storage class specifier is deprecated"] },
    { 'category':'C/C++',   'severity':severity.LOW,      'members':[], 'option':'-Wpointer-sign',
        'description':'Converts between pointers to integer types with different sign',
        'patterns':[r".*: warning: .+ converts between pointers to integer types with different sign"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS, 'members':[], 'option':'',
        'description':'Extra tokens after #endif',
        'patterns':[r".*: warning: extra tokens at end of #endif directive"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wenum-compare',
        'description':'Comparison between different enums',
        'patterns':[r".*: warning: comparison between '.+' and '.+'.+Wenum-compare"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wconversion',
        'description':'Implicit conversion of negative number to unsigned type',
        'patterns':[r".*: warning: converting negative value '.+' to '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Passing NULL as non-pointer argument',
        'patterns':[r".*: warning: passing NULL to non-pointer argument [0-9]+ of '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wctor-dtor-privacy',
        'description':'Class seems unusable because of private ctor/dtor' ,
        'patterns':[r".*: warning: all member functions in class '.+' are private"] },
    # skip this next one, because it only points out some RefBase-based classes where having a private destructor is perfectly fine
    { 'category':'C/C++',   'severity':severity.SKIP,     'members':[], 'option':'-Wctor-dtor-privacy',
        'description':'Class seems unusable because of private ctor/dtor' ,
        'patterns':[r".*: warning: 'class .+' only defines a private destructor and has no friends"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wctor-dtor-privacy',
        'description':'Class seems unusable because of private ctor/dtor' ,
        'patterns':[r".*: warning: 'class .+' only defines private constructors and has no friends"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wgnu-static-float-init',
        'description':'In-class initializer for static const float/double' ,
        'patterns':[r".*: warning: in-class initializer for static data member of .+const (float|double)"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wpointer-arith',
        'description':'void* used in arithmetic' ,
        'patterns':[r".*: warning: pointer of type 'void \*' used in (arithmetic|subtraction)",
                    r".*: warning: arithmetic on .+ to void is a GNU extension.*Wpointer-arith",
                    r".*: warning: wrong type argument to increment"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wsign-promo',
        'description':'Overload resolution chose to promote from unsigned or enum to signed type' ,
        'patterns':[r".*: warning: passing '.+' chooses 'int' over '.* int'"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning:   in call to '.+'"] },
    { 'category':'C/C++',   'severity':severity.HIGH,     'members':[], 'option':'-Wextra',
        'description':'Base should be explicitly initialized in copy constructor',
        'patterns':[r".*: warning: base class '.+' should be explicitly initialized in the copy constructor"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Converting from <type> to <other type>',
        'patterns':[r".*: warning: converting to '.+' from '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'VLA has zero or negative size',
        'patterns':[r".*: warning: Declared variable-length array \(VLA\) has .+ size"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Return value from void function',
        'patterns':[r".*: warning: 'return' with a value, in function returning void"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'multichar',
        'description':'Multi-character character constant',
        'patterns':[r".*: warning: multi-character character constant"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'writable-strings',
        'description':'Conversion from string literal to char*',
        'patterns':[r".*: warning: .+ does not allow conversion from string literal to 'char \*'"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'',
        'description':'Useless specifier',
        'patterns':[r".*: warning: useless storage class specifier in empty declaration"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'-Wduplicate-decl-specifier',
        'description':'Duplicate declaration specifier',
        'patterns':[r".*: warning: duplicate '.+' declaration specifier"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'',
        'description':'Duplicate logtag',
        'patterns':[r".*: warning: tag \".+\" \(.+\) duplicated in .+"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'typedef-redefinition',
        'description':'Typedef redefinition',
        'patterns':[r".*: warning: redefinition of typedef '.+' is a C11 feature"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'gnu-designator',
        'description':'GNU old-style field designator',
        'patterns':[r".*: warning: use of GNU old-style field designator extension"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'missing-field-initializers',
        'description':'Missing field initializers',
        'patterns':[r".*: warning: missing field '.+' initializer"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'missing-braces',
        'description':'Missing braces',
        'patterns':[r".*: warning: suggest braces around initialization of",
                    r".*: warning: too many braces around scalar initializer .+Wmany-braces-around-scalar-init",
                    r".*: warning: braces around scalar initializer"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'sign-compare',
        'description':'Comparison of integers of different signs',
        'patterns':[r".*: warning: comparison of integers of different signs.+sign-compare"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'dangling-else',
        'description':'Add braces to avoid dangling else',
        'patterns':[r".*: warning: add explicit braces to avoid dangling else"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'initializer-overrides',
        'description':'Initializer overrides prior initialization',
        'patterns':[r".*: warning: initializer overrides prior initialization of this subobject"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'self-assign',
        'description':'Assigning value to self',
        'patterns':[r".*: warning: explicitly assigning value of .+ to itself"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'gnu-variable-sized-type-not-at-end',
        'description':'GNU extension, variable sized type not at end',
        'patterns':[r".*: warning: field '.+' with variable sized type '.+' not at the end of a struct or class"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'tautological-constant-out-of-range-compare',
        'description':'Comparison of constant is always false/true',
        'patterns':[r".*: comparison of .+ is always .+Wtautological-constant-out-of-range-compare"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'overloaded-virtual',
        'description':'Hides overloaded virtual function',
        'patterns':[r".*: '.+' hides overloaded virtual function"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'incompatible-pointer-types',
        'description':'Incompatible pointer types',
        'patterns':[r".*: warning: incompatible pointer types .+Wincompatible-pointer-types"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'asm-operand-widths',
        'description':'ASM value size does not match register size',
        'patterns':[r".*: warning: value size does not match register size specified by the constraint and modifier"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'literal-suffix',
        'description':'Needs a space between literal and string macro',
        'patterns':[r".*: warning: invalid suffix on literal.+ requires a space .+Wliteral-suffix"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'#warnings',
        'description':'Warnings from #warning',
        'patterns':[r".*: warning: .+-W#warnings"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'absolute-value',
        'description':'Using float/int absolute value function with int/float argument',
        'patterns':[r".*: warning: using .+ absolute value function .+ when argument is .+ type .+Wabsolute-value"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'',
        'description':'Refers to implicitly defined namespace',
        'patterns':[r".*: warning: using directive refers to implicitly-defined namespace .+"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'-Winvalid-pp-token',
        'description':'Invalid pp token',
        'patterns':[r".*: warning: missing .+Winvalid-pp-token"] },

    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Operator new returns NULL',
        'patterns':[r".*: warning: 'operator new' must not return NULL unless it is declared 'throw\(\)' .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'NULL used in arithmetic',
        'patterns':[r".*: warning: NULL used in arithmetic"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'header-guard',
        'description':'Misspelled header guard',
        'patterns':[r".*: warning: '.+' is used as a header guard .+ followed by .+ different macro"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'empty-body',
        'description':'Empty loop body',
        'patterns':[r".*: warning: .+ loop has empty body"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'enum-conversion',
        'description':'Implicit conversion from enumeration type',
        'patterns':[r".*: warning: implicit conversion from enumeration type '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'switch',
        'description':'case value not in enumerated type',
        'patterns':[r".*: warning: case value not in enumerated type '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Undefined result',
        'patterns':[r".*: warning: The result of .+ is undefined",
                    r".*: warning: 'this' pointer cannot be null in well-defined C\+\+ code;",
                    r".*: warning: shifting a negative signed value is undefined"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Division by zero',
        'patterns':[r".*: warning: Division by zero"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Use of deprecated method',
        'patterns':[r".*: warning: '.+' is deprecated .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Use of garbage or uninitialized value',
        'patterns':[r".*: warning: .+ is a garbage value",
                    r".*: warning: Function call argument is an uninitialized value",
                    r".*: warning: Undefined or garbage value returned to caller",
                    r".*: warning: Called .+ pointer is.+uninitialized",
                    r".*: warning: Called .+ pointer is.+uninitalized",  # match a typo in compiler message
                    r".*: warning: Use of zero-allocated memory",
                    r".*: warning: Dereference of undefined pointer value",
                    r".*: warning: Passed-by-value .+ contains uninitialized data",
                    r".*: warning: Branch condition evaluates to a garbage value",
                    r".*: warning: The .+ of .+ is an uninitialized value.",
                    r".*: warning: .+ is used uninitialized whenever .+sometimes-uninitialized",
                    r".*: warning: Assigned value is garbage or undefined"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Result of malloc type incompatible with sizeof operand type',
        'patterns':[r".*: warning: Result of '.+' is converted to .+ incompatible with sizeof operand type"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Return value not checked',
        'patterns':[r".*: warning: The return value from .+ is not checked"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Possible heap pollution',
        'patterns':[r".*: warning: .*Possible heap pollution from .+ type .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Allocation size of 0 byte',
        'patterns':[r".*: warning: Call to .+ has an allocation size of 0 byte"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Result of malloc type incompatible with sizeof operand type',
        'patterns':[r".*: warning: Result of '.+' is converted to .+ incompatible with sizeof operand type"] },

    { 'category':'C/C++',   'severity':severity.HARMLESS,     'members':[], 'option':'',
        'description':'Discarded qualifier from pointer target type',
        'patterns':[r".*: warning: .+ discards '.+' qualifier from pointer target type"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS,     'members':[], 'option':'',
        'description':'Use snprintf instead of sprintf',
        'patterns':[r".*: warning: .*sprintf is often misused; please use snprintf"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS,     'members':[], 'option':'',
        'description':'Unsupported optimizaton flag',
        'patterns':[r".*: warning: optimization flag '.+' is not supported"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS,     'members':[], 'option':'',
        'description':'Extra or missing parentheses',
        'patterns':[r".*: warning: equality comparison with extraneous parentheses",
                    r".*: warning: .+ within .+Wlogical-op-parentheses"] },
    { 'category':'C/C++',   'severity':severity.HARMLESS,     'members':[], 'option':'mismatched-tags',
        'description':'Mismatched class vs struct tags',
        'patterns':[r".*: warning: '.+' defined as a .+ here but previously declared as a .+mismatched-tags",
                    r".*: warning: .+ was previously declared as a .+mismatched-tags"] },

    # these next ones are to deal with formatting problems resulting from the log being mixed up by 'make -j'
    { 'category':'C/C++',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: ,$"] },
    { 'category':'C/C++',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: $"] },
    { 'category':'C/C++',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: In file included from .+,"] },

    # warnings from clang-tidy
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy readability',
        'patterns':[r".*: .+\[readability-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy c++ core guidelines',
        'patterns':[r".*: .+\[cppcoreguidelines-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy google-runtime',
        'patterns':[r".*: .+\[google-runtime-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy google-build',
        'patterns':[r".*: .+\[google-build-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy google-explicit',
        'patterns':[r".*: .+\[google-explicit-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy google-readability',
        'patterns':[r".*: .+\[google-readability-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy google-global',
        'patterns':[r".*: .+\[google-global-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy modernize',
        'patterns':[r".*: .+\[modernize-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy misc',
        'patterns':[r".*: .+\[misc-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy CERT',
        'patterns':[r".*: .+\[cert-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy llvm',
        'patterns':[r".*: .+\[llvm-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy clang-diagnostic',
        'patterns':[r".*: .+\[clang-diagnostic-.+\]$"] },
    { 'category':'C/C++',   'severity':severity.TIDY,     'members':[], 'option':'',
        'description':'clang-tidy clang-analyzer',
        'patterns':[r".*: .+\[clang-analyzer-.+\]$",
                    r".*: Call Path : .+$"] },

    # catch-all for warnings this script doesn't know about yet
    { 'category':'C/C++',   'severity':severity.UNKNOWN,  'members':[], 'option':'',
        'description':'Unclassified/unrecognized warnings',
        'patterns':[r".*: warning: .+"] },
]

anchor = 0
cur_row_color = 0
row_colors = [ 'e0e0e0', 'd0d0d0' ]

def output(text):
    print text,

def htmlbig(param):
    return '<font size="+2">' + param + '</font>'

def dumphtmlprologue(title):
    output('<html>\n<head>\n<title>' + title + '</title>\n<body>\n')
    output('<a name="PageTop">')
    output(htmlbig(title))
    output('<p>\n')

def tablerow(text):
    global cur_row_color
    output('<tr bgcolor="' + row_colors[cur_row_color] + '"><td colspan="2">',)
    cur_row_color = 1 - cur_row_color
    output(text,)
    output('</td></tr>')

def begintable(text, backgroundcolor, extraanchor):
    global anchor
    output('<table border="1" rules="cols" frame="box" width="100%" bgcolor="black"><tr bgcolor="' +
        backgroundcolor + '"><a name="anchor' + str(anchor) + '">')
    if extraanchor:
        output('<a name="' + extraanchor + '">')
    output('<td>')
    output(htmlbig(text[0]) + '<br>')
    for i in text[1:]:
        output(i + '<br>')
    output('</td>')
    output('<td width="100" bgcolor="grey">' +
           '<a align="right" href="#PageTop">top</a><br>' +
           '<a align="right" href="#anchor' + str(anchor-1) + '">previous</a><br>' +
           '<a align="right" href="#anchor' + str(anchor+1) + '">next</a>')
    output('</td></a></tr>')
    anchor += 1

def endtable():
    output('</table><p>')


# dump some stats about total number of warnings and such
def dumpstats():
    known = 0
    unknown = 0
    for i in warnpatterns:
        i['members'] = sorted(set(i['members']))
        if i['severity'] == severity.UNKNOWN:
            unknown += len(i['members'])
        elif i['severity'] != severity.SKIP:
            known += len(i['members'])
    output('\nNumber of classified warnings: <b>' + str(known) + '</b><br>' )
    output('\nNumber of unclassified warnings: <b>' + str(unknown) + '</b><br>')
    total = unknown + known
    output('\nTotal number of warnings: <b>' + str(total) + '</b>')
    if total < 1000:
        output('(low count may indicate incremental build)')
    output('\n<p>\n')

# dump count of warnings of a given severity in TOC
def dumpcount(sev):
    first = True
    for i in warnpatterns:
      if i['severity'] == sev and len(i['members']) > 0:
          if first:
              output(headerforseverity(sev) + ':\n<blockquote>' +
                     '<table border="1" frame="box" width="100%">')
          output('<tr bgcolor="' + colorforseverity(sev) + '">' +
                 '<td><a href="#' + i['anchor'] + '">' + descriptionfor(i) +
                 ' (' + str(len(i['members'])) + ')</a></td></tr>\n')
          first = False
    if not first:
        output('</table></blockquote>\n')

# dump table of content, list of all warning patterns
def dumptoc():
    n = 1
    output('<blockquote>\n')
    for i in warnpatterns:
        i['anchor'] = 'Warning' + str(n)
        n += 1
    dumpcount(severity.FIXMENOW)
    dumpcount(severity.HIGH)
    dumpcount(severity.MEDIUM)
    dumpcount(severity.LOW)
    dumpcount(severity.TIDY)
    dumpcount(severity.HARMLESS)
    dumpcount(severity.UNKNOWN)
    output('</blockquote>\n<p>\n')

def allpatterns(cat):
    pats = ''
    for i in cat['patterns']:
        pats += i
        pats += ' / '
    return pats

def descriptionfor(cat):
    if cat['description'] != '':
        return cat['description']
    return allpatterns(cat)


# show which warnings no longer occur
def dumpfixed():
    tablestarted = False
    for i in warnpatterns:
        if len(i['members']) == 0 and i['severity'] != severity.SKIP:
            if tablestarted == False:
                tablestarted = True
                begintable(['Fixed warnings', 'No more occurences. Please consider turning these in to errors if possible, before they are reintroduced in to the build'], 'blue', '')
            tablerow(i['description'] + ' (' + allpatterns(i) + ') ' + i['option'])
    if tablestarted:
        endtable()


# dump a category, provided it is not marked as 'SKIP' and has more than 0 occurrences
def dumpcategory(cat):
    if cat['severity'] != severity.SKIP and len(cat['members']) != 0:
        header = [descriptionfor(cat),str(len(cat['members'])) + ' occurences:']
        if cat['option'] != '':
            header[1:1] = [' (related option: ' + cat['option'] +')']
        begintable(header, colorforseverity(cat['severity']), cat['anchor'])
        for i in cat['members']:
            tablerow(i)
        endtable()


# dump everything for a given severity
def dumpseverity(sev):
    for i in warnpatterns:
        if i['severity'] == sev:
            dumpcategory(i)


def classifywarning(line):
    for i in warnpatterns:
        for cpat in i['compiledpatterns']:
            if cpat.match(line):
                i['members'].append(line)
                return
    else:
        # If we end up here, there was a problem parsing the log
        # probably caused by 'make -j' mixing the output from
        # 2 or more concurrent compiles
        pass

# precompiling every pattern speeds up parsing by about 30x
def compilepatterns():
    for i in warnpatterns:
        i['compiledpatterns'] = []
        for pat in i['patterns']:
            i['compiledpatterns'].append(re.compile(pat))

infile = open(sys.argv[1], 'r')
warnings = []

platformversion = 'unknown'
targetproduct = 'unknown'
targetvariant = 'unknown'
linecounter = 0

warningpattern = re.compile('.* warning:.*')
compilepatterns()

# read the log file and classify all the warnings
lastmatchedline = ''
for line in infile:
    # replace fancy quotes with plain ol' quotes
    line = line.replace("‘", "'");
    line = line.replace("’", "'");
    if warningpattern.match(line):
        if line != lastmatchedline:
            classifywarning(line)
            lastmatchedline = line
    else:
        # save a little bit of time by only doing this for the first few lines
        if linecounter < 50:
            linecounter +=1
            m = re.search('(?<=^PLATFORM_VERSION=).*', line)
            if m != None:
                platformversion = m.group(0)
            m = re.search('(?<=^TARGET_PRODUCT=).*', line)
            if m != None:
                targetproduct = m.group(0)
            m = re.search('(?<=^TARGET_BUILD_VARIANT=).*', line)
            if m != None:
                targetvariant = m.group(0)


# dump the html output to stdout
dumphtmlprologue('Warnings for ' + platformversion + ' - ' + targetproduct + ' - ' + targetvariant)
dumpstats()
# sort table based on number of members once dumpstats has deduplicated the
# members.
warnpatterns.sort(reverse=True, key=lambda i: len(i['members']))
dumptoc()
dumpseverity(severity.FIXMENOW)
dumpseverity(severity.HIGH)
dumpseverity(severity.MEDIUM)
dumpseverity(severity.LOW)
dumpseverity(severity.TIDY)
dumpseverity(severity.HARMLESS)
dumpseverity(severity.UNKNOWN)
dumpfixed()
