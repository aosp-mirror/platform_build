#!/usr/bin/env python
# vim: ts=2 sw=2 nocindent

import re
import sys

def choose_regex(regs, line):
  for func,reg in regs:
    m = reg.match(line)
    if m:
      return (func,m)
  return (None,None)

def gather(included, deps):
  result = set()
  for inc in included:
    result.add(inc)
    for d in deps:
      if inc == d[1]:
        result.add(d[0])
  return result

def main():
  deps = []
  infos = []
  def dependency(m):
    deps.append((m.group(1), m.group(2)))
  def info(m):
    infos.append((m.group(1), m.group(2)))

  REGS = [
      (dependency, re.compile(r'"(.*)"\s*->\s*"(.*)"')), 
      (info, re.compile(r'"(.*)"(\s*\[.*\])')), 
    ]

  lines = sys.stdin.readlines()
  lines = [line.strip() for line in lines]

  for line in lines:
    func,m = choose_regex(REGS, line)
    if func:
      func(m)

  # filter
  sys.stderr.write("argv: " + str(sys.argv) + "\n")
  if not (len(sys.argv) == 2 and sys.argv[1] == "--all"):
    targets = sys.argv[1:]

    included = set(targets)
    prevLen = -1
    while prevLen != len(included):
      prevLen = len(included)
      included = gather(included, deps)

    deps = [dep for dep in deps if dep[1] in included]
    infos = [info for info in infos if info[0] in included]

  print "digraph {"
  print "graph [ ratio=.5 ];"
  for dep in deps:
    print '"%s" -> "%s"' % dep
  for info in infos:
    print '"%s"%s' % info
  print "}"


if __name__ == "__main__":
  main()
