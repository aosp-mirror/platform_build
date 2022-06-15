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
# Create an artifact to include TEST_MAPPING files in source tree.

.PHONY: owners

intermediates := $(call intermediates-dir-for,PACKAGING,owners)
owners_zip := $(intermediates)/owners.zip
owners_list := $(OUT_DIR)/.module_paths/OWNERS.list
owners := $(file <$(owners_list))
$(owners_zip) : PRIVATE_owners := $(subst $(newline),\n,$(owners))

$(owners_zip) : $(owners) $(SOONG_ZIP)
	@echo "Building artifact to include OWNERS files."
	rm -rf $@
	echo -e "$(PRIVATE_owners)" > $@.list
	$(SOONG_ZIP) -o $@ -C . -l $@.list
	rm -f $@.list

owners : $(owners_zip)

$(call dist-for-goals, general-tests, $(owners_zip))
