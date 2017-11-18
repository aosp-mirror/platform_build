# Copyright (C) 2017 The Android Open Source Project
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

# BOARD_VNDK_VERSION must be set to 'current' in order to generate a VNDK snapshot.
ifeq ($(BOARD_VNDK_VERSION),current)

# Returns arch-specific libclang_rt.ubsan* library name.
# Because VNDK_CORE_LIBRARIES includes all arch variants for libclang_rt.ubsan*
# libs, the arch-specific libs are selected separately.
#
# Args:
#   $(1): if not empty, evaluates for TARGET_2ND_ARCH
define clang-ubsan-vndk-core
  $(eval prefix := $(if $(1),2ND_,))
  $(addsuffix .vendor,$($(addprefix $(prefix),UBSAN_RUNTIME_LIBRARY)))
endef

# Args:
#   $(1): list of lib names without '.so' suffix (e.g., libX.vendor)
#   $(2): if not empty, evaluates for TARGET_2ND_ARCH
define paths-of-intermediates
  $(strip \
    $(foreach lib,$(1), \
      $(call append-path,$(call intermediates-dir-for,SHARED_LIBRARIES,$(lib),,,$(2)),$(lib).so)))
endef

vndk_core_libs := $(addsuffix .vendor,$(filter-out libclang_rt.ubsan%,$(VNDK_CORE_LIBRARIES)))
vndk_sp_libs := $(addsuffix .vendor,$(VNDK_SAMEPROCESS_LIBRARIES))
vndk_snapshot_dependencies := \
  $(vndk_core_libs) \
  $(vndk_sp_libs)

# If in the future libclang_rt.ubsan* is removed from the VNDK-core list,
# need to update the related logic in this file.
ifeq (,$(filter libclang_rt.ubsan%,$(VNDK_CORE_LIBRARIES)))
  $(error libclang_rt.ubsan* is no longer a VNDK-core library.)
endif

# for TARGET_ARCH
clang_ubsan_vndk_core_$(TARGET_ARCH) := $(call clang-ubsan-vndk-core)
vndk_snapshot_dependencies += \
  $(clang_ubsan_vndk_core_$(TARGET_ARCH))

ifdef TARGET_2ND_ARCH
clang_ubsan_vndk_core_$(TARGET_2ND_ARCH) := $(call clang-ubsan-vndk-core,true)
vndk_snapshot_dependencies += \
  $(clang_ubsan_vndk_core_$(TARGET_2ND_ARCH))
endif

vndk_snapshot_zip := $(PRODUCT_OUT)/android-vndk-$(TARGET_ARCH).zip
vndk_snapshot_out := $(call intermediates-dir-for,PACKAGING,vndk-snapshot)
$(vndk_snapshot_zip): PRIVATE_VNDK_SNAPSHOT_OUT := $(vndk_snapshot_out)

$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_OUT_$(TARGET_ARCH) := \
  $(vndk_snapshot_out)/arch-$(TARGET_ARCH)/shared/vndk-core
$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_INTERMEDIATES_$(TARGET_ARCH) := \
  $(call paths-of-intermediates,$(vndk_core_libs) $(clang_ubsan_vndk_core_$(TARGET_ARCH)))
$(vndk_snapshot_zip): PRIVATE_VNDK_SP_OUT_$(TARGET_ARCH) := \
  $(vndk_snapshot_out)/arch-$(TARGET_ARCH)/shared/vndk-sp
$(vndk_snapshot_zip): PRIVATE_VNDK_SP_INTERMEDIATES_$(TARGET_ARCH) := \
  $(call paths-of-intermediates,$(vndk_sp_libs))

ifdef TARGET_2ND_ARCH
$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_OUT_$(TARGET_2ND_ARCH) := \
  $(vndk_snapshot_out)/arch-$(TARGET_2ND_ARCH)/shared/vndk-core
$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_INTERMEDIATES_$(TARGET_2ND_ARCH) := \
  $(call paths-of-intermediates,$(vndk_core_libs) $(clang_ubsan_vndk_core_$(TARGET_2ND_ARCH)),true)
$(vndk_snapshot_zip): PRIVATE_VNDK_SP_OUT_$(TARGET_2ND_ARCH) := \
  $(vndk_snapshot_out)/arch-$(TARGET_2ND_ARCH)/shared/vndk-sp
$(vndk_snapshot_zip): PRIVATE_VNDK_SP_INTERMEDIATES_$(TARGET_2ND_ARCH) := \
  $(call paths-of-intermediates,$(vndk_sp_libs),true)
endif

# Args
#   $(1): destination directory
#   $(2): list of libs to copy
$(vndk_snapshot_zip): private-copy-vndk-intermediates = \
	@mkdir -p $(1); \
	$(foreach lib,$(2),cp -p $(lib) $(call append-path,$(1),$(subst .vendor,,$(notdir $(lib))));)

$(vndk_snapshot_zip): $(vndk_snapshot_dependencies) $(SOONG_ZIP)
	@echo 'Generating VNDK snapshot: $@'
	@rm -f $@
	@rm -rf $(PRIVATE_VNDK_SNAPSHOT_OUT)
	@mkdir -p $(PRIVATE_VNDK_SNAPSHOT_OUT)
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_VNDK_CORE_OUT_$(TARGET_ARCH)),$(PRIVATE_VNDK_CORE_INTERMEDIATES_$(TARGET_ARCH)))
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_VNDK_SP_OUT_$(TARGET_ARCH)),$(PRIVATE_VNDK_SP_INTERMEDIATES_$(TARGET_ARCH)))
ifdef TARGET_2ND_ARCH
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_VNDK_CORE_OUT_$(TARGET_2ND_ARCH)),$(PRIVATE_VNDK_CORE_INTERMEDIATES_$(TARGET_2ND_ARCH)))
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_VNDK_SP_OUT_$(TARGET_2ND_ARCH)),$(PRIVATE_VNDK_SP_INTERMEDIATES_$(TARGET_2ND_ARCH)))
endif
	$(hide) $(SOONG_ZIP) -o $@ -P vndk-snapshot -C $(PRIVATE_VNDK_SNAPSHOT_OUT) \
	-D $(PRIVATE_VNDK_SNAPSHOT_OUT)

.PHONY: vndk
vndk: $(vndk_snapshot_zip)

$(call dist-for-goals, vndk, $(vndk_snapshot_zip))

else # BOARD_VNDK_VERSION is NOT set to 'current'

.PHONY: vndk
vndk:
	$(call echo-error,$(current_makefile),CANNOT generate VNDK snapshot. BOARD_VNDK_VERSION must be set to 'current'.)
	exit 1

endif # BOARD_VNDK_VERSION
