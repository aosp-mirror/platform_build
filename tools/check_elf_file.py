#!/usr/bin/env python
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

"""ELF file checker.

This command ensures all undefined symbols in an ELF file can be resolved to
global (or weak) symbols defined in shared objects specified in DT_NEEDED
entries.
"""

from __future__ import print_function

import argparse
import collections
import os
import os.path
import re
import struct
import subprocess
import sys


_ELF_MAGIC = b'\x7fELF'


# Known machines
_EM_386 = 3
_EM_ARM = 40
_EM_X86_64 = 62
_EM_AARCH64 = 183

_KNOWN_MACHINES = {_EM_386, _EM_ARM, _EM_X86_64, _EM_AARCH64}


# ELF header struct
_ELF_HEADER_STRUCT = (
  ('ei_magic', '4s'),
  ('ei_class', 'B'),
  ('ei_data', 'B'),
  ('ei_version', 'B'),
  ('ei_osabi', 'B'),
  ('ei_pad', '8s'),
  ('e_type', 'H'),
  ('e_machine', 'H'),
  ('e_version', 'I'),
)

_ELF_HEADER_STRUCT_FMT = ''.join(_fmt for _, _fmt in _ELF_HEADER_STRUCT)


ELFHeader = collections.namedtuple(
  'ELFHeader', [_name for _name, _ in _ELF_HEADER_STRUCT])


ELF = collections.namedtuple(
  'ELF',
  ('dt_soname', 'dt_needed', 'imported', 'exported', 'header'))


def _get_os_name():
  """Get the host OS name."""
  if sys.platform.startswith('linux'):
    return 'linux'
  if sys.platform.startswith('darwin'):
    return 'darwin'
  raise ValueError(sys.platform + ' is not supported')


def _get_build_top():
  """Find the build top of the source tree ($ANDROID_BUILD_TOP)."""
  prev_path = None
  curr_path = os.path.abspath(os.getcwd())
  while prev_path != curr_path:
    if os.path.exists(os.path.join(curr_path, '.repo')):
      return curr_path
    prev_path = curr_path
    curr_path = os.path.dirname(curr_path)
  return None


def _select_latest_llvm_version(versions):
  """Select the latest LLVM prebuilts version from a set of versions."""
  pattern = re.compile('clang-r([0-9]+)([a-z]?)')
  found_rev = 0
  found_ver = None
  for curr_ver in versions:
    match = pattern.match(curr_ver)
    if not match:
      continue
    curr_rev = int(match.group(1))
    if not found_ver or curr_rev > found_rev or (
        curr_rev == found_rev and curr_ver > found_ver):
      found_rev = curr_rev
      found_ver = curr_ver
  return found_ver


def _get_latest_llvm_version(llvm_dir):
  """Find the latest LLVM prebuilts version from `llvm_dir`."""
  return _select_latest_llvm_version(os.listdir(llvm_dir))


def _get_llvm_dir():
  """Find the path to LLVM prebuilts."""
  build_top = _get_build_top()

  llvm_prebuilts_base = os.environ.get('LLVM_PREBUILTS_BASE')
  if not llvm_prebuilts_base:
    llvm_prebuilts_base = os.path.join('prebuilts', 'clang', 'host')

  llvm_dir = os.path.join(
    build_top, llvm_prebuilts_base, _get_os_name() + '-x86')

  if not os.path.exists(llvm_dir):
    return None

  llvm_prebuilts_version = os.environ.get('LLVM_PREBUILTS_VERSION')
  if not llvm_prebuilts_version:
    llvm_prebuilts_version = _get_latest_llvm_version(llvm_dir)

  llvm_dir = os.path.join(llvm_dir, llvm_prebuilts_version)

  if not os.path.exists(llvm_dir):
    return None

  return llvm_dir


def _get_llvm_readobj():
  """Find the path to llvm-readobj executable."""
  llvm_dir = _get_llvm_dir()
  llvm_readobj = os.path.join(llvm_dir, 'bin', 'llvm-readobj')
  return llvm_readobj if os.path.exists(llvm_readobj) else 'llvm-readobj'


class ELFError(ValueError):
  """Generic ELF parse error"""
  pass


class ELFInvalidMagicError(ELFError):
  """Invalid ELF magic word error"""
  def __init__(self):
    super(ELFInvalidMagicError, self).__init__('bad ELF magic')


