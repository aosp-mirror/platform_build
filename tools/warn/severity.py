#
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

"""Severity levels and attributes."""


class Severity(object):
  """Severity levels and attributes."""
  # numbered by dump order
  FIXMENOW = 0
  HIGH = 1
  MEDIUM = 2
  LOW = 3
  ANALYZER = 4
  TIDY = 5
  HARMLESS = 6
  UNKNOWN = 7
  SKIP = 8
  range = range(SKIP + 1)
  attributes = [
      # pylint:disable=bad-whitespace
      ['fuchsia',   'FixNow',    'Critical warnings, fix me now'],
      ['red',       'High',      'High severity warnings'],
      ['orange',    'Medium',    'Medium severity warnings'],
      ['yellow',    'Low',       'Low severity warnings'],
      ['hotpink',   'Analyzer',  'Clang-Analyzer warnings'],
      ['peachpuff', 'Tidy',      'Clang-Tidy warnings'],
      ['limegreen', 'Harmless',  'Harmless warnings'],
      ['lightblue', 'Unknown',   'Unknown warnings'],
      ['grey',      'Unhandled', 'Unhandled warnings']
  ]
  colors = [a[0] for a in attributes]
  column_headers = [a[1] for a in attributes]
  headers = [a[2] for a in attributes]

