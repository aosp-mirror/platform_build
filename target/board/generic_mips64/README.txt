The "generic_mips64" product defines a MIPS64 based non-hardware-specific
target without a kernel or bootloader.

It can be used to build the entire user-level system, and
will work with the emulator.

It is not a product "base class"; no other products inherit
from it or use it in any way.
