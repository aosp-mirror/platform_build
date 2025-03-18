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
.PHONY: general-tests-files-list

general_tests_tools := \
    $(HOST_OUT_JAVA_LIBRARIES)/cts-tradefed.jar \
    $(HOST_OUT_JAVA_LIBRARIES)/compatibility-host-util.jar \
    $(HOST_OUT_JAVA_LIBRARIES)/vts-tradefed.jar \

intermediates_dir := $(call intermediates-dir-for,PACKAGING,general-tests)
general_tests_zip := $(PRODUCT_OUT)/general-tests.zip
# Create an artifact to include a list of test config files in general-tests.
general_tests_list_zip := $(PRODUCT_OUT)/general-tests_list.zip

# Create an artifact to include all test config files in general-tests.
general_tests_configs_zip := $(PRODUCT_OUT)/general-tests_configs.zip

# Filter shared entries between general-tests and device-tests's HOST_SHARED_LIBRARY.FILES,
# to avoid warning about overriding commands.
my_host_shared_lib_for_general_tests := \
  $(foreach m,$(filter $(COMPATIBILITY.device-tests.HOST_SHARED_LIBRARY.FILES),\
	   $(COMPATIBILITY.general-tests.HOST_SHARED_LIBRARY.FILES)),$(call word-colon,2,$(m)))
my_general_tests_shared_lib_files := \
  $(filter-out $(COMPATIBILITY.device-tests.HOST_SHARED_LIBRARY.FILES),\
	 $(COMPATIBILITY.general-tests.HOST_SHARED_LIBRARY.FILES))

my_host_shared_lib_for_general_tests += $(call copy-many-files,$(my_general_tests_shared_lib_files))

my_host_shared_lib_symlinks := \
    $(filter $(COMPATIBILITY.host-unit-tests.SYMLINKS),\
	$(COMPATIBILITY.general-tests.SYMLINKS))

my_general_tests_symlinks := \
    $(filter-out $(COMPATIBILITY.camera-hal-tests.SYMLINKS),\
    $(filter-out $(COMPATIBILITY.host-unit-tests.SYMLINKS),\
	 $(COMPATIBILITY.general-tests.SYMLINKS)))

my_symlinks_for_general_tests := $(foreach f,$(my_general_tests_symlinks),\
	$(strip $(eval _cmf_tuple := $(subst :, ,$(f))) \
	$(eval _cmf_dep := $(word 1,$(_cmf_tuple))) \
	$(eval _cmf_src := $(word 2,$(_cmf_tuple))) \
	$(eval _cmf_dest := $(word 3,$(_cmf_tuple))) \
	$(call symlink-file,$(_cmf_dep),$(_cmf_src),$(_cmf_dest)) \
	$(_cmf_dest)))

# In this one directly take the overlap into the zip since we can't rewrite rules
my_symlinks_for_general_tests += $(foreach f,$(my_host_shared_lib_symlinks),\
        $(strip $(eval _cmf_tuple := $(subst :, ,$(f))) \
        $(eval _cmf_dep := $(word 1,$(_cmf_tuple))) \
        $(eval _cmf_src := $(word 2,$(_cmf_tuple))) \
        $(eval _cmf_dest := $(word 3,$(_cmf_tuple))) \
        $(_cmf_dest)))

general_tests_files_list := $(PRODUCT_OUT)/general-tests_files
general_tests_host_files_list := $(PRODUCT_OUT)/general-tests_host_files
general_tests_target_files_list := $(PRODUCT_OUT)/general-tests_target_files

