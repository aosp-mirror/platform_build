#!/usr/bin/env python3
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

import argparse
import copy
import json
import logging
import os
import sys
import yaml
from collections import defaultdict
from typing import (
  List,
  Set,
)

import utils

# SKIP_COMPONENT_SEARCH = (
#    'tools',
# )
COMPONENT_METADATA_DIR = '.repo'
COMPONENT_METADATA_FILE = 'treeinfo.yaml'
GENERATED_METADATA_FILE = 'metadata.json'
COMBINED_METADATA_FILENAME = 'multitree_meta.json'


class Dep(object):
  def __init__(self, name, component, deps_type):
    self.name = name
    self.component = component
    self.type = deps_type
    self.out_paths = list()


class ExportedDep(Dep):
  def __init__(self, name, component, deps_type):
    super().__init__(name, component, deps_type)

  def setOutputPaths(self, output_paths: list):
    self.out_paths = output_paths


class ImportedDep(Dep):
  required_type_map = {
    # import type: (required type, get imported module list)
    utils.META_FILEGROUP: (utils.META_MODULES, True),
  }

  def __init__(self, name, component, deps_type, import_map):
    super().__init__(name, component, deps_type)
    self.exported_deps: Set[ExportedDep] = set()
    self.imported_modules: List[str] = list()
    self.required_type = deps_type
    get_imported_module = False
    if deps_type in ImportedDep.required_type_map:
      self.required_type, get_imported_module = ImportedDep.required_type_map[deps_type]
    if get_imported_module:
      self.imported_modules = import_map[name]
    else:
      self.imported_modules.append(name)

  def verify_and_add(self, exported: ExportedDep):
    if self.required_type != exported.type:
      raise RuntimeError(
          '{comp} components imports {module} for {imp_type} but it is exported as {exp_type}.'
          .format(comp=self.component, module=exported.name, imp_type=self.required_type, exp_type=exported.type))
    self.exported_deps.add(exported)
    self.out_paths.extend(exported.out_paths)
    # Remove duplicates. We may not use set() which is not JSON serializable
    self.out_paths = list(dict.fromkeys(self.out_paths))