class ELFParser(object):
  """ELF file parser"""

  @classmethod
  def _read_elf_header(cls, elf_file_path):
    """Read the ELF magic word from the beginning of the file."""
    with open(elf_file_path, 'rb') as elf_file:
      buf = elf_file.read(struct.calcsize(_ELF_HEADER_STRUCT_FMT))
      try:
        return ELFHeader(*struct.unpack(_ELF_HEADER_STRUCT_FMT, buf))
      except struct.error:
        return None


  @classmethod
  def open(cls, elf_file_path, llvm_readobj):
    """Open and parse the ELF file."""
    # Parse the ELF header to check the magic word.
    header = cls._read_elf_header(elf_file_path)
    if not header or header.ei_magic != _ELF_MAGIC:
      raise ELFInvalidMagicError()

    # Run llvm-readobj and parse the output.
    return cls._read_llvm_readobj(elf_file_path, header, llvm_readobj)


  @classmethod
  def _find_prefix(cls, pattern, lines_it):
    """Iterate `lines_it` until finding a string that starts with `pattern`."""
    for line in lines_it:
      if line.startswith(pattern):
        return True
    return False


  @classmethod
  def _read_llvm_readobj(cls, elf_file_path, header, llvm_readobj):
    """Run llvm-readobj and parse the output."""
    cmd = [llvm_readobj, '--dynamic-table', '--dyn-symbols', elf_file_path]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, _ = proc.communicate()
    rc = proc.returncode
    if rc != 0:
      raise subprocess.CalledProcessError(rc, cmd, out)
    lines = out.splitlines()
    return cls._parse_llvm_readobj(elf_file_path, header, lines)


  @classmethod
  def _parse_llvm_readobj(cls, elf_file_path, header, lines):
    """Parse the output of llvm-readobj."""
    lines_it = iter(lines)
    dt_soname, dt_needed = cls._parse_dynamic_table(elf_file_path, lines_it)
    imported, exported = cls._parse_dynamic_symbols(lines_it)
    return ELF(dt_soname, dt_needed, imported, exported, header)


  _DYNAMIC_SECTION_START_PATTERN = 'DynamicSection ['

  _DYNAMIC_SECTION_NEEDED_PATTERN = re.compile(
    '^  0x[0-9a-fA-F]+\\s+NEEDED\\s+Shared library: \\[(.*)\\]$')

  _DYNAMIC_SECTION_SONAME_PATTERN = re.compile(
    '^  0x[0-9a-fA-F]+\\s+SONAME\\s+Library soname: \\[(.*)\\]$')

  _DYNAMIC_SECTION_END_PATTERN = ']'


  @classmethod
  def _parse_dynamic_table(cls, elf_file_path, lines_it):
    """Parse the dynamic table section."""
    dt_soname = os.path.basename(elf_file_path)
    dt_needed = []

    dynamic = cls._find_prefix(cls._DYNAMIC_SECTION_START_PATTERN, lines_it)
    if not dynamic:
      return (dt_soname, dt_needed)

    for line in lines_it:
      if line == cls._DYNAMIC_SECTION_END_PATTERN:
        break

      match = cls._DYNAMIC_SECTION_NEEDED_PATTERN.match(line)
      if match:
        dt_needed.append(match.group(1))
        continue

      match = cls._DYNAMIC_SECTION_SONAME_PATTERN.match(line)
      if match:
        dt_soname = match.group(1)
        continue

    return (dt_soname, dt_needed)


  _DYNAMIC_SYMBOLS_START_PATTERN = 'DynamicSymbols ['
  _DYNAMIC_SYMBOLS_END_PATTERN = ']'

  _SYMBOL_ENTRY_START_PATTERN = '  Symbol {'
  _SYMBOL_ENTRY_PATTERN = re.compile('^    ([A-Za-z0-9_]+): (.*)$')
  _SYMBOL_ENTRY_PAREN_PATTERN = re.compile(
    '\\s+\\((?:(?:\\d+)|(?:0x[0-9a-fA-F]+))\\)$')
  _SYMBOL_ENTRY_END_PATTERN = '  }'


  @staticmethod
  def _parse_symbol_name(name_with_version):
    """Split `name_with_version` into name and version. This function may split
    at last occurrence of `@@` or `@`."""
    pos = name_with_version.rfind('@')
    if pos == -1:
      name = name_with_version
      version = ''
    else:
      if pos > 0 and name_with_version[pos - 1] == '@':
        name = name_with_version[0:pos - 1]
      else:
        name = name_with_version[0:pos]
      version = name_with_version[pos + 1:]
    return (name, version)


  @classmethod
  def _parse_dynamic_symbols(cls, lines_it):
    """Parse dynamic symbol table and collect imported and exported symbols."""
    imported = collections.defaultdict(set)
    exported = collections.defaultdict(set)

    for symbol in cls._parse_dynamic_symbols_internal(lines_it):
      name, version = cls._parse_symbol_name(symbol['Name'])
      if name:
        if symbol['Section'] == 'Undefined':
          if symbol['Binding'] != 'Weak':
            imported[name].add(version)
        else:
          if symbol['Binding'] != 'Local':
            exported[name].add(version)

    # Freeze the returned imported/exported dict.
    return (dict(imported), dict(exported))


  @classmethod
  def _parse_dynamic_symbols_internal(cls, lines_it):
    """Parse symbols entries and yield each symbols."""

    if not cls._find_prefix(cls._DYNAMIC_SYMBOLS_START_PATTERN, lines_it):
      return

    for line in lines_it:
      if line == cls._DYNAMIC_SYMBOLS_END_PATTERN:
        return

      if line == cls._SYMBOL_ENTRY_START_PATTERN:
        symbol = {}
        continue

      if line == cls._SYMBOL_ENTRY_END_PATTERN:
        yield symbol
        symbol = None
        continue

      match = cls._SYMBOL_ENTRY_PATTERN.match(line)
      if match:
        key = match.group(1)
        value = cls._SYMBOL_ENTRY_PAREN_PATTERN.sub('', match.group(2))
        symbol[key] = value
        continue


