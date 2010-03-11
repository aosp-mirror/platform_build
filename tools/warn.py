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
    HARMLESS=5

def colorforseverity(sev):
    if sev == severity.FIXMENOW:
        return 'fuchsia'
    if sev == severity.HIGH:
        return 'red'
    if sev == severity.MEDIUM:
        return 'orange'
    if sev == severity.LOW:
        return 'yellow'
    if sev == severity.HARMLESS:
        return 'limegreen'
    if sev == severity.UNKNOWN:
        return 'blue'
    return 'grey'

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
        'patterns':[r".*: warning: comparison is always false due to limited range of data type",
                    r".*: warning: comparison of unsigned expression >= 0 is always true",
                    r".*: warning: comparison of unsigned expression < 0 is always false"] },
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
                    r".*: warning: unused variable '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wunused-value',
        'description':'Statement with no effect',
        'patterns':[r".*: warning: statement with no effect"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wmissing-field-initializers',
        'description':'Missing initializer',
        'patterns':[r".*: warning: missing initializer"] },
    { 'category':'cont.',   'severity':severity.SKIP,     'members':[], 'option':'',
        'description':'',
        'patterns':[r".*: warning: \(near initialization for '.+'\)"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wformat',
        'description':'Format string does not match arguments',
        'patterns':[r".*: warning: format '.+' expects type '.+', but argument [0-9]+ has type '.+'"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wformat-extra-args',
        'description':'Too many arguments for format string',
        'patterns':[r".*: warning: too many arguments for format"] },
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
        'patterns':[r".*: warning: '.+' is used uninitialized in this function"] },
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
                    r".*: warning: suggest parentheses around '.+?' .+ '.+?'",
                    r".*: warning: suggest parentheses around assignment used as truth value"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Static variable used in non-static inline function',
        'patterns':[r".*: warning: '.+' is static but used in inline function '.+' which is not static"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wimplicit int',
        'description':'No type or storage class (will default to int)',
        'patterns':[r".*: warning: data definition has no type or storage class"] },
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
        'patterns':[r".*: warning: enumeration value '.+' not handled in switch"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'-encoding',
        'description':'Java: Non-ascii characters used, but ascii encoding specified',
        'patterns':[r".*: warning: unmappable character for encoding ascii"] },
    { 'category':'java',    'severity':severity.MEDIUM,   'members':[], 'option':'',
        'description':'Java: Non-varargs call of varargs method with inexact argument type for last parameter',
        'patterns':[r".*: warning: non-varargs call of varargs method with inexact argument type for last parameter"] },
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
                    r".*: warning: array subscript is below array bounds"] },
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
        'patterns':[r".*: warning: array subscript has type 'char'"] },
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
        'patterns':[r".*: warning: '.+' will be initialized after"] },
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
        'patterns':[r".*: warning: type qualifiers ignored on function return type"] },
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
    { 'category':'C/C++',   'severity':severity.HARMLESS, 'members':[], 'option':'',
        'description':'Extra tokens after #endif',
        'patterns':[r".*: warning: extra tokens at end of #endif directive"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wenum-compare',
        'description':'Comparison between different enums',
        'patterns':[r".*: warning: comparison between 'enum .+' and 'enum .+'"] },
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
    { 'category':'C/C++',   'severity':severity.MEDIUM,   'members':[], 'option':'-Wpointer-arith',
        'description':'void* used in arithmetic' ,
        'patterns':[r".*: warning: pointer of type 'void \*' used in (arithmetic|subtraction)",
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
        'description':'Return value from void function',
        'patterns':[r".*: warning: 'return' with a value, in function returning void"] },
    { 'category':'C/C++',   'severity':severity.LOW,     'members':[], 'option':'',
        'description':'Useless specifier',
        'patterns':[r".*: warning: useless storage class specifier in empty declaration"] },
    { 'category':'logtags',   'severity':severity.LOW,     'members':[], 'option':'',
        'description':'Duplicate logtag',
        'patterns':[r".*: warning: tag "".+"" \(None\) duplicated in .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Operator new returns NULL',
        'patterns':[r".*: warning: 'operator new' must not return NULL unless it is declared 'throw\(\)' .+"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'NULL used in arithmetic',
        'patterns':[r".*: warning: NULL used in arithmetic"] },
    { 'category':'C/C++',   'severity':severity.MEDIUM,     'members':[], 'option':'',
        'description':'Use of deprecated method',
        'patterns':[r".*: warning: '.+' is deprecated .+"] },

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
    output(htmlbig(title))
    output('<p>\n')

def tablerow(text):
    global cur_row_color
    output('<tr bgcolor="' + row_colors[cur_row_color] + '"><td colspan="2">',)
    cur_row_color = 1 - cur_row_color
    output(text,)
    output('</td></tr>')

def begintable(text, backgroundcolor):
    global anchor
    output('<table border="1" rules="cols" frame="box" width="100%" bgcolor="black"><tr bgcolor="' +
        backgroundcolor + '"><a name="anchor' + str(anchor) + '"><td>')
    output(htmlbig(text[0]) + '<br>')
    for i in text[1:]:
        output(i + '<br>')
    output('</td>')
    output('<td width="100" bgcolor="grey"><a align="right" href="#anchor' + str(anchor-1) +
        '">previous</a><br><a align="right" href="#anchor' + str(anchor+1) + '">next</a>')
    output('</td></a></tr>')
    anchor += 1

def endtable():
    output('</table><p>')


# dump some stats about total number of warnings and such
def dumpstats():
    known = 0
    unknown = 0
    for i in warnpatterns:
        if i['severity'] == severity.UNKNOWN:
            unknown += len(i['members'])
        elif i['severity'] != severity.SKIP:
            known += len(i['members'])
    output('Number of classified warnings: <b>' + str(known) + '</b><br>' )
    output('Number of unclassified warnings: <b>' + str(unknown) + '</b><br>')
    total = unknown + known
    output('Total number of warnings: <b>' + str(total) + '</b>')
    if total < 1000:
        output('(low count may indicate incremental build)')
    output('<p>')

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
                begintable(['Fixed warnings', 'No more occurences. Please consider turning these in to errors if possible, before they are reintroduced in to the build'], 'blue')
            tablerow(i['description'] + ' (' + allpatterns(i) + ') ' + i['option'])
    if tablestarted:
        endtable()


# dump a category, provided it is not marked as 'SKIP' and has more than 0 occurrences
def dumpcategory(cat):
    if cat['severity'] != severity.SKIP and len(cat['members']) != 0:
        header = [descriptionfor(cat),str(len(cat['members'])) + ' occurences:']
        if cat['option'] != '':
            header[1:1] = [' (related option: ' + cat['option'] +')']
        begintable(header, colorforseverity(cat['severity']))
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
dumpseverity(severity.FIXMENOW)
dumpseverity(severity.HIGH)
dumpseverity(severity.MEDIUM)
dumpseverity(severity.LOW)
dumpseverity(severity.HARMLESS)
dumpseverity(severity.UNKNOWN)
dumpfixed()

