# Copyright (C) 2020 The Android Open Source Project
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

current_makefile := $(lastword $(MAKEFILE_LIST))

# BOARD_VNDK_VERSION must be set to 'current' in order to generate a vendor snapshot.
ifeq ($(BOARD_VNDK_VERSION),current)

.PHONY: vendor-snapshot
vendor-snapshot: $(SOONG_VENDOR_SNAPSHOT_ZIP)

$(call dist-for-goals, vendor-snapshot, $(SOONG_VENDOR_SNAPSHOT_ZIP))

.PHONY: vendor-fake-snapshot
vendor-fake-snapshot: $(SOONG_VENDOR_FAKE_SNAPSHOT_ZIP)

$(call dist-for-goals, vendor-fake-snapshot, $(SOONG_VENDOR_FAKE_SNAPSHOT_ZIP):fake/$(notdir $(SOONG_VENDOR_FAKE_SNAPSHOT_ZIP)))

# Capture prebuilt vendor static libraries of hwasan variant.
# To build the hwasan variant `SANITIZE_TARGET=hwaddress` must be set.
# vendor-hwasan-snapshot goal zips hwasan static libs listed in
# PRODUCT_VSDK_HWASAN_STATIC_PATHS which has a list of pairs of
# 'module name':'source directory path'
ifeq ($(SANITIZE_TARGET),hwaddress)

vsdk_hwasan_static_zip := $(PRODUCT_OUT)/vsdk-hwasan-snapshot.zip
vsdk_hwasan_static_dir := $(PRODUCT_OUT)/vsdk-hwasan-snapshot
vsdk_hwasan_variants := \
	android \
	vendor.$(PLATFORM_VNDK_VERSION) \
	$(TARGET_ARCH) \
	$(TARGET_ARCH_VARIANT) \
	$(TARGET_CPU_VARIANT) \
	static \
	hwasan
vsdk_hwasan_variant_name := $(subst _generic_,_,$(subst $(space),_,$(vsdk_hwasan_variants)))

define get_vendor_hwasan_static_path
$(SOONG_OUT_DIR)/.intermediates/$(call word-colon,2,$(1))/$(call word-colon,1,$(1))/$(vsdk_hwasan_variant_name)/$(call word-colon,1,$(1)).a
endef

$(vsdk_hwasan_static_zip): PRIVATE_MAKEFILE := $(current_makefile)
$(vsdk_hwasan_static_zip): PRIVATE_HWASAN_DIR := $(vsdk_hwasan_static_dir)
$(vsdk_hwasan_static_zip): $(SOONG_ZIP) $(foreach p, $(PRODUCT_VSDK_HWASAN_STATIC_PATHS), $(call get_vendor_hwasan_static_path,$(p)))
	$(if $(PRODUCT_VSDK_HWASAN_STATIC_PATHS),,\
		$(call echo-error,$(PRIVATE_MAKEFILE),\
			"CANNOT generate Vendor HWASAN snapshot. PRODUCT_VSDK_HWASAN_STATIC_PATHS is not defined.") &&\
			exit 1)
	@rm -rf $(PRIVATE_HWASAN_DIR)
	@mkdir -p $(PRIVATE_HWASAN_DIR)
	$(foreach p, $(PRODUCT_VSDK_HWASAN_STATIC_PATHS), \
		cp -f $(call get_vendor_hwasan_static_path,$(p)) $(PRIVATE_HWASAN_DIR) &&) true
	$(SOONG_ZIP) -o $@ -C $(PRIVATE_HWASAN_DIR) -D $(PRIVATE_HWASAN_DIR)

.PHONY: vendor-hwasan-snapshot
vendor-hwasan-snapshot: $(vsdk_hwasan_static_zip)

$(call dist-for-goals, vendor-hwasan-snapshot, $(vsdk_hwasan_static_zip))

else # Not for the HWASAN build
.PHONY: vendor-hwasan-snapshot
vendor-hwasan-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
vendor-hwasan-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Vendor HWASAN snapshot. SANITIZE_TARGET must be set to 'hwaddress'.")
	exit 1
endif # SANITIZE_TARGET

else # BOARD_VNDK_VERSION is NOT set to 'current'

.PHONY: vendor-snapshot
vendor-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
vendor-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Vendor snapshot. BOARD_VNDK_VERSION must be set to 'current'.")
	exit 1

.PHONY: vendor-fake-snapshot
vendor-fake-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
vendor-fake-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Vendor snapshot. BOARD_VNDK_VERSION must be set to 'current'.")
	exit 1

.PHONY: vendor-hwasan-snapshot
vendor-hwasan-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
vendor-hwasan-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Vendor HWASAN snapshot. BOARD_VNDK_VERSION must be set to 'current'.")
	exit 1

endif # BOARD_VNDK_VERSION
