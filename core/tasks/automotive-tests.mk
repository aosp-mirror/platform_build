# Copyright (C) 2022 The Android Open Source Project
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


.PHONY: automotive-tests

automotive-tests-zip := $(PRODUCT_OUT)/automotive-tests.zip
# Create an artifact to include a list of test config files in automotive-tests.
automotive-tests-list-zip := $(PRODUCT_OUT)/automotive-tests_list.zip
# Create an artifact to include all test config files in automotive-tests.
automotive-tests-configs-zip := $(PRODUCT_OUT)/automotive-tests_configs.zip
my_host_shared_lib_for_automotive_tests := $(call copy-many-files,$(COMPATIBILITY.automotive-tests.HOST_SHARED_LIBRARY.FILES))
automotive_tests_host_shared_libs_zip := $(PRODUCT_OUT)/automotive-tests_host-shared-libs.zip

$(automotive-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(automotive-tests-list-zip) $(automotive-tests-configs-zip) $(automotive_tests_host_shared_libs_zip)
$(automotive-tests-zip) : PRIVATE_automotive_tests_list := $(PRODUCT_OUT)/automotive-tests_list
$(automotive-tests-zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_automotive_tests)
$(automotive-tests-zip) : PRIVATE_automotive_host_shared_libs_zip := $(automotive_tests_host_shared_libs_zip)
$(automotive-tests-zip) : $(COMPATIBILITY.automotive-tests.FILES) $(my_host_shared_lib_for_automotive_tests) $(SOONG_ZIP)
	rm -f $@-shared-libs.list
	echo $(sort $(COMPATIBILITY.automotive-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep -e .*\\.config$$ $@-host.list > $@-host-test-configs.list || true
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $@-host.list; \
	  echo $$shared_lib >> $@-shared-libs.list; \
	done
	grep $(HOST_OUT_TESTCASES) $@-shared-libs.list > $@-host-shared-libs.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	grep -e .*\\.config$$ $@-target.list > $@-target-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list
	$(hide) $(SOONG_ZIP) -d -o $(automotive-tests-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	$(SOONG_ZIP) -d -o $(PRIVATE_automotive_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $@-host-shared-libs.list
	rm -f $(PRIVATE_automotive_tests_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_automotive_tests_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_automotive_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(automotive-tests-list-zip) -C $(dir $@) -f $(PRIVATE_automotive_tests_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
	  $@-shared-libs.list $@-host-shared-libs.list $(PRIVATE_automotive_tests_list)

automotive-tests: $(automotive-tests-zip)
$(call dist-for-goals, automotive-tests, $(automotive-tests-zip) $(automotive-tests-list-zip) $(automotive-tests-configs-zip) $(automotive_tests_host_shared_libs_zip))

$(call declare-1p-container,$(automotive-tests-zip),)
$(call declare-container-license-deps,$(automotive-tests-zip),$(COMPATIBILITY.automotive-tests.FILES) $(my_host_shared_lib_for_automotive_tests),$(PRODUCT_OUT)/:/)

tests: automotive-tests
