NINJA ?= prebuilts/build-tools/$(HOST_PREBUILT_TAG)/bin/ninja

include $(BUILD_SYSTEM)/soong.mk

KATI_OUTPUT_PATTERNS := $(OUT_DIR)/build%.ninja $(OUT_DIR)/ninja%.sh

# Modifier goals we don't need to pass to Ninja.
NINJA_EXCLUDE_GOALS := showcommands all dist
.PHONY : $(NINJA_EXCLUDE_GOALS)

# A list of goals which affect parsing of makefiles and we need to pass to Kati.
PARSE_TIME_MAKE_GOALS := \
	$(PARSE_TIME_MAKE_GOALS) \
	$(dont_bother_goals) \
	all \
	APP-% \
	DUMP_% \
	ECLIPSE-% \
	PRODUCT-% \
	AUX-% \
	boottarball-nodeps \
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
	dist \
	dump-products \
	dumpvar-% \
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
	systemtarball-nodeps \
	target-files-package \
	test-art% \
	user \
	userdataimage \
	userdebug \
	valgrind-test-art% \
	win_sdk \
	winsdk-tools

-include vendor/google/build/ninja_config.mk

# Any Android goals that need to be built.
ANDROID_GOALS := $(filter-out $(KATI_OUTPUT_PATTERNS) $(CKATI) $(MAKEPARALLEL),\
    $(sort $(ORIGINAL_MAKECMDGOALS) $(MAKECMDGOALS)))
# Goals we need to pass to Ninja.
NINJA_GOALS := $(filter-out $(NINJA_EXCLUDE_GOALS), $(ANDROID_GOALS))
# Goals we need to pass to Kati.
KATI_GOALS := $(filter $(PARSE_TIME_MAKE_GOALS),  $(ANDROID_GOALS))

define replace_space_and_slash
$(subst /,_,$(subst $(space),_,$(sort $1)))
endef

KATI_NINJA_SUFFIX := -$(TARGET_PRODUCT)
ifneq ($(KATI_GOALS),)
KATI_NINJA_SUFFIX := $(KATI_NINJA_SUFFIX)-$(call replace_space_and_slash,$(KATI_GOALS))
endif
ifneq ($(ONE_SHOT_MAKEFILE),)
KATI_NINJA_SUFFIX := $(KATI_NINJA_SUFFIX)-mmm-$(call replace_space_and_slash,$(ONE_SHOT_MAKEFILE))
endif

my_checksum_suffix :=
my_ninja_suffix_too_long := $(filter 1, $(shell v='$(KATI_NINJA_SUFFIX)' && echo $$(($${$(pound)v} > 64))))
ifneq ($(my_ninja_suffix_too_long),)
# Replace the suffix with a checksum if it gets too long.
my_checksum_suffix := $(KATI_NINJA_SUFFIX)
KATI_NINJA_SUFFIX := -$(word 1, $(shell echo $(my_checksum_suffix) | $(MD5SUM)))
endif

KATI_BUILD_NINJA := $(OUT_DIR)/build$(KATI_NINJA_SUFFIX).ninja
KATI_ENV_SH := $(OUT_DIR)/env$(KATI_NINJA_SUFFIX).sh

# Write out a file mapping checksum to the real suffix.
ifneq ($(my_checksum_suffix),)
my_ninja_suffix_file := $(basename $(KATI_BUILD_NINJA)).suf
$(shell mkdir -p $(dir $(my_ninja_suffix_file)) && \
    echo $(my_checksum_suffix) > $(my_ninja_suffix_file))
endif

ifeq (,$(NINJA_STATUS))
NINJA_STATUS := [%p %f/%t]$(space)
endif

NINJA_EXTRA_ARGS :=

ifneq (,$(filter showcommands,$(ORIGINAL_MAKECMDGOALS)))
NINJA_EXTRA_ARGS += "-v"
endif

# Make multiple rules to generate the same target an error instead of
# proceeding with undefined behavior.
NINJA_EXTRA_ARGS += -w dupbuild=err

ifdef USE_GOMA
KATI_MAKEPARALLEL := $(MAKEPARALLEL)
# Ninja runs remote jobs (i.e., commands which contain gomacc) with
# this parallelism. Note the parallelism of all other jobs is still
# limited by the -j flag passed to GNU make.
NINJA_REMOTE_NUM_JOBS ?= 500
NINJA_EXTRA_ARGS += -j$(NINJA_REMOTE_NUM_JOBS)
else
NINJA_MAKEPARALLEL := $(MAKEPARALLEL) --ninja
endif

NINJA_ARGS += $(NINJA_EXTRA_ARGS)

COMBINED_BUILD_NINJA := $(OUT_DIR)/combined$(KATI_NINJA_SUFFIX).ninja

$(COMBINED_BUILD_NINJA): $(KATI_BUILD_NINJA)
	$(hide) echo "builddir = $(OUT_DIR)" > $(COMBINED_BUILD_NINJA)
	$(hide) echo "subninja $(SOONG_BUILD_NINJA)" >> $(COMBINED_BUILD_NINJA)
	$(hide) echo "subninja $(KATI_BUILD_NINJA)" >> $(COMBINED_BUILD_NINJA)

$(sort $(DEFAULT_GOAL) $(ANDROID_GOALS)) : ninja_wrapper
	@#empty

.PHONY: ninja_wrapper
ninja_wrapper: $(COMBINED_BUILD_NINJA) $(MAKEPARALLEL)
	@echo Starting build with ninja
	+$(hide) export NINJA_STATUS="$(NINJA_STATUS)" && source $(KATI_ENV_SH) && $(NINJA_MAKEPARALLEL) $(NINJA) -d keepdepfile $(NINJA_GOALS) -C $(TOP) -f $(COMBINED_BUILD_NINJA) $(NINJA_ARGS)

# Dummy Android.mk and CleanSpec.mk files so that kati won't recurse into the
# out directory
DUMMY_OUT_MKS := $(OUT_DIR)/Android.mk $(OUT_DIR)/CleanSpec.mk
$(DUMMY_OUT_MKS):
	@mkdir -p $(dir $@)
	$(hide) echo '# This file prevents findleaves.py from traversing this directory further' >$@

KATI_FIND_EMULATOR := --use_find_emulator
ifeq ($(KATI_EMULATE_FIND),false)
  KATI_FIND_EMULATOR :=
endif
$(KATI_BUILD_NINJA): $(CKATI) $(MAKEPARALLEL) $(DUMMY_OUT_MKS) run_soong FORCE
	@echo Running kati to generate build$(KATI_NINJA_SUFFIX).ninja...
	+$(hide) $(KATI_MAKEPARALLEL) $(CKATI) --ninja --ninja_dir=$(OUT_DIR) --ninja_suffix=$(KATI_NINJA_SUFFIX) --regen --ignore_dirty=$(OUT_DIR)/% --no_ignore_dirty=$(SOONG_OUT_DIR)/%.mk --ignore_optional_include=$(OUT_DIR)/%.P --detect_android_echo $(KATI_FIND_EMULATOR) -f build/core/main.mk $(KATI_GOALS) --gen_all_targets BUILDING_WITH_NINJA=true SOONG_ANDROID_MK=$(SOONG_ANDROID_MK) SOONG_MAKEVARS_MK=$(SOONG_MAKEVARS_MK)

.PHONY: FORCE
FORCE:
