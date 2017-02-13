#!/usr/bin/env python
#
# Copyright 2016 The Android Open Source Project
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
import sys
import struct

FAT_TABLE_START = 0x200
DEL_MARKER = 0xe5
ESCAPE_DEL_MARKER = 0x05

ATTRIBUTE_READ_ONLY = 0x1
ATTRIBUTE_HIDDEN = 0x2
ATTRIBUTE_SYSTEM = 0x4
ATTRIBUTE_VOLUME_LABEL = 0x8
ATTRIBUTE_SUBDIRECTORY = 0x10
ATTRIBUTE_ARCHIVE = 0x20
ATTRIBUTE_DEVICE = 0x40

LFN_ATTRIBUTES = \
    ATTRIBUTE_VOLUME_LABEL | \
    ATTRIBUTE_SYSTEM | \
    ATTRIBUTE_HIDDEN | \
    ATTRIBUTE_READ_ONLY
LFN_ATTRIBUTES_BYTE = struct.pack("B", LFN_ATTRIBUTES)

MAX_CLUSTER_ID = 0x7FFF

def read_le_short(f):
  "Read a little-endian 2-byte integer from the given file-like object"
  return struct.unpack("<H", f.read(2))[0]

def read_le_long(f):
  "Read a little-endian 4-byte integer from the given file-like object"
  return struct.unpack("<L", f.read(4))[0]

def read_byte(f):
  "Read a 1-byte integer from the given file-like object"
  return struct.unpack("B", f.read(1))[0]

def skip_bytes(f, n):
  "Fast-forward the given file-like object by n bytes"
  f.seek(n, os.SEEK_CUR)

def skip_short(f):
  "Fast-forward the given file-like object 2 bytes"
  skip_bytes(f, 2)

def skip_byte(f):
  "Fast-forward the given file-like object 1 byte"
  skip_bytes(f, 1)

def rewind_bytes(f, n):
  "Rewind the given file-like object n bytes"
  skip_bytes(f, -n)

def rewind_short(f):
  "Rewind the given file-like object 2 bytes"
  rewind_bytes(f, 2)

class fake_file(object):
  """
  Interface for python file-like objects that we use to manipulate the image.
  Inheritors must have an idx member which indicates the file pointer, and a
  size member which indicates the total file size.
  """

  def seek(self, amount, direction=0):
    "Implementation of seek from python's file-like object interface."
    if direction == os.SEEK_CUR:
      self.idx += amount
    elif direction == os.SEEK_END:
      self.idx = self.size - amount
    else:
      self.idx = amount

    if self.idx < 0:
      self.idx = 0
    if self.idx > self.size:
      self.idx = self.size

class fat_file(fake_file):
  """
  A file inside of our fat image. The file may or may not have a dentry, and
  if it does this object knows nothing about it. All we see is a valid cluster
  chain.
  """

  def __init__(self, fs, cluster, size=None):
    """
    fs: The fat() object for the image this file resides in.
    cluster: The first cluster of data for this file.
    size: The size of this file. If not given, we use the total length of the
          cluster chain that starts from the cluster argument.
    """
    self.fs = fs
    self.start_cluster = cluster
    self.size = size

    if self.size is None:
      self.size = fs.get_chain_size(cluster)

    self.idx = 0

  def read(self, size):
    "Read method for pythonic file-like interface."
    if self.idx + size > self.size:
      size = self.size - self.idx
    got = self.fs.read_file(self.start_cluster, self.idx, size)
    self.idx += len(got)
    return got

  def write(self, data):
    "Write method for pythonic file-like interface."
    self.fs.write_file(self.start_cluster, self.idx, data)
    self.idx += len(data)

    if self.idx > self.size:
      self.size = self.idx

def shorten(name, index):
  """
  Create a file short name from the given long name (with the extension already
  removed). The index argument gives a disambiguating integer to work into the
  name to avoid collisions.
  """
  name = "".join(name.split('.')).upper()
  postfix = "~" + str(index)
  return name[:8 - len(postfix)] + postfix

