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


import os
import tempfile
import test_utils
import merge_ota
import update_payload
from update_metadata_pb2 import DynamicPartitionGroup
from update_metadata_pb2 import DynamicPartitionMetadata
from test_utils import SkipIfExternalToolsUnavailable, ReleaseToolsTestCase


class MergeOtaTest(ReleaseToolsTestCase):
  def setUp(self) -> None:
    self.testdata_dir = test_utils.get_testdata_dir()
    return super().setUp()

  @SkipIfExternalToolsUnavailable()
  def test_MergeThreeOtas(self):
    ota1 = os.path.join(self.testdata_dir, "tuna_vbmeta.zip")
    ota2 = os.path.join(self.testdata_dir, "tuna_vbmeta_system.zip")
    ota3 = os.path.join(self.testdata_dir, "tuna_vbmeta_vendor.zip")
    payloads = [update_payload.Payload(ota) for ota in [ota1, ota2, ota3]]
    with tempfile.NamedTemporaryFile() as output_file:
      merge_ota.main(["merge_ota", "-v", ota1, ota2, ota3,
                     "--output", output_file.name])
      payload = update_payload.Payload(output_file.name)
      partition_names = [
          part.partition_name for part in payload.manifest.partitions]
      self.assertEqual(partition_names, [
                       "vbmeta", "vbmeta_system", "vbmeta_vendor"])
      payload.CheckDataHash()
      for i in range(3):
        self.assertEqual(payload.manifest.partitions[i].old_partition_info,
                         payloads[i].manifest.partitions[0].old_partition_info)
        self.assertEqual(payload.manifest.partitions[i].new_partition_info,
                         payloads[i].manifest.partitions[0].new_partition_info)

  def test_MergeDAPSnapshotDisabled(self):
    dap1 = DynamicPartitionMetadata()
    dap2 = DynamicPartitionMetadata()
    merged_dap = DynamicPartitionMetadata()
    dap1.snapshot_enabled = True
    dap2.snapshot_enabled = False
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap1)
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap2)
    self.assertFalse(merged_dap.snapshot_enabled)

  def test_MergeDAPSnapshotEnabled(self):
    dap1 = DynamicPartitionMetadata()
    dap2 = DynamicPartitionMetadata()
    merged_dap = DynamicPartitionMetadata()
    merged_dap.snapshot_enabled = True
    dap1.snapshot_enabled = True
    dap2.snapshot_enabled = True
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap1)
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap2)
    self.assertTrue(merged_dap.snapshot_enabled)

  def test_MergeDAPGroups(self):
    dap1 = DynamicPartitionMetadata()
    dap1.groups.append(DynamicPartitionGroup(
        name="abc", partition_names=["a", "b", "c"]))
    dap2 = DynamicPartitionMetadata()
    dap2.groups.append(DynamicPartitionGroup(
        name="abc", partition_names=["d", "e", "f"]))
    merged_dap = DynamicPartitionMetadata()
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap1)
    merge_ota.MergeDynamicPartitionMetadata(merged_dap, dap2)
    self.assertEqual(len(merged_dap.groups), 1)
    self.assertEqual(merged_dap.groups[0].name, "abc")
    self.assertEqual(merged_dap.groups[0].partition_names, [
                     "a", "b", "c", "d", "e", "f"])
