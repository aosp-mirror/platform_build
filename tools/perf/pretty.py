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

# Formatting utilities

class Sentinel():
    pass

SEPARATOR = Sentinel()

def FormatTable(data, prefix="", alignments=[]):
    """Pretty print a table.

    Prefixes each row with `prefix`.
    """
    if not data:
        return ""
    widths = [max([len(x) if x else 0 for x in col]) for col
              in zip(*[d for d in data if not isinstance(d, Sentinel)])]
    result = ""
    colsep = "  "
    for row in data:
        result += prefix
        if row == SEPARATOR:
            for w in widths:
                result += "-" * w
                result += colsep
            result += "\n"
        else:
            for i in range(len(row)):
                cell = row[i] if row[i] else ""
                if i >= len(alignments) or alignments[i] == "R":
                    result += " " * (widths[i] - len(cell))
                result += cell
                if i < len(alignments) and alignments[i] == "L":
                    result += " " * (widths[i] - len(cell))
                result += colsep
            result += "\n"
    return result