class fat_dir(object):
  "A directory in our fat filesystem."

  def __init__(self, backing):
    """
    backing: A file-like object from which we can read dentry info. Should have
    an fs member allowing us to get to the underlying image.
    """
    self.backing = backing
    self.dentries = []
    to_read = self.backing.size / 32

    self.backing.seek(0)

    while to_read > 0:
      (dent, consumed) = self.backing.fs.read_dentry(self.backing)
      to_read -= consumed

      if dent:
        self.dentries.append(dent)

  def __str__(self):
    return "\n".join([str(x) for x in self.dentries]) + "\n"

  def add_dentry(self, attributes, shortname, ext, longname, first_cluster,
      size):
    """
    Add a new dentry to this directory.
    attributes: Attribute flags for this dentry. See the ATTRIBUTE_ constants
                above.
    shortname: Short name of this file. Up to 8 characters, no dots.
    ext: Extension for this file. Up to 3 characters, no dots.
    longname: The long name for this file, with extension. Largely unrestricted.
    first_cluster: The first cluster in the cluster chain holding the contents
                   of this file.
    size: The size of this file. Set to 0 for subdirectories.
    """
    new_dentry = dentry(self.backing.fs, attributes, shortname, ext,
        longname, first_cluster, size)
    new_dentry.commit(self.backing)
    self.dentries.append(new_dentry)
    return new_dentry

  def make_short_name(self, name):
    """
    Given a long file name, return an 8.3 short name as a tuple. Name will be
    engineered not to collide with other such names in this folder.
    """
    parts = name.rsplit('.', 1)

    if len(parts) == 1:
      parts.append('')

    name = parts[0]
    ext = parts[1].upper()

    index = 1
    shortened = shorten(name, index)

    for dent in self.dentries:
      assert dent.longname != name, "File must not exist"
      if dent.shortname == shortened:
        index += 1
        shortened = shorten(name, index)

    if len(name) <= 8 and len(ext) <= 3 and not '.' in name:
      return (name.upper().ljust(8), ext.ljust(3))

    return (shortened.ljust(8), ext[:3].ljust(3))

  def new_file(self, name, data=None):
    """
    Add a new regular file to this directory.
    name: The name of the new file.
    data: The contents of the new file. Given as a file-like object.
    """
    size = 0
    if data:
      data.seek(0, os.SEEK_END)
      size = data.tell()

    # Empty files shouldn't have any clusters assigned.
    chunk = self.backing.fs.allocate(size) if size > 0 else 0
    (shortname, ext) = self.make_short_name(name)
    self.add_dentry(0, shortname, ext, name, chunk, size)

    if data is None:
      return

    data_file = fat_file(self.backing.fs, chunk, size)
    data.seek(0)
    data_file.write(data.read())

  def open_subdirectory(self, name):
    """
    Open a subdirectory of this directory with the given name. If the
    subdirectory doesn't exist, a new one is created instead.
    Returns a fat_dir().
    """
    for dent in self.dentries:
      if dent.longname == name:
        return dent.open_directory()

    chunk = self.backing.fs.allocate(1)
    (shortname, ext) = self.make_short_name(name)
    new_dentry = self.add_dentry(ATTRIBUTE_SUBDIRECTORY, shortname,
            ext, name, chunk, 0)
    result = new_dentry.open_directory()

    parent_cluster = 0

    if hasattr(self.backing, 'start_cluster'):
      parent_cluster = self.backing.start_cluster

    result.add_dentry(ATTRIBUTE_SUBDIRECTORY, '.', '', '', chunk, 0)
    result.add_dentry(ATTRIBUTE_SUBDIRECTORY, '..', '', '', parent_cluster, 0)

    return result

def lfn_checksum(name_data):
  """
  Given the characters of an 8.3 file name (concatenated *without* the dot),
  Compute a one-byte checksum which needs to appear in corresponding long file
  name entries.
  """
  assert len(name_data) == 11, "Name data should be exactly 11 characters"
  name_data = struct.unpack("B" * 11, name_data)

  result = 0

  for char in name_data:
    last_bit = (result & 1) << 7
    result = (result >> 1) | last_bit
    result += char
    result = result & 0xFF

  return struct.pack("B", result)

