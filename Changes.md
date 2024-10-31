# Build System Changes for Android.mk/Android.bp Writers

## Soong genrules are now sandboxed

Previously, soong genrules could access any files in the source tree, without specifying them as
inputs. This makes them incorrect in incremental builds, and incompatible with RBE and Bazel.

Now, genrules are sandboxed so they can only access their listed srcs. Modules denylisted in
genrule/allowlists.go are exempt from this. You can also set `BUILD_BROKEN_GENRULE_SANDBOXING`
in board config to disable this behavior.

## Partitions are no longer affected by previous builds

Partition builds used to include everything in their staging directories, and building an
individual module will install it to the staging directory. Thus, previously, `m mymodule` followed
by `m` would cause `mymodule` to be presinstalled on the device, even if it wasn't listed in
`PRODUCT_PACKAGES`.

This behavior has been changed, and now the partition images only include what they'd have if you
did a clean build. This behavior can be disabled by setting the
`BUILD_BROKEN_INCORRECT_PARTITION_IMAGES` environment variable or board config variable.

Manually adding make rules that build to the staging directories without going through the make
module system will not be compatible with this change. This includes many usages of
`LOCAL_POST_INSTALL_CMD`.

## Perform validation of Soong plugins

Each Soong plugin will require manual work to migrate to Bazel. In order to
minimize the manual work outside of build/soong, we are restricting plugins to
those that exist today and those in vendor or hardware directories.

