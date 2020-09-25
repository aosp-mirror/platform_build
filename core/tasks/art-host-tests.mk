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

.PHONY: art-host-tests

intermediates_dir := $(call intermediates-dir-for,PACKAGING,art-host-tests)
art_host_tests_zip := $(PRODUCT_OUT)/art-host-tests.zip
$(art_host_tests_zip) : $(COMPATIBILITY.art-host-tests.FILES) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.art-host-tests.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list
	rm -f $@.list $@-host.list $@-target.list

art-host-tests: $(art_host_tests_zip)
$(call dist-for-goals, art-host-tests, $(art_host_tests_zip))

tests: art-host-tests
