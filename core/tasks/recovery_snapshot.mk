# Copyright (C) 2020 The Android Open Source Project
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

current_makefile := $(lastword $(MAKEFILE_LIST))

# RECOVERY_SNAPSHOT_VERSION must be set to 'current' in order to generate a recovery snapshot.
ifeq ($(RECOVERY_SNAPSHOT_VERSION),current)

.PHONY: recovery-snapshot
recovery-snapshot: $(SOONG_RECOVERY_SNAPSHOT_ZIP)

$(call dist-for-goals, recovery-snapshot, $(SOONG_RECOVERY_SNAPSHOT_ZIP))

else # RECOVERY_SNAPSHOT_VERSION is NOT set to 'current'

.PHONY: recovery-snapshot
recovery-snapshot: PRIVATE_MAKEFILE := $(current_makefile)
recovery-snapshot:
	$(call echo-error,$(PRIVATE_MAKEFILE),\
		"CANNOT generate Recovery snapshot. RECOVERY_SNAPSHOT_VERSION must be set to 'current'.")
	exit 1

endif # RECOVERY_SNAPSHOT_VERSION
