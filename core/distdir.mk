#
# Copyright (C) 2007 The Android Open Source Project
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

# When specifying "dist", the user has asked that we copy the important
# files from this build into DIST_DIR.

# list of all goals that depend on any dist files
_all_dist_goals :=
# pairs of goal:distfile
_all_dist_goal_output_pairs :=
# pairs of srcfile:distfile
_all_dist_src_dst_pairs :=

# Other parts of the system should use this function to associate
# certain files with certain goals.  When those goals are built
# and "dist" is specified, the marked files will be copied to DIST_DIR.
#
# $(1): a list of goals  (e.g. droid, sdk, ndk). These must be PHONY
# $(2): the dist files to add to those goals.  If the file contains ':',
#       the text following the colon is the name that the file is copied
#       to under the dist directory.  Subdirs are ok, and will be created
#       at copy time if necessary.
define dist-for-goals
$(if $(strip $(2)), \
  $(eval _all_dist_goals += $$(1))) \
$(foreach file,$(2), \
  $(eval src := $(call word-colon,1,$(file))) \
  $(eval dst := $(call word-colon,2,$(file))) \
  $(if $(dst),,$(eval dst := $$(notdir $$(src)))) \
  $(eval _all_dist_src_dst_pairs += $$(src):$$(dst)) \
  $(foreach goal,$(1), \
    $(eval _all_dist_goal_output_pairs += $$(goal):$$(dst))))
endef

#------------------------------------------------------------------
# To be used at the end of the build to collect all the uses of
# dist-for-goals, and write them into a file for the packaging step to use.

# $(1): The file to write
define dist-write-file
$(strip \
  $(KATI_obsolete_var dist-for-goals,Cannot be used after dist-write-file) \
  $(foreach goal,$(sort $(_all_dist_goals)), \
    $(eval $$(goal): _dist_$$(goal))) \
  $(shell mkdir -p $(dir $(1))) \
  $(file >$(1).tmp, \
    DIST_GOAL_OUTPUT_PAIRS := $(sort $(_all_dist_goal_output_pairs)) \
    $(newline)DIST_SRC_DST_PAIRS := $(sort $(_all_dist_src_dst_pairs))) \
  $(shell if ! cmp -s $(1).tmp $(1); then \
            mv $(1).tmp $(1); \
          else \
            rm $(1).tmp; \
          fi))
endef

.KATI_READONLY := dist-for-goals dist-write-file
