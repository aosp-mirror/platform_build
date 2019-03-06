# Build System Changes for Android.mk Writers

## `PRODUCT_HOST_PACKAGES` split from `PRODUCT_PACKAGES` {#PRODUCT_HOST_PACKAGES}

Previously, adding a module to `PRODUCT_PACKAGES` that supported both the host
and the target (`host_supported` in Android.bp; two modules with the same name
in Android.mk) would cause both to be built and installed. In many cases you
only want either the host or target versions to be built/installed by default,
and would be over-building with both. So `PRODUCT_PACKAGES` will be changing to
just affect target modules, while `PRODUCT_HOST_PACKAGES` is being added for
host modules.

Functional differences between `PRODUCT_PACKAGES` and `PRODUCT_HOST_PACKAGES`:

* `PRODUCT_HOST_PACKAGES` does not have `_ENG`/`_DEBUG` variants, as that's a
  property of the target, not the host.
* `PRODUCT_HOST_PACKAGES` does not support `LOCAL_MODULE_OVERRIDES`.
* `PRODUCT_HOST_PACKAGES` requires listed modules to exist, and be host
  modules. (Unless `ALLOW_MISSING_DEPENDENCIES` is set)

This is still an active migration, so currently it still uses
`PRODUCT_PACKAGES` to make installation decisions, but verifies that if we used
`PRODUCT_HOST_PACKAGES`, it would trigger installation for all of the same host
packages. This check ignores shared libraries, as those are not normally
necessary in `PRODUCT_*PACKAGES`, and tended to be over-built (especially the
32-bit variants).

Future changes will switch installation decisions to `PRODUCT_HOST_PACKAGES`
for host modules, error when there's a host-only module in `PRODUCT_PACKAGES`,
and do some further cleanup where `LOCAL_REQUIRED_MODULES` are still merged
between host and target modules with the same name.

## `*.c.arm` / `*.cpp.arm` deprecation  {#file_arm}

In Android.mk files, you used to be able to change LOCAL_ARM_MODE for each
source file by appending `.arm` to the end of the filename in
`LOCAL_SRC_FILES`.

Soong does not support this uncommonly used behavior, instead expecting those
files to be split out into a separate static library that chooses `arm` over
`thumb` for the entire library. This must now also be done in Android.mk files.

## Windows cross-compiles no longer supported in Android.mk

Modules that build for Windows (our only `HOST_CROSS` OS currently) must now be
defined in `Android.bp` files.

## `LOCAL_MODULE_TAGS := eng debug` deprecation  {#LOCAL_MODULE_TAGS}

`LOCAL_MODULE_TAGS` value `eng` and `debug` are being deprecated. They allowed
modules to specify that they should always be installed on `-eng`, or `-eng`
and `-userdebug` builds. This conflicted with the ability for products to
specify which modules should be installed, effectively making it impossible to
build a stripped down product configuration that did not include those modules.

For the equivalent functionality, specify the modules in `PRODUCT_PACKAGES_ENG`
or `PRODUCT_PACKAGES_DEBUG` in the appropriate product makefiles.

Core android packages like `su` got added to the list in
`build/make/target/product/base_system.mk`, but for device-specific modules
there are often better base product makefiles to use instead.

## `USER` deprecation  {#USER}

`USER` will soon be `nobody` in many cases due to the addition of a sandbox
around the Android build. Most of the time you shouldn't need to know the
identity of the user running the build, but if you do, it's available in the
make variable `BUILD_USERNAME` for now.

Similarly, the `hostname` tool will also be returning a more consistent value
of `android-build`. The real value is available as `BUILD_HOSTNAME`.

## `BUILD_NUMBER` removal from Android.mk  {#BUILD_NUMBER}

`BUILD_NUMBER` should not be used directly in Android.mk files, as it would
trigger them to be re-read every time the `BUILD_NUMBER` changes (which it does
on every build server build). If possible, just remove the use so that your
builds are more reproducible. If you do need it, use `BUILD_NUMBER_FROM_FILE`:

``` make
$(LOCAL_BUILT_MODULE):
	mytool --build_number $(BUILD_NUMBER_FROM_FILE) -o $@
```

That will expand out to a subshell that will read the current `BUILD_NUMBER`
whenever it's run. It will not re-run your command if the build number has
changed, so incremental builds will have the build number from the last time
the particular output was rebuilt.

## `DIST_DIR`, `dist_goal`, and `dist-for-goals`  {#dist}

`DIST_DIR` and `dist_goal` are no longer available when reading Android.mk
files (or other build tasks). Always use `dist-for-goals` instead, which takes
a PHONY goal, and a list of files to copy to `$DIST_DIR`. Whenever `dist` is
specified, and the goal would be built (either explicitly on the command line,
or as a dependency of something on the command line), that file will be copied
into `$DIST_DIR`. For example,

``` make
$(call dist-for-goals,foo,bar/baz)
```

will copy `bar/baz` into `$DIST_DIR/baz` when `m foo dist` is run.

#### Renames during copy

Instead of specifying just a file, a destination name can be specified,
including subdirectories:

