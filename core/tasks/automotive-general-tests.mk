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

.PHONY: automotive-general-tests

automotive_general_tests_tools := \
    $(HOST_OUT_JAVA_LIBRARIES)/cts-tradefed.jar \
    $(HOST_OUT_JAVA_LIBRARIES)/compatibility-host-util.jar \
    $(HOST_OUT_JAVA_LIBRARIES)/vts-tradefed.jar \

intermediates_dir := $(call intermediates-dir-for,PACKAGING,automotive-general-tests)
automotive_general_tests_zip := $(PRODUCT_OUT)/automotive-general-tests.zip
# Create an artifact to include a list of test config files in automotive-general-tests.
automotive_general_tests_list_zip := $(PRODUCT_OUT)/automotive-general-tests_list.zip

# Filter shared entries between automotive-general-tests and automotive-tests's HOST_SHARED_LIBRARY.FILES,
# to avoid warning about overriding commands.
my_host_shared_lib_for_automotive_general_tests := \
  $(foreach m,$(filter $(COMPATIBILITY.automotive-tests.HOST_SHARED_LIBRARY.FILES),\
	   $(COMPATIBILITY.automotive-general-tests.HOST_SHARED_LIBRARY.FILES)),$(call word-colon,2,$(m)))
my_automotive_general_tests_shared_lib_files := \
  $(filter-out $(COMPATIBILITY.automotive-tests.HOST_SHARED_LIBRARY.FILES),\
	 $(COMPATIBILITY.automotive-general-tests.HOST_SHARED_LIBRARY.FILES))

my_host_shared_lib_for_automotive_general_tests += $(call copy-many-files,$(my_automotive_general_tests_shared_lib_files))

# Create an artifact to include all test config files in automotive-general-tests.
automotive_general_tests_configs_zip := $(PRODUCT_OUT)/automotive-general-tests_configs.zip
# Create an artifact to include all shared librariy files in automotive-general-tests.
automotive_general_tests_host_shared_libs_zip := $(PRODUCT_OUT)/automotive-general-tests_host-shared-libs.zip

$(automotive_general_tests_zip) : PRIVATE_automotive_general_tests_list_zip := $(automotive_general_tests_list_zip)
$(automotive_general_tests_zip) : .KATI_IMPLICIT_OUTPUTS := $(automotive_general_tests_list_zip) $(automotive_general_tests_configs_zip) $(automotive_general_tests_host_shared_libs_zip)
$(automotive_general_tests_zip) : PRIVATE_TOOLS := $(automotive_general_tests_tools)
$(automotive_general_tests_zip) : PRIVATE_INTERMEDIATES_DIR := $(intermediates_dir)
$(automotive_general_tests_zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_automotive_general_tests)
$(automotive_general_tests_zip) : PRIVATE_automotive_general_tests_configs_zip := $(automotive_general_tests_configs_zip)
$(automotive_general_tests_zip) : PRIVATE_general_host_shared_libs_zip := $(automotive_general_tests_host_shared_libs_zip)
$(automotive_general_tests_zip) : $(COMPATIBILITY.automotive-general-tests.FILES) $(automotive_general_tests_tools) $(my_host_shared_lib_for_automotive_general_tests) $(SOONG_ZIP)
	rm -rf $(PRIVATE_INTERMEDIATES_DIR)
	rm -f $@ $(PRIVATE_automotive_general_tests_list_zip)
	mkdir -p $(PRIVATE_INTERMEDIATES_DIR) $(PRIVATE_INTERMEDIATES_DIR)/tools
	echo $(sort $(COMPATIBILITY.automotive-general-tests.FILES)) | tr " " "\n" > $(PRIVATE_INTERMEDIATES_DIR)/list
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/list > $(PRIVATE_INTERMEDIATES_DIR)/host.list || true
	grep $(TARGET_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/list > $(PRIVATE_INTERMEDIATES_DIR)/target.list || true
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list > $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list || true
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/target.list > $(PRIVATE_INTERMEDIATES_DIR)/target-test-configs.list || true
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $(PRIVATE_INTERMEDIATES_DIR)/host.list; \
	  echo $$shared_lib >> $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list; \
	done
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list > $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list || true
	cp -fp $(PRIVATE_TOOLS) $(PRIVATE_INTERMEDIATES_DIR)/tools/
	$(SOONG_ZIP) -d -o $@ \
	  -P host -C $(PRIVATE_INTERMEDIATES_DIR) -D $(PRIVATE_INTERMEDIATES_DIR)/tools \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host.list \
	  -P target -C $(PRODUCT_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/target.list
	$(SOONG_ZIP) -d -o $(PRIVATE_automotive_general_tests_configs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/target-test-configs.list
	$(SOONG_ZIP) -d -o $(PRIVATE_general_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_INTERMEDIATES_DIR)/automotive-general-tests_list
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_INTERMEDIATES_DIR)/automotive-general-tests_list
	$(SOONG_ZIP) -d -o $(PRIVATE_automotive_general_tests_list_zip) -C $(PRIVATE_INTERMEDIATES_DIR) -f $(PRIVATE_INTERMEDIATES_DIR)/automotive-general-tests_list

automotive-general-tests: $(automotive_general_tests_zip)
$(call dist-for-goals, automotive-general-tests, $(automotive_general_tests_zip) $(automotive_general_tests_list_zip) $(automotive_general_tests_configs_zip) $(automotive_general_tests_host_shared_libs_zip))

$(call declare-1p-container,$(automotive_general_tests_zip),)
$(call declare-container-license-deps,$(automotive_general_tests_zip),$(COMPATIBILITY.automotive-general-tests.FILES) $(automotive_general_tests_tools) $(my_host_shared_lib_for_automotive_general_tests),$(PRODUCT_OUT)/:/)

intermediates_dir :=
automotive_general_tests_tools :=
automotive_general_tests_zip :=
automotive_general_tests_list_zip :=
automotive_general_tests_configs_zip :=
automotive_general_tests_host_shared_libs_zip :=
