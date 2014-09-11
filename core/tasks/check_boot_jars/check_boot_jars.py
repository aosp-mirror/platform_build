#!/usr/bin/env python

"""
Check boot jars.

Usage: check_boot_jars.py <package_whitelist_file> <jar1> <jar2> ...
"""
import logging
import os.path
import re
import subprocess
import sys


# The compiled whitelist RE.
whitelist_re = None


def LoadWhitelist(filename):
  """ Load and compile whitelist regular expressions from filename.
  """
  lines = []
  with open(filename, 'r') as f:
    for line in f:
      line = line.strip()
      if not line or line.startswith('#'):
        continue
      lines.append(line)
  combined_re = r'^(%s)$' % '|'.join(lines)
  global whitelist_re
  try:
    whitelist_re = re.compile(combined_re)
  except re.error:
    logging.exception(
        'Cannot compile package whitelist regular expression: %r',
        combined_re)
    whitelist_re = None
    return False
  return True


def CheckJar(jar):
  """Check a jar file.
  """
  # Get the list of files inside the jar file.
  p = subprocess.Popen(args='jar tf %s' % jar,
      stdout=subprocess.PIPE, shell=True)
  stdout, _ = p.communicate()
  if p.returncode != 0:
    return False
  items = stdout.split()
  for f in items:
    if f.endswith('.class'):
      package_name = os.path.dirname(f)
      package_name = package_name.replace('/', '.')
      # Skip class without a package name
      if package_name and not whitelist_re.match(package_name):
        print >> sys.stderr, ('Error: %s: unknown package name of class file %s'
                              % (jar, f))
        return False
  return True


def main(argv):
  if len(argv) < 2:
    print __doc__
    sys.exit(1)

  if not LoadWhitelist(argv[0]):
    sys.exit(1)

  passed = True
  for jar in argv[1:]:
    if not CheckJar(jar):
      passed = False
  if not passed:
    return 1

  return 0


if __name__ == '__main__':
  main(sys.argv[1:])
