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

ifneq ($(wildcard test/sts/README-sts-sdk.md),)
test_suite_name := sts-lite
test_suite_tradefed := sts-tradefed
test_suite_readme := test/sts/README-sts-sdk.md
sts_sdk_zip := $(HOST_OUT)/$(test_suite_name)/sts-sdk.zip

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

sts_sdk_samples := $(call intermediates-dir-for,ETC,sts-sdk-samples.zip)/sts-sdk-samples.zip

$(sts_sdk_zip): STS_LITE_ZIP := $(compatibility_zip)
$(sts_sdk_zip): STS_SDK_SAMPLES := $(sts_sdk_samples)
$(sts_sdk_zip): $(MERGE_ZIPS) $(ZIP2ZIP) $(compatibility_zip) $(sts_sdk_samples)
	rm -f $@ $(STS_LITE_ZIP)_filtered
	$(ZIP2ZIP) -i $(STS_LITE_ZIP) -o $(STS_LITE_ZIP)_filtered \
		-x android-sts-lite/tools/sts-tradefed-tests.jar \
		'android-sts-lite/tools/*:sts-test/libs/' \
		'android-sts-lite/testcases/*:sts-test/utils/'
	$(MERGE_ZIPS) $@ $(STS_LITE_ZIP)_filtered $(STS_SDK_SAMPLES)
	rm -f $(STS_LITE_ZIP)_filtered

.PHONY: sts-sdk
sts-sdk: $(sts_sdk_zip)
$(call dist-for-goals, sts-sdk, $(sts_sdk_zip))

endif
