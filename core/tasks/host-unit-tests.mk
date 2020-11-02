# Copyright (C) 2020 The Android Open Source Project
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

# `host-unit-tests` shall only include hostside unittest that don't require a device to run. Tests
# included will be run as part of presubmit check.
# To add tests to the suite, do one of the following:
# * For test modules configured with Android.bp, set attribute `test_options: { unit_test: true }`
# * For test modules configured with mk, set `LOCAL_IS_UNIT_TEST := true`
.PHONY: host-unit-tests

intermediates_dir := $(call intermediates-dir-for,PACKAGING,host-unit-tests)
host_unit_tests_zip := $(PRODUCT_OUT)/host-unit-tests.zip
# Get the hostside libraries to be packaged in the test zip. Unlike
# device-tests.mk or general-tests.mk, the files are not copied to the
# testcases directory.
my_host_shared_lib_for_host_unit_tests := $(foreach f,$(COMPATIBILITY.host-unit-tests.HOST_SHARED_LIBRARY.FILES),$(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(_cmf_src)))

$(host_unit_tests_zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_host_unit_tests)

$(host_unit_tests_zip) : $(COMPATIBILITY.host-unit-tests.FILES) $(my_host_shared_lib_for_host_unit_tests) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.host-unit-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	echo "" >> $@-host-libs.list
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $@-host-libs.list; \
	done
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target.list \
	  -P host/testcases -C $(HOST_OUT) -l $@-host-libs.list
	rm -f $@.list $@-host.list $@-target.list $@-host-libs.list

host-unit-tests: $(host_unit_tests_zip)
$(call dist-for-goals, host-unit-tests, $(host_unit_tests_zip))

tests: host-unit-tests
