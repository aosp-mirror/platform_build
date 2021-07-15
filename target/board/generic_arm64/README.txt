The "generic_arm64" product defines a non-hardware-specific arm64 target
without a bootloader.

It is also the target to build the generic kernel image (GKI).

It is not a product "base class"; no other products inherit
from it or use it in any way.
