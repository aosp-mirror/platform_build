ifeq ($(filter address,$(SANITIZE_HOST)),)
NINJA ?= prebuilts/build-tools/$(HOST_PREBUILT_TAG)/bin/ninja
else
NINJA ?= prebuilts/build-tools/$(HOST_PREBUILT_TAG)/asan/bin/ninja
endif

KATI_OUTPUT_PATTERNS := $(OUT_DIR)/build%.ninja $(OUT_DIR)/ninja%.sh

# Modifier goals we don't need to pass to Ninja.
NINJA_EXCLUDE_GOALS := all APP-% PRODUCT-%

# A list of goals which affect parsing of makefiles and we need to pass to Kati.
PARSE_TIME_MAKE_GOALS := \
	$(PARSE_TIME_MAKE_GOALS) \
	$(dont_bother_goals) \
	all \
	ECLIPSE-% \
	AUX-% \
	brillo_tests \
	btnod \
	build-art% \
	build_kernel-nodeps \
	clean-oat% \
	continuous_instrumentation_tests \
	continuous_native_tests \
	cts \
	custom_images \
	deps-license \
	dicttool_aosp \
	dump-products \
	eng \
	fusion \
	oem_image \
	online-system-api-sdk-docs \
	pdk \
	platform \
	platform-java \
	product-graph \
	samplecode \
	sdk \
	sdk_addon \
	sdk_repo \
	snod \
	stnod \
	systemimage-nodeps \
	target-files-package \
	test-art% \
	user \
	userdataimage \
	userdebug \
	vts \
	win_sdk \
	winsdk-tools

include $(wildcard vendor/*/build/ninja_config.mk)

# Any Android goals that need to be built.
ANDROID_GOALS := $(filter-out $(KATI_OUTPUT_PATTERNS) $(CKATI) $(MAKEPARALLEL),\
    $(sort $(ORIGINAL_MAKECMDGOALS) $(MAKECMDGOALS)))
# Goals we need to pass to Ninja.
NINJA_GOALS := $(filter-out $(NINJA_EXCLUDE_GOALS), $(ANDROID_GOALS))
ifndef NINJA_GOALS
  NINJA_GOALS := droid
endif
# Goals we need to pass to Kati.
KATI_GOALS := $(filter $(PARSE_TIME_MAKE_GOALS), $(ANDROID_GOALS))