class dentry(object):
  "A directory entry"
  def __init__(self, fs, attributes, shortname, ext, longname,
      first_cluster, size):
    """
    fs: The fat() object for the image we're stored in.
    attributes: The attribute flags for this dentry. See the ATTRIBUTE_ flags
                above.
    shortname: The short name stored in this dentry. Up to 8 characters, no
               dots.
    ext: The file extension stored in this dentry. Up to 3 characters, no
         dots.
    longname: The long file name stored in this dentry.
    first_cluster: The first cluster in the cluster chain backing the file
                   this dentry points to.
    size: Size of the file this dentry points to. 0 for subdirectories.
    """
    self.fs = fs
    self.attributes = attributes
    self.shortname = shortname
    self.ext = ext
    self.longname = longname
    self.first_cluster = first_cluster
    self.size = size

  def name(self):
    "A friendly text file name for this dentry."
    if self.longname:
      return self.longname

    if not self.ext or len(self.ext) == 0:
      return self.shortname

    return self.shortname + "." + self.ext

  def __str__(self):
    return self.name() + " (" + str(self.size) + \
      " bytes @ " + str(self.first_cluster) + ")"

  def is_directory(self):
    "Return whether this dentry points to a directory."
    return (self.attributes & ATTRIBUTE_SUBDIRECTORY) != 0

  def open_file(self):
    "Open the target of this dentry if it is a regular file."
    assert not self.is_directory(), "Cannot open directory as file"
    return fat_file(self.fs, self.first_cluster, self.size)

  def open_directory(self):
    "Open the target of this dentry if it is a directory."
    assert self.is_directory(), "Cannot open file as directory"
    return fat_dir(fat_file(self.fs, self.first_cluster))

  def longname_records(self, checksum):
    """
    Get the longname records necessary to store this dentry's long name,
    packed as a series of 32-byte strings.
    """
    if self.longname is None:
      return []
    if len(self.longname) == 0:
      return []

    encoded_long_name = self.longname.encode('utf-16-le')
    long_name_padding = "\0" * (26 - (len(encoded_long_name) % 26))
    padded_long_name = encoded_long_name + long_name_padding

    chunks = [padded_long_name[i:i+26] for i in range(0,
      len(padded_long_name), 26)]
    records = []
    sequence_number = 1

    for c in chunks:
      sequence_byte = struct.pack("B", sequence_number)
      sequence_number += 1
      record = sequence_byte + c[:10] + LFN_ATTRIBUTES_BYTE + "\0" + \
          checksum + c[10:22] + "\0\0" + c[22:]
      records.append(record)

    last = records.pop()
    last_seq = struct.unpack("B", last[0])[0]
    last_seq = last_seq | 0x40
    last = struct.pack("B", last_seq) + last[1:]
    records.append(last)
    records.reverse()

    return records

  def commit(self, f):
    """
    Write this dentry into the given file-like object,
    which is assumed to contain a FAT directory.
    """
    f.seek(0)
    padded_short_name = self.shortname.ljust(8)
    padded_ext = self.ext.ljust(3)
    name_data = padded_short_name + padded_ext
    longname_record_data = self.longname_records(lfn_checksum(name_data))
    record = struct.pack("<11sBBBHHHHHHHL",
        name_data,
        self.attributes,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        self.first_cluster,
        self.size)
    entry = "".join(longname_record_data + [record])

    record_count = len(longname_record_data) + 1

    found_count = 0
    while found_count < record_count:
      record = f.read(32)

      if record is None or len(record) != 32:
        # We reached the EOF, so we need to extend the file with a new cluster.
        f.write("\0" * self.fs.bytes_per_cluster)
        f.seek(-self.fs.bytes_per_cluster, os.SEEK_CUR)
        record = f.read(32)

      marker = struct.unpack("B", record[0])[0]

      if marker == DEL_MARKER or marker == 0:
        found_count += 1
      else:
        found_count = 0

    f.seek(-(record_count * 32), os.SEEK_CUR)
    f.write(entry)

class root_dentry_file(fake_file):
  """
  File-like object for the root directory. The root directory isn't stored in a
  normal file, so we can't use a normal fat_file object to create a view of it.
  """
  def __init__(self, fs):
    self.fs = fs
    self.idx = 0
    self.size = fs.root_entries * 32

  def read(self, count):
    f = self.fs.f
    f.seek(self.fs.data_start() + self.idx)

    if self.idx + count > self.size:
      count = self.size - self.idx

    ret = f.read(count)
    self.idx += len(ret)
    return ret

  def write(self, data):
    f = self.fs.f
    f.seek(self.fs.data_start() + self.idx)

    if self.idx + len(data) > self.size:
      data = data[:self.size - self.idx]

    f.write(data)
    self.idx += len(data)
    if self.idx > self.size:
      self.size = self.idx

