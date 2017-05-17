# Copyright (C) 2017 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agrls eed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


.PHONY: device-tests

device-tests-zip := $(PRODUCT_OUT)/device-tests.zip
$(device-tests-zip): $(COMPATIBILITY.device-tests.FILES) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.device-tests.FILES)) > $@.list
	sed -i -e 's/\s\+/\n/g' $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list

device-tests: $(device-tests-zip)
$(call dist-for-goals, device-tests, $(device-tests-zip))

tests: device-tests
