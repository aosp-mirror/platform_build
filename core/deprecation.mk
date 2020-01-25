# These module types can still be used without warnings or errors.
AVAILABLE_BUILD_MODULE_TYPES :=$= \
  BUILD_COPY_HEADERS \
  BUILD_EXECUTABLE \
  BUILD_FUZZ_TEST \
  BUILD_HEADER_LIBRARY \
  BUILD_HOST_DALVIK_JAVA_LIBRARY \
  BUILD_HOST_DALVIK_STATIC_JAVA_LIBRARY \
  BUILD_HOST_EXECUTABLE \
  BUILD_HOST_JAVA_LIBRARY \
  BUILD_HOST_PREBUILT \
  BUILD_JAVA_LIBRARY \
  BUILD_MULTI_PREBUILT \
  BUILD_NATIVE_TEST \
  BUILD_NOTICE_FILE \
  BUILD_PACKAGE \
  BUILD_PHONY_PACKAGE \
  BUILD_PREBUILT \
  BUILD_RRO_PACKAGE \
  BUILD_SHARED_LIBRARY \
  BUILD_STATIC_JAVA_LIBRARY \
  BUILD_STATIC_LIBRARY \

# These are BUILD_* variables that will throw a warning when used. This is
# generally a temporary state until all the devices are marked with the
# relevant BUILD_BROKEN_USES_BUILD_* variables, then these would move to
# DEFAULT_ERROR_BUILD_MODULE_TYPES.
DEFAULT_WARNING_BUILD_MODULE_TYPES :=$= \
  BUILD_HOST_SHARED_LIBRARY \
  BUILD_HOST_STATIC_LIBRARY \

# These are BUILD_* variables that are errors to reference, but you can set
# BUILD_BROKEN_USES_BUILD_* in your BoardConfig.mk in order to turn them back
# to warnings.
DEFAULT_ERROR_BUILD_MODULE_TYPES :=$= \
  BUILD_AUX_EXECUTABLE \
  BUILD_AUX_STATIC_LIBRARY \
  BUILD_HOST_FUZZ_TEST \
  BUILD_HOST_NATIVE_TEST \
  BUILD_HOST_STATIC_TEST_LIBRARY \
  BUILD_HOST_TEST_CONFIG \
  BUILD_NATIVE_BENCHMARK \
  BUILD_STATIC_TEST_LIBRARY \
  BUILD_TARGET_TEST_CONFIG \

# These are BUILD_* variables that are always errors to reference.
# Setting the BUILD_BROKEN_USES_BUILD_* variables is also an error.
OBSOLETE_BUILD_MODULE_TYPES :=$= \
  BUILD_HOST_SHARED_TEST_LIBRARY \
  BUILD_SHARED_TEST_LIBRARY \

$(foreach m,$(OBSOLETE_BUILD_MODULE_TYPES),\
  $(KATI_obsolete_var $(m),Please convert to Soong) \
  $(KATI_obsolete_var BUILD_BROKEN_USES_$(m),Please convert to Soong))

