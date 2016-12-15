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

#######################################################
# Check if we need to delete obsolete generated java files.
# When an proto/etc file gets deleted (or renamed), the generated java file is obsolete.
previous_gen_java_config := $(TARGET_OUT_COMMON_INTERMEDIATES)/previous_gen_java_config.mk
current_gen_java_config := $(TARGET_OUT_COMMON_INTERMEDIATES)/current_gen_java_config.mk

$(shell rm -rf $(current_gen_java_config) \
  && mkdir -p $(dir $(current_gen_java_config))\
  && touch $(current_gen_java_config))
-include $(previous_gen_java_config)

intermediates_to_clean :=
modules_with_gen_java_files :=
$(foreach p, $(ALL_MODULES), \
  $(eval gs := $(strip $(ALL_MODULES.$(p).PROTO_FILES)\
                       $(ALL_MODULES.$(p).RS_FILES)))\
  $(if $(gs),\
    $(eval modules_with_gen_java_files += $(p))\
    $(shell echo 'GEN_SRC_FILES.$(p) := $(gs)' >> $(current_gen_java_config)))\
  $(if $(filter-out $(gs),$(GEN_SRC_FILES.$(p))),\
    $(eval intermediates_to_clean += $(ALL_MODULES.$(p).INTERMEDIATE_SOURCE_DIR))))
intermediates_to_clean := $(strip $(intermediates_to_clean))
ifdef intermediates_to_clean
$(info *** Obsolete generated java files detected, clean intermediate files...)
$(info *** rm -rf $(intermediates_to_clean))
$(shell rm -rf $(intermediates_to_clean))
intermediates_to_clean :=
endif

# For modules not loaded by the current build (e.g. you are running mm/mmm),
# we copy the info from the previous bulid.
$(foreach p, $(filter-out $(ALL_MODULES),$(MODULES_WITH_GEN_JAVA_FILES)),\
  $(shell echo 'GEN_SRC_FILES.$(p) := $(GEN_SRC_FILES.$(p))' >> $(current_gen_java_config)))
MODULES_WITH_GEN_JAVA_FILES := $(sort $(MODULES_WITH_GEN_JAVA_FILES) $(modules_with_gen_java_files))
$(shell echo 'MODULES_WITH_GEN_JAVA_FILES := $(MODULES_WITH_GEN_JAVA_FILES)' >> $(current_gen_java_config))

# Now current becomes previous.
$(shell cmp $(current_gen_java_config) $(previous_gen_java_config) > /dev/null 2>&1 || mv -f $(current_gen_java_config) $(previous_gen_java_config))

MODULES_WITH_GEN_JAVA_FILES :=
modules_with_gen_java_files :=
previous_gen_java_config :=
current_gen_java_config :=
