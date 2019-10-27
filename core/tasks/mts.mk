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

ifneq ($(wildcard test/mts/README.md),)
test_suite_name := mts
test_suite_tradefed := mts-tradefed
test_suite_readme := test/mts/README.md

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: mts
mts: $(compatibility_zip)
$(call dist-for-goals, mts, $(compatibility_zip))
endif
