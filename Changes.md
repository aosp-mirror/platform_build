# Build System Changes for Android.mk Writers

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