class MetadataCollector(object):
  """Visit all component directories and collect the metadata from them.

Example of metadata:
==========
build_cmd: m    # build command for this component. 'm' if omitted
out_dir: out    # out dir of this component. 'out' if omitted
exports:
  libraries:
    - name: libopenjdkjvm
    - name: libopenjdkjvmd
      build_cmd: mma      # build command for libopenjdkjvmd if specified
      out_dir: out/soong  # out dir for libopenjdkjvmd if specified
    - name: libctstiagent
  APIs:
    - api1
    - api2
imports:
  libraries:
    - lib1
    - lib2
  APIs:
    - import_api1
    - import_api2
lunch_targets:
  - arm64
  - x86_64
"""

  def __init__(self, component_top, out_dir, meta_dir, meta_file, force_update=False):
    if not os.path.exists(out_dir):
      os.makedirs(out_dir)

    self.__component_top = component_top
    self.__out_dir = out_dir
    self.__metadata_path = os.path.join(meta_dir, meta_file)
    self.__combined_metadata_path = os.path.join(self.__out_dir,
                                                 COMBINED_METADATA_FILENAME)
    self.__force_update = force_update

    self.__metadata = dict()
    self.__map_exports = dict()
    self.__component_set = set()

  def collect(self):
    """ Read precomputed combined metadata from the json file.

    If any components have updated their metadata, update the metadata
    information and the json file.
    """
    timestamp = self.__restore_metadata()
    if timestamp and os.path.getmtime(__file__) > timestamp:
      logging.info('Update the metadata as the orchestrator has been changed')
      self.__force_update = True
    self.__collect_from_components(timestamp)

  def get_metadata(self):
    """ Returns collected metadata from all components"""
    if not self.__metadata:
      logging.warning('Metadata is empty')
    return copy.deepcopy(self.__metadata)

  def __collect_from_components(self, timestamp):
    """ Read metadata from all components

    If any components have newer metadata files or are removed, update the
    combined metadata.
    """
    metadata_updated = False
    for component in os.listdir(self.__component_top):
      # if component in SKIP_COMPONENT_SEARCH:
      #     continue
      if self.__read_component_metadata(timestamp, component):
        metadata_updated = True
      if self.__read_generated_metadata(timestamp, component):
        metadata_updated = True

    deleted_components = set()
    for meta in self.__metadata:
      if meta not in self.__component_set:
        logging.info('Component {} is removed'.format(meta))
        deleted_components.add(meta)
        metadata_updated = True
    for meta in deleted_components:
      del self.__metadata[meta]

    if metadata_updated:
      self.__update_dependencies()
      self.__store_metadata()
      logging.info('Metadata updated')

  def __read_component_metadata(self, timestamp, component):
    """ Search for the metadata file from a component.

    If the metadata is modified, read the file and update the metadata.
    """
    component_path = os.path.join(self.__component_top, component)
    metadata_file = os.path.join(component_path, self.__metadata_path)
    logging.info(
        'Reading a metadata file from {} component ...'.format(component))
    if not os.path.isfile(metadata_file):
      logging.warning('Metadata file {} not found!'.format(metadata_file))
      return False

    self.__component_set.add(component)
    if not self.__force_update and timestamp and timestamp > os.path.getmtime(metadata_file):
      logging.info('... yaml not changed. Skip')
      return False

    with open(metadata_file) as f:
      meta = yaml.load(f, Loader=yaml.SafeLoader)

    meta['path'] = component_path
    if utils.META_BUILDCMD not in meta:
      meta[utils.META_BUILDCMD] = utils.DEFAULT_BUILDCMD
    if utils.META_OUTDIR not in meta:
      meta[utils.META_OUTDIR] = utils.DEFAULT_OUTDIR

    if utils.META_IMPORTS not in meta:
      meta[utils.META_IMPORTS] = defaultdict(dict)
    if utils.META_EXPORTS not in meta:
      meta[utils.META_EXPORTS] = defaultdict(dict)

    self.__metadata[component] = meta
    return True

  def __read_generated_metadata(self, timestamp, component):
    """ Read a metadata gerated by 'update-meta' build command from the soong build system

    Soong generate the metadata that has the information of import/export module/files.
    Build orchestrator read the generated metadata to collect the dependency information.

    Generated metadata has the following format:
    {
      "Imported": {
        "FileGroups": {
          "<name_of_filegroup>": [
            "<exported_module_name>",
            ...
          ],
          ...
        }
      }
      "Exported": {
        "<exported_module_name>": [
          "<output_file_path>",
          ...
        ],
        ...
      }
    }
    """
    if component not in self.__component_set:
      # skip reading generated metadata if the component metadata file was missing
      return False
    component_out = os.path.join(self.__component_top, component, self.__metadata[component][utils.META_OUTDIR])
    generated_metadata_file = os.path.join(component_out, 'soong', 'multitree', GENERATED_METADATA_FILE)
    if not os.path.isfile(generated_metadata_file):
      logging.info('... Soong did not generated the metadata file. Skip')
      return False
    if not self.__force_update and timestamp and timestamp > os.path.getmtime(generated_metadata_file):
      logging.info('... Soong generated metadata not changed. Skip')
      return False

    with open(generated_metadata_file, 'r') as gen_meta_json:
      try:
        gen_metadata = json.load(gen_meta_json)
      except json.decoder.JSONDecodeError:
        logging.warning('JSONDecodeError!!!: skip reading the {} file'.format(
            generated_metadata_file))
        return False

    if utils.SOONG_IMPORTED in gen_metadata:
      imported = gen_metadata[utils.SOONG_IMPORTED]
      if utils.SOONG_IMPORTED_FILEGROUPS in imported:
        self.__metadata[component][utils.META_IMPORTS][utils.META_FILEGROUP] = imported[utils.SOONG_IMPORTED_FILEGROUPS]
    if utils.SOONG_EXPORTED in gen_metadata:
      self.__metadata[component][utils.META_EXPORTS][utils.META_MODULES] = gen_metadata[utils.SOONG_EXPORTED]

    return True

  def __update_export_map(self):
    """ Read metadata of all components and update the export map

    'libraries' and 'APIs' are special exproted types that are provided manually
    from the .yaml metadata files. These need to be replaced with the implementation
    in soong gerated metadata.
    The export type 'module' is generated from the soong build system from the modules
    with 'export: true' property. This export type includes a dictionary with module
    names as keys and their output files as values. These output files will be used as
    prebuilt sources when generating the imported modules.
    """
    self.__map_exports = dict()
    for comp in self.__metadata:
      if utils.META_EXPORTS not in self.__metadata[comp]:
        continue
      exports = self.__metadata[comp][utils.META_EXPORTS]

      for export_type in exports:
        for module in exports[export_type]:
          if export_type == utils.META_LIBS:
            name = module[utils.META_LIB_NAME]
          else:
            name = module

          if name in self.__map_exports:
            raise RuntimeError(
                'Exported libs conflict!!!: "{name}" in the {comp} component is already exported by the {prev} component.'
                .format(name=name, comp=comp, prev=self.__map_exports[name][utils.EXP_COMPONENT]))
          exported_deps = ExportedDep(name, comp, export_type)
          if export_type == utils.META_MODULES:
            exported_deps.setOutputPaths(exports[export_type][module])
          self.__map_exports[name] = exported_deps

  def __verify_and_add_dependencies(self, component):
    """ Search all imported items from the export_map.

    If any imported items are not provided by the other components, report
    an error.
    Otherwise, add the component dependency and update the exported information to the
    import maps.
    """
    def verify_and_add_dependencies(imported_dep: ImportedDep):
      for module in imported_dep.imported_modules:
        if module not in self.__map_exports:
          raise RuntimeError(
              'Imported item not found!!!: Imported module "{module}" in the {comp} component is not exported from any other components.'
              .format(module=module, comp=imported_dep.component))
        imported_dep.verify_and_add(self.__map_exports[module])

        deps = self.__metadata[component][utils.META_DEPS]
        exp_comp = self.__map_exports[module].component
        if exp_comp not in deps:
          deps[exp_comp] = defaultdict(defaultdict)
        deps[exp_comp][imported_dep.type][imported_dep.name] = imported_dep.out_paths

    self.__metadata[component][utils.META_DEPS] = defaultdict()
    imports = self.__metadata[component][utils.META_IMPORTS]
    for import_type in imports:
      for module in imports[import_type]:
        verify_and_add_dependencies(ImportedDep(module, component, import_type, imports[import_type]))

  def __check_imports(self):
    """ Search the export map to find the component to import libraries or APIs.

    Update the 'deps' field that includes the dependent components.
    """
    for component in self.__metadata:
      self.__verify_and_add_dependencies(component)
      if utils.META_DEPS in self.__metadata[component]:
        logging.debug('{comp} depends on {list} components'.format(
            comp=component, list=self.__metadata[component][utils.META_DEPS]))

  def __update_dependencies(self):
    """ Generate a dependency graph for the components

    Update __map_exports and the dependency graph with the maps.
    """
    self.__update_export_map()
    self.__check_imports()

  def __store_metadata(self):
    """ Store the __metadata dictionary as json format"""
    with open(self.__combined_metadata_path, 'w') as json_file:
      json.dump(self.__metadata, json_file, indent=2)

  def __restore_metadata(self):
    """ Read the stored json file and return the time stamps of the

        metadata file.
        """
    if not os.path.exists(self.__combined_metadata_path):
      return None

    with open(self.__combined_metadata_path, 'r') as json_file:
      try:
        self.__metadata = json.load(json_file)
      except json.decoder.JSONDecodeError:
        logging.warning('JSONDecodeError!!!: skip reading the {} file'.format(
            self.__combined_metadata_path))
        return None

    logging.info('Metadata restored from {}'.format(
        self.__combined_metadata_path))
    self.__update_export_map()
    return os.path.getmtime(self.__combined_metadata_path)


