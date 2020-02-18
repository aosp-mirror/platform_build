# Copyright (C) 2019 The Android Open Source Project
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

test_suite_name := vts-core
test_suite_tradefed := vts-core-tradefed
test_suite_readme := test/vts/tools/vts-core-tradefed/README

# TODO(b/149249068): Clean up after all VTS tests are converted.
vts_test_artifact_paths :=
# Some repo may not include vts project.
-include test/vts/tools/build/tasks/framework/vts_for_core_suite.mk

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: vts-core
$(compatibility_zip): $(vts_test_artifact_paths)
vts-core: $(compatibility_zip)
$(call dist-for-goals, vts-core, $(compatibility_zip))

tests: vts-core
