#############################################
## A thin wrapper around BUILD_SHARED_LIBRARY
## Common flags for native tests are added.
#############################################

$(error BUILD_SHARED_TEST_LIBRARY is obsolete)

include $(BUILD_SYSTEM)/target_test_internal.mk

include $(BUILD_SHARED_LIBRARY)
