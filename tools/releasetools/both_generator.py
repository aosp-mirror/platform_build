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

import edify_generator
import amend_generator

class BothGenerator(object):
  def __init__(self, version):
    self.version = version
    self.edify = edify_generator.EdifyGenerator(version)
    self.amend = amend_generator.AmendGenerator()

  def MakeTemporary(self):
    x = BothGenerator(self.version)
    x.edify = self.edify.MakeTemporary()
    x.amend = self.amend.MakeTemporary()
    return x

  def AppendScript(self, other):
    self.edify.AppendScript(other.edify)
    self.amend.AppendScript(other.amend)

  def _DoBoth(self, name, *args):
    getattr(self.edify, name)(*args)
    getattr(self.amend, name)(*args)

  def AssertSomeFingerprint(self, *a): self._DoBoth("AssertSomeFingerprint", *a)
  def AssertOlderBuild(self, *a): self._DoBoth("AssertOlderBuild", *a)
  def AssertDevice(self, *a): self._DoBoth("AssertDevice", *a)
  def AssertSomeBootloader(self, *a): self._DoBoth("AssertSomeBootloader", *a)
  def ShowProgress(self, *a): self._DoBoth("ShowProgress", *a)
  def PatchCheck(self, *a): self._DoBoth("PatchCheck", *a)
  def CacheFreeSpaceCheck(self, *a): self._DoBoth("CacheFreeSpaceCheck", *a)
  def Mount(self, *a): self._DoBoth("Mount", *a)
  def UnpackPackageDir(self, *a): self._DoBoth("UnpackPackageDir", *a)
  def Comment(self, *a): self._DoBoth("Comment", *a)
  def Print(self, *a): self._DoBoth("Print", *a)
  def FormatPartition(self, *a): self._DoBoth("FormatPartition", *a)
  def DeleteFiles(self, *a): self._DoBoth("DeleteFiles", *a)
  def ApplyPatch(self, *a): self._DoBoth("ApplyPatch", *a)
  def WriteFirmwareImage(self, *a): self._DoBoth("WriteFirmwareImage", *a)
  def WriteRawImage(self, *a): self._DoBoth("WriteRawImage", *a)
  def SetPermissions(self, *a): self._DoBoth("SetPermissions", *a)
  def SetPermissionsRecursive(self, *a): self._DoBoth("SetPermissionsRecursive", *a)
  def MakeSymlinks(self, *a): self._DoBoth("MakeSymlinks", *a)
  def AppendExtra(self, *a): self._DoBoth("AppendExtra", *a)

  def AddToZip(self, input_zip, output_zip, input_path=None):
    self._DoBoth("AddToZip", input_zip, output_zip, input_path)
