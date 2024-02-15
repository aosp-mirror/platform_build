#
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
#

# Enables more comprehensive detection of memory errors on hardware that
# supports the ARM Memory Tagging Extension (MTE), by building the image with
# MTE stack instrumentation and forcing MTE on in SYNC mode in all processes.
# For more details, see:
# https://source.android.com/docs/security/test/memory-safety/arm-mte
ifeq ($(filter memtag_heap,$(SANITIZE_TARGET)),)
  # TODO(b/292478827): Re-enable memtag_stack when new toolchain rolls.
  SANITIZE_TARGET := $(strip $(SANITIZE_TARGET) memtag_heap)
  SANITIZE_TARGET_DIAG := $(strip $(SANITIZE_TARGET_DIAG) memtag_heap)
endif
PRODUCT_PRODUCT_PROPERTIES += persist.arm64.memtag.default=sync
PRODUCT_SCUDO_ALLOCATION_RING_BUFFER_SIZE := 131072
