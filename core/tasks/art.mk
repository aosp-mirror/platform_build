# Copyright (C) 2024 The Android Open Source Project
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

########################################################################
# clean-oat rules
#

.PHONY: clean-oat
clean-oat: clean-oat-host clean-oat-target

.PHONY: clean-oat-host
clean-oat-host:
	find $(OUT_DIR) '(' -name '*.oat' -o -name '*.odex' -o -name '*.art' -o -name '*.vdex' ')' -a -type f | xargs rm -f
	rm -rf $(TMPDIR)/*/test-*/dalvik-cache/*
	rm -rf $(TMPDIR)/android-data/dalvik-cache/*
