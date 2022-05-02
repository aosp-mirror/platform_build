#!/usr/bin/env python3
import os
import sys
import yaml

from hierarchy import parse_hierarchy


def main():
  if len(sys.argv) != 2:
    print('usage: %s target' % sys.argv[0])
    exit(1)

  args = sys.argv[1].split('-')
  if len(args) != 2:
    print('target format: {target}-{variant}')
    exit(1)

  target, variant = args

  if variant not in ['eng', 'user', 'userdebug']:
    print('unknown variant "%s": expected "eng", "user" or "userdebug"' %
          variant)
    exit(1)

  build_top = os.getenv('BUFFET_BUILD_TOP')
  if not build_top:
    print('BUFFET_BUILD_TOP is not set; Did you correctly run envsetup.sh?')
    exit(1)

  hierarchy_map = parse_hierarchy(build_top)

  if target not in hierarchy_map:
    raise RuntimeError(
        "unknown target '%s': couldn't find the target. Supported targets are: %s"
        % (target, list(hierarchy_map.keys())))

  hierarchy = [target]
  while hierarchy_map[hierarchy[-1]]:
    hierarchy.append(hierarchy_map[hierarchy[-1]])

  print('Target hierarchy for %s: %s' % (target, hierarchy))


if __name__ == '__main__':
  main()