class Checker(object):
  """ELF file checker that checks DT_SONAME, DT_NEEDED, and symbols."""

  def __init__(self, llvm_readobj):
    self._file_path = ''
    self._file_under_test = None
    self._shared_libs = []

    self._llvm_readobj = llvm_readobj


  if sys.stderr.isatty():
    _ERROR_TAG = '\033[0;1;31merror:\033[m'  # Red error
    _NOTE_TAG = '\033[0;1;30mnote:\033[m'  # Black note
  else:
    _ERROR_TAG = 'error:'  # Red error
    _NOTE_TAG = 'note:'  # Black note


  def _error(self, *args):
    """Emit an error to stderr."""
    print(self._file_path + ': ' + self._ERROR_TAG, *args, file=sys.stderr)


  def _note(self, *args):
    """Emit a note to stderr."""
    print(self._file_path + ': ' + self._NOTE_TAG, *args, file=sys.stderr)


  def _load_elf_file(self, path, skip_bad_elf_magic):
    """Load an ELF file from the `path`."""
    try:
      return ELFParser.open(path, self._llvm_readobj)
    except (IOError, OSError):
      self._error('Failed to open "{}".'.format(path))
      sys.exit(2)
    except ELFInvalidMagicError:
      if skip_bad_elf_magic:
        sys.exit(0)
      else:
        self._error('File "{}" must have a valid ELF magic word.'.format(path))
        sys.exit(2)
    except:
      self._error('An unknown error occurred while opening "{}".'.format(path))
      raise


  def load_file_under_test(self, path, skip_bad_elf_magic,
                           skip_unknown_elf_machine):
    """Load file-under-test (either an executable or a shared lib)."""
    self._file_path = path
    self._file_under_test = self._load_elf_file(path, skip_bad_elf_magic)

    if skip_unknown_elf_machine and \
        self._file_under_test.header.e_machine not in _KNOWN_MACHINES:
      sys.exit(0)


  def load_shared_libs(self, shared_lib_paths):
    """Load shared libraries."""
    for path in shared_lib_paths:
      self._shared_libs.append(self._load_elf_file(path, False))


  def check_dt_soname(self, soname):
    """Check whether DT_SONAME matches installation file name."""
    if self._file_under_test.dt_soname != soname:
      self._error('DT_SONAME "{}" must be equal to the file name "{}".'
                  .format(self._file_under_test.dt_soname, soname))
      sys.exit(2)


  def check_dt_needed(self, system_shared_lib_names):
    """Check whether all DT_NEEDED entries are specified in the build
    system."""

    missing_shared_libs = False

    # Collect the DT_SONAMEs from shared libs specified in the build system.
    specified_sonames = {lib.dt_soname for lib in self._shared_libs}

    # Chech whether all DT_NEEDED entries are specified.
    for lib in self._file_under_test.dt_needed:
      if lib not in specified_sonames:
        self._error('DT_NEEDED "{}" is not specified in shared_libs.'
                    .format(lib.decode('utf-8')))
        missing_shared_libs = True

    if missing_shared_libs:
      dt_needed = sorted(set(self._file_under_test.dt_needed))
      modules = [re.sub('\\.so$', '', lib) for lib in dt_needed]

      # Remove system shared libraries from the suggestion since they are added
      # by default.
      modules = [name for name in modules
                 if name not in system_shared_lib_names]

      self._note()
      self._note('Fix suggestions:')
      self._note(
        '  Android.bp: shared_libs: [' +
        ', '.join('"' + module + '"' for module in modules) + '],')
      self._note(
        '  Android.mk: LOCAL_SHARED_LIBRARIES := ' + ' '.join(modules))

      self._note()
      self._note('If the fix above doesn\'t work, bypass this check with:')
      self._note('  Android.bp: check_elf_files: false,')
      self._note('  Android.mk: LOCAL_CHECK_ELF_FILES := false')

      sys.exit(2)


  @staticmethod
  def _find_symbol(lib, name, version):
    """Check whether the symbol name and version matches a definition in
    lib."""
    try:
      lib_sym_vers = lib.exported[name]
    except KeyError:
      return False
    if version == '':  # Symbol version is not requested
      return True
    return version in lib_sym_vers


  @classmethod
  def _find_symbol_from_libs(cls, libs, name, version):
    """Check whether the symbol name and version is defined in one of the
    shared libraries in libs."""
    for lib in libs:
      if cls._find_symbol(lib, name, version):
        return lib
    return None


  def check_symbols(self):
    """Check whether all undefined symbols are resolved to a definition."""
    all_elf_files = [self._file_under_test] + self._shared_libs
    missing_symbols = []
    for sym, imported_vers in self._file_under_test.imported.iteritems():
      for imported_ver in imported_vers:
        lib = self._find_symbol_from_libs(all_elf_files, sym, imported_ver)
        if not lib:
          missing_symbols.append((sym, imported_ver))

    if missing_symbols:
      for sym, ver in sorted(missing_symbols):
        sym = sym.decode('utf-8')
        if ver:
          sym += '@' + ver.decode('utf-8')
        self._error('Unresolved symbol: {}'.format(sym))

      self._note()
      self._note('Some dependencies might be changed, thus the symbol(s) '
                 'above cannot be resolved.')
      self._note('Please re-build the prebuilt file: "{}".'
                 .format(self._file_path))

      self._note()
      self._note('If this is a new prebuilt file and it is designed to have '
                 'unresolved symbols, add one of the following properties:')
      self._note('  Android.bp: allow_undefined_symbols: true,')
      self._note('  Android.mk: LOCAL_ALLOW_UNDEFINED_SYMBOLS := true')

      sys.exit(2)


