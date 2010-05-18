#
# Copyright (C) 2010 The Android Open Source Project
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

define filter-ide-goals
$(strip $(filter $(1)-%,$(MAKECMDGOALS)))
endef

define filter-ide-modules
$(strip $(subst -,$(space),$(patsubst $(1)-%,%,$(2))))
endef

# eclipse
eclipse_project_goals := $(call filter-ide-goals,ECLIPSE)
ifdef eclipse_project_goals
  ifneq ($(words $(eclipse_project_goals)),1)
    $(error Only one ECLIPSE- goal may be specified: $(eclipse_project_goals))
  endif
  eclipse_project_modules := $(call filter-ide-modules,ECLIPSE,$(eclipse_project_goals))

  source_paths := $(foreach m,$(eclipse_project_modules),$(ALL_MODULES.$(m).PATH)) \
              $(foreach m,$(eclipse_project_modules),$(ALL_MODULES.$(m).INTERMEDIATE_SOURCE_DIR))

.classpath: PRIVATE_MODULES := $(eclipse_project_modules)
.classpath: PRIVATE_DIRS := $(source_paths) $(INTERNAL_SDK_SOURCE_DIRS)

# the mess below with ./src tries to guess whether the src
$(eclipse_project_goals): .classpath
.classpath: FORCE
	$(hide) echo Generating .classpath for modules: $(PRIVATE_MODULES)
	$(hide) echo '<classpath>' > $@
	$(hide) for p in $(PRIVATE_DIRS) ; do \
		echo -n '  <classpathentry kind="src" path="' >> $@ ; \
		( if [ -d $$p/src ] ; then echo -n $$p/src ; else echo -n $$p ; fi ) >> $@ ; \
		echo '"/>' >> $@ ; \
	done
	$(hide) echo '</classpath>' >> $@
endif

