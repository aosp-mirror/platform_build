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

.PHONY: dist
dist: ;

dist_goal := $(strip $(filter dist,$(MAKECMDGOALS)))
MAKECMDGOALS := $(strip $(filter-out dist,$(MAKECMDGOALS)))
ifeq (,$(strip $(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS))))
# The commandline was something like "make dist" or "make dist showcommands".
# Add a dependency on a real target.
dist: $(DEFAULT_GOAL)
endif

ifdef dist_goal

# $(1): source file
# $(2): destination file
# $(3): goals that should copy the file
#
define copy-one-dist-file
$(3): $(2)
$(2): $(1)
	@echo "Dist: $$@"
	$$(copy-file-to-new-target-with-cp)
endef

# Other parts of the system should use this function to associate
# certain files with certain goals.  When those goals are built
# and "dist" is specified, the marked files will be copied to DIST_DIR.
#
# $(1): a list of goals  (e.g. droid, sdk, pdk, ndk)
# $(2): the dist files to add to those goals
define dist-for-goals
$(foreach file,$(2), \
  $(eval \
      $(call copy-one-dist-file, \
          $(file), \
          $(DIST_DIR)/$(notdir $(file)), \
	  $(1) \
       ) \
   ) \
 )
endef

else # !dist_goal

# empty definition when not building dist
define dist-for-goals
endef

endif # !dist_goal
