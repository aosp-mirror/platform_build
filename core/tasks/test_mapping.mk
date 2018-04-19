# Copyright (C) 2017 The Android Open Source Project
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

# Create an artifact to include TEST_MAPPING files in source tree. Also include
# a file (out/disabled-presubmit-tests) containing the tests that should be
# skipped in presubmit check.

.PHONY: test_mapping

intermediates := $(call intermediates-dir-for,PACKAGING,test_mapping)
test_mappings_zip := $(intermediates)/test_mappings.zip
test_mapping_list := $(OUT_DIR)/.module_paths/TEST_MAPPING.list
test_mappings := $(file <$(test_mapping_list))
$(test_mappings_zip) : PRIVATE_test_mappings := $(subst $(newline),\n,$(test_mappings))
$(test_mappings_zip) : PRIVATE_all_disabled_presubmit_tests := $(ALL_DISABLED_PRESUBMIT_TESTS)

$(test_mappings_zip) : $(test_mappings) $(SOONG_ZIP)
	@echo "Building artifact to include TEST_MAPPING files and tests to skip in presubmit check."
	rm -rf $@ $(dir $@)/disabled-presubmit-tests
	echo $(sort $(PRIVATE_all_disabled_presubmit_tests)) | tr " " "\n" > $(dir $@)/disabled-presubmit-tests
	echo -e "$(PRIVATE_test_mappings)" > $@.list
	$(SOONG_ZIP) -o $@ -C . -l $@.list -C $(dir $@) -f $(dir $@)/disabled-presubmit-tests
	rm -f $@.list $(dir $@)/disabled-presubmit-tests

test_mapping : $(test_mappings_zip)

$(call dist-for-goals, dist_files test_mapping,$(test_mappings_zip))
