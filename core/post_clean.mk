# Copyright (C) 2012 The Android Open Source Project
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

# Clean steps that need global knowledge of individual modules.
# This file must be included after all Android.mks have been loaded.

# Checks the current build configurations against the previous build,
# clean artifacts in TARGET_COMMON_OUT_ROOT if necessary.
# If a package's resource overlay has been changed, its R class needs to be
# regenerated.
previous_package_overlay_config := $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/previous_overlays.txt
current_package_overlay_config := $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/current_overlays.txt
current_all_packages_config := $(dir $(current_package_overlay_config))current_packages.txt

$(shell rm -rf $(current_package_overlay_config) \
    && mkdir -p $(dir $(current_package_overlay_config)) \
    && touch $(current_package_overlay_config))
$(shell echo '$(PACKAGES)' > $(current_all_packages_config))
$(foreach p, $(PACKAGES), $(if $(PACKAGES.$(p).RESOURCE_OVERLAYS), \
  $(shell echo '$(p)' '$(PACKAGES.$(p).RESOURCE_OVERLAYS)' >> $(current_package_overlay_config))))

ifneq (,$(wildcard $(previous_package_overlay_config)))
packages_overlay_changed := $(shell build/tools/diff_package_overlays.py \
    $(current_all_packages_config) $(current_package_overlay_config) \
    $(previous_package_overlay_config))
ifneq (,$(packages_overlay_changed))
overlay_cleanup_cmd := $(strip rm -rf $(foreach p, $(packages_overlay_changed),\
    $(TARGET_OUT_COMMON_INTERMEDIATES)/APPS/$(p)_intermediates))
$(info *** Overlay change detected, clean shared intermediate files...)
$(info *** $(overlay_cleanup_cmd))
$(shell $(overlay_cleanup_cmd))
overlay_cleanup_cmd :=
endif
packages_overlay_changed :=
endif

# Now current becomes previous.
$(shell mv -f $(current_package_overlay_config) $(previous_package_overlay_config))

previous_package_overlay_config :=
current_package_overlay_config :=
current_all_packages_config :=
