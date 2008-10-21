# Copyright (C) 2008 The Android Open Source Project
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
# Rules for building the xlb files for export for translation.
# 

# Gather all of the resource files for the default locale -- that is,
# all resources in directories called values or values-something, where
# one of the - separated segments is not two characters long -- those are the
# language directories, and we don't want those.
all_resource_files := $(foreach pkg, \
        $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES), \
        $(PACKAGES.$(pkg).RESOURCE_FILES))
values_resource_files := $(shell echo $(all_resource_files) | \
		tr -s / | \
		tr " " "\n" | \
		grep -E "\/values[^/]*/(strings.xml|arrays.xml)$$" | \
		grep -v -E -e "-[a-zA-Z]{2}[/\-]")

xlb_target := $(PRODUCT_OUT)/strings.xlb

$(xlb_target): $(values_resource_files) | $(LOCALIZE)
	@echo XLB: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) $(LOCALIZE) xlb $@ $^

# Add a phony target so typing make xlb is convenient
.PHONY: xlb
xlb: $(xlb_target)

# We want this on the build-server builds, but no reason to inflict it on
# everyone
$(call dist-for-goals, user droid, $(xlb_target))

