# Copyright (C) 2019 The Android Open Source Project
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

.PHONY: vts-core

vts-core-zip := $(PRODUCT_OUT)/vts-core-tests.zip
# Create an artifact to include a list of test config files in vts-core.
vts-core-list-zip := $(PRODUCT_OUT)/vts-core_list.zip
# Create an artifact to include all test config files in vts-core.
vts-core-configs-zip := $(PRODUCT_OUT)/vts-core_configs.zip
my_host_shared_lib_for_vts_core := $(call copy-many-files,$(COMPATIBILITY.vts-core.HOST_SHARED_LIBRARY.FILES))
$(vts-core-zip) : .KATI_IMPLICIT_OUTPUTS := $(vts-core-list-zip) $(vts-core-configs-zip)
$(vts-core-zip) : PRIVATE_vts_core_list := $(PRODUCT_OUT)/vts-core_list
$(vts-core-zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_vts_core)
$(vts-core-zip) : $(COMPATIBILITY.vts-core.FILES) $(my_host_shared_lib_for_vts_core) $(SOONG_ZIP)
	echo $(sort $(COMPATIBILITY.vts-core.FILES)) | tr " " "\n" > $@.list
	grep $(HOST_OUT_TESTCASES) $@.list > $@-host.list || true
	grep -e .*\\.config$$ $@-host.list > $@-host-test-configs.list || true
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $@-host.list; \
	done
	grep $(TARGET_OUT_TESTCASES) $@.list > $@-target.list || true
	grep -e .*\\.config$$ $@-target.list > $@-target-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $@-host.list -P target -C $(PRODUCT_OUT) -l $@-target.list
	$(hide) $(SOONG_ZIP) -d -o $(vts-core-configs-zip) \
	  -P host -C $(HOST_OUT) -l $@-host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $@-target-test-configs.list
	rm -f $(PRIVATE_vts_core_list)
	$(hide) grep -e .*\\.config$$ $@-host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_vts_core_list)
	$(hide) grep -e .*\\.config$$ $@-target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_vts_core_list)
	$(hide) $(SOONG_ZIP) -d -o $(vts-core-list-zip) -C $(dir $@) -f $(PRIVATE_vts_core_list)
	rm -f $@.list $@-host.list $@-target.list $@-host-test-configs.list $@-target-test-configs.list \
	  $(PRIVATE_vts_core_list)

vts-core: $(vts-core-zip)
$(call dist-for-goals, vts-core, $(vts-core-zip) $(vts-core-list-zip) $(vts-core-configs-zip))

tests: vts-core
