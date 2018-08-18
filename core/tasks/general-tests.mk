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

.PHONY: general-tests

general_tests_zip := $(PRODUCT_OUT)/general-tests.zip
# Create an artifact to include a list of test config files in general-tests.
general_tests_list_zip := $(PRODUCT_OUT)/general-tests_list.zip
$(general_tests_zip) : PRIVATE_general_tests_list_zip := $(general_tests_list_zip)
$(general_tests_zip) : .KATI_IMPLICIT_OUTPUTS := $(general_tests_list_zip)
$(general_tests_zip) : PRIVATE_general_tests_list := $(PRODUCT_OUT)/general-tests_list
$(general_tests_zip) : $(COMPATIBILITY.general-tests.FILES) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.general-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list
	rm -f $(PRIVATE_general_tests_list)
	$(hide) grep -e .*.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_general_tests_list)
	$(hide) grep -e .*.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_general_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(PRIVATE_general_tests_list_zip) -C $(dir $@) -f $(PRIVATE_general_tests_list)
	rm -f $@.list $@-host.list $@-target.list $(PRIVATE_general_tests_list)

general-tests: $(general_tests_zip)
$(call dist-for-goals, general-tests, $(general_tests_zip) $(general_tests_list_zip))

general_tests_zip :=
general_tests_list_zip :=
