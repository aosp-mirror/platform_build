ifeq ($(filter address,$(SANITIZE_HOST)),)
NINJA ?= prebuilts/build-tools/$(HOST_PREBUILT_TAG)/bin/ninja
else
NINJA ?= prebuilts/build-tools/$(HOST_PREBUILT_TAG)/asan/bin/ninja
endif

KATI_OUTPUT_PATTERNS := $(OUT_DIR)/build%.ninja $(OUT_DIR)/ninja%.sh

# Modifier goals we don't need to pass to Ninja.
NINJA_EXCLUDE_GOALS := all

# A list of goals which affect parsing of makefiles and we need to pass to Kati.
PARSE_TIME_MAKE_GOALS := \
	$(PARSE_TIME_MAKE_GOALS) \
	$(dont_bother_goals) \
	all \
	brillo_tests \
	btnod \
	build-art% \
	build_kernel-nodeps \
	clean-oat% \
	continuous_instrumentation_tests \
	continuous_native_tests \
	cts \
	custom_images \
	dicttool_aosp \
	docs \
	eng \
	oem_image \
	online-system-api-sdk-docs \
	product-graph \
	samplecode \
	sdk \
	sdk_addon \
	sdk_repo \
	stnod \
	test-art% \
	user \
	userdataimage \
	userdebug

include $(wildcard vendor/*/build/ninja_config.mk)

# Any Android goals that need to be built.
ANDROID_GOALS := $(filter-out $(KATI_OUTPUT_PATTERNS),\
    $(sort $(ORIGINAL_MAKECMDGOALS) $(MAKECMDGOALS)))
# Temporary compatibility support until the build server configs are updated
ANDROID_GOALS := $(patsubst win_sdk,sdk,$(ANDROID_GOALS))
ifneq ($(HOST_OS),linux)
  ANDROID_GOALS := $(filter-out sdk,$(ANDROID_GOALS))
  ANDROID_GOALS := $(patsubst sdk_repo,sdk-repo-build-tools sdk-repo-platform-tools,$(ANDROID_GOALS))
endif
# Goals we need to pass to Ninja.
NINJA_GOALS := $(filter-out $(NINJA_EXCLUDE_GOALS), $(ANDROID_GOALS))
ifndef NINJA_GOALS
  NINJA_GOALS := droid
endif
# Goals we need to pass to Kati.
KATI_GOALS := $(filter $(PARSE_TIME_MAKE_GOALS), $(ANDROID_GOALS))
