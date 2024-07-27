# Copyright (C) 2023 The Android Open Source Project
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

ifneq ($(wildcard test/mts/README.md),)

mcts_test_suites :=
mcts_all_test_suites :=
mcts_all_test_suites += mcts

$(foreach module, $(mts_modules), $(eval mcts_test_suites += mcts-$(module)))

$(foreach suite, $(mcts_test_suites), \
	$(eval test_suite_name := $(suite)) \
	$(eval test_suite_tradefed := mts-tradefed) \
	$(eval test_suite_readme := test/mts/README.md) \
	$(eval include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk) \
	$(eval .PHONY: $(suite)) \
	$(eval $(suite): $(compatibility_zip)) \
	$(eval $(call dist-for-goals, $(suite), $(compatibility_zip))) \
)

$(foreach suite, $(mcts_all_test_suites), \
	$(eval test_suite_name := $(suite)) \
	$(eval test_suite_tradefed := mcts-tradefed) \
	$(eval test_suite_readme := test/mts/README.md) \
	$(eval include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk) \
	$(eval .PHONY: $(suite)) \
	$(eval $(suite): $(compatibility_zip)) \
	$(eval $(call dist-for-goals, $(suite), $(compatibility_zip))) \
)

endif
