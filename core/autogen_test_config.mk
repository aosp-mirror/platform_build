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
#   full_android_manifest: Name of the AndroidManifest file for the test.
# Output:
#   autogen_test_config_file: Path to the test config file generated.

autogen_test_config_file := $(dir $(LOCAL_BUILT_MODULE))$(LOCAL_MODULE).config
# TODO: (b/167308193) Switch to /data/local/tests/unrestricted as the default install base.
autogen_test_install_base := /data/local/tmp
# Automatically setup test root for native test.
ifeq (true,$(is_native))
  ifeq (true,$(LOCAL_VENDOR_MODULE))
    autogen_test_install_base = /data/local/tests/vendor
  endif
  ifeq (true,$(call module-in-vendor-or-product))
    autogen_test_install_base = /data/local/tests/vendor
  endif
endif
ifeq (true,$(is_native))
ifeq ($(LOCAL_NATIVE_BENCHMARK),true)
autogen_test_config_template := $(NATIVE_BENCHMARK_TEST_CONFIG_TEMPLATE)
else
  ifeq ($(LOCAL_IS_HOST_MODULE),true)
    autogen_test_config_template := $(NATIVE_HOST_TEST_CONFIG_TEMPLATE)
  else
    autogen_test_config_template := $(NATIVE_TEST_CONFIG_TEMPLATE)
  endif
endif
# Auto generating test config file for native test
$(autogen_test_config_file): PRIVATE_TEST_INSTALL_BASE := $(autogen_test_install_base)
$(autogen_test_config_file): PRIVATE_MODULE_NAME := $(LOCAL_MODULE)
$(autogen_test_config_file) : $(autogen_test_config_template)
	@echo "Auto generating test config $(notdir $@)"
	$(hide) sed 's&{MODULE}&$(PRIVATE_MODULE_NAME)&g;s&{TEST_INSTALL_BASE}&$(PRIVATE_TEST_INSTALL_BASE)&g;s&{EXTRA_CONFIGS}&&g' $< > $@
my_auto_generate_config := true
else
# Auto generating test config file for instrumentation test
ifneq (,$(full_android_manifest))
$(autogen_test_config_file): PRIVATE_AUTOGEN_TEST_CONFIG_SCRIPT := $(AUTOGEN_TEST_CONFIG_SCRIPT)
$(autogen_test_config_file): PRIVATE_TEST_CONFIG_ANDROID_MANIFEST := $(full_android_manifest)
$(autogen_test_config_file): PRIVATE_EMPTY_TEST_CONFIG := $(EMPTY_TEST_CONFIG)
$(autogen_test_config_file): PRIVATE_TEMPLATE := $(INSTRUMENTATION_TEST_CONFIG_TEMPLATE)
$(autogen_test_config_file) : $(full_android_manifest) $(EMPTY_TEST_CONFIG) $(INSTRUMENTATION_TEST_CONFIG_TEMPLATE) $(AUTOGEN_TEST_CONFIG_SCRIPT)
	@echo "Auto generating test config $(notdir $@)"
	@rm -f $@
	$(hide) $(PRIVATE_AUTOGEN_TEST_CONFIG_SCRIPT) $@ $(PRIVATE_TEST_CONFIG_ANDROID_MANIFEST) $(PRIVATE_EMPTY_TEST_CONFIG) $(PRIVATE_TEMPLATE)
my_auto_generate_config := true
endif # ifneq (,$(full_android_manifest))
endif # ifneq (true,$(is_native))

ifeq (true,$(my_auto_generate_config))
  LOCAL_INTERMEDIATE_TARGETS += $(autogen_test_config_file)
  $(LOCAL_BUILT_MODULE): $(autogen_test_config_file)
  ALL_MODULES.$(my_register_name).auto_test_config := true
  $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_autogen := true
else
  autogen_test_config_file :=
endif

my_auto_generate_config :=