class fat(object):
  "A FAT image"

  def __init__(self, path):
    """
    path: Path to an image file containing a FAT file system.
    """
    f = open(path, "r+b")

    self.f = f

    f.seek(0xb)
    bytes_per_sector = read_le_short(f)
    sectors_per_cluster = read_byte(f)

    self.bytes_per_cluster = bytes_per_sector * sectors_per_cluster

    reserved_sectors = read_le_short(f)
    assert reserved_sectors == 1, \
        "Can only handle FAT with 1 reserved sector"

    fat_count = read_byte(f)
    assert fat_count == 2, "Can only handle FAT with 2 tables"

    self.root_entries = read_le_short(f)

    skip_short(f) # Image size. Sort of. Useless field.
    skip_byte(f) # Media type. We don't care.

    self.fat_size = read_le_short(f) * bytes_per_sector
    self.root = fat_dir(root_dentry_file(self))

  def data_start(self):
    """
    Index of the first byte after the FAT tables.
    """
    return FAT_TABLE_START + self.fat_size * 2

  def get_chain_size(self, head_cluster):
    """
    Return how many total bytes are in the cluster chain rooted at the given
    cluster.
    """
    if head_cluster == 0:
      return 0

    f = self.f
    f.seek(FAT_TABLE_START + head_cluster * 2)

    cluster_count = 0

    while head_cluster <= MAX_CLUSTER_ID:
      cluster_count += 1
      head_cluster = read_le_short(f)
      f.seek(FAT_TABLE_START + head_cluster * 2)

    return cluster_count * self.bytes_per_cluster

  def read_dentry(self, f=None):
    """
    Read and decode a dentry from the given file-like object at its current
    seek position.
    """
    f = f or self.f
    attributes = None

    consumed = 1

    lfn_entries = {}

    while True:
      skip_bytes(f, 11)
      attributes = read_byte(f)
      rewind_bytes(f, 12)

      if attributes & LFN_ATTRIBUTES != LFN_ATTRIBUTES:
        break

      consumed += 1

      seq = read_byte(f)
      chars = f.read(10)
      skip_bytes(f, 3) # Various hackish nonsense
      chars += f.read(12)
      skip_short(f) # Lots more nonsense
      chars += f.read(4)

      chars = unicode(chars, "utf-16-le").encode("utf-8")

      lfn_entries[seq] = chars

    ind = read_byte(f)

    if ind == 0 or ind == DEL_MARKER:
      skip_bytes(f, 31)
      return (None, consumed)

    if ind == ESCAPE_DEL_MARKER:
      ind = DEL_MARKER

    ind = str(unichr(ind))

    if ind == '.':
      skip_bytes(f, 31)
      return (None, consumed)

    shortname = ind + f.read(7).rstrip()
    ext = f.read(3).rstrip()
    skip_bytes(f, 15) # Assorted flags, ctime/atime/mtime, etc.
    first_cluster = read_le_short(f)
    size = read_le_long(f)

    lfn = lfn_entries.items()
    lfn.sort(key=lambda x: x[0])
    lfn = reduce(lambda x, y: x + y[1], lfn, "")

    if len(lfn) == 0:
      lfn = None
    else:
      lfn = lfn.split('\0', 1)[0]

    return (dentry(self, attributes, shortname, ext, lfn, first_cluster,
      size), consumed)

  def read_file(self, head_cluster, start_byte, size):
    """
    Read from a given FAT file.
    head_cluster: The first cluster in the file.
    start_byte: How many bytes in to the file to begin the read.
    size: How many bytes to read.
    """
    f = self.f

    assert size >= 0, "Can't read a negative amount"
    if size == 0:
      return ""

    got_data = ""

    while True:
      size_now = size
      if start_byte + size > self.bytes_per_cluster:
        size_now = self.bytes_per_cluster - start_byte

      if start_byte < self.bytes_per_cluster:
        size -= size_now

        cluster_bytes_from_root = (head_cluster - 2) * \
            self.bytes_per_cluster
        bytes_from_root = cluster_bytes_from_root + start_byte
        bytes_from_data_start = bytes_from_root + self.root_entries * 32

        f.seek(self.data_start() + bytes_from_data_start)
        line = f.read(size_now)
        got_data += line

        if size == 0:
          return got_data

      start_byte -= self.bytes_per_cluster

      if start_byte < 0:
        start_byte = 0

      f.seek(FAT_TABLE_START + head_cluster * 2)
      assert head_cluster <= MAX_CLUSTER_ID, "Out-of-bounds read"
      head_cluster = read_le_short(f)
      assert head_cluster > 0, "Read free cluster"

    return got_data

  def write_cluster_entry(self, entry):
    """
    Write a cluster entry to the FAT table. Assumes our backing file is already
    seeked to the correct entry in the first FAT table.
    """
    f = self.f
    f.write(struct.pack("<H", entry))
    skip_bytes(f, self.fat_size - 2)
    f.write(struct.pack("<H", entry))
    rewind_bytes(f, self.fat_size)

  def allocate(self, amount):
    """
    Allocate a new cluster chain big enough to hold at least the given amount
    of bytes.
    """
    assert amount > 0, "Must allocate a non-zero amount."

    f = self.f
    f.seek(FAT_TABLE_START + 4)

    current = None
    current_size = 0
    free_zones = {}

    pos = 2
    while pos < self.fat_size / 2:
      data = read_le_short(f)

      if data == 0 and current is not None:
        current_size += 1
      elif data == 0:
        current = pos
        current_size = 1
      elif current is not None:
        free_zones[current] = current_size
        current = None

      pos += 1

    if current is not None:
      free_zones[current] = current_size

    free_zones = free_zones.items()
    free_zones.sort(key=lambda x: x[1])

    grabbed_zones = []
    grabbed = 0

    while grabbed < amount and len(free_zones) > 0:
      zone = free_zones.pop()
      grabbed += zone[1] * self.bytes_per_cluster
      grabbed_zones.append(zone)

    if grabbed < amount:
      return None

    excess = (grabbed - amount) / self.bytes_per_cluster

    grabbed_zones[-1] = (grabbed_zones[-1][0],
        grabbed_zones[-1][1] - excess)

    out = None
    grabbed_zones.reverse()

    for cluster, size in grabbed_zones:
      entries = range(cluster + 1, cluster + size)
      entries.append(out or 0xFFFF)
      out = cluster
      f.seek(FAT_TABLE_START + cluster * 2)
      for entry in entries:
        self.write_cluster_entry(entry)

    return out

  def extend_cluster(self, cluster, amount):
    """
    Given a cluster which is the *last* cluster in a chain, extend it to hold
    at least `amount` more bytes.
    """
    if amount == 0:
      return
    f = self.f
    entry_offset = FAT_TABLE_START + cluster * 2
    f.seek(entry_offset)
    assert read_le_short(f) == 0xFFFF, "Extending from middle of chain"

    return_cluster = self.allocate(amount)
    f.seek(entry_offset)
    self.write_cluster_entry(return_cluster)
    return return_cluster

  def write_file(self, head_cluster, start_byte, data):
    """
    Write to a given FAT file.

    head_cluster: The first cluster in the file.
    start_byte: How many bytes in to the file to begin the write.
    data: The data to write.
    """
    f = self.f
    last_offset = start_byte + len(data)
    current_offset = 0
    current_cluster = head_cluster

    while current_offset < last_offset:
      # Write everything that falls in the cluster starting at current_offset.
      data_begin = max(0, current_offset - start_byte)
      data_end = min(len(data),
                     current_offset + self.bytes_per_cluster - start_byte)
      if data_end > data_begin:
        cluster_file_offset = (self.data_start() + self.root_entries * 32 +
                               (current_cluster - 2) * self.bytes_per_cluster)
        f.seek(cluster_file_offset + max(0, start_byte - current_offset))
        f.write(data[data_begin:data_end])

      # Advance to the next cluster in the chain or get a new cluster if needed.
      current_offset += self.bytes_per_cluster
      if last_offset > current_offset:
        f.seek(FAT_TABLE_START + current_cluster * 2)
        next_cluster = read_le_short(f)
        if next_cluster > MAX_CLUSTER_ID:
          next_cluster = self.extend_cluster(current_cluster, len(data))
        current_cluster = next_cluster
        assert current_cluster > 0, "Cannot write free cluster"


def add_item(directory, item):
  """
  Copy a file into the given FAT directory. If the path given is a directory,
  copy recursively.
  directory: fat_dir to copy the file in to
  item: Path of local file to copy
  """
  if os.path.isdir(item):
    base = os.path.basename(item)
    if len(base) == 0:
      base = os.path.basename(item[:-1])
    sub = directory.open_subdirectory(base)
    for next_item in sorted(os.listdir(item)):
      add_item(sub, os.path.join(item, next_item))
  else:
    with open(item, 'rb') as f:
      directory.new_file(os.path.basename(item), f)

if __name__ == "__main__":
  if len(sys.argv) < 3:
    print("Usage: fat16copy.py <image> <file> [<file> ...]")
    print("Files are copied into the root of the image.")
    print("Directories are copied recursively")
    sys.exit(1)

  root = fat(sys.argv[1]).root

  for p in sys.argv[2:]:
    add_item(root, p)
