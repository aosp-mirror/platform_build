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

.PHONY: general-tests-shared-libs

intermediates_dir := $(call intermediates-dir-for,PACKAGING,general-tests-shared-libs)

general_tests_shared_libs_zip := $(PRODUCT_OUT)/general-tests_host-shared-libs.zip

# Filter shared entries between general-tests and device-tests's HOST_SHARED_LIBRARY.FILES,
# to avoid warning about overriding commands.
my_host_shared_lib_for_general_tests := \
  $(foreach m,$(filter $(COMPATIBILITY.device-tests.HOST_SHARED_LIBRARY.FILES),\
	   $(COMPATIBILITY.general-tests.HOST_SHARED_LIBRARY.FILES)),$(call word-colon,2,$(m)))
my_general_tests_shared_lib_files := \
  $(filter-out $(COMPATIBILITY.device-tests.HOST_SHARED_LIBRARY.FILES),\
	 $(COMPATIBILITY.general-tests.HOST_SHARED_LIBRARY.FILES))

my_host_shared_lib_for_general_tests += $(call copy-many-files,$(my_general_tests_shared_lib_files))

$(general_tests_shared_libs_zip) : PRIVATE_INTERMEDIATES_DIR := $(intermediates_dir)
$(general_tests_shared_libs_zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_general_tests)
$(general_tests_shared_libs_zip) : PRIVATE_general_host_shared_libs_zip := $(general_tests_shared_libs_zip)
$(general_tests_shared_libs_zip) : $(my_host_shared_lib_for_general_tests) $(SOONG_ZIP)
	rm -rf $(PRIVATE_INTERMEDIATES_DIR)
	mkdir -p $(PRIVATE_INTERMEDIATES_DIR) $(PRIVATE_INTERMEDIATES_DIR)/tools
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list; \
	done
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list > $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list || true
	$(SOONG_ZIP) -d -o $(PRIVATE_general_host_shared_libs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list

general-tests-shared-libs: $(general_tests_shared_libs_zip)
$(call dist-for-goals, general-tests-shared-libs, $(general_tests_shared_libs_zip))

$(call declare-1p-container,$(general_tests_shared_libs_zip),)
$(call declare-container-license-deps,$(general_tests_shared_libs_zip),$(my_host_shared_lib_for_general_tests),$(PRODUCT_OUT)/:/)

intermediates_dir :=
general_tests_shared_libs_zip :=
