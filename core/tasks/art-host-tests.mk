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
# Get the hostside libraries to be packaged in the test zip. Unlike
# device-tests.mk or general-tests.mk, the files are not copied to the
# testcases directory.
my_host_shared_lib_for_art_host_tests := $(foreach f,$(COMPATIBILITY.art-host-tests.HOST_SHARED_LIBRARY.FILES),$(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(_cmf_src)))

# Create an artifact to include a list of test config files in art-host-tests.
art_host_tests_list_zip := $(PRODUCT_OUT)/art-host-tests_list.zip
# Create an artifact to include all test config files in art-host-tests.
art_host_tests_configs_zip := $(PRODUCT_OUT)/art-host-tests_configs.zip
# Create an artifact to include all shared library files in art-host-tests.
art_host_tests_host_shared_libs_zip := $(PRODUCT_OUT)/art-host-tests_host-shared-libs.zip

$(art_host_tests_zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_art_host_tests)
$(art_host_tests_zip) : PRIVATE_art_host_tests_list_zip := $(art_host_tests_list_zip)
$(art_host_tests_zip) : PRIVATE_art_host_tests_configs_zip := $(art_host_tests_configs_zip)
$(art_host_tests_zip) : PRIVATE_art_host_tests_host_shared_libs_zip := $(art_host_tests_host_shared_libs_zip)
$(art_host_tests_zip) : .KATI_IMPLICIT_OUTPUTS := $(art_host_tests_list_zip) $(art_host_tests_configs_zip) $(art_host_tests_host_shared_libs_zip)
$(art_host_tests_zip) : PRIVATE_INTERMEDIATES_DIR := $(intermediates_dir)
$(art_host_tests_zip) : $(COMPATIBILITY.art-host-tests.FILES) $(my_host_shared_lib_for_art_host_tests) $(SOONG_ZIP)
	rm -rf $(PRIVATE_INTERMEDIATES_DIR)
	rm -f $@ $(PRIVATE_art_host_tests_list_zip)
	mkdir -p $(PRIVATE_INTERMEDIATES_DIR)
	echo $(sort $(COMPATIBILITY.art-host-tests.FILES)) | tr " " "\n" > $(PRIVATE_INTERMEDIATES_DIR)/list
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/list > $(PRIVATE_INTERMEDIATES_DIR)/host.list || true
	$(hide) touch $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list; \
	done
	$(hide) $(SOONG_ZIP) -d -o $@ -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host.list \
	  -P host/testcases -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list \
	  -sha256
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list > $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list || true
	$(hide) $(SOONG_ZIP) -d -o $(PRIVATE_art_host_tests_configs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list
	grep $(HOST_OUT) $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list > $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list || true
	$(hide) $(SOONG_ZIP) -d -o $(PRIVATE_art_host_tests_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_INTERMEDIATES_DIR)/art-host-tests_list
	$(hide) $(SOONG_ZIP) -d -o $(PRIVATE_art_host_tests_list_zip) -C $(PRIVATE_INTERMEDIATES_DIR) -f $(PRIVATE_INTERMEDIATES_DIR)/art-host-tests_list

art-host-tests: $(art_host_tests_zip)
$(call dist-for-goals, art-host-tests, $(art_host_tests_zip) $(art_host_tests_list_zip) $(art_host_tests_configs_zip) $(art_host_tests_host_shared_libs_zip))

$(call declare-1p-container,$(art_host_tests_zip),)
$(call declare-container-license-deps,$(art_host_tests_zip),$(COMPATIBILITY.art-host-tests.FILES) $(my_host_shared_lib_for_art_host_tests),$(PRODUCT_OUT)/:/)

tests: art-host-tests

intermediates_dir :=
art_host_tests_zip :=
art_host_tests_list_zip :=
art_host_tests_configs_zip :=
art_host_tests_host_shared_libs_zip :=
