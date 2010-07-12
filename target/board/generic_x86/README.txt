The generic_x86 board target provides basic services on very basic
hardware (really for an emulation). To build with generic_x86, you will
need an appropriate kernel for your emulation (or device).

A1. Create a new top level directory and pull the AOSP repository
        mkdir $HOME/AOSP
        cd $HOME/AOSP
        repo init -u git://android.git.kernel.org/platform/manifest.git
        repo sync

A2. Copy in the kernel
        cd $HOME/AOSP
        cp ~/bzImage.your_device $HOME/AOSP/prebuilt/android-x86/kernel/kernel

A3. Build
        cd $HOME/AOSP
        source build/envsetup.sh
        lunch generic_x86-eng
        make -j8

The build will generate some image files whose format may or may not be correct for your
device. You can build an installer image disk for the VirtualBox emulator using the command:

A4. Build a VirtualBox installer image
	cd $HOME/AOSP
        source build/envsetup.sh
        lunch generic_x86-eng
        make -j8 installer_vdi

