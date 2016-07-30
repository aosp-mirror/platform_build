#############################################
## A thin wrapper around BUILD_STATIC_LIBRARY
## Common flags for native tests are added.
#############################################
$(call record-module-type,STATIC_TEST_LIBRARY)

include $(BUILD_SYSTEM)/target_test_internal.mk

include $(BUILD_STATIC_LIBRARY)
