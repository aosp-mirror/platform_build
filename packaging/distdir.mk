#
# Copyright (C) 2018 The Android Open Source Project
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

# From the Android.mk pass:
DIST_GOAL_OUTPUT_PAIRS :=
DIST_SRC_DST_PAIRS :=
include $(KATI_PACKAGE_MK_DIR)/dist.mk

$(foreach pair,$(DIST_GOAL_OUTPUT_PAIRS), \
  $(eval goal := $(call word-colon,1,$(pair))) \
  $(eval output := $(call word-colon,2,$(pair))) \
  $(eval .PHONY: _dist_$$(goal)) \
  $(if $(call streq,$(DIST),true),\
    $(eval _dist_$$(goal): $$(DIST_DIR)/$$(output)), \
    $(eval _dist_$$(goal):)))

define copy-one-dist-file
$(2): $(1)
	@echo "Dist: $$@"
	rm -f $$@
	cp $$< $$@
endef

ifeq ($(DIST),true)
  $(foreach pair,$(DIST_SRC_DST_PAIRS), \
    $(eval src := $(call word-colon,1,$(pair))) \
    $(eval dst := $(DIST_DIR)/$(call word-colon,2,$(pair))) \
    $(eval $(call copy-one-dist-file,$(src),$(dst))))
endif

copy-one-dist-file :=
DIST_GOAL_OUTPUT_PAIRS :=
DIST_SRC_DST_PAIRS :=
