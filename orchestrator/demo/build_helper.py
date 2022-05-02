#!/usr/bin/env python3
# Copyright (C) 2022 The Android Open Source Project
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

import collections
import copy
import hierarchy
import json
import logging
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile
import collect_metadata
import utils

BUILD_CMD_TO_ALL = (
  'clean',
  'installclean',
  'update-meta',
)
BUILD_ALL_EXEMPTION = (
  'art',
)

def get_supported_product(ctx, supported_products):
  hierarchy_map = hierarchy.parse_hierarchy(ctx.build_top())
  target = ctx.target_product()

  while target not in supported_products:
    if target not in hierarchy_map:
      return None
    target = hierarchy_map[target]
  return target


def parse_goals(ctx, metadata, goals):
  """Parse goals and returns a map from each component to goals.

    e.g.

    "m main art timezone:foo timezone:bar" will return the following dict: {
        "main": {"all"},
        "art": {"all"},
        "timezone": {"foo", "bar"},
    }
  """
  # for now, goal should look like:
  # {component} or {component}:{subgoal}

  ret = collections.defaultdict(set)

  for goal in goals:
    # check if the command is for all components
    if goal in BUILD_CMD_TO_ALL:
      ret['all'].add(goal)
      continue

    # should be {component} or {component}:{subgoal}
    try:
      component, subgoal = goal.split(':') if ':' in goal else (goal, 'all')
    except ValueError:
      raise RuntimeError(
          'unknown goal: %s: should be {component} or {component}:{subgoal}' %
          goal)
    if component not in metadata:
      raise RuntimeError('unknown goal: %s: component %s not found' %
                         (goal, component))
    if not get_supported_product(ctx, metadata[component]['lunch_targets']):
      raise RuntimeError("can't find matching target. Supported targets are: " +
                         str(metadata[component]['lunch_targets']))

    ret[component].add(subgoal)

  return ret


def find_cycle(metadata):
  """ Finds a cyclic dependency among components.

  This is for debugging.
  """
  visited = set()
  parent_node = dict()
  in_stack = set()

  # Returns a cycle if one is found
  def dfs(node):
    # visit_order[visit_time[node] - 1] == node
    nonlocal visited, parent_node, in_stack

    visited.add(node)
    in_stack.add(node)
    if 'deps' not in metadata[node]:
      in_stack.remove(node)
      return None
    for next in metadata[node]['deps']:
      # We found a cycle (next ~ node) if next is still in the stack
      if next in in_stack:
        cycle = [node]
        while cycle[-1] != next:
          cycle.append(parent_node[cycle[-1]])
        return cycle

      # Else, continue searching
      if next in visited:
        continue

      parent_node[next] = node
      result = dfs(next)
      if result:
        return result

    in_stack.remove(node)
    return None

  for component in metadata:
    if component in visited:
      continue

    result = dfs(component)
    if result:
      return result

  return None


def topological_sort_components(metadata):
  """ Performs topological sort on components.

  If A depends on B, B appears first.
  """
  # If A depends on B, we want B to appear before A. But the graph in metadata
  # is represented as A -> B (B in metadata[A]['deps']). So we sort in the
  # reverse order, and then reverse the result again to get the desired order.
  indegree = collections.defaultdict(int)
  for component in metadata:
    if 'deps' not in metadata[component]:
      continue
    for dep in metadata[component]['deps']:
      indegree[dep] += 1

  component_queue = collections.deque()
  for component in metadata:
    if indegree[component] == 0:
      component_queue.append(component)

  result = []
  while component_queue:
    component = component_queue.popleft()
    result.append(component)
    if 'deps' not in metadata[component]:
      continue
    for dep in metadata[component]['deps']:
      indegree[dep] -= 1
      if indegree[dep] == 0:
        component_queue.append(dep)

  # If topological sort fails, there must be a cycle.
  if len(result) != len(metadata):
    cycle = find_cycle(metadata)
    raise RuntimeError('circular dependency found among metadata: %s' % cycle)

  return result[::-1]


def add_dependency_goals(ctx, metadata, component, goals):
  """ Adds goals that given component depends on."""
  # For now, let's just add "all"
  # TODO: add detailed goals (e.g. API build rules, library build rules, etc.)
  if 'deps' not in metadata[component]:
    return

  for dep in metadata[component]['deps']:
    goals[dep].add('all')


def sorted_goals_with_dependencies(ctx, metadata, parsed_goals):
  """ Analyzes the dependency graph among components, adds build commands for

  dependencies, and then sorts the goals.

  Returns a list of tuples: (component_name, set of subgoals).
  Builds should be run in the list's order.
  """
  # TODO(inseob@): after topological sort, some components may be built in
  # parallel.

  topological_order = topological_sort_components(metadata)
  combined_goals = copy.deepcopy(parsed_goals)

  # Add build rules for each component's dependencies
  # We do this in reverse order, so it can be transitive.
  # e.g. if A depends on B and B depends on C, and we build A,
  # C should also be built, in addition to B.
  for component in topological_order[::-1]:
    if component in combined_goals:
      add_dependency_goals(ctx, metadata, component, combined_goals)

  ret = []
  for component in ['all'] + topological_order:
    if component in combined_goals:
      ret.append((component, combined_goals[component]))

  return ret


