The "generic_arm64_plus_armv7" product defines a non-hardware-specific arm64
target with armv7 compatible arm32.  It is used for building CTS and other
test suites for which the 32-bit binaries may be run on older devices with
armv7 CPUs.

It is not a product "base class"; no other products inherit
from it or use it in any way.
