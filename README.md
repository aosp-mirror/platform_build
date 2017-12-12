# Android Make Build System

This is the Makefile-based portion of the Android Build System.

For documentation on how to run a build, see [Usage.txt](Usage.txt)

For a list of behavioral changes useful for Android.mk writers see
[Changes.md](Changes.md)

For an outdated reference on Android.mk files, see
[build-system.html](/core/build-system.html). Our Android.mk files look similar,
but are entirely different from the Android.mk files used by the NDK build
system. When searching for documentation elsewhere, ensure that it is for the
platform build system -- most are not.

This Makefile-based system is in the process of being replaced with [Soong], a
new build system written in Go. During the transition, all of these makefiles
are read by [Kati], and generate a ninja file instead of being executed
directly. That's combined with a ninja file read by Soong so that the build
graph of the two systems can be combined and run as one.

[Kati]: https://github.com/google/kati
[Soong]: https://android.googlesource.com/platform/build/soong/+/master
