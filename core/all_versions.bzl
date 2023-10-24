# Copyright (C) 2023 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

_all_versions = ["OPR1", "OPD1", "OPD2", "OPM1", "OPM2", "PPR1", "PPD1", "PPD2", "PPM1", "PPM2", "QPR1"] + [
    version + subversion
    for version in ["Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    for subversion in ["P1A", "P1B", "P2A", "P2B", "D1A", "D1B", "D2A", "D2B", "Q1A", "Q1B", "Q2A", "Q2B", "Q3A", "Q3B"]
]

variables_to_export_to_make = {
    "ALL_VERSIONS": _all_versions,
}
