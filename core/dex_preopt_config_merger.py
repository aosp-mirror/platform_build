#!/usr/bin/env python
#
# Copyright (C) 2021 The Android Open Source Project
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
"""
A tool for merging dexpreopt.config files for <uses-library> dependencies into
the dexpreopt.config file of the library/app that uses them. This is needed to
generate class loader context (CLC) for dexpreopt.

In Make there is no topological order when processing different modules, so a
<uses-library> dependency module may have not been processed yet by the time the
dependent module is processed. Therefore makefiles communicate the information
from dependencies via dexpreopt.config files and add file-level dependencies
from a module dexpreopt.config to its dependency configs. The actual patching
of configs is done by this script, which is called from the makefiles.
"""

from __future__ import print_function

import json
from collections import OrderedDict
import os
import sys


def main():
  """Program entry point."""
  if len(sys.argv) < 2:
    raise SystemExit('usage: %s <main-config> [dep-config ...]' % sys.argv[0])

  # Read all JSON configs.
  cfgs = []
  for arg in sys.argv[1:]:
    if os.stat(arg).st_size != 0:
      with open(arg, 'r') as f:
        cfgs.append(json.load(f, object_pairs_hook=OrderedDict))

  # The first config is the dexpreopted library/app, the rest are its
  # <uses-library> dependencies.
  cfg0 = cfgs[0]

  # Put dependency configs in a map keyed on module name (for easier lookup).
  uses_libs = {}
  for cfg in cfgs[1:]:
    uses_libs[cfg['Name']] = cfg

  # Load the original CLC map.
  clc_map = cfg0['ClassLoaderContexts']

  # Create a new CLC map that will be a copy of the original one with patched
  # fields from dependency dexpreopt.config files.
  clc_map2 = OrderedDict()

  # Patch CLC for each SDK version. Although this should not be necessary for
  # compatibility libraries (so-called "conditional CLC"), because they all have
  # known names, known paths in system/framework, and no subcontext. But keep
  # the loop in case this changes in the future.
  for sdk_ver in clc_map:
    clcs = clc_map[sdk_ver]
    clcs2 = []
    for clc in clcs:
      lib = clc['Name']
      if lib in uses_libs:
        ulib = uses_libs[lib]
        # The real <uses-library> name (may be different from the module name).
        clc['Name'] = ulib['ProvidesUsesLibrary']
        # On-device (install) path to the dependency DEX jar file.
        clc['Device'] = ulib['DexLocation']
        # CLC of the dependency becomes a subcontext. We only need sub-CLC for
        # 'any' version because all other versions are for compatibility
        # libraries, which exist only for apps and not for libraries.
        clc['Subcontexts'] = ulib['ClassLoaderContexts'].get('any')
      else:
        # dexpreopt.config for this <uses-library> is not among the script
        # arguments, which may be the case with compatibility libraries that
        # don't need patching anyway. Just use the original CLC.
        pass
      clcs2.append(clc)
    clc_map2[sdk_ver] = clcs2

  # Go over all uses-libraries in dependency dexpreopt.config files (these don't
  # have to be uses-libraries themselves, they can be e.g. transitive static
  # library dependencies) and merge their CLC to the current one
  for ulib, cfg in uses_libs.items():
    any_sdk_ver = 'any' # not interested in compatibility libraries
    clcs = cfg['ClassLoaderContexts'].get(any_sdk_ver, [])

    # If the dependency is a uses-library itself, its uses-library dependencies
    # are added as a subcontext, so don't add them to top-level CLC.
    dep_is_a_uses_lib = False
    for clc2 in clc_map2[any_sdk_ver]:
      if clc2['Name'] == cfg['ProvidesUsesLibrary']:
        dep_is_a_uses_lib = True
    if dep_is_a_uses_lib:
      continue

    # Check if CLC for these libraries is already present (avoid duplicates).
    # Don't bother optimizing quadratic loop, since CLC is typically small.
    for clc in clcs:
      already_in_clc = False
      for clc2 in clc_map2[any_sdk_ver]:
        if clc2['Name'] == clc['Name']:
          already_in_clc = True
          break
      if not already_in_clc:
        clc_map2[any_sdk_ver] += clcs

  # Overwrite the original class loader context with the patched one.
  cfg0['ClassLoaderContexts'] = clc_map2

  # Update dexpreopt.config file.
  with open(sys.argv[1], 'w') as f:
    f.write(json.dumps(cfgs[0], indent=4, separators=(',', ': ')))

if __name__ == '__main__':
  main()
