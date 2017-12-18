#
# Copyright (C) 2017 The Android Open Source Project
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

from __future__ import print_function

import unittest

from sign_target_files_apks import EditTags, RewriteProps


class SignTargetFilesApksTest(unittest.TestCase):

  def test_EditTags(self):
    self.assertEqual(EditTags('dev-keys'), ('release-keys'))
    self.assertEqual(EditTags('test-keys'), ('release-keys'))

    # Multiple tags.
    self.assertEqual(EditTags('abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

    # Tags are sorted.
    self.assertEqual(EditTags('xyz,abc,dev-keys,xyz'), ('abc,release-keys,xyz'))

  def test_RewriteProps(self):
    props = (
        ('', '\n'),
        ('ro.build.fingerprint=foo/bar/dev-keys',
         'ro.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.build.thumbprint=foo/bar/dev-keys',
         'ro.build.thumbprint=foo/bar/release-keys\n'),
        ('ro.vendor.build.fingerprint=foo/bar/dev-keys',
         'ro.vendor.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.vendor.build.thumbprint=foo/bar/dev-keys',
         'ro.vendor.build.thumbprint=foo/bar/release-keys\n'),
        ('# comment line 1', '# comment line 1\n'),
        ('ro.bootimage.build.fingerprint=foo/bar/dev-keys',
         'ro.bootimage.build.fingerprint=foo/bar/release-keys\n'),
        ('ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 dev-keys',
         'ro.build.description='
         'sailfish-user 8.0.0 OPR6.170623.012 4283428 release-keys\n'),
        ('ro.build.tags=dev-keys', 'ro.build.tags=release-keys\n'),
        ('# comment line 2', '# comment line 2\n'),
        ('ro.build.display.id=OPR6.170623.012 dev-keys',
         'ro.build.display.id=OPR6.170623.012\n'),
        ('# comment line 3', '# comment line 3\n'),
    )

    # Assert the case for each individual line.
    for input, output in props:
      self.assertEqual(RewriteProps(input), output)

    # Concatenate all the input lines.
    self.assertEqual(RewriteProps('\n'.join([prop[0] for prop in props])),
                     ''.join([prop[1] for prop in props]))
