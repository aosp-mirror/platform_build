The "generic_mips" product defines a MIPS based non-hardware-specific
target without a kernel or bootloader.

It can be used to build the entire user-level system, and
will work with the emulator, though sound will not work
(see the "emulator" product for that).

It is not a product "base class"; no other products inherit
from it or use it in any way.
