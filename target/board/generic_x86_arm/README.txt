The "generic_x86_arm" product defines a non-hardware-specific IA target
without a kernel or bootloader.

It can be used to build the entire user-level system, and
will work with the IA version of the emulator,

It is not a product "base class"; no other products inherit
from it or use it in any way.

Third party arm to x86 translator has to be installed as well