def _parse_args():
  """Parse command line options."""
  parser = argparse.ArgumentParser()

  # Input file
  parser.add_argument('file',
                      help='Path to the input file to be checked')
  parser.add_argument('--soname',
                      help='Shared object name of the input file')

  # Shared library dependencies
  parser.add_argument('--shared-lib', action='append', default=[],
                      help='Path to shared library dependencies')

  # System Shared library names
  parser.add_argument('--system-shared-lib', action='append', default=[],
                      help='System shared libraries to be hidden from fix '
                      'suggestions')

  # Check options
  parser.add_argument('--skip-bad-elf-magic', action='store_true',
                      help='Ignore the input file without the ELF magic word')
  parser.add_argument('--skip-unknown-elf-machine', action='store_true',
                      help='Ignore the input file with unknown machine ID')
  parser.add_argument('--allow-undefined-symbols', action='store_true',
                      help='Ignore unresolved undefined symbols')

  # Other options
  parser.add_argument('--llvm-readobj',
                      help='Path to the llvm-readobj executable')

  return parser.parse_args()


def main():
  """Main function"""
  args = _parse_args()

  llvm_readobj = args.llvm_readobj
  if not llvm_readobj:
    llvm_readobj = _get_llvm_readobj()

  # Load ELF files
  checker = Checker(llvm_readobj)
  checker.load_file_under_test(
    args.file, args.skip_bad_elf_magic, args.skip_unknown_elf_machine)
  checker.load_shared_libs(args.shared_lib)

  # Run checks
  if args.soname:
    checker.check_dt_soname(args.soname)

  checker.check_dt_needed(args.system_shared_lib)

  if not args.allow_undefined_symbols:
    checker.check_symbols()


if __name__ == '__main__':
  main()
