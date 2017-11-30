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
$(strip \
  $(eval prefix := $(if $(1),2ND_,)) \
  $(addsuffix .vendor,$($(addprefix $(prefix),UBSAN_RUNTIME_LIBRARY))) \
)
endef

# Returns list of file paths of the intermediate objs
#
# Args:
#   $(1): list of obj names (e.g., libfoo.vendor, ld.config.txt, ...)
#   $(2): target class (e.g., SHARED_LIBRARIES, STATIC_LIBRARIES, ETC)
#   $(3): if not empty, evaluates for TARGET_2ND_ARCH
define paths-of-intermediates
$(strip \
  $(foreach obj,$(1), \
    $(eval file_name := $(if $(filter SHARED_LIBRARIES,$(2)),$(patsubst %.so,%,$(obj)).so,$(obj))) \
    $(eval dir := $(call intermediates-dir-for,$(2),$(obj),,,$(3))) \
    $(call append-path,$(dir),$(file_name)) \
  ) \
)
endef

# If in the future libclang_rt.ubsan* is removed from the VNDK-core list,
# need to update the related logic in this file.
ifeq (,$(filter libclang_rt.ubsan%,$(VNDK_CORE_LIBRARIES)))
  $(warning libclang_rt.ubsan* is no longer a VNDK-core library. Please update this file.)
  vndk_core_libs := $(addsuffix .vendor,$(VNDK_CORE_LIBRARIES))
else
  vndk_core_libs := $(addsuffix .vendor,$(filter-out libclang_rt.ubsan%,$(VNDK_CORE_LIBRARIES)))

  # for TARGET_ARCH
  vndk_core_libs += $(call clang-ubsan-vndk-core)

  # TODO(b/69834489): Package additional arch variants
  # ifdef TARGET_2ND_ARCH
  #   vndk_core_libs += $(call clang-ubsan-vndk-core,true)
  # endif
endif

vndk_sp_libs := $(addsuffix .vendor,$(VNDK_SAMEPROCESS_LIBRARIES))
vndk_private_libs := $(addsuffix .vendor,$(VNDK_PRIVATE_LIBRARIES))

vndk_snapshot_libs := \
  $(vndk_core_libs) \
  $(vndk_sp_libs)

vndk_prebuilt_txts := \
  ld.config.txt \
  vndksp.libraries.txt \
  llndk.libraries.txt

vndk_snapshot_top := $(call intermediates-dir-for,PACKAGING,vndk-snapshot)
vndk_snapshot_out := $(vndk_snapshot_top)/vndk-snapshot
vndk_snapshot_configs_out := $(vndk_snapshot_top)/configs

#######################################
# vndkcore.libraries.txt
vndkcore.libraries.txt := $(vndk_snapshot_configs_out)/vndkcore.libraries.txt
$(vndkcore.libraries.txt): $(vndk_core_libs)
	@echo 'Generating: $@'
	@rm -f $@
	@mkdir -p $(dir $@)
	$(hide) echo -n > $@
	$(hide) $(foreach lib,$^,echo $(patsubst %.vendor,%,$(lib)).so >> $@;)


#######################################
# vndkprivate.libraries.txt
vndkprivate.libraries.txt := $(vndk_snapshot_configs_out)/vndkprivate.libraries.txt
$(vndkprivate.libraries.txt): $(vndk_private_libs)
	@echo 'Generating: $@'
	@rm -f $@
	@mkdir -p $(dir $@)
	$(hide) echo -n > $@
	$(hide) $(foreach lib,$^,echo $(patsubst %.vendor,%,$(lib)).so >> $@;)


vndk_snapshot_configs := \
  $(vndkcore.libraries.txt) \
  $(vndkprivate.libraries.txt)

#######################################
# vndk_snapshot_zip
vndk_snapshot_arch := $(vndk_snapshot_out)/arch-$(TARGET_ARCH)-$(TARGET_ARCH_VARIANT)
vndk_snapshot_zip := $(PRODUCT_OUT)/android-vndk-$(TARGET_ARCH).zip

$(vndk_snapshot_zip): PRIVATE_VNDK_SNAPSHOT_OUT := $(vndk_snapshot_out)

$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_OUT := $(vndk_snapshot_arch)/shared/vndk-core
$(vndk_snapshot_zip): PRIVATE_VNDK_CORE_INTERMEDIATES := \
  $(call paths-of-intermediates,$(vndk_core_libs),SHARED_LIBRARIES)

$(vndk_snapshot_zip): PRIVATE_VNDK_SP_OUT := $(vndk_snapshot_arch)/shared/vndk-sp
$(vndk_snapshot_zip): PRIVATE_VNDK_SP_INTERMEDIATES := \
  $(call paths-of-intermediates,$(vndk_sp_libs),SHARED_LIBRARIES)

