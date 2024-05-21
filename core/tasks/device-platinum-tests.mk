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


.PHONY: device-platinum-tests

device-platinum-tests-zip := $(PRODUCT_OUT)/device-platinum-tests.zip
# Create an artifact to include a list of test config files in device-platinum-tests.
device-platinum-tests-list-zip := $(PRODUCT_OUT)/device-platinum-tests_list.zip
# Create an artifact to include all test config files in device-platinum-tests.
device-platinum-tests-configs-zip := $(PRODUCT_OUT)/device-platinum-tests_configs.zip
my_host_shared_lib_for_device_platinum_tests := $(call copy-many-files,$(COMPATIBILITY.device-platinum-tests.HOST_SHARED_LIBRARY.FILES))
device_platinum_tests_host_shared_libs_zip := $(PRODUCT_OUT)/device-platinum-tests_host-shared-libs.zip

$(device-platinum-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(device-platinum-tests-list-zip) $(device-platinum-tests-configs-zip) $(device_platinum_tests_host_shared_libs_zip)
$(device-platinum-tests-zip) : PRIVATE_device_platinum_tests_list := $(PRODUCT_OUT)/device-platinum-tests_list
$(device-platinum-tests-zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_device_platinum_tests)
$(device-platinum-tests-zip) : PRIVATE_device_host_shared_libs_zip := $(device_platinum_tests_host_shared_libs_zip)
$(device-platinum-tests-zip) : $(COMPATIBILITY.device-platinum-tests.FILES) $(my_host_shared_lib_for_device_platinum_tests) $(SOONG_ZIP)
	rm -f $@-shared-libs.list
	echo $(sort $(COMPATIBILITY.device-platinum-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep -e .*\\.config$$ $@-host.list > $@-host-test-configs.list || true
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $@-host.list; \
	  echo $$shared_lib >> $@-shared-libs.list; \
	done
	grep $(HOST_OUT_TESTCASES) $@-shared-libs.list > $@-host-shared-libs.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	grep -e .*\\.config$$ $@-target.list > $@-target-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list -sha256
	$(hide) $(SOONG_ZIP) -d -o $(device-platinum-tests-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	$(SOONG_ZIP) -d -o $(PRIVATE_device_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $@-host-shared-libs.list
	rm -f $(PRIVATE_device_platinum_tests_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_device_platinum_tests_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_device_platinum_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(device-platinum-tests-list-zip) -C $(dir $@) -f $(PRIVATE_device_platinum_tests_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
	  $@-shared-libs.list $@-host-shared-libs.list $(PRIVATE_device_platinum_tests_list)

device-platinum-tests: $(device-platinum-tests-zip)
$(call dist-for-goals, device-platinum-tests, $(device-platinum-tests-zip) $(device-platinum-tests-list-zip) $(device-platinum-tests-configs-zip) $(device_platinum_tests_host_shared_libs_zip))

$(call declare-1p-container,$(device-platinum-tests-zip),)
$(call declare-container-license-deps,$(device-platinum-tests-zip),$(COMPATIBILITY.device-platinum-tests.FILES) $(my_host_shared_lib_for_device_platinum_tests),$(PRODUCT_OUT)/:/)

tests: device-platinum-tests

# Reset temp vars
device-platinum-tests-zip :=
device-platinum-tests-list-zip :=
device-platinum-tests-configs-zip :=
my_host_shared_lib_for_device_platinum_tests :=
device_platinum_tests_host_shared_libs_zip :=