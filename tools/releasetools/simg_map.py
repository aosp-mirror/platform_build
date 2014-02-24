#! /usr/bin/env python

# Copyright (C) 2012 The Android Open Source Project
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

from __future__ import print_function
import getopt, posixpath, signal, struct, sys

def main():
  if len(sys.argv) == 4:
    print("No sparse_image_file specified")
    usage(me)

  sparse_fn = sys.argv[1]
  unsparse_fn = sys.argv[2]
  map_file = sys.argv[3]
  mapped_unsparse_fn = sys.argv[4]

  return ComputeMap(sparse_fn, unsparse_fn, map_file, mapped_unsparse_fn)


def ComputeMap(sparse_fn, unsparse_fn, map_file, mapped_unsparse_fn):
  care_map = []

  with open(sparse_fn, "rb") as FH:
    header_bin = FH.read(28)
    header = struct.unpack("<I4H4I", header_bin)

    magic = header[0]
    major_version = header[1]
    minor_version = header[2]
    file_hdr_sz = header[3]
    chunk_hdr_sz = header[4]
    blk_sz = header[5]
    total_blks = header[6]
    total_chunks = header[7]
    image_checksum = header[8]

    if magic != 0xED26FF3A:
      print("%s: %s: Magic should be 0xED26FF3A but is 0x%08X"
            % (me, path, magic))
      return 1
    if major_version != 1 or minor_version != 0:
      print("%s: %s: I only know about version 1.0, but this is version %u.%u"
            % (me, path, major_version, minor_version))
      return 1
    if file_hdr_sz != 28:
      print("%s: %s: The file header size was expected to be 28, but is %u."
            % (me, path, file_hdr_sz))
      return 1
    if chunk_hdr_sz != 12:
      print("%s: %s: The chunk header size was expected to be 12, but is %u."
            % (me, path, chunk_hdr_sz))
      return 1

    print("%s: Total of %u %u-byte output blocks in %u input chunks."
          % (sparse_fn, total_blks, blk_sz, total_chunks))

    offset = 0
    for i in range(total_chunks):
      header_bin = FH.read(12)
      header = struct.unpack("<2H2I", header_bin)
      chunk_type = header[0]
      reserved1 = header[1]
      chunk_sz = header[2]
      total_sz = header[3]
      data_sz = total_sz - 12

      if chunk_type == 0xCAC1:
        if data_sz != (chunk_sz * blk_sz):
          print("Raw chunk input size (%u) does not match output size (%u)"
                % (data_sz, chunk_sz * blk_sz))
          return 1
        else:
          care_map.append((1, chunk_sz))
          FH.seek(data_sz, 1)

      elif chunk_type == 0xCAC2:
        print("Fill chunks are not supported")
        return 1

      elif chunk_type == 0xCAC3:
        if data_sz != 0:
          print("Don't care chunk input size is non-zero (%u)" % (data_sz))
          return 1
        else:
          care_map.append((0, chunk_sz))

      elif chunk_type == 0xCAC4:
        print("CRC32 chunks are not supported")

      else:
        print("Unknown chunk type 0x%04X not supported" % (chunk_type,))
        return 1

      offset += chunk_sz

    if total_blks != offset:
      print("The header said we should have %u output blocks, but we saw %u"
            % (total_blks, offset))

    junk_len = len(FH.read())
    if junk_len:
      print("There were %u bytes of extra data at the end of the file."
            % (junk_len))
      return 1

  last_kind = None
  new_care_map = []
  for kind, size in care_map:
    if kind != last_kind:
      new_care_map.append((kind, size))
      last_kind = kind
    else:
      new_care_map[-1] = (kind, new_care_map[-1][1] + size)

  if new_care_map[0][0] == 0:
    new_care_map.insert(0, (1, 0))
  if len(new_care_map) % 2:
    new_care_map.append((0, 0))

  with open(map_file, "w") as fmap:
    fmap.write("%d\n%d\n" % (blk_sz, len(new_care_map)))
    for _, sz in new_care_map:
      fmap.write("%d\n" % sz)

  with open(unsparse_fn, "rb") as fin:
    with open(mapped_unsparse_fn, "wb") as fout:
      for k, sz in care_map:
        data = fin.read(sz * blk_sz)
        if k:
          fout.write(data)
        else:
          assert data == "\x00" * len(data)

if __name__ == "__main__":
  sys.exit(main())
