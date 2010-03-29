#
# Copyright (C) 2009 The Android Open Source Project
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

# This is a build configuration that just contains a list of languages.
# It helps in situations where laugnages must come first in the list,
# mostly because screen densities interfere with the list of locales and
# the system misbehaves when a density is the first locale.

# This is the list of languages that originally shipped on ADP1

PRODUCT_LOCALES := en_US en_GB fr_FR it_IT de_DE es_ES