$(general_tests_zip) : PRIVATE_general_tests_list_zip := $(general_tests_list_zip)
$(general_tests_zip) : .KATI_IMPLICIT_OUTPUTS := $(general_tests_list_zip) $(general_tests_configs_zip)
$(general_tests_zip) : PRIVATE_TOOLS := $(general_tests_tools)
$(general_tests_zip) : PRIVATE_INTERMEDIATES_DIR := $(intermediates_dir)
$(general_tests_zip) : PRIVATE_HOST_SHARED_LIBS := $(my_host_shared_lib_for_general_tests)
$(general_tests_zip) : PRIVATE_SYMLINKS := $(my_symlinks_for_general_tests)
$(general_tests_zip) : PRIVATE_general_tests_configs_zip := $(general_tests_configs_zip)
$(general_tests_zip) : $(COMPATIBILITY.general-tests.FILES) $(my_host_shared_lib_for_general_tests) $(COMPATIBILITY.general-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES) $(general_tests_tools) $(my_symlinks_for_general_tests) $(SOONG_ZIP)
	rm -rf $(PRIVATE_INTERMEDIATES_DIR)
	rm -f $@ $(PRIVATE_general_tests_list_zip)
	mkdir -p $(PRIVATE_INTERMEDIATES_DIR) $(PRIVATE_INTERMEDIATES_DIR)/tools
	echo $(sort $(COMPATIBILITY.general-tests.FILES) $(COMPATIBILITY.general-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES)) | tr " " "\n" > $(PRIVATE_INTERMEDIATES_DIR)/list
	for symlink in $(PRIVATE_SYMLINKS); do \
	  echo $$symlink >> $(PRIVATE_INTERMEDIATES_DIR)/list; \
	done
	$(hide) for shared_lib in $(PRIVATE_HOST_SHARED_LIBS); do \
	  echo $$shared_lib >> $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list; \
	done
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/shared-libs.list > $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list || true
	grep $(HOST_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/list > $(PRIVATE_INTERMEDIATES_DIR)/host.list || true
	grep $(TARGET_OUT_TESTCASES) $(PRIVATE_INTERMEDIATES_DIR)/list > $(PRIVATE_INTERMEDIATES_DIR)/target.list || true
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list > $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list || true
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/target.list > $(PRIVATE_INTERMEDIATES_DIR)/target-test-configs.list || true
	cp -fp $(PRIVATE_TOOLS) $(PRIVATE_INTERMEDIATES_DIR)/tools/
	$(SOONG_ZIP) -d -o $@ \
	  -P host -C $(PRIVATE_INTERMEDIATES_DIR) -D $(PRIVATE_INTERMEDIATES_DIR)/tools \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host.list \
	  -P target -C $(PRODUCT_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/target.list \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-shared-libs.list \
	  -sha256
	$(SOONG_ZIP) -d -o $(PRIVATE_general_tests_configs_zip) \
	  -P host -C $(HOST_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/host-test-configs.list \
	  -P target -C $(PRODUCT_OUT) -l $(PRIVATE_INTERMEDIATES_DIR)/target-test-configs.list
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/host.list | sed s%$(HOST_OUT)%host%g > $(PRIVATE_INTERMEDIATES_DIR)/general-tests_list
	grep -e .*\\.config$$ $(PRIVATE_INTERMEDIATES_DIR)/target.list | sed s%$(PRODUCT_OUT)%target%g >> $(PRIVATE_INTERMEDIATES_DIR)/general-tests_list
	$(SOONG_ZIP) -d -o $(PRIVATE_general_tests_list_zip) -C $(PRIVATE_INTERMEDIATES_DIR) -f $(PRIVATE_INTERMEDIATES_DIR)/general-tests_list

$(general_tests_files_list) : PRIVATE_INTERMEDIATES_DIR := $(intermediates_dir)
$(general_tests_files_list) : PRIVATE_general_tests_host_files_list := $(general_tests_host_files_list)
$(general_tests_files_list) : PRIVATE_general_tests_target_files_list := $(general_tests_target_files_list)
$(general_tests_files_list) :
	echo $(sort $(COMPATIBILITY.general-tests.FILES) $(COMPATIBILITY.device-tests.SOONG_INSTALLED_COMPATIBILITY_SUPPORT_FILES)) | tr " " "\n" > $@
	grep $(HOST_OUT_TESTCASES) $@ > $(PRIVATE_general_tests_host_files_list) || true
	grep $(TARGET_OUT_TESTCASES) $@ >> $(PRIVATE_general_tests_target_files_list) || true

general-tests: $(general_tests_zip)
general-tests-files-list: $(general_tests_files_list)
$(call dist-for-goals, general-tests, $(general_tests_zip) $(general_tests_list_zip) $(general_tests_configs_zip) $(general_tests_shared_libs_zip))

$(call declare-1p-container,$(general_tests_zip),)
$(call declare-container-license-deps,$(general_tests_zip),$(COMPATIBILITY.general-tests.FILES) $(general_tests_tools),$(PRODUCT_OUT)/:/)

intermediates_dir :=
general_tests_tools :=
general_tests_zip :=
general_tests_list_zip :=
general_tests_configs_zip :=
general_tests_shared_libs_zip :=
my_host_shared_lib_for_general_tests :=
my_symlinks_for_general_tests :=
my_general_tests_shared_lib_files :=
my_general_tests_symlinks :=
my_host_shared_lib_symlinks :=