$(vndk_snapshot_zip): PRIVATE_CONFIGS_OUT := $(vndk_snapshot_arch)/configs
$(vndk_snapshot_zip): PRIVATE_CONFIGS_INTERMEDIATES := \
  $(call paths-of-intermediates,$(vndk_prebuilt_txts),ETC) \
  $(vndk_snapshot_configs)

# TODO(b/69834489): Package additional arch variants
# ifdef TARGET_2ND_ARCH
# vndk_snapshot_arch_2ND := $(vndk_snapshot_out)/arch-$(TARGET_2ND_ARCH)-$(TARGET_2ND_ARCH_VARIANT)
# $(vndk_snapshot_zip): PRIVATE_VNDK_CORE_OUT_2ND := $(vndk_snapshot_arch_2ND)/shared/vndk-core
# $(vndk_snapshot_zip): PRIVATE_VNDK_CORE_INTERMEDIATES_2ND := \
#   $(call paths-of-intermediates,$(vndk_core_libs),SHARED_LIBRARIES,true)
# $(vndk_snapshot_zip): PRIVATE_VNDK_SP_OUT_2ND := $(vndk_snapshot_arch_2ND)/shared/vndk-sp
# $(vndk_snapshot_zip): PRIVATE_VNDK_SP_INTERMEDIATES_2ND := \
#   $(call paths-of-intermediates,$(vndk_sp_libs),SHARED_LIBRARIES,true)
# endif

# Args
#   $(1): destination directory
#   $(2): list of files to copy
$(vndk_snapshot_zip): private-copy-vndk-intermediates = \
  $(if $(2),$(strip \
    @mkdir -p $(1); \
    $(foreach file,$(2), \
      if [ -e $(file) ]; then \
        cp -p $(file) $(call append-path,$(1),$(subst .vendor,,$(notdir $(file)))); \
      fi; \
    ) \
  ))

vndk_snapshot_dependencies := \
  $(vndk_snapshot_libs) \
  $(vndk_prebuilt_txts) \
  $(vndk_snapshot_configs)

$(vndk_snapshot_zip): $(vndk_snapshot_dependencies) $(SOONG_ZIP)
	@echo 'Generating VNDK snapshot: $@'
	@rm -f $@
	@rm -rf $(PRIVATE_VNDK_SNAPSHOT_OUT)
	@mkdir -p $(PRIVATE_VNDK_SNAPSHOT_OUT)
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_VNDK_CORE_OUT),$(PRIVATE_VNDK_CORE_INTERMEDIATES))
	$(call private-copy-vndk-intermediates, \
	 	$(PRIVATE_VNDK_SP_OUT),$(PRIVATE_VNDK_SP_INTERMEDIATES))
	$(call private-copy-vndk-intermediates, \
		$(PRIVATE_CONFIGS_OUT),$(PRIVATE_CONFIGS_INTERMEDIATES))
# TODO(b/69834489): Package additional arch variants
# ifdef TARGET_2ND_ARCH
# 	$(call private-copy-vndk-intermediates, \
# 		$(PRIVATE_VNDK_CORE_OUT_2ND),$(PRIVATE_VNDK_CORE_INTERMEDIATES_2ND))
# 	$(call private-copy-vndk-intermediates, \
# 		$(PRIVATE_VNDK_SP_OUT_2ND),$(PRIVATE_VNDK_SP_INTERMEDIATES_2ND))
# endif
	$(hide) $(SOONG_ZIP) -o $@ -P android-vndk-snapshot -C $(PRIVATE_VNDK_SNAPSHOT_OUT) \
	-D $(PRIVATE_VNDK_SNAPSHOT_OUT)

.PHONY: vndk
vndk: $(vndk_snapshot_zip)

$(call dist-for-goals, vndk, $(vndk_snapshot_zip))

# clear global vars
clang-ubsan-vndk-core :=
paths-of-intermediates :=
vndk_core_libs :=
vndk_sp_libs :=
vndk_snapshot_libs :=
vndk_prebuilt_txts :=
vndk_snapshot_configs :=
vndk_snapshot_top :=
vndk_snapshot_out :=
vndk_snapshot_configs_out :=
vndk_snapshot_arch :=
vndk_snapshot_dependencies :=
# TODO(b/69834489): Package additional arch variants
# ifdef TARGET_2ND_ARCH
# vndk_snapshot_arch_2ND :=
# endif

else # BOARD_VNDK_VERSION is NOT set to 'current'

.PHONY: vndk
vndk:
	$(call echo-error,$(current_makefile),CANNOT generate VNDK snapshot. BOARD_VNDK_VERSION must be set to 'current'.)
	exit 1

endif # BOARD_VNDK_VERSION