def get_args():

  def check_dir(path):
    if os.path.exists(path) and os.path.isdir(path):
      return os.path.normpath(path)
    else:
      raise argparse.ArgumentTypeError('\"{}\" is not a directory'.format(path))

  parser = argparse.ArgumentParser()
  parser.add_argument(
      '--component-top',
      help='Scan all components under this directory.',
      default=os.path.join(os.path.dirname(__file__), '../../../components'),
      type=check_dir)
  parser.add_argument(
      '--meta-file',
      help='Name of the metadata file.',
      default=COMPONENT_METADATA_FILE,
      type=str)
  parser.add_argument(
      '--meta-dir',
      help='Each component has the metadata in this directory.',
      default=COMPONENT_METADATA_DIR,
      type=str)
  parser.add_argument(
      '--out-dir',
      help='Out dir for the outer tree. The orchestrator stores the collected metadata in this directory.',
      default=os.path.join(os.path.dirname(__file__), '../../../out'),
      type=os.path.normpath)
  parser.add_argument(
      '--force',
      '-f',
      action='store_true',
      help='Force to collect metadata',
  )
  parser.add_argument(
      '--verbose',
      '-v',
      help='Increase output verbosity, e.g. "-v", "-vv".',
      action='count',
      default=0)
  return parser.parse_args()


def main():
  args = get_args()
  utils.set_logging_config(args.verbose)

  metadata_collector = MetadataCollector(args.component_top, args.out_dir,
                                         args.meta_dir, args.meta_file, args.force)
  metadata_collector.collect()


if __name__ == '__main__':
  main()
