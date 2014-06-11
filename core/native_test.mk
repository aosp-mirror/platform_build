###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native tests are added.
###########################################

include $(BUILD_SYSTEM)/target_test_internal.mk

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

include $(BUILD_EXECUTABLE)
