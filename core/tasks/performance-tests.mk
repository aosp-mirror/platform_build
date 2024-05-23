# Copyright (C) 2024 The Android Open Source Project
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


.PHONY: performance-tests

performance-tests-zip := $(PRODUCT_OUT)/performance-tests.zip
# Create an artifact to include a list of test config files in performance-tests.
performance-tests-list-zip := $(PRODUCT_OUT)/performance-tests_list.zip
# Create an artifact to include all test config files in performance-tests.
performance-tests-configs-zip := $(PRODUCT_OUT)/performance-tests_configs.zip

$(performance-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(performance-tests-list-zip) $(performance-tests-configs-zip)
$(performance-tests-zip) : PRIVATE_performance_tests_list := $(PRODUCT_OUT)/performance-tests_list
$(performance-tests-zip) : $(COMPATIBILITY.performance-tests.FILES) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.performance-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep -e .*\\.config$$ $@-host.list > $@-host-test-configs.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	grep -e .*\\.config$$ $@-target.list > $@-target-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list -sha256
	$(hide) $(SOONG_ZIP) -d -o $(performance-tests-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	rm -f $(PRIVATE_performance_tests_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_performance_tests_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_performance_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(performance-tests-list-zip) -C $(dir $@) -f $(PRIVATE_performance_tests_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
	  $(PRIVATE_performance_tests_list)

performance-tests: $(performance-tests-zip)
$(call dist-for-goals, performance-tests, $(performance-tests-zip) $(performance-tests-list-zip) $(performance-tests-configs-zip))

$(call declare-1p-container,$(performance-tests-zip),)
$(call declare-container-license-deps,$(performance-tests-zip),$(COMPATIBILITY.performance-tests.FILES),$(PRODUCT_OUT)/:/)

tests: performance-tests

# Reset temp vars
performance-tests-zip :=
performance-tests-list-zip :=
performance-tests-configs-zip :=
