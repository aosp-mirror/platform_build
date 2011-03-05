The "vbox_x86" product defines a non-hardware-specific target intended
to run on the VirtualBox emulator.

Most of the Android devices (networking, phones, sound, etc) do not work.

ADB via ethernet works with this target. You can use 'adb install' to
test applications that do not require network, phone or sound support.
This emulation is useful because VirtualBox runs much faster then does the
QEMU emulators (at least until a KVM enabled QEMU emulator is available).
