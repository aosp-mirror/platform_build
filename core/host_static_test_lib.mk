##################################################
## A thin wrapper around BUILD_HOST_STATIC_LIBRARY
## Common flags for host native tests are added.
##################################################
$(call record-module-type,HOST_STATIC_TEST_LIBRARY)

include $(BUILD_SYSTEM)/host_test_internal.mk

include $(BUILD_HOST_STATIC_LIBRARY)
