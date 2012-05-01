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

#
# Defines branch-specific values.
#

# BUILD_ID is usually used to specify the branch name
# (like "MAIN") or a branch name and a release candidate
# (like "TC1-RC5").  It must be a single word, and is
# capitalized by convention.
#
BUILD_ID := OPENMASTER

# DISPLAY_BUILD_NUMBER should only be set for development branches,
# If set, the BUILD_NUMBER (cl) is appended to the BUILD_ID for
# a more descriptive BUILD_ID_DISPLAY, otherwise BUILD_ID_DISPLAY
# is the same as BUILD_ID
DISPLAY_BUILD_NUMBER := true
