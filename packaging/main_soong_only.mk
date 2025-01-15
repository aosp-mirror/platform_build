# Copyright (C) 2025 The Android Open Source Project
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

ifndef KATI
$(error Only Kati is supported.)
endif

$(info [1/4] initializing packaging system ...)

.KATI_READONLY := KATI_PACKAGE_MK_DIR

include build/make/common/core.mk
include build/make/common/strings.mk

# Define well-known goals and their dependency graph that they've
# traditionally had in make builds. Also it's important to define
# droid first so that it's built by default.

.PHONY: droid
droid: droid_targets

.PHONY: droid_targets
droid_targets: droidcore dist_files

.PHONY: dist_files
dist_files:

.PHONY: droidcore
droidcore: droidcore-unbundled

.PHONY: droidcore-unbundled
droidcore-unbundled:

$(info [2/4] including distdir.mk ...)

include build/make/packaging/distdir.mk

$(info [3/4] defining phony modules ...)

include $(OUT_DIR)/soong/soong_phony_targets.mk

goals := $(sort $(foreach pair,$(DIST_GOAL_OUTPUT_PAIRS),$(call word-colon,1,$(pair))))
$(foreach goal,$(goals), \
  $(eval .PHONY: $$(goal)) \
  $(eval $$(goal):) \
  $(if $(call streq,$(DIST),true),\
    $(eval $$(goal): _dist_$$(goal))))

$(info [4/4] writing packaging rules ...)
