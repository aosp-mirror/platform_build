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
_FLAG_PARTITIONS := product system vendor


# -----------------------------------------------------------------
# Aconfig Flags

# Create a summary file of build flags for each partition
# $(1): built aconfig flags file (out)
# $(2): installed aconfig flags file (out)
# $(3): the partition (in)
define generate-partition-aconfig-flag-file
$(eval $(strip $(1)): PRIVATE_OUT := $(strip $(1)))
$(eval $(strip $(1)): PRIVATE_IN := $(strip $(4)))
$(strip $(1)): $(ACONFIG) $(strip $(4))
	mkdir -p $$(dir $$(PRIVATE_OUT))
	$$(if $$(PRIVATE_IN), \
		$$(ACONFIG) dump --dedup --format protobuf --out $$(PRIVATE_OUT) \
			--filter container:$(strip $(3)) \
			$$(addprefix --cache ,$$(PRIVATE_IN)), \
		echo -n > $$(PRIVATE_OUT) \
	)
$(call copy-one-file, $(1), $(2))
endef


# Create a summary file of build flags for each partition
# $(1): built aconfig flags file (out)
# $(2): installed aconfig flags file (out)
# $(3): input aconfig files for the partition (in)
define generate-global-aconfig-flag-file
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
			$(partition), \
			$(sort \
				$(foreach m, $(call register-names-for-partition, $(partition)), \
					$(ALL_MODULES.$(m).ACONFIG_FILES) \
				) \
				$(if $(filter system, $(partition)), \
					$(foreach m, $(call register-names-for-partition, system_ext), \
						$(ALL_MODULES.$(m).ACONFIG_FILES) \
					) \
				) \
			) \
	)) \
)

# Collect the on-device flags into a single file, similar to all_aconfig_declarations.
required_aconfig_flags_files := \
		$(sort $(foreach partition, $(filter $(IMAGES_TO_BUILD), $(_FLAG_PARTITIONS)), \
			$(aconfig_flag_summaries_protobuf.$(partition)) \
		))

.PHONY: device_aconfig_declarations
device_aconfig_declarations: $(PRODUCT_OUT)/device_aconfig_declarations.pb
$(eval $(call generate-global-aconfig-flag-file, \
			$(TARGET_OUT_FLAGS)/device_aconfig_declarations.pb, \
			$(PRODUCT_OUT)/device_aconfig_declarations.pb, \
			$(sort $(required_aconfig_flags_files)) \
)) \

# Create a set of storage file for each partition
# $(1): built aconfig flags storage package map file (out)
# $(2): built aconfig flags storage flag map file (out)
# $(3): built aconfig flags storage flag val file (out)
# $(4): installed aconfig flags storage package map file (out)
# $(5): installed aconfig flags storage flag map file (out)
# $(6): installed aconfig flags storage flag value file (out)
# $(7): input aconfig files for the partition (in)
# $(8): partition name
define generate-partition-aconfig-storage-file
$(eval $(strip $(1)): PRIVATE_OUT := $(strip $(1)))
$(eval $(strip $(1)): PRIVATE_IN := $(strip $(7)))
$(strip $(1)): $(ACONFIG) $(strip $(7))
	mkdir -p $$(dir $$(PRIVATE_OUT))
	$$(if $$(PRIVATE_IN), \
		$$(ACONFIG) create-storage --container $(8) --file package_map --out $$(PRIVATE_OUT) \
			$$(addprefix --cache ,$$(PRIVATE_IN)), \
	)
	touch $$(PRIVATE_OUT)
$(eval $(strip $(2)): PRIVATE_OUT := $(strip $(2)))
$(eval $(strip $(2)): PRIVATE_IN := $(strip $(7)))
$(strip $(2)): $(ACONFIG) $(strip $(7))
	mkdir -p $$(dir $$(PRIVATE_OUT))
	$$(if $$(PRIVATE_IN), \
		$$(ACONFIG) create-storage --container $(8) --file flag_map --out $$(PRIVATE_OUT) \
			$$(addprefix --cache ,$$(PRIVATE_IN)), \
	)
	touch $$(PRIVATE_OUT)
$(eval $(strip $(3)): PRIVATE_OUT := $(strip $(3)))
$(eval $(strip $(3)): PRIVATE_IN := $(strip $(7)))
$(strip $(3)): $(ACONFIG) $(strip $(7))
	mkdir -p $$(dir $$(PRIVATE_OUT))
	$$(if $$(PRIVATE_IN), \
		$$(ACONFIG) create-storage --container $(8) --file flag_val --out $$(PRIVATE_OUT) \
		$$(addprefix --cache ,$$(PRIVATE_IN)), \
	)
	touch $$(PRIVATE_OUT)
$(call copy-one-file, $(strip $(1)), $(4))
$(call copy-one-file, $(strip $(2)), $(5))
$(call copy-one-file, $(strip $(3)), $(6))
endef

ifeq ($(RELEASE_CREATE_ACONFIG_STORAGE_FILE),true)
$(foreach partition, $(_FLAG_PARTITIONS), \
	$(eval aconfig_storage_package_map.$(partition) := $(PRODUCT_OUT)/$(partition)/etc/aconfig/package.map) \
	$(eval aconfig_storage_flag_map.$(partition) := $(PRODUCT_OUT)/$(partition)/etc/aconfig/flag.map) \
	$(eval aconfig_storage_flag_val.$(partition) := $(PRODUCT_OUT)/$(partition)/etc/aconfig/flag.val) \
	$(eval $(call generate-partition-aconfig-storage-file, \
				$(TARGET_OUT_FLAGS)/$(partition)/package.map, \
				$(TARGET_OUT_FLAGS)/$(partition)/flag.map, \
				$(TARGET_OUT_FLAGS)/$(partition)/flag.val, \
				$(aconfig_storage_package_map.$(partition)), \
				$(aconfig_storage_flag_map.$(partition)), \
				$(aconfig_storage_flag_val.$(partition)), \
				$(aconfig_flag_summaries_protobuf.$(partition)), \
				$(partition), \
	)) \
)
endif

# -----------------------------------------------------------------
# Install the ones we need for the configured product
required_flags_files := \
		$(sort $(foreach partition, $(filter $(IMAGES_TO_BUILD), $(_FLAG_PARTITIONS)), \
			$(build_flag_summaries.$(partition)) \
			$(aconfig_flag_summaries_protobuf.$(partition)) \
			$(aconfig_storage_package_map.$(partition)) \
			$(aconfig_storage_flag_map.$(partition)) \
			$(aconfig_storage_flag_val.$(partition)) \
		))

ALL_DEFAULT_INSTALLED_MODULES += $(required_flags_files)
ALL_FLAGS_FILES := $(required_flags_files)

# TODO: Remove
.PHONY: flag-files
flag-files: $(required_flags_files)


# Clean up
required_flags_files:=
required_aconfig_flags_files:=
$(foreach partition, $(_FLAG_PARTITIONS), \
	$(eval build_flag_summaries.$(partition):=) \
	$(eval aconfig_flag_summaries_protobuf.$(partition):=) \
	$(eval aconfig_storage_package_map.$(partition):=) \
	$(eval aconfig_storage_flag_map.$(partition):=) \
	$(eval aconfig_storage_flag_val.$(partition):=) \
)
