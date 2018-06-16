# Build System Changes for Android.mk Writers

## Implicit make rules are deprecated {#implicit_rules}

Implicit rules look something like the following:

``` make
$(TARGET_OUT_SHARED_LIBRARIES)/%_vendor.so: $(TARGET_OUT_SHARED_LIBRARIES)/%.so
	...

%.o : %.foo
	...
```

These can have wide ranging effects across unrelated modules, so they're now deprecated. Instead, use static pattern rules, which are similar, but explicitly match the specified outputs:

``` make
libs := $(foreach lib,libfoo libbar,$(TARGET_OUT_SHARED_LIBRARIES)/$(lib)_vendor.so)
$(libs): %_vendor.so: %.so
	...

files := $(wildcard $(LOCAL_PATH)/*.foo)
gen := $(patsubst $(LOCAL_PATH)/%.foo,$(intermediates)/%.o,$(files))
$(gen): %.o : %.foo
	...
```

## Removing '/' from Valid Module Names {#name_slash}

The build system uses module names in path names in many places. Having an
extra '/' or '../' being inserted can cause problems -- and not just build
breaks, but stranger invalid behavior.

In every case we've seen, the fix is relatively simple: move the directory into
`LOCAL_MODULE_RELATIVE_PATH` (or `LOCAL_MODULE_PATH` if you're still using it).
If this causes multiple modules to be named the same, use unique module names
and `LOCAL_MODULE_STEM` to change the installed file name:

``` make
include $(CLEAR_VARS)
LOCAL_MODULE := ver1/code.bin
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/firmware
...
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := ver2/code.bin
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/firmware
...
include $(BUILD_PREBUILT)
```

Can be rewritten as:

```
include $(CLEAR_VARS)
LOCAL_MODULE := ver1_code.bin
LOCAL_MODULE_STEM := code.bin
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/firmware/ver1
...
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := ver2_code.bin
LOCAL_MODULE_STEM := code.bin
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)/firmware/ver2
...
include $(BUILD_PREBUILT)
```

You just need to make sure that any other references (`PRODUCT_PACKAGES`,
`LOCAL_REQUIRED_MODULES`, etc) are converted to the new names.

## Valid Module Names {#name}

We've adopted lexical requirements very similar to [Bazel's
requirements](https://docs.bazel.build/versions/master/build-ref.html#name) for
target names. Valid characters are `a-z`, `A-Z`, `0-9`, and the special
characters `_.+-=,@~`. This currently applies to `LOCAL_PACKAGE_NAME`,
`LOCAL_MODULE`, and `LOCAL_MODULE_SUFFIX`, and `LOCAL_MODULE_STEM*`.

Many other characters already caused problems if you used them, so we don't
expect this to have a large effect.

## PATH Tools {#PATH_Tools}

The build has started restricting the external host tools usable inside the
build. This will help ensure that build results are reproducible across
different machines, and catch mistakes before they become larger issues.

To start with, this includes replacing the $PATH with our own directory of
tools, mirroring that of the host PATH.  The only difference so far is the
removal of the host GCC tools. Anything that is not explicitly in the
configuration as allowed will continue functioning, but will generate a log
message. This is expected to become more restrictive over time.

The configuration is located in build/soong/ui/build/paths/config.go, and
contains all the common tools in use in many builds. Anything not in that list
will currently print a warning in the `$OUT_DIR/soong.log` file, including the
command and arguments used, and the process tree in order to help locate the
usage.

In order to fix any issues brought up by these checks, the best way to fix them
is to use tools checked into the tree -- either as prebuilts, or building them
as host tools during the build.

As a temporary measure, you can set `TEMPORARY_DISABLE_PATH_RESTRICTIONS=true`
in your environment to temporarily turn off the error checks and allow any tool
to be used (with logging). Beware that GCC didn't work well with the interposer
used for logging, so this may not help in all cases.

## Deprecating / obsoleting envsetup.sh variables in Makefiles

It is not required to source envsetup.sh before running a build. Many scripts,
including a majority of our automated build systems, do not do so. Make will
transparently make every environment variable available as a make variable.
This means that relying on environment variables only set up in envsetup.sh will
produce different output for local users and scripted users.

Many of these variables also include absolute path names, which we'd like to
keep out of the generated files, so that you don't need to do a full rebuild if
you move the source tree.

To fix this, we're marking the variables that are set in envsetup.sh as
deprecated in the makefiles. This will trigger a warning every time one is read
(or written) inside Kati. Once all the warnings have been removed for a
particular variable, we'll switch it to obsolete, and any references will become
errors.

### envsetup.sh variables with make equivalents

| instead of                                                   | use                  |
|--------------------------------------------------------------|----------------------|
| OUT {#OUT}                                                   | OUT_DIR              |
| ANDROID_HOST_OUT {#ANDROID_HOST_OUT}                         | HOST_OUT             |
| ANDROID_PRODUCT_OUT {#ANDROID_PRODUCT_OUT}                   | PRODUCT_OUT          |
| ANDROID_HOST_OUT_TESTCASES {#ANDROID_HOST_OUT_TESTCASES}     | HOST_OUT_TESTCASES   |
| ANDROID_TARGET_OUT_TESTCASES {#ANDROID_TARGET_OUT_TESTCASES} | TARGET_OUT_TESTCASES |

All of the make variables may be relative paths from the current directory, or
absolute paths if the output directory was specified as an absolute path. If you
need an absolute variable, convert it to absolute during a rule, so that it's
not expanded into the generated ninja file:

``` make
$(PRODUCT_OUT)/gen.img: my/src/path/gen.sh
	export PRODUCT_OUT=$$(cd $(PRODUCT_OUT); pwd); cd my/src/path; ./gen.sh -o $${PRODUCT_OUT}/gen.img
```

### ANDROID_BUILD_TOP  {#ANDROID_BUILD_TOP}

In Android.mk files, you can always assume that the current directory is the
root of the source tree, so this can just be replaced with '.' (which is what
$TOP is hardcoded to), or removed entirely. If you need an absolute path, see
the instructions above.

### Stop using PATH directly  {#PATH}

This isn't only set by envsetup.sh, but it is modified by it. Due to that it's
rather easy for this to change between different shells, and it's not ideal to
reread the makefiles every time this changes.

In most cases, you shouldn't need to touch PATH at all. When you need to have a
rule reference a particular binary that's part of the source tree or outputs,
it's preferrable to just use the path to the file itself (since you should
already be adding that as a dependency).

Depending on the rule, passing the file path itself may not be feasible due to
layers of unchangable scripts/binaries. In that case, be sure to add the
dependency, but modify the PATH within the rule itself:

``` make
$(TARGET): myscript my/path/binary
	PATH=my/path:$$PATH myscript -o $@
```

### Stop using PYTHONPATH directly  {#PYTHONPATH}

Like PATH, this isn't only set by envsetup.sh, but it is modified by it. Due to
that it's rather easy for this to change between different shells, and it's not
ideal to reread the makefiles every time.

The best solution here is to start switching to Soong's python building support,
which packages the python interpreter, libraries, and script all into one file
that no longer needs PYTHONPATH. See fontchain_lint for examples of this:

* [external/fonttools/Lib/fontTools/Android.bp] for python_library_host
* [frameworks/base/Android.bp] for python_binary_host
* [frameworks/base/data/fonts/Android.mk] to execute the python binary

If you still need to use PYTHONPATH, do so within the rule itself, just like
path:

``` make
$(TARGET): myscript.py $(sort $(shell find my/python/lib -name '*.py'))
	PYTHONPATH=my/python/lib:$$PYTHONPATH myscript.py -o $@
```
### Stop using PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE directly {#PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE}

Specify Framework Compatibility Matrix Version in device manifest by adding a `target-level`
attribute to the root element `<manifest>`. If `PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE`
is 26 or 27, you can add `"target-level"="1"` to your device manifest instead.

### Stop using USE_CLANG_PLATFORM_BUILD {#USE_CLANG_PLATFORM_BUILD}

Clang is the default and only supported Android compiler, so there is no reason
for this option to exist.

### Other envsetup.sh variables  {#other_envsetup_variables}

* ANDROID_TOOLCHAIN
* ANDROID_TOOLCHAIN_2ND_ARCH
* ANDROID_DEV_SCRIPTS
* ANDROID_EMULATOR_PREBUILTS
* ANDROID_PRE_BUILD_PATHS

These are all exported from envsetup.sh, but don't have clear equivalents within
the makefile system. If you need one of them, you'll have to set up your own
version.


[build/soong/Changes.md]: https://android.googlesource.com/platform/build/soong/+/master/Changes.md
[external/fonttools/Lib/fontTools/Android.bp]: https://android.googlesource.com/platform/external/fonttools/+/master/Lib/fontTools/Android.bp
[frameworks/base/Android.bp]: https://android.googlesource.com/platform/frameworks/base/+/master/Android.bp
[frameworks/base/data/fonts/Android.mk]: https://android.googlesource.com/platform/frameworks/base/+/master/data/fonts/Android.mk
