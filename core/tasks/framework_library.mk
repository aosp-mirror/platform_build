#
# Copyright (C) 2008 The Android Open Source Project
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

# embedded builds use nothing in frameworks/base
ifneq ($(ANDROID_BUILD_EMBEDDED),true)

include $(CLEAR_VARS)

# sdk.atree needs to copy the whole dir: $(OUT_DOCS)/offline-sdk to the final zip.
# So keep offline-sdk-timestamp target here, and unzip offline-sdk-docs.zip to
# $(OUT_DOCS)/offline-sdk.
$(OUT_DOCS)/offline-sdk-timestamp: $(OUT_DOCS)/offline-sdk-docs-docs.zip
	$(hide) rm -rf $(OUT_DOCS)/offline-sdk
	$(hide) mkdir -p $(OUT_DOCS)/offline-sdk
	( unzip -qo $< -d $(OUT_DOCS)/offline-sdk && touch -f $@ ) || exit 1

.PHONY: docs offline-sdk-docs
docs offline-sdk-docs: $(OUT_DOCS)/offline-sdk-timestamp

SDK_METADATA_DIR :=$= $(call intermediates-dir-for,PACKAGING,framework-doc-stubs-metadata,,COMMON)
SDK_METADATA_FILES :=$= $(addprefix $(SDK_METADATA_DIR)/,\
    activity_actions.txt \
    broadcast_actions.txt \
    categories.txt \
    features.txt \
    service_actions.txt \
    widgets.txt)
SDK_METADATA :=$= $(firstword $(SDK_METADATA_FILES))
$(SDK_METADATA): .KATI_IMPLICIT_OUTPUTS := $(filter-out $(SDK_METADATA),$(SDK_METADATA_FILES))
$(SDK_METADATA): $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/framework-doc-stubs-metadata.zip
	rm -rf $(SDK_METADATA_DIR)
	mkdir -p $(SDK_METADATA_DIR)
	unzip -DDqo $< -d $(SDK_METADATA_DIR)

.PHONY: framework-doc-stubs
framework-doc-stubs: $(SDK_METADATA)

endif # ANDROID_BUILD_EMBEDDED
