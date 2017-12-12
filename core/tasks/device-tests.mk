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

device-tests-zip := $(PRODUCT_OUT)/device-tests.zip
# Create an artifact to include a list of test config files in device-tests.
device-tests-list-zip := $(PRODUCT_OUT)/device-tests_list.zip
$(device-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(device-tests-list-zip)
$(device-tests-zip) : PRIVATE_device_tests_list := $(PRODUCT_OUT)/device-tests_list

$(device-tests-zip) : $(COMPATIBILITY.device-tests.FILES) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.device-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list
	rm -f $(PRIVATE_device_tests_list)
	$(hide) grep -e .*.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_device_tests_list)
	$(hide) grep -e .*.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_device_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(device-tests-list-zip) -C $(dir $@) -f $(PRIVATE_device_tests_list)
	rm -f $@.list $@-host.list $@-target.list $(PRIVATE_device_tests_list)

device-tests: $(device-tests-zip)
$(call dist-for-goals, device-tests, $(device-tests-zip) $(device-tests-list-zip))

tests: device-tests
