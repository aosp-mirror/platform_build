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

ifneq ($(wildcard test/sts/README-autorepro.md),)
test_suite_name := autorepro
test_suite_tradefed := sts-tradefed
test_suite_readme := test/sts/README-autorepro.md
autorepro_zip := $(HOST_OUT)/$(test_suite_name)/autorepro.zip

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

autorepro_plugin_skel := $(call intermediates-dir-for,ETC,autorepro-plugin-skel.zip)/autorepro-plugin-skel.zip

$(autorepro_zip): AUTOREPRO_ZIP := $(compatibility_zip)
$(autorepro_zip): AUTOREPRO_PLUGIN_SKEL := $(autorepro_plugin_skel)
$(autorepro_zip): $(MERGE_ZIPS) $(ZIP2ZIP) $(compatibility_zip) $(autorepro_plugin_skel)
	rm -f $@ $(AUTOREPRO_ZIP)_filtered
	$(ZIP2ZIP) -i $(AUTOREPRO_ZIP) -o $(AUTOREPRO_ZIP)_filtered \
		-x android-autorepro/tools/sts-tradefed-tests.jar \
		'android-autorepro/tools/*:autorepro/src/main/resources/sts-tradefed-tools/'
	$(MERGE_ZIPS) $@ $(AUTOREPRO_ZIP)_filtered $(AUTOREPRO_PLUGIN_SKEL)
	rm -f $(AUTOREPRO_ZIP)_filtered

.PHONY: autorepro
autorepro: $(autorepro_zip)
$(call dist-for-goals, autorepro, $(autorepro_zip))

endif
