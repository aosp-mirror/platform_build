#!/usr/bin/env python

"""
Check boot jars.

Usage: check_boot_jars.py <package_allow_list_file> <jar1> <jar2> ...
"""
import logging
import os.path
import re
import subprocess
import sys


# The compiled allow list RE.
allow_list_re = None


def LoadAllowList(filename):
  """ Load and compile allow list regular expressions from filename.
  """
  lines = []
  with open(filename, 'r') as f:
    for line in f:
      line = line.strip()
      if not line or line.startswith('#'):
        continue
      lines.append(line)
  combined_re = r'^(%s)$' % '|'.join(lines)
  global allow_list_re
  try:
    allow_list_re = re.compile(combined_re)
  except re.error:
    logging.exception(
        'Cannot compile package allow list regular expression: %r',
        combined_re)
    allow_list_re = None
    return False
  return True


def CheckJar(allow_list_path, jar):
  """Check a jar file.
  """
  # Get the list of files inside the jar file.
  p = subprocess.Popen(args='jar tf %s' % jar,
      stdout=subprocess.PIPE, shell=True)
  stdout, _ = p.communicate()
  if p.returncode != 0:
    return False
  items = stdout.split()
  classes = 0
  for f in items:
    if f.endswith('.class'):
      classes += 1
      package_name = os.path.dirname(f)
      package_name = package_name.replace('/', '.')
      if not package_name or not allow_list_re.match(package_name):
        print >> sys.stderr, ('Error: %s contains class file %s, whose package name %s is empty or'
                              ' not in the allow list %s of packages allowed on the bootclasspath.'
                              % (jar, f, package_name, allow_list_path))
        return False
  if classes == 0:
    print >> sys.stderr, ('Error: %s does not contain any class files.' % jar)
    return False
  return True


def main(argv):
  if len(argv) < 2:
    print __doc__
    return 1
  allow_list_path = argv[0]

  if not LoadAllowList(allow_list_path):
    return 1

  passed = True
  for jar in argv[1:]:
    if not CheckJar(allow_list_path, jar):
      passed = False
  if not passed:
    return 1

  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
