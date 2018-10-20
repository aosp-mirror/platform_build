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

# Create a default rule. This is unused currently, as the real default rule is
# still in the Kati build step.
.PHONY: _packaging_default_rule_
_packaging_default_rule_:

ifndef KATI
$(error Only Kati is supported.)
endif

$(info [1/3] initializing packaging system ...)

.KATI_READONLY := KATI_PACKAGE_MK_DIR

include build/make/common/core.mk
include build/make/common/strings.mk

$(info [2/3] including distdir.mk ...)

include build/make/packaging/distdir.mk

$(info [3/3] writing packaging rules ...)
