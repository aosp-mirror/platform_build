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


LOCAL_CFLAGS += -fsanitize-coverage=trace-pc-guard,indirect-calls,trace-cmp

ifeq ($(my_fuzzer),libFuzzer)
LOCAL_STATIC_LIBRARIES += libFuzzer
else ifeq ($(my_fuzzer),honggfuzz)
LOCAL_STATIC_LIBRARIES += honggfuzz_libhfuzz
LOCAL_REQUIRED_MODULES += honggfuzz
LOCAL_LDFLAGS += \
        "-Wl,--wrap=strcmp" \
        "-Wl,--wrap=strcasecmp" \
        "-Wl,--wrap=strncmp" \
        "-Wl,--wrap=strncasecmp" \
        "-Wl,--wrap=strstr" \
        "-Wl,--wrap=strcasestr" \
        "-Wl,--wrap=memcmp" \
        "-Wl,--wrap=bcmp" \
        "-Wl,--wrap=memmem" \
        "-Wl,--wrap=ap_cstr_casecmp" \
        "-Wl,--wrap=ap_cstr_casecmpn" \
        "-Wl,--wrap=ap_strcasestr" \
        "-Wl,--wrap=apr_cstr_casecmp" \
        "-Wl,--wrap=apr_cstr_casecmpn" \
        "-Wl,--wrap=CRYPTO_memcmp" \
        "-Wl,--wrap=OPENSSL_memcmp" \
        "-Wl,--wrap=OPENSSL_strcasecmp" \
        "-Wl,--wrap=OPENSSL_strncasecmp" \
        "-Wl,--wrap=xmlStrncmp" \
        "-Wl,--wrap=xmlStrcmp" \
        "-Wl,--wrap=xmlStrEqual" \
        "-Wl,--wrap=xmlStrcasecmp" \
        "-Wl,--wrap=xmlStrncasecmp" \
        "-Wl,--wrap=xmlStrstr" \
        "-Wl,--wrap=xmlStrcasestr"
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

LOCAL_MODULE_PATH_64 := $(TARGET_OUT_DATA_NATIVE_TESTS)/fuzzers/$(LOCAL_MODULE)
LOCAL_MODULE_PATH_32 := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_NATIVE_TESTS)/fuzzers/$(LOCAL_MODULE)

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

ifndef LOCAL_STRIP_MODULE
LOCAL_STRIP_MODULE := keep_symbols
endif

include $(BUILD_EXECUTABLE)
