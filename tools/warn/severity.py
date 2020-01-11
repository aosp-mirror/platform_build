# python3
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

"""Clang_Tidy_Warn Severity class definition.

This file stores definition for class Severity that is used in warn_patterns.
"""


# pylint:disable=old-style-class
class Severity:
  """Class of Severity levels where each level is a SeverityInfo."""

  class SeverityInfo:

    def __init__(self, value, color, column_header, header):
      self.value = value
      self.color = color
      self.column_header = column_header
      self.header = header

  # SEVERITY_UNKNOWN should never occur since every warn_pattern listed has
  # a specified severity. It exists for protobuf, the other values must
  # map to non-zero values (since 0 is reserved for a default UNKNOWN), but
  # logic in clang_tidy_warn.py assumes severity level values are consecutive
  # ints starting with 0.
  SEVERITY_UNKNOWN = SeverityInfo(0, 'blueviolet', 'Errors of unknown severity',
                                  'Unknown severity (should not occur)')
  FIXMENOW = SeverityInfo(1, 'fuschia', 'FixNow',
                          'Critical warnings, fix me now')
  HIGH = SeverityInfo(2, 'red', 'High', 'High severity warnings')
  MEDIUM = SeverityInfo(3, 'orange', 'Medium', 'Medium severity warnings')
  LOW = SeverityInfo(4, 'yellow', 'Low', 'Low severity warnings')
  ANALYZER = SeverityInfo(5, 'hotpink', 'Analyzer', 'Clang-Analyzer warnings')
  TIDY = SeverityInfo(6, 'peachpuff', 'Tidy', 'Clang-Tidy warnings')
  HARMLESS = SeverityInfo(7, 'limegreen', 'Harmless', 'Harmless warnings')
  UNMATCHED = SeverityInfo(8, 'lightblue', 'Unmatched', 'Unmatched warnings')
  SKIP = SeverityInfo(9, 'grey', 'Unhandled', 'Unhandled warnings')

  levels = [
      SEVERITY_UNKNOWN, FIXMENOW, HIGH, MEDIUM, LOW, ANALYZER, TIDY, HARMLESS,
      UNMATCHED, SKIP
  ]
  # HTML relies on ordering by value. Sort here to ensure that this is proper
  levels = sorted(levels, key=lambda severity: severity.value)