def run_build(ctx, metadata, component, subgoals):
  build_cmd = metadata[component]['build_cmd']
  out_dir = metadata[component]['out_dir']
  default_goals = ''
  if 'default_goals' in metadata[component]:
    default_goals = metadata[component]['default_goals']

  if 'all' in subgoals:
    goal = default_goals
  else:
    goal = ' '.join(subgoals)

  build_vars = ''
  if 'update-meta' in subgoals:
    build_vars = 'TARGET_MULTITREE_UPDATE_META=true'
  # TODO(inseob@): shell escape
  cmd = [
      '/bin/bash', '-c',
      'source build/envsetup.sh && lunch %s-%s && %s %s %s' %
      (get_supported_product(ctx, metadata[component]['lunch_targets']),
       ctx.target_build_variant(), build_vars, build_cmd, goal)
  ]
  logging.debug('cwd: ' + metadata[component]['path'])
  logging.debug('running build: ' + str(cmd))

  subprocess.run(cmd, cwd=metadata[component]['path'], check=True)


def run_build_all(ctx, metadata, subgoals):
  for component in metadata:
    if component in BUILD_ALL_EXEMPTION:
      continue
    run_build(ctx, metadata, component, subgoals)


def find_components(metadata, predicate):
  for component in metadata:
    if predicate(component):
      yield component


def import_filegroups(metadata, component, exporting_component, target_file_pairs):
  imported_filegroup_dir = os.path.join(metadata[component]['path'], 'imported', exporting_component)

  bp_content = ''
  for name, outpaths in target_file_pairs:
    bp_content += ('filegroup {{\n'
                   '    name: "{fname}",\n'
                   '    srcs: [\n'.format(fname=name))
    for outpath in outpaths:
      bp_content += '        "{outfile}",\n'.format(outfile=os.path.basename(outpath))
    bp_content += ('    ],\n'
                   '}\n')

    with tempfile.TemporaryDirectory() as tmp_dir:
      with open(os.path.join(tmp_dir, 'Android.bp'), 'w') as fout:
        fout.write(bp_content)
      for _, outpaths in target_file_pairs:
        for outpath in outpaths:
          os.symlink(os.path.join(metadata[exporting_component]['path'], outpath),
                    os.path.join(tmp_dir, os.path.basename(outpath)))
      cmp_result = filecmp.dircmp(tmp_dir, imported_filegroup_dir)
      if os.path.exists(imported_filegroup_dir) and len(
          cmp_result.left_only) + len(cmp_result.right_only) + len(
              cmp_result.diff_files) == 0:
        # Files are identical, it doesn't need to be written
        logging.info(
            'imported files exists and the contents are identical: {} -> {}'
            .format(component, exporting_component))
        continue
      logging.info('creating symlinks for imported files: {} -> {}'.format(
          component, exporting_component))
      os.makedirs(imported_filegroup_dir, exist_ok=True)
      shutil.rmtree(imported_filegroup_dir, ignore_errors=True)
      shutil.move(tmp_dir, imported_filegroup_dir)


def prepare_build(metadata, component):
  imported_dir = os.path.join(metadata[component]['path'], 'imported')
  if utils.META_DEPS not in metadata[component]:
    if os.path.exists(imported_dir):
      logging.debug('remove {}'.format(imported_dir))
      shutil.rmtree(imported_dir)
    return

  imported_components = set()
  for exp_comp in metadata[component][utils.META_DEPS]:
    if utils.META_FILEGROUP in metadata[component][utils.META_DEPS][exp_comp]:
      filegroups = metadata[component][utils.META_DEPS][exp_comp][utils.META_FILEGROUP]
      target_file_pairs = []
      for name in filegroups:
        target_file_pairs.append((name, filegroups[name]))
      import_filegroups(metadata, component, exp_comp, target_file_pairs)
      imported_components.add(exp_comp)

  # Remove directories that are not generated this time.
  if os.path.exists(imported_dir):
    if len(imported_components) == 0:
      shutil.rmtree(imported_dir)
    else:
      for remove_target in set(os.listdir(imported_dir)) - imported_components:
        logging.info('remove unnecessary imported dir: {}'.format(remove_target))
        shutil.rmtree(os.path.join(imported_dir, remove_target))


def main():
  utils.set_logging_config(logging.DEBUG)
  ctx = utils.get_build_context()

  logging.info('collecting metadata')

  utils.set_logging_config(True)

  goals = sys.argv[1:]
  if not goals:
    logging.debug('empty goals. defaults to main')
    goals = ['main']

  logging.debug('goals: ' + str(goals))

  # Force update the metadata for the 'update-meta' build
  metadata_collector = collect_metadata.MetadataCollector(
      ctx.components_top(), ctx.out_dir(),
      collect_metadata.COMPONENT_METADATA_DIR,
      collect_metadata.COMPONENT_METADATA_FILE,
      force_update='update-meta' in goals)
  metadata_collector.collect()

  metadata = metadata_collector.get_metadata()
  logging.debug('metadata: ' + str(metadata))

  parsed_goals = parse_goals(ctx, metadata, goals)
  logging.debug('parsed goals: ' + str(parsed_goals))

  sorted_goals = sorted_goals_with_dependencies(ctx, metadata, parsed_goals)
  logging.debug('sorted goals with deps: ' + str(sorted_goals))

  for component, subgoals in sorted_goals:
    if component == 'all':
      run_build_all(ctx, metadata, subgoals)
      continue
    prepare_build(metadata, component)
    run_build(ctx, metadata, component, subgoals)


if __name__ == '__main__':
  main()
