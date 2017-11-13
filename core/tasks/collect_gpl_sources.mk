# Copyright (C) 2011 The Android Open Source Project
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

ifdef dist_goal

# The rule below doesn't have dependenices on the files that it copies,
# so manually generate directly into the DIST_DIR directory that is always
# wiped between dist builds.
gpl_source_tgz := $(DIST_DIR)/gpl_source.tgz

# FORCE since we can't know whether any of the sources changed
$(gpl_source_tgz): PRIVATE_PATHS := $(sort $(patsubst %/, %, $(dir $(ALL_GPL_MODULE_LICENSE_FILES))))
$(gpl_source_tgz) : $(ALL_GPL_MODULE_LICENSE_FILES)
	@echo Package gpl sources: $@
	$(hide) tar cfz $@ --exclude ".git*" $(PRIVATE_PATHS)

# Dist the tgz only if we are doing a full build
ifeq (,$(TARGET_BUILD_APPS))
droidcore: $(gpl_source_tgz)
endif

endif # dist_goal
