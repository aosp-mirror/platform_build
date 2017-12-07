#
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
#

LOCAL_MODULE_CLASS := TEST_CONFIG

# Output test config files to testcases directory.
ifeq (,$(filter general-tests, $(LOCAL_COMPATIBILITY_SUITE)))
  LOCAL_COMPATIBILITY_SUITE += general-tests
endif

LOCAL_MODULE_SUFFIX := .config

my_test_config_file := $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE).xml)
LOCAL_SRC_FILES :=

include $(BUILD_SYSTEM)/base_rules.mk

# The test config is not in a standalone XML file.
ifndef my_test_config_file

ifndef LOCAL_TEST_CONFIG_OPTIONS
  $(call pretty-error,LOCAL_TEST_CONFIG_OPTIONS must be set if the test XML file is not provided.)
endif

my_base_test_config_file := $(LOCAL_PATH)/AndroidTest.xml
my_test_config_file := $(dir $(LOCAL_BUILT_MODULE))AndroidTest.xml

$(my_test_config_file) : PRIVATE_test_config_options := $(LOCAL_TEST_CONFIG_OPTIONS)
$(my_test_config_file) : $(my_base_test_config_file)
	@echo "Create $(notdir $@) with options: $(PRIVATE_test_config_options)."
	$(eval _option_xml := \
		$(foreach option,$(PRIVATE_test_config_options), \
			$(eval p := $(subst :,$(space),$(option))) \
			<option name="$(word 1,$(p))" value="$(word 2,$(p))" \/>\n))
	$(hide) sed 's&</configuration>&$(_option_xml)</configuration>&' $< > $@

endif # my_test_config_file

$(LOCAL_BUILT_MODULE) : $(my_test_config_file)
	$(copy-file-to-target)

my_base_test_config_file :=
my_test_config_file :=