If you need to extend the build system via a plugin, please reach out to the
build team via email android-building@googlegroups.com (external) for any
questions, or see [go/soong](http://go/soong) (internal).

To omit the validation, `BUILD_BROKEN_PLUGIN_VALIDATION` expects a
space-separated list of plugins to omit from the validation. This must be set
within a product configuration .mk file, board config .mk file, or buildspec.mk.

## Python 2 to 3 migration

The path set when running builds now makes the `python` executable point to python 3,
whereas on previous versions it pointed to python 2. If you still have python 2 scripts,
you can change the shebang line to use `python2` explicitly. This only applies for
scripts run directly from makefiles, or from soong genrules.

In addition, `python_*` soong modules no longer allow python 2.

Python 2 is slated for complete removal in V.

## Stop referencing sysprop_library directly from cc modules

For the migration to Bazel, we are no longer mapping sysprop_library targets
to their generated `cc_library` counterparts when dependning on them from a
cc module. Instead, directly depend on the generated module by prefixing the
module name with `lib`. For example, depending on the following module:

```
sysprop_library {
    name: "foo",
    srcs: ["foo.sysprop"],
}
```

from a module named `bar` can be done like so:

```
cc_library {
    name: "bar",
    srcs: ["bar.cc"],
    deps: ["libfoo"],
}
```

Failure to do this will result in an error about a missing variant.

## Gensrcs starts disallowing depfile property

To migrate all gensrcs to Bazel, we are restricting the use of depfile property
because Bazel requires specifying the dependencies directly.

To fix existing uses, remove depfile and directly specify all the dependencies
in .bp files. For example:

```
gensrcs {
    name: "framework-cppstream-protos",
    tools: [
        "aprotoc",
        "protoc-gen-cppstream",
    ],
    cmd: "mkdir -p $(genDir)/$(in) " +
        "&& $(location aprotoc) " +
        "  --plugin=$(location protoc-gen-cppstream) " +
        "  -I . " +
        "  $(in) ",
    srcs: [
        "bar.proto",
    ],
    output_extension: "srcjar",
}
```
where `bar.proto` imports `external.proto` would become

```
gensrcs {
    name: "framework-cppstream-protos",
    tools: [
        "aprotoc",
        "protoc-gen-cpptream",
    ],
    tool_files: [
        "external.proto",
    ],
    cmd: "mkdir -p $(genDir)/$(in) " +
        "&& $(location aprotoc) " +
        "  --plugin=$(location protoc-gen-cppstream) " +
        "  $(in) ",
    srcs: [
        "bar.proto",
    ],
    output_extension: "srcjar",
}
```
as in https://android-review.googlesource.com/c/platform/frameworks/base/+/2125692/.

`BUILD_BROKEN_DEPFILE` can be used to allowlist usage of depfile in `gensrcs`.

If `depfile` is needed for generating javastream proto, `java_library` with `proto.type`
set `stream` is the alternative solution. Sees
https://android-review.googlesource.com/c/platform/packages/modules/Permission/+/2118004/
for an example.

## Genrule starts disallowing directory inputs

To better specify the inputs to the build, we are restricting use of directories
as inputs to genrules.

To fix existing uses, change inputs to specify the inputs and update the command
accordingly. For example:

```
genrule: {
    name: "foo",
    srcs: ["bar"],
    cmd: "cp $(location bar)/*.xml $(gendir)",
    ...
}
```

would become

```
genrule: {
    name: "foo",
    srcs: ["bar/*.xml"],
    cmd: "cp $(in) $(gendir)",
    ...
}
```

`BUILD_BROKEN_INPUT_DIR_MODULES` can be used to allowlist specific directories
with genrules that have input directories.

## Dexpreopt starts enforcing `<uses-library>` checks (for Java modules)

In order to construct correct class loader context for dexpreopt, build system
needs to know about the shared library dependencies of Java modules listed in
the `<uses-library>` tags in the manifest. Since the build system does not have
access to the manifest contents, that information must be present in the build
files. In simple cases Soong is able to infer it from its knowledge of Java SDK
libraries and the `libs` property in Android.bp, but in more complex cases it is
necessary to add the missing information in Android.bp/Android.mk manually.

To specify a list of libraries for a given modules, use:

* Android.bp properties: `uses_libs`, `optional_uses_libs`
* Android.mk variables: `LOCAL_USES_LIBRARIES`, `LOCAL_OPTIONAL_USES_LIBRARIES`

If a library is in `libs`, it usually should *not* be added to the above
properties, and Soong should be able to infer the `<uses-library>` tag. But
sometimes a library also needs additional information in its
Android.bp/Android.mk file (e.g. when it is a `java_library` rather than a
`java_sdk_library`, or when the library name is different from its module name,
or when the module is defined in Android.mk rather than Android.bp). In such
cases it is possible to tell the build system that the library provides a
`<uses-library>` with a given name (however, this is discouraged and will be
deprecated in the future, and it is recommended to fix the underlying problem):

* Android.bp property: `provides_uses_lib`
* Android.mk variable: `LOCAL_PROVIDES_USES_LIBRARY`

It is possible to disable the check on a per-module basis. When doing that it is
also recommended to disable dexpreopt, as disabling a failed check will result
in incorrect class loader context recorded in the .odex file, which will cause
class loader context mismatch and dexopt at first boot.

* Android.bp property: `enforce_uses_lib`
* Android.mk variable: `LOCAL_ENFORCE_USES_LIBRARIES`

Finally, it is possible to globally disable the check:

* For a given product: `PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true`
* On the command line: `RELAX_USES_LIBRARY_CHECK=true`

The environment variable overrides the product variable, so it is possible to
disable the check for a product, but quickly re-enable it for a local build.

## `LOCAL_REQUIRED_MODULES` requires listed modules to exist {#BUILD_BROKEN_MISSING_REQUIRED_MODULES}

Modules listed in `LOCAL_REQUIRED_MODULES`, `LOCAL_HOST_REQUIRED_MODULES` and
`LOCAL_TARGET_REQUIRED_MODULES` need to exist unless `ALLOW_MISSING_DEPENDENCIES`
is set.

To temporarily relax missing required modules check, use:

`BUILD_BROKEN_MISSING_REQUIRED_MODULES := true`

## Changes in system properties settings

### Product variables

System properties for each of the partition is supposed to be set via following
product config variables.

For system partition,

* `PRODUCT_SYSTEM_PROPERTIES`
* `PRODUCT_SYSTEM_DEFAULT_PROPERTIES` is highly discouraged. Will be deprecated.

For vendor partition,

* `PRODUCT_VENDOR_PROPERTIES`
* `PRODUCT_PROPERTY_OVERRIDES` is highly discouraged. Will be deprecated.
* `PRODUCT_DEFAULT_PROPERTY_OVERRIDES` is also discouraged. Will be deprecated.

For odm partition,

* `PRODUCT_ODM_PROPERTIES`

For system_ext partition,

* `PRODUCT_SYSTEM_EXT_PROPERTIES`

For product partition,

* `PRODUCT_PRODUCT_PROPERTIES`

### Duplication is not allowed within a partition

For each partition, having multiple sysprop assignments for the same name is
prohibited. For example, the following will now trigger an error:

`PRODUCT_VENDOR_PROPERTIES += foo=true foo=false`

Having duplication across partitions are still allowed. So, the following is
not an error:

`PRODUCT_VENDOR_PROPERTIES += foo=true`
`PRODUCT_SYSTEM_PROPERTIES += foo=false`

In that case, the final value is determined at runtime. The precedence is

* product
* odm
* vendor
* system_ext
* system

So, `foo` becomes `true` because vendor has higher priority than system.

To temporarily turn the build-time restriction off, use

`BUILD_BROKEN_DUP_SYSPROP := true`

### Optional assignments

System properties can now be set as optional using the new syntax:

`name ?= value`

Then the system property named `name` gets the value `value` only when there
is no other non-optional assignments having the same name. For example, the
following is allowed and `foo` gets `true`

`PRODUCT_VENDOR_PROPERTIES += foo=true foo?=false`

Note that the order between the optional and the non-optional assignments
doesn't matter. The following gives the same result as above.

`PRODUCT_VENDOR_PROPERTIES += foo?=false foo=true`

Optional assignments can be duplicated and in that case their order matters.
Specifically, the last one eclipses others.

`PRODUCT_VENDOR_PROPERTIES += foo?=apple foo?=banana foo?=mango`

With above, `foo` becomes `mango` since its the last one.

Note that this behavior is different from the previous behavior of preferring
the first one. To go back to the original behavior for compatability reason,
use:

`BUILD_BROKEN_DUP_SYSPROP := true`

## ELF prebuilts in `PRODUCT_COPY_FILES` {#BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES}

ELF prebuilts in `PRODUCT_COPY_FILES` that are installed into these paths are an
error:

* `<partition>/bin/*`
* `<partition>/lib/*`
* `<partition>/lib64/*`

Define prebuilt modules and add them to `PRODUCT_PACKAGES` instead.
To temporarily relax this check and restore the behavior prior to this change,
set `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true` in `BoardConfig.mk`.

## COPY_HEADERS usage now produces warnings {#copy_headers}

We've considered `BUILD_COPY_HEADERS`/`LOCAL_COPY_HEADERS` to be deprecated for
a long time, and the places where it's been able to be used have shrinked over
the last several releases. Equivalent functionality is not available in Soong.

See the [build/soong/docs/best_practices.md#headers] for more information about
how best to handle headers in Android.

## `m4` is not available on `$PATH`

There is a prebuilt of it available in prebuilts/build-tools, and a make
variable `M4` that contains the path.

Beyond the direct usage, whenever you use bison or flex directly, they call m4
behind the scene, so you must set the M4 environment variable (and depend upon
it for incremental build correctness):

```
$(intermediates)/foo.c: .KATI_IMPLICIT_OUTPUTS := $(intermediates)/foo.h
$(intermediates)/foo.c: $(LOCAL_PATH)/foo.y $(M4) $(BISON) $(BISON_DATA)
	M4=$(M4) $(BISON) ...
```

## Rules executed within limited environment

With `ALLOW_NINJA_ENV=false` (soon to be the default), ninja, and all the
rules/actions executed within it will only have access to a limited number of
environment variables. Ninja does not track when environment variables change
in order to trigger rebuilds, so changing behavior based on arbitrary variables
is not safe with incremental builds.

Kati and Soong can safely use environment variables, so the expectation is that
you'd embed any environment variables that you need to use within the command
line generated by those tools. See the [export section](#export_keyword) below
for examples.

For a temporary workaround, you can set `ALLOW_NINJA_ENV=true` in your
environment to restore the previous behavior, or set
`BUILD_BROKEN_NINJA_USES_ENV_VAR := <var> <var2> ...` in your `BoardConfig.mk`
to allow specific variables to be passed through until you've fixed the rules.

## LOCAL_C_INCLUDES outside the source/output trees are an error {#BUILD_BROKEN_OUTSIDE_INCLUDE_DIRS}

Include directories are expected to be within the source tree (or in the output
directory, generated during the build). This has been checked in some form
since Oreo, but now has better checks.

There's now a `BUILD_BROKEN_OUTSIDE_INCLUDE_DIRS` variable, that when set, will
turn these errors into warnings temporarily. I don't expect this to last more
than a release, since they're fairly easy to clean up.

Neither of these cases are supported by Soong, and will produce errors when
converting your module.

### Absolute paths

This has been checked since Oreo. The common reason to hit this is because a
makefile is calculating a path, and ran abspath/realpath/etc. This is a problem
because it makes your build non-reproducible. It's very unlikely that your
source path is the same on every machine.

### Using `../` to leave the source/output directories

This is the new check that has been added. In every case I've found, this has
been a mistake in the Android.mk -- assuming that `LOCAL_C_INCLUDES` (which is
relative to the top of the source tree) acts like `LOCAL_SRC_FILES` (which is
relative to `LOCAL_PATH`).

Since this usually isn't a valid path, you can almost always just remove the
offending line.


## `BOARD_HAL_STATIC_LIBRARIES` and `LOCAL_HAL_STATIC_LIBRARIES` are obsolete {#BOARD_HAL_STATIC_LIBRARIES}

Define proper HIDL / Stable AIDL HAL instead.

* For libhealthd, use health HAL. See instructions for implementing
  health HAL:

  * [hardware/interfaces/health/2.1/README.md] for health 2.1 HAL (recommended)
  * [hardware/interfaces/health/1.0/README.md] for health 1.0 HAL

* For libdumpstate, use at least Dumpstate HAL 1.0.

## PRODUCT_STATIC_BOOT_CONTROL_HAL is obsolete {#PRODUCT_STATIC_BOOT_CONTROL_HAL}

`PRODUCT_STATIC_BOOT_CONTROL_HAL` was the workaround to allow sideloading with
statically linked boot control HAL, before shared library HALs were supported
under recovery. Android Q has added such support (HALs will be loaded in
passthrough mode), and the workarounds are being removed. Targets should build
and install the recovery variant of boot control HAL modules into recovery
image, similar to the ones installed for normal boot. See the change to
crosshatch for example of this:

* [device/google/crosshatch/bootctrl/Android.bp] for `bootctrl.sdm845` building
  rules
* [device/google/crosshatch/device.mk] for installing `bootctrl.sdm845.recovery`
  and `android.hardware.boot@1.0-impl.recovery` into recovery image

[device/google/crosshatch/bootctrl/Android.bp]: https://android.googlesource.com/device/google/crosshatch/+/master/bootctrl/Android.bp
[device/google/crosshatch/device.mk]: https://android.googlesource.com/device/google/crosshatch/+/master/device.mk

## Deprecation of `BUILD_*` module types

See [build/make/Deprecation.md](Deprecation.md) for the current status.

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

## `LOCAL_MODULE_TAGS := eng debug` are obsolete {#LOCAL_MODULE_TAGS}

`LOCAL_MODULE_TAGS` value `eng` and `debug` are now obsolete. They allowed
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

#### FILE_NAME_TAG  {#FILE_NAME_TAG}

To embed the `BUILD_NUMBER` (or for local builds, `eng.${USER}`), include
`FILE_NAME_TAG_PLACEHOLDER` in the destination:

``` make
# you can use dist-for-goals-with-filenametag function
$(call dist-for-goals-with-filenametag,foo,bar.zip)
# or use FILE_NAME_TAG_PLACEHOLDER manually
$(call dist-for-goals,foo,bar.zip:baz-FILE_NAME_TAG_PLACEHOLDER.zip)
```

Which will produce `$DIST_DIR/baz-1234567.zip` on build servers which set
`BUILD_NUMBER=1234567`, or `$DIST_DIR/baz-eng.builder.zip` for local builds.

If you just want to append `BUILD_NUMBER` at the end of basename, use
`dist-for-goals-with-filenametag` instead of `dist-for-goals`.

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

The `export` and `unexport` keywords are obsolete, and will throw errors when
used.

Device specific configuration should not be able to affect common core build
steps -- we're looking at triggering build steps to be invalidated if the set
of environment variables they can access changes. If device specific
configuration is allowed to change those, switching devices with the same
output directory could become significantly more expensive than it already can
be.

If used during Android.mk files, and later tasks, it is increasingly likely
that they are being used incorrectly. Attempting to change the environment for
a single build step, and instead setting it for hundreds of thousands.

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
| OUT {#OUT}                                                   | PRODUCT_OUT          |
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

### Stop using clang property

The clang property has been deleted from Soong. To fix any build errors, remove the clang
property from affected Android.bp files using bpmodify.


``` make
go run bpmodify.go -w -m=module_name -remove-property=true -property=clang filepath
```

`BUILD_BROKEN_CLANG_PROPERTY` can be used as temporarily workaround


### Stop using clang_cflags and clang_asflags

clang_cflags and clang_asflags are deprecated.
To fix any build errors, use bpmodify to either
    - move the contents of clang_asflags/clang_cflags into asflags/cflags or
    - delete clang_cflags/as_flags as necessary

To Move the contents:
``` make
go run bpmodify.go -w -m=module_name -move-property=true -property=clang_cflags -new-location=cflags filepath
```

To Delete:
``` make
go run bpmodify.go -w -m=module_name -remove-property=true -property=clang_cflags filepath
```

`BUILD_BROKEN_CLANG_ASFLAGS` and `BUILD_BROKEN_CLANG_CFLAGS` can be used as temporarily workarounds

### Other envsetup.sh variables  {#other_envsetup_variables}

* ANDROID_TOOLCHAIN
* ANDROID_TOOLCHAIN_2ND_ARCH
* ANDROID_DEV_SCRIPTS
* ANDROID_EMULATOR_PREBUILTS
* ANDROID_PRE_BUILD_PATHS

These are all exported from envsetup.sh, but don't have clear equivalents within
the makefile system. If you need one of them, you'll have to set up your own
version.

## Soong config variables

### Soong config string variables must list all values they can be set to

In order to facilitate the transition to bazel, all soong_config_string_variables
must only be set to a value listed in their `values` property, or an empty string.
It is a build error otherwise.

Example Android.bp:
```
soong_config_string_variable {
    name: "my_string_variable",
    values: [
        "foo",
        "bar",
    ],
}

soong_config_module_type {
    name: "my_cc_defaults",
    module_type: "cc_defaults",
    config_namespace: "my_namespace",
    variables: ["my_string_variable"],
    properties: [
        "shared_libs",
        "static_libs",
    ],
}
```
Product config:
```
$(call soong_config_set,my_namespace,my_string_variable,baz) # Will be an error as baz is not listed in my_string_variable's values.
```

[build/soong/Changes.md]: https://android.googlesource.com/platform/build/soong/+/master/Changes.md
[build/soong/docs/best_practices.md#headers]: https://android.googlesource.com/platform/build/soong/+/master/docs/best_practices.md#headers
[external/fonttools/Lib/fontTools/Android.bp]: https://android.googlesource.com/platform/external/fonttools/+/master/Lib/fontTools/Android.bp
[frameworks/base/Android.bp]: https://android.googlesource.com/platform/frameworks/base/+/master/Android.bp
[frameworks/base/data/fonts/Android.mk]: https://android.googlesource.com/platform/frameworks/base/+/master/data/fonts/Android.mk
[hardware/interfaces/health/1.0/README.md]: https://android.googlesource.com/platform/hardware/interfaces/+/master/health/1.0/README.md
[hardware/interfaces/health/2.1/README.md]: https://android.googlesource.com/platform/hardware/interfaces/+/master/health/2.1/README.md
