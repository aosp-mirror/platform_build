# Copyright (C) 2023 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This file is included by build/make/core/Makefile, and contains the logic for
# the combined flags files.
#

# TODO: Should we do all of the images in $(IMAGES_TO_BUILD)?
_FLAG_PARTITIONS := product system system_ext vendor


# -----------------------------------------------------------------
# Release Config Flags

# Create a summary file of build flags for each partition
# $(1): built build flags json file
# $(2): installed build flags json file
# $(3): flag names
define generate-partition-build-flag-file
$(eval $(strip $(1)): PRIVATE_OUT := $(strip $(1)))
$(eval $(strip $(1)): PRIVATE_FLAG_NAMES := $(strip $(3)))
$(strip $(1)):
	mkdir -p $$(dir $$(PRIVATE_OUT))
	echo '{' > $$(PRIVATE_OUT)
	echo '"flags": [' >> $$(PRIVATE_OUT)
	$$(foreach flag, $$(PRIVATE_FLAG_NAMES), \
		( \
			printf '  { "name": "%s", "value": "%s", ' \
					'$$(flag)' \
					'$$(_ALL_RELEASE_FLAGS.$$(flag).VALUE)' \
					; \
			printf '"set": "%s", "default": "%s", "declared": "%s" }' \
					'$$(_ALL_RELEASE_FLAGS.$$(flag).SET_IN)' \
					'$$(_ALL_RELEASE_FLAGS.$$(flag).DEFAULT)' \
					'$$(_ALL_RELEASE_FLAGS.$$(flag).DECLARED_IN)' \
					; \
			printf '$$(if $$(filter $$(lastword $$(PRIVATE_FLAG_NAMES)),$$(flag)),,$$(comma))\n' ; \
		) >> $$(PRIVATE_OUT) ; \
	)
	echo "]" >> $$(PRIVATE_OUT)
	echo "}" >> $$(PRIVATE_OUT)
$(call copy-one-file, $(1), $(2))
endef

$(foreach partition, $(_FLAG_PARTITIONS), \
	$(eval build_flag_summaries.$(partition) := $(PRODUCT_OUT)/$(partition)/etc/build_flags.json) \
	$(eval $(call generate-partition-build-flag-file, \
				$(TARGET_OUT_FLAGS)/$(partition)/build_flags.json, \
				$(build_flag_summaries.$(partition)), \
				$(_ALL_RELEASE_FLAGS.PARTITIONS.$(partition)) \
			) \
	) \
)


# -----------------------------------------------------------------
# Aconfig Flags

# Create a summary file of build flags for each partition
# $(1): built aconfig flags file (out)
# $(2): installed aconfig flags file (out)
# $(3): input aconfig files for the partition (in)
define generate-partition-aconfig-flag-file
$(eval $(strip $(1)): PRIVATE_OUT := $(strip $(1)))
$(eval $(strip $(1)): PRIVATE_IN := $(strip $(3)))
$(strip $(1)): $(ACONFIG) $(strip $(3))
	mkdir -p $$(dir $$(PRIVATE_OUT))
	$$(if $$(PRIVATE_IN), \
		$$(ACONFIG) dump --dedup --format protobuf --out $$(PRIVATE_OUT) \
			$$(addprefix --cache ,$$(PRIVATE_IN)), \
		echo -n > $$(PRIVATE_OUT) \
	)
$(call copy-one-file, $(1), $(2))
endef


$(foreach partition, $(_FLAG_PARTITIONS), \
	$(eval aconfig_flag_summaries_protobuf.$(partition) := $(PRODUCT_OUT)/$(partition)/etc/aconfig_flags.pb) \
	$(eval $(call generate-partition-aconfig-flag-file, \
				$(TARGET_OUT_FLAGS)/$(partition)/aconfig_flags.pb, \
				$(aconfig_flag_summaries_protobuf.$(partition)), \
				$(sort $(foreach m,$(call register-names-for-partition, $(partition)), \
					$(ALL_MODULES.$(m).ACONFIG_FILES) \
				)), \
	)) \
)


# -----------------------------------------------------------------
# Install the ones we need for the configured product
required_flags_files := \
		$(sort $(foreach partition, $(filter $(IMAGES_TO_BUILD), $(_FLAG_PARTITIONS)), \
			$(build_flag_summaries.$(partition)) \
			$(aconfig_flag_summaries_protobuf.$(partition)) \
		))

ALL_DEFAULT_INSTALLED_MODULES += $(required_flags_files)
ALL_FLAGS_FILES := $(required_flags_files)

# TODO: Remove
.PHONY: flag-files
flag-files: $(required_flags_files)


# Clean up
required_flags_files:=
$(foreach partition, $(_FLAG_PARTITIONS), \
	$(eval build_flag_summaries.$(partition):=) \
	$(eval aconfig_flag_summaries_protobuf.$(partition):=) \
)

