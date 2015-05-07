#
# Copyright (C) 2015 The Android Open Source Project
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

# Print modules and their transitive dependencies with license files.
# To invoke, run "make deps-license PROJ_PATH=<proj-path-patterns> DEP_PATH=<dep-path-patterns>".
# PROJ_PATH restricts the paths of the source modules; DEP_PATH restricts the paths of the dependency modules.
# Both can be makefile patterns supported by makefile function $(filter).
# Example: "make deps-license packages/app/% external/%" prints all modules in packages/app/ with their dpendencies in external/.
# The printout lines look like "<module_name> :: <module_paths> :: <license_files>".

ifneq (,$(filter deps-license,$(MAKECMDGOALS)))
ifndef PROJ_PATH
$(error To "make deps-license" you must specify PROJ_PATH and DEP_PATH.)
endif
ifndef DEP_PATH
$(error To "make deps-license" you must specify PROJ_PATH and DEP_PATH.)
endif

# Expand a module's dependencies transitively.
# $(1): the variable name to hold the result.
# $(2): the initial module name.
define get-module-all-dependencies
$(eval _gmad_new := $(sort $(filter-out $($(1)),\
  $(foreach m,$(2),$(ALL_DEPS.$(m).ALL_DEPS)))))\
$(if $(_gmad_new),$(eval $(1) += $(_gmad_new))\
  $(call get-module-all-dependencies,$(1),$(_gmad_new)))
endef

define print-deps-license
$(foreach m, $(ALL_DEPS.MODULES),\
  $(eval m_p := $(sort $(ALL_MODULES.$(m).PATH) $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).PATH)))\
  $(if $(filter $(PROJ_PATH),$(m_p)),\
    $(eval deps :=)\
    $(eval $(call get-module-all-dependencies,deps,$(m)))\
    $(info $(m) :: $(m_p) :: $(ALL_DEPS.$(m).LICENSE))\
    $(foreach d,$(deps),\
      $(eval d_p := $(sort $(ALL_MODULES.$(d).PATH) $(ALL_MODULES.$(d)$(TARGET_2ND_ARCH_MODULE_SUFFIX).PATH)))\
      $(if $(filter $(DEP_PATH),$(d_p)),\
        $(info $(space)$(space)$(space)$(space)$(d) :: $(d_p) :: $(ALL_DEPS.$(d).LICENSE))))))
endef

.PHONY: deps-license
deps-license:
	@$(call print-deps-license)

endif
