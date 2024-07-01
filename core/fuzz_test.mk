###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for fuzz tests are added.
###########################################
$(call record-module-type,FUZZ_TEST)

ifdef LOCAL_SDK_VERSION
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): NDK fuzz tests are not supported.)
endif

my_fuzzer:=libFuzzer
ifdef LOCAL_FUZZ_ENGINE
    my_fuzzer:=$(LOCAL_FUZZ_ENGINE)
else ifdef TARGET_FUZZ_ENGINE
    my_fuzzer:=$(TARGET_FUZZ_ENGINE)
endif

LOCAL_SANITIZE += fuzzer

ifeq ($(my_fuzzer),libFuzzer)
LOCAL_STATIC_LIBRARIES += libFuzzer
else
$(call pretty-error, Unknown fuzz engine $(my_fuzzer))
endif

ifdef LOCAL_MODULE_PATH
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH when building test $(LOCAL_MODULE))
endif

ifdef LOCAL_MODULE_PATH_32
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH_32 when building test $(LOCAL_MODULE))
endif

ifdef LOCAL_MODULE_PATH_64
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH_64 when building test $(LOCAL_MODULE))
endif

LOCAL_MODULE_PATH_64 := $(TARGET_OUT_DATA_NATIVE_TESTS)/fuzzers/$(my_fuzzer)/$(LOCAL_MODULE)
LOCAL_MODULE_PATH_32 := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_NATIVE_TESTS)/fuzzers/$(my_fuzzer)/$(LOCAL_MODULE)

ifndef LOCAL_STRIP_MODULE
LOCAL_STRIP_MODULE := keep_symbols
endif

include $(BUILD_EXECUTABLE)

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=FUZZ_TEST))