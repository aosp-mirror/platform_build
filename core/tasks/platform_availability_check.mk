#
# Copyright (C) 2020 The Android Open Source Project
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

# Check whether there is any module that isn't available for platform
# is installed to the platform.

# Filter FAKE and NON_INSTALLABLE modules out and then collect those are not
# available for platform
_modules_not_available_for_platform := \
$(strip $(foreach m,$(product_MODULES),\
  $(if $(filter-out FAKE,$(ALL_MODULES.$(m).CLASS)),\
    $(if $(ALL_MODULES.$(m).INSTALLED),\
      $(if $(filter true,$(ALL_MODULES.$(m).NOT_AVAILABLE_FOR_PLATFORM)),\
        $(m))))))

_violators_with_path := $(foreach m,$(sort $(_modules_not_available_for_platform)),\
    $(m):$(word 1,$(ALL_MODULES.$(m).PATH))\
)

$(call maybe-print-list-and-error,$(_violators_with_path),\
Following modules are requested to be installed. But are not available \
for platform because they do not have "//apex_available:platform" or \
they depend on other modules that are not available for platform)
