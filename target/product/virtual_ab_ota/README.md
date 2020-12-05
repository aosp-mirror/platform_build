# Virtual A/B makefiles

Devices that uses Virtual A/B must inherit from one of the makefiles in this directory.

## Structure

```
launch.mk
  |- retrofit.mk
  |- plus_non_ab.mk

launch_with_vendor_ramdisk.mk
  |- compression.mk

compression_retrofit.mk
```
