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

# This build rule allows TradeFed test config file to be created based on
# following inputs:
#   is_native: If the test is a native test.
#   LOCAL_MANIFEST_FILE: Name of the AndroidManifest file for the test. If it's
#       not set, default value `AndroidManifest.xml` will be used.
# Output:
#   autogen_test_config_file: Path to the test config file generated.

autogen_test_config_file := $(dir $(LOCAL_BUILT_MODULE))$(LOCAL_MODULE).config
ifeq (true,$(is_native))
# Auto generating test config file for native test
$(autogen_test_config_file) : $(NATIVE_TEST_CONFIG_TEMPLATE)
	@echo "Auto generating test config $(notdir $@)"
	$(hide) sed 's&{MODULE}&$(PRIVATE_MODULE)&g' $^ > $@
my_auto_generate_config := true
else
# Auto generating test config file for instrumentation test
ifeq ($(strip $(LOCAL_MANIFEST_FILE)),)
  LOCAL_MANIFEST_FILE := AndroidManifest.xml
endif
ifdef LOCAL_FULL_MANIFEST_FILE
  my_android_manifest := $(LOCAL_FULL_MANIFEST_FILE)
else
  my_android_manifest := $(LOCAL_PATH)/$(LOCAL_MANIFEST_FILE)
endif
ifneq (,$(wildcard $(my_android_manifest)))
$(autogen_test_config_file): PRIVATE_AUTOGEN_TEST_CONFIG_SCRIPT := $(AUTOGEN_TEST_CONFIG_SCRIPT)
$(autogen_test_config_file): PRIVATE_TEST_CONFIG_ANDROID_MANIFEST := $(my_android_manifest)
$(autogen_test_config_file): PRIVATE_EMPTY_TEST_CONFIG := $(EMPTY_TEST_CONFIG)
$(autogen_test_config_file): PRIVATE_TEMPLATE := $(INSTRUMENTATION_TEST_CONFIG_TEMPLATE)
$(autogen_test_config_file) : $(my_android_manifest) $(EMPTY_TEST_CONFIG) $(INSTRUMENTATION_TEST_CONFIG_TEMPLATE) $(AUTOGEN_TEST_CONFIG_SCRIPT)
	@echo "Auto generating test config $(notdir $@)"
	@rm -f $@
	$(hide) $(PRIVATE_AUTOGEN_TEST_CONFIG_SCRIPT) $@ $(PRIVATE_TEST_CONFIG_ANDROID_MANIFEST) $(PRIVATE_EMPTY_TEST_CONFIG) $(PRIVATE_TEMPLATE)
my_auto_generate_config := true
endif # ifeq (,$(wildcard $(my_android_manifest)))
endif # ifneq (true,$(is_native))

ifeq (true,$(my_auto_generate_config))
  LOCAL_INTERMEDIATE_TARGETS += $(autogen_test_config_file)
  $(LOCAL_BUILT_MODULE): $(autogen_test_config_file)
  ALL_MODULES.$(my_register_name).auto_test_config := true
else
  autogen_test_config_file :=
endif

my_android_manifest :=
my_auto_generate_config :=
