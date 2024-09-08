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

# List all TradeFed tests from COMPATIBILITY.tradefed_tests_dir
.PHONY: tradefed-tests-list

COMPATIBILITY.tradefed_tests_dir := \
  $(COMPATIBILITY.tradefed_tests_dir) \
  tools/tradefederation/core/res/config \
  tools/tradefederation/core/javatests/res/config

tradefed_tests :=
$(foreach dir, $(COMPATIBILITY.tradefed_tests_dir), \
  $(eval tradefed_tests += $(shell find $(dir) -type f -name "*.xml")))
tradefed_tests_list_intermediates := $(call intermediates-dir-for,PACKAGING,tradefed_tests_list,HOST,COMMON)
tradefed_tests_list_zip := $(tradefed_tests_list_intermediates)/tradefed-tests_list.zip
all_tests :=
$(foreach test, $(tradefed_tests), \
  $(eval all_tests += $(word 2,$(subst /res/config/,$(space),$(test)))))
$(tradefed_tests_list_zip) : PRIVATE_tradefed_tests := $(subst .xml,,$(subst $(space),\n,$(sort $(all_tests))))
$(tradefed_tests_list_zip) : PRIVATE_tradefed_tests_list := $(tradefed_tests_list_intermediates)/tradefed-tests_list

$(tradefed_tests_list_zip) : $(tradefed_tests) $(SOONG_ZIP)
	@echo "Package: $@"
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@)
	$(hide) echo -e "$(PRIVATE_tradefed_tests)" > $(PRIVATE_tradefed_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(dir $@) -f $(PRIVATE_tradefed_tests_list)

tradefed-tests-list : $(tradefed_tests_list_zip)
$(call dist-for-goals, tradefed-tests-list, $(tradefed_tests_list_zip))

$(call declare-1p-target,$(tradefed_tests_list_zip),)

tests: tradefed-tests-list
