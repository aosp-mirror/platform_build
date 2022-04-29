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

import logging
import os

# default build configuration for each component
DEFAULT_BUILDCMD = 'm'
DEFAULT_OUTDIR = 'out'

# yaml fields
META_BUILDCMD = 'build_cmd'
META_OUTDIR = 'out_dir'
META_EXPORTS = 'exports'
META_IMPORTS = 'imports'
META_TARGETS = 'lunch_targets'
META_DEPS = 'deps'
# fields under 'exports' and 'imports'
META_LIBS = 'libraries'
META_APIS = 'APIs'
META_FILEGROUP = 'filegroup'
META_MODULES = 'modules'
# fields under 'libraries'
META_LIB_NAME = 'name'

# fields for generated metadata file
SOONG_IMPORTED = 'Imported'
SOONG_IMPORTED_FILEGROUPS = 'FileGroups'
SOONG_EXPORTED = 'Exported'

# export map items
EXP_COMPONENT = 'component'
EXP_TYPE = 'type'
EXP_OUTPATHS = 'outpaths'

class BuildContext:

  def __init__(self):
    self._build_top = os.getenv('BUFFET_BUILD_TOP')
    self._components_top = os.getenv('BUFFET_COMPONENTS_TOP')
    self._target_product = os.getenv('BUFFET_TARGET_PRODUCT')
    self._target_build_variant = os.getenv('BUFFET_TARGET_BUILD_VARIANT')
    self._target_build_type = os.getenv('BUFFET_TARGET_BUILD_TYPE')
    self._out_dir = os.path.join(self._build_top, 'out')

    if not self._build_top:
      raise RuntimeError("Can't find root. Did you run buffet?")

  def build_top(self):
    return self._build_top

  def components_top(self):
    return self._components_top

  def target_product(self):
    return self._target_product

  def target_build_variant(self):
    return self._target_build_variant

  def target_build_type(self):
    return self._target_build_type

  def out_dir(self):
    return self._out_dir


def get_build_context():
  return BuildContext()


def set_logging_config(verbose_level):
  verbose_map = (logging.WARNING, logging.INFO, logging.DEBUG)
  verbosity = min(verbose_level, 2)
  logging.basicConfig(
      format='%(levelname)-8s [%(filename)s:%(lineno)d] %(message)s',
      level=verbose_map[verbosity])
