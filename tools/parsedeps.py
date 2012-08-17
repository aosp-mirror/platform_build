#!/usr/bin/env python
# vim: ts=2 sw=2

import optparse
import re
import sys


class Dependency:
  def __init__(self, tgt):
    self.tgt = tgt
    self.pos = ""
    self.prereqs = set()
    self.visit = 0

  def add(self, prereq):
    self.prereqs.add(prereq)


class Dependencies:
  def __init__(self):
    self.lines = {}
    self.__visit = 0
    self.count = 0

  def add(self, tgt, prereq):
    t = self.lines.get(tgt)
    if not t:
      t = Dependency(tgt)
      self.lines[tgt] = t
    p = self.lines.get(prereq)
    if not p:
      p = Dependency(prereq)
      self.lines[prereq] = p
    t.add(p)
    self.count = self.count + 1

  def setPos(self, tgt, pos):
    t = self.lines.get(tgt)
    if not t:
      t = Dependency(tgt)
      self.lines[tgt] = t
    t.pos = pos

  def get(self, tgt):
    if self.lines.has_key(tgt):
      return self.lines[tgt]
    else:
      return None

  def __iter__(self):
    return self.lines.iteritems()

  def trace(self, tgt, prereq):
    self.__visit = self.__visit + 1
    d = self.lines.get(tgt)
    if not d:
      return
    return self.__trace(d, prereq)

  def __trace(self, d, prereq):
    if d.visit == self.__visit:
      return d.trace
    if d.tgt == prereq:
      return [ [ d ], ]
    d.visit = self.__visit
    result = []
    for pre in d.prereqs:
      recursed = self.__trace(pre, prereq)
      for r in recursed:
        result.append([ d ] + r)
    d.trace = result
    return result

def help():
  print "Commands:"
  print "  dep TARGET             Print the prerequisites for TARGET"
  print "  trace TARGET PREREQ    Print the paths from TARGET to PREREQ"


def main(argv):
  opts = optparse.OptionParser()
  opts.add_option("-i", "--interactive", action="store_true", dest="interactive",
                    help="Interactive mode")
  (options, args) = opts.parse_args()

  deps = Dependencies()

  filename = args[0]
  print "Reading %s" % filename

  if True:
    f = open(filename)
    for line in f:
      line = line.strip()
      if len(line) > 0:
        if line[0] == '#':
          pos,tgt = line.rsplit(":", 1)
          pos = pos[1:].strip()
          tgt = tgt.strip()
          deps.setPos(tgt, pos)
        else:
          (tgt,prereq) = line.split(':', 1)
          tgt = tgt.strip()
          prereq = prereq.strip()
          deps.add(tgt, prereq)
    f.close()

  print "Read %d dependencies. %d targets." % (deps.count, len(deps.lines))
  while True:
    line = raw_input("target> ")
    if not line.strip():
      continue
    split = line.split()
    cmd = split[0]
    if len(split) == 2 and cmd == "dep":
      tgt = split[1]
      d = deps.get(tgt)
      if d:
        for prereq in d.prereqs:
          print prereq.tgt
    elif len(split) == 3 and cmd == "trace":
      tgt = split[1]
      prereq = split[2]
      if False:
        print "from %s to %s" % (tgt, prereq)
      trace = deps.trace(tgt, prereq)
      if trace:
        width = 0
        for g in trace:
          for t in g:
            if len(t.tgt) > width:
              width = len(t.tgt)
        for g in trace:
          for t in g:
            if t.pos:
              print t.tgt, " " * (width-len(t.tgt)), "  #", t.pos
            else:
              print t.tgt
          print
    else:
      help()

if __name__ == "__main__":
  try:
    main(sys.argv)
  except KeyboardInterrupt:
    print
  except EOFError:
    print

