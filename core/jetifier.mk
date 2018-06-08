#
# Copyright (C) 2018 The Android Open Source Project
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

# This file sets up the running of Jetifier

# now add the rule to run jetifier
ifeq ($(strip $(LOCAL_JETIFIER_ENABLED)),true)
  my_jetifier_input_path := $(LOCAL_JETIFIER_INPUT_FILE)
  my_files := $(intermediates.COMMON)/jetifier
  my_jetifier_output_path := $(my_files)/jetified-$(notdir $(my_jetifier_input_path))

$(my_jetifier_output_path) : $(my_jetifier_input_path) $(JETIFIER)
	rm -rf $@
	$(JETIFIER) -outputfile $@ -i $<

  LOCAL_JETIFIER_OUTPUT_FILE := $(my_jetifier_output_path)
  LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_JETIFIER_OUTPUT_FILE)
else
  LOCAL_JETIFIER_OUTPUT_FILE := $(LOCAL_JETIFIER_INPUT_FILE)
endif

