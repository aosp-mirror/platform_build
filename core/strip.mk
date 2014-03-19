#
# Copyright (C) 2014 The Android Open Source Project
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

ifneq ($(TARGET_BUILD_VARIANT),user)
  TARGET_STRIP_EXTRA = && $(PRIVATE_OBJCOPY) --add-gnu-debuglink=$< $@
  TARGET_STRIP_KEEP_SYMBOLS_EXTRA = --add-gnu-debuglink=$<
endif
$(combo_2nd_arch_prefix)TARGET_STRIP_COMMAND = $(PRIVATE_STRIP) --strip-all $< -o $@ $(TARGET_STRIP_EXTRA)
$(combo_2nd_arch_prefix)TARGET_STRIP_KEEP_SYMBOLS_COMMAND = \
  $(PRIVATE_OBJCOPY) \
    `$(PRIVATE_READELF) -S $< | awk '/.debug_/ {print "-R " $$2}' | xargs` \
    $(TARGET_STRIP_KEEP_SYMBOLS_EXTRA) $< $@
