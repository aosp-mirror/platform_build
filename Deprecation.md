# Deprecation of Make

We've made significant progress converting AOSP from Make to Soong (Android.mk
to Android.bp), and we're ready to start turning off pieces of Make. If you
have any problems converting, please contact us via:

* The [android-building@googlegroups.com] group.
* Our [public bug tracker](https://issuetracker.google.com/issues/new?component=381517).
* Or privately through your existing contacts at Google.

## Status

[build/make/core/deprecation.mk] is the source of truth, but for easy browsing:

| Module type                      | State     |
| -------------------------------- | --------- |
| `BUILD_AUX_EXECUTABLE`           | Error     |
| `BUILD_AUX_STATIC_LIBRARY`       | Error     |
| `BUILD_HOST_FUZZ_TEST`           | Error     |
| `BUILD_HOST_NATIVE_TEST`         | Error     |
| `BUILD_HOST_SHARED_LIBRARY`      | Warning   |
| `BUILD_HOST_SHARED_TEST_LIBRARY` | Error     |
| `BUILD_HOST_STATIC_LIBRARY`      | Warning   |
| `BUILD_HOST_STATIC_TEST_LIBRARY` | Error     |
| `BUILD_HOST_TEST_CONFIG`         | Error     |
| `BUILD_NATIVE_BENCHMARK`         | Error     |
| `BUILD_SHARED_TEST_LIBRARY`      | Error     |
| `BUILD_STATIC_TEST_LIBRARY`      | Error     |
| `BUILD_TARGET_TEST_CONFIG`       | Error     |
| `BUILD_*`                        | Available |

## Module Type Deprecation Process

We'll be turning off `BUILD_*` module types as all of the users are removed
from AOSP (and Google's internal trees). The process will go something like
this, using `BUILD_PACKAGE` as an example:

* Prerequisite: all common users of `BUILD_PACKAGE` have been removed (some
  device-specific ones may remain).
* `BUILD_PACKAGE` will be moved from `AVAILABLE_BUILD_MODULE_TYPES` to
  `DEFAULT_WARNING_BUILD_MODULE_TYPES` in [build/make/core/deprecation.mk]. This
  will make referring to `BUILD_PACKAGE` a warning.
* Any devices that still have warnings will have
  `BUILD_BROKEN_USES_BUILD_PACKAGE := true` added to their `BoardConfig.mk`.
* `BUILD_PACKAGE` will be switched from `DEFAULT_WARNING_BUILD_MODULE_TYPES` to
  `DEFAULT_ERROR_BUILD_MODULE_TYPES`, which will turn referring to
  `BUILD_PACKAGE` into an error unless the device has overridden it.
* At some later point, after all devices in AOSP no longer set
  `BUILD_BROKEN_USES_BUILD_PACKAGE`, `BUILD_PACKAGE` will be moved from
  `DEFAULT_ERROR_BUILD_MODULE_TYPES` to `OBSOLETE_BUILD_MODULE_TYPES` and the
  code will be removed. It will no longer be possible to use `BUILD_PACKAGE`.

In most cases, we expect module types to stay in the default warning state for
about two weeks before becoming an error by default. Then it will spend some
amount of time in the default error state before moving to obsolete -- we'll
try and keep that around for a while, but other development may cause those to
break, and the fix may to be to obsolete them. There is no expectation that the
`BUILD_BROKEN_USES_BUILD_*` workarounds will work in a future release, it's a
short-term workaround.

Just to be clear, the above process will happen on the AOSP master branch. So
if you're following Android releases, none of the deprecation steps will be in
Android Q, and the 2020 release will have jumped directly to the end for many
module types.

[android-building@googlegroups.com]: https://groups.google.com/forum/#!forum/android-building
[build/make/core/deprecation.mk]: /core/deprecation.mk
