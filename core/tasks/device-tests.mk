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


.PHONY: device-tests
.PHONY: device-tests-files-list

device-tests-zip := $(PRODUCT_OUT)/device-tests.zip
# Create an artifact to include a list of test config files in device-tests.
device-tests-list-zip := $(PRODUCT_OUT)/device-tests_list.zip
# Create an artifact to include all test config files in device-tests.
device-tests-configs-zip := $(PRODUCT_OUT)/device-tests_configs.zip
my_host_shared_lib_for_device_tests := $(call copy-many-files,$(COMPATIBILITY.device-tests.HOST_SHARED_LIBRARY.FILES))
device_tests_files_list := $(PRODUCT_OUT)/device-tests_files

$(device-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(device-tests-list-zip) $(device-tests-configs-zip)
$(device-tests-zip) : PRIVATE_device_tests_list := $(PRODUCT_OUT)/device-tests_list
$(device-tests-zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_device_tests)
$(device-tests-zip) : $(COMPATIBILITY.device-tests.FILES) $(COMPATIBILITY.device-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES) $(my_host_shared_lib_for_device_tests) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.device-tests.FILES) $(COMPATIBILITY.device-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep -e .*\\.config$$ $@-host.list > $@-host-test-configs.list || true
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $@-host.list; \
	done
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	grep -e .*\\.config$$ $@-target.list > $@-target-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list -sha256
	$(hide) $(SOONG_ZIP) -d -o $(device-tests-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	rm -f $(PRIVATE_device_tests_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_device_tests_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_device_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(device-tests-list-zip) -C $(dir $@) -f $(PRIVATE_device_tests_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
		$(PRIVATE_device_tests_list)

$(device_tests_files_list) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_device_tests)
$(device_tests_files_list) :
	echo $(sort $(COMPATIBILITY.device-tests.FILES) $(COMPATIBILITY.device-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES)) | tr " " "\n" > $@.full_list
	grep $(HOST_OUT_TESTCASES) $@.full_list > $@ || true
	grep $(TARGET_OUT_TESTCASES) $@.full_list >> $@ || true

device-tests: $(device-tests-zip)
device-tests-files-list: $(device_tests_files_list)

$(call dist-for-goals, device-tests, $(device-tests-zip) $(device-tests-list-zip) $(device-tests-configs-zip))

$(call declare-1p-container,$(device-tests-zip),)
$(call declare-container-license-deps,$(device-tests-zip),$(COMPATIBILITY.device-tests.FILES) $(my_host_shared_lib_for_device_tests),$(PRODUCT_OUT)/:/)

tests: device-tests
