#############################################
## A thin wrapper around BUILD_SHARED_LIBRARY
## Common flags for native tests are added.
#############################################

include $(BUILD_SYSTEM)/target_test_internal.mk

include $(BUILD_SHARED_LIBRARY)
