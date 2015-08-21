KATI ?= $(HOST_OUT_EXECUTABLES)/ckati

KATI_OUTPUTS := $(PRODUCT_OUT)/build.ninja $(PRODUCT_OUT)/ninja.sh
NINJA_GOALS := fastincremental generateonly droid showcommands

ANDROID_TARGETS := $(filter-out $(KATI_OUTPUTS) $(NINJA_GOALS),$(ORIGINAL_MAKECMDGOALS))

ifeq (,$(NINJA_STATUS))
NINJA_STATUS := [%p %s/%t]$(space)
endif

ifneq (,$(filter showcommands,$(ORIGINAL_MAKECMDGOALS)))
NINJA_ARGS += "-v"
PHONY: showcommands
showcommands: droid
endif

ifeq (,$(filter generateonly,$(ORIGINAL_MAKECMDGOALS)))
fastincremental droid $(ANDROID_TARGETS): ninja.intermediate
	@#empty

.INTERMEDIATE: ninja.intermediate
ninja.intermediate: $(KATI_OUTPUTS)
	@echo Starting build with ninja
	$(hide) PATH=prebuilts/ninja/$(HOST_PREBUILT_TAG)/:$$PATH NINJA_STATUS="$(NINJA_STATUS)" $(PRODUCT_OUT)/ninja.sh -C $(TOP) $(NINJA_ARGS) $(ANDROID_TARGETS)
else
generateonly droid $(ANDROID_TARGETS): $(KATI_OUTPUTS)
	@#empty
endif

ifeq (,$(filter fastincremental,$(ORIGINAL_MAKECMDGOALS)))
KATI_FORCE := FORCE
endif

$(KATI_OUTPUTS): kati.intermediate $(KATI_FORCE)

.INTERMEDIATE: kati.intermediate
kati.intermediate: $(KATI)
	@echo Running kati to generate build.ninja...
	@#TODO: use separate ninja file for mm or single target build
	$(hide) $(KATI) --ninja --ninja_dir=$(PRODUCT_OUT) --regen --ignore_dirty=$(OUT_DIR)/% --ignore_optional_include=$(OUT_DIR)/%.P --detect_android_echo --use_find_emulator $(KATI_REMOTE_NUM_JOBS_FLAG) -f build/core/main.mk $(ANDROID_TARGETS) USE_NINJA=false

KATI_CXX := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_CPPFLAGS)
KATI_LD := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_LDFLAGS)
# Build static ckati. Unfortunately Mac OS X doesn't officially support static exectuables.
ifeq ($(BUILD_OS),linux)
KATI_LD += -static
endif

KATI_INTERMEDIATES_PATH := $(HOST_OUT_INTERMEDIATES)/EXECUTABLES/ckati_intermediates
KATI_BIN_PATH := $(HOST_OUT_EXECUTABLES)
include build/kati/Makefile.ckati

.PHONY: FORCE
FORCE:
