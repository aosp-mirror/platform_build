LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := vndk_package
LOCAL_REQUIRED_MODULES := \
    $(addsuffix .vendor,$(VNDK_CORE_LIBRARIES)) \
    $(addsuffix .vendor,$(VNDK_SAMEPROCESS_LIBRARIES)) \
    $(LLNDK_LIBRARIES) \
    llndk.libraries.txt \
    vndksp.libraries.txt

include $(BUILD_PHONY_PACKAGE)
