The "emulator" product defines an almost non-hardware-specific target
without a kernel or bootloader, except that it defines the
HAVE_HTC_AUDIO_DRIVER constant, since that is what the emulator
emulates currently.

It can be used to build the entire user-level system, and
will work with the emulator.

It is not a product "base class"; no other products inherit
from it or use it in any way.