``` make
$(call dist-for-goals,foo,bar/baz:logs/foo.log)
```

will copy `bar/baz` into `$DIST_DIR/logs/foo.log` when `m foo dist` is run.

## `.PHONY` rule enforcement  {#phony_targets}

There are several new warnings/errors meant to ensure the proper use of
`.PHONY` targets in order to improve the speed and reliability of incremental
builds.

`.PHONY`-marked targets are often used as shortcuts to provide "friendly" names
for real files to be built, but any target marked with `.PHONY` is also always
considered dirty, needing to be rebuilt every build. This isn't a problem for
aliases or one-off user-requested operations, but if real builds steps depend
on a `.PHONY` target, it can get quite expensive for what should be a tiny
build.

``` make
...mk:42: warning: PHONY target "out/.../foo" looks like a real file (contains a "/")
```

Between this warning and the next, we're requiring that `.PHONY` targets do not
have "/" in them, and real file targets do have a "/". This makes it more
obvious when reading makefiles what is happening, and will help the build
system differentiate these in the future too.

``` make
...mk:42: warning: writing to readonly directory: "kernel-modules"
```

This warning will show up for one of two reasons:

1. The target isn't intended to be a real file, and should be marked with
   `.PHONY`. This would be the case for this example.
2. The target is a real file, but it's outside the output directories. All
   outputs from the build system should be within the output directory,
   otherwise `m clean` is unable to clean the build, and future builds may not
   work properly.

``` make
...mk:42: warning: real file "out/.../foo" depends on PHONY target "buildbins"
```

If the first target isn't intended to be a real file, then it should be marked
with `.PHONY`, which will satisfy this warning. This isn't the case for this
example, as we require `.PHONY` targets not to have '/' in them.

If the second (PHONY) target is a real file, it may unnecessarily be marked
with `.PHONY`.

### `.PHONY` and calling other build systems

One common pattern (mostly outside AOSP) that we've seen hit these warning is
when building with external build systems (firmware, bootloader, kernel, etc).
Those are often marked as `.PHONY` because the Android build system doesn't
have enough dependencies to know when to run the other build system again
during an incremental build.

We recommend to build these outside of Android, and deliver prebuilts into the
Android tree instead of decreasing the speed and reliability of the incremental
Android build.

In cases where that's not desired, to preserve the speed of Android
incrementals, over-specifying dependencies is likely a better option than
marking it with `.PHONY`:

``` make
out/target/.../zImage: $(sort $(shell find -L $(KERNEL_SRCDIR)))
	...
```

For reliability, many of these other build systems do not guarantee the same
level of incremental build assurances as the Android Build is attempting to do
-- without custom checks, Make doesn't rebuild objects when CFLAGS change, etc.
In order to fix this, our recommendation is to do clean builds for each of
these external build systems every time anything they rely on changes. For
relatively smaller builds (like the kernel), this may be reasonable as long as
you're not trying to actively debug the kernel.

## `export` and `unexport` deprecation  {#export_keyword}

The `export` and `unexport` keywords have been deprecated, and will throw
warnings or errors depending on where they are used.

Early in the make system, during product configuration and BoardConfig.mk
reading: these will throw a warnings, and will be an error in the future.
Device specific configuration should not be able to affect common core build
steps -- we're looking at triggering build steps to be invalidated if the set
of environment variables they can access changes. If device specific
configuration is allowed to change those, switching devices with the same
output directory could become significantly more expensive than it already can
be.

Later, during Android.mk files, and later tasks: these will throw errors, since
it is increasingly likely that they are being used incorrectly, attempting to
change the environment for a single build step, and instead setting it for
hundreds of thousands.

It is not recommended to just move the environment variable setting outside of
the build (in vendorsetup.sh, or some other configuration script or wrapper).
We expect to limit the environment variables that the build respects in the
future, others will be cleared. (There will be methods to get custom variables
into the build, just not to every build step)

Instead, write the export commands into the rule command lines themselves:

``` make
$(intermediates)/generated_output.img:
	rm -rf $@
	export MY_ENV_A="$(MY_A)"; make ...
```

If you want to set many environment variables, and/or use them many times,
write them out to a script and source the script:

``` make
envsh := $(intermediates)/env.sh
$(envsh):
	rm -rf $@
	echo 'export MY_ENV_A="$(MY_A)"' >$@
	echo 'export MY_ENV_B="$(MY_B)"' >>$@

$(intermediates)/generated_output.img: PRIVATE_ENV := $(envsh)
$(intermediates)/generated_output.img: $(envsh) a/b/c/package.sh
	rm -rf $@
	source $(PRIVATE_ENV); make ...
	source $(PRIVATE_ENV); a/b/c/package.sh ...
```

## Implicit make rules are obsolete {#implicit_rules}

Implicit rules look something like the following:

``` make
$(TARGET_OUT_SHARED_LIBRARIES)/%_vendor.so: $(TARGET_OUT_SHARED_LIBRARIES)/%.so
	...

%.o : %.foo
	...
```

These can have wide ranging effects across unrelated modules, so they're now obsolete. Instead, use static pattern rules, which are similar, but explicitly match the specified outputs:

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
