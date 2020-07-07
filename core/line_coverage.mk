# -----------------------------------------------------------------
# Make target for line coverage. This target generates a zip file
# called `line_coverage_profiles.zip` that contains a large set of
# zip files one for each fuzz target/critical component. Each zip
# file contains a set of profile files (*.gcno) that we will use
# to generate line coverage reports. Furthermore, target compiles
# all fuzz targets with line coverage instrumentation enabled and
# packs them into another zip file called `line_coverage_profiles.zip`.
#
# To run the make target set the coverage related envvars first:
# 	NATIVE_COVERAGE=true NATIVE_COVERAGE_PATHS=* make haiku-line-coverage
# -----------------------------------------------------------------

# TODO(b/148306195): Due this issue some fuzz targets cannot be built with
# line coverage instrumentation. For now we just blacklist them.
blacklisted_fuzz_targets := libneuralnetworks_fuzzer

fuzz_targets := $(ALL_FUZZ_TARGETS)
fuzz_targets := $(filter-out $(blacklisted_fuzz_targets),$(fuzz_targets))


# Android components that considered critical.
# Please note that adding/Removing critical components is very rare.
critical_components_static := \
	lib-bt-packets \
	libbt-stack \
	libffi \
	libhevcdec \
	libhevcenc \
	libmpeg2dec \
	libosi \
	libpdx \
	libselinux \
	libvold \
	libyuv

# Format is <module_name> or <module_name>:<apex_name>
critical_components_shared := \
	libaudioprocessing \
	libbinder \
	libbluetooth_gd \
	libbrillo \
	libcameraservice \
	libcurl \
	libhardware \
	libinputflinger \
	libopus \
	libstagefright \
	libunwind \
	libvixl:com.android.art.debug

# Use the intermediates directory to avoid installing libraries to the device.
intermediates := $(call intermediates-dir-for,PACKAGING,haiku-line-coverage)


# We want the profile files for all fuzz targets + critical components.
line_coverage_profiles := $(intermediates)/line_coverage_profiles.zip

critical_components_static_inputs := $(foreach lib,$(critical_components_static), \
	$(call intermediates-dir-for,STATIC_LIBRARIES,$(lib))/$(lib).a)

critical_components_shared_inputs := $(foreach lib,$(critical_components_shared), \
	$(eval filename := $(call word-colon,1,$(lib))) \
	$(eval modulename := $(subst :,.,$(lib))) \
	$(call intermediates-dir-for,SHARED_LIBRARIES,$(modulename))/$(filename).so)

fuzz_target_inputs := $(foreach fuzz,$(fuzz_targets), \
	$(call intermediates-dir-for,EXECUTABLES,$(fuzz))/$(fuzz))

# When coverage is enabled (NATIVE_COVERAGE is set), make creates
# a "coverage" directory and stores all profile (*.gcno) files in inside.
# We need everything that is stored inside this directory.
$(line_coverage_profiles): $(fuzz_target_inputs)
$(line_coverage_profiles): $(critical_components_static_inputs)
$(line_coverage_profiles): $(critical_components_shared_inputs)
$(line_coverage_profiles): $(SOONG_ZIP)
	$(SOONG_ZIP) -o $@ -D $(PRODUCT_OUT)/coverage


# Zip all fuzz targets compiled with line coverage.
line_coverage_fuzz_targets := $(intermediates)/line_coverage_fuzz_targets.zip

$(line_coverage_fuzz_targets): $(fuzz_target_inputs)
$(line_coverage_fuzz_targets): $(SOONG_ZIP)
	$(SOONG_ZIP) -o $@ -j $(addprefix -f ,$(fuzz_target_inputs))


.PHONY: haiku-line-coverage
haiku-line-coverage: $(line_coverage_profiles) $(line_coverage_fuzz_targets)
$(call dist-for-goals, haiku-line-coverage, \
	$(line_coverage_profiles):line_coverage_profiles.zip \
	$(line_coverage_fuzz_targets):line_coverage_fuzz_targets.zip)

line_coverage_profiles :=
line_coverage_fuzz_targets :=
