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


.PHONY: automotive-sdv-tests

automotive-sdv-tests-zip := $(PRODUCT_OUT)/automotive-sdv-tests.zip
# Create an artifact to include a list of test config files in automotive-sdv-tests.
automotive-sdv-tests-list-zip := $(PRODUCT_OUT)/automotive-sdv-tests_list.zip
# Create an artifact to include all test config files in automotive-sdv-tests.
automotive-sdv-tests-configs-zip := $(PRODUCT_OUT)/automotive-sdv-tests_configs.zip
my_host_shared_lib_for_automotive_sdv_tests := $(call copy-many-files,$(COMPATIBILITY.automotive-sdv-tests.HOST_SHARED_LIBRARY.FILES))
automotive_sdv_tests_host_shared_libs_zip := $(PRODUCT_OUT)/automotive-sdv-tests_host-shared-libs.zip

$(automotive-sdv-tests-zip) : .KATI_IMPLICIT_OUTPUTS := $(automotive-sdv-tests-list-zip) $(automotive-sdv-tests-configs-zip) $(automotive_sdv_tests_host_shared_libs_zip)
$(automotive-sdv-tests-zip) : PRIVATE_automotive_sdv_tests_list := $(PRODUCT_OUT)/automotive-sdv-tests_list
$(automotive-sdv-tests-zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_automotive_sdv_tests)
$(automotive-sdv-tests-zip) : PRIVATE_automotive_host_shared_libs_zip := $(automotive_sdv_tests_host_shared_libs_zip)
$(automotive-sdv-tests-zip) : $(COMPATIBILITY.automotive-sdv-tests.FILES) $(my_host_shared_lib_for_automotive_sdv_tests) $(SOONG_ZIP)
	rm -f $@-shared-libs.list
	echo $(sort $(COMPATIBILITY.automotive-sdv-tests.FILES)) | tr " " "\n" > $@.list
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
	$(hide) $(SOONG_ZIP) -d -o $(automotive-sdv-tests-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	$(SOONG_ZIP) -d -o $(PRIVATE_automotive_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $@-host-shared-libs.list
	rm -f $(PRIVATE_automotive_sdv_tests_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_automotive_sdv_tests_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_automotive_sdv_tests_list)
	$(hide) $(SOONG_ZIP) -d -o $(automotive-sdv-tests-list-zip) -C $(dir $@) -f $(PRIVATE_automotive_sdv_tests_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
	  $@-shared-libs.list $@-host-shared-libs.list $(PRIVATE_automotive_sdv_tests_list)

automotive-sdv-tests: $(automotive-sdv-tests-zip)
$(call dist-for-goals, automotive-sdv-tests, $(automotive-sdv-tests-zip) $(automotive-sdv-tests-list-zip) $(automotive-sdv-tests-configs-zip) $(automotive_sdv_tests_host_shared_libs_zip))

$(call declare-1p-container,$(automotive-sdv-tests-zip),)
$(call declare-container-license-deps,$(automotive-sdv-tests-zip),$(COMPATIBILITY.automotive-sdv-tests.FILES) $(my_host_shared_lib_for_automotive_sdv_tests),$(PRODUCT_OUT)/:/)

tests: automotive-sdv-tests
