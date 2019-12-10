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

"""Warning patterns for build make tools."""

from severity import Severity

patterns = [
    # pylint:disable=line-too-long,g-inconsistent-quotes
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'make: overriding commands/ignoring old commands',
     'patterns': [r".*: warning: overriding commands for target .+",
                  r".*: warning: ignoring old commands for target .+"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'make: LOCAL_CLANG is false',
     'patterns': [r".*: warning: LOCAL_CLANG is set to false"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'SDK App using platform shared library',
     'patterns': [r".*: warning: .+ \(.*app:sdk.*\) should not link to .+ \(native:platform\)"]},
    {'category': 'make', 'severity': Severity.HIGH,
     'description': 'System module linking to a vendor module',
     'patterns': [r".*: warning: .+ \(.+\) should not link to .+ \(partition:.+\)"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'Invalid SDK/NDK linking',
     'patterns': [r".*: warning: .+ \(.+\) should not link to .+ \(.+\)"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'Duplicate header copy',
     'patterns': [r".*: warning: Duplicate header copy: .+"]},
    {'category': 'FindEmulator', 'severity': Severity.HARMLESS,
     'description': 'FindEmulator: No such file or directory',
     'patterns': [r".*: warning: FindEmulator: .* No such file or directory"]},
    {'category': 'make', 'severity': Severity.HARMLESS,
     'description': 'make: unknown installed file',
     'patterns': [r".*: warning: .*_tests: Unknown installed file for module"]},
    {'category': 'make', 'severity': Severity.HARMLESS,
     'description': 'unusual tags debug eng',
     'patterns': [r".*: warning: .*: unusual tags debug eng"]},
    {'category': 'make', 'severity': Severity.MEDIUM,
     'description': 'make: please convert to soong',
     'patterns': [r".*: warning: .* has been deprecated. Please convert to Soong."]},
]
