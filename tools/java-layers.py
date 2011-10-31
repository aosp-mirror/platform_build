#!/usr/bin/env python

import os
import re
import sys

def fail_with_usage():
  sys.stderr.write("usage: java-layers.py DEPENDENCY_FILE SOURCE_DIRECTORIES...\n")
  sys.stderr.write("\n")
  sys.stderr.write("Enforces layering between java packages.  Scans\n")
  sys.stderr.write("DIRECTORY and prints errors when the packages violate\n")
  sys.stderr.write("the rules defined in the DEPENDENCY_FILE.\n")
  sys.stderr.write("\n")
  sys.stderr.write("Prints a warning when an unknown package is encountered\n")
  sys.stderr.write("on the assumption that it should fit somewhere into the\n")
  sys.stderr.write("layering.\n")
  sys.stderr.write("\n")
  sys.stderr.write("DEPENDENCY_FILE format\n")
  sys.stderr.write("  - # starts comment\n")
  sys.stderr.write("  - Lines consisting of two java package names:  The\n")
  sys.stderr.write("    first package listed must not contain any references\n")
  sys.stderr.write("    to any classes present in the second package, or any\n")
  sys.stderr.write("    of its dependencies.\n")
  sys.stderr.write("  - Lines consisting of one java package name:  The\n")
  sys.stderr.write("    packge is assumed to be a high level package and\n")
  sys.stderr.write("    nothing may depend on it.\n")
  sys.stderr.write("  - Lines consisting of a dash (+) followed by one java\n")
  sys.stderr.write("    package name: The package is considered a low level\n")
  sys.stderr.write("    package and may not import any of the other packages\n")
  sys.stderr.write("    listed in the dependency file.\n")
  sys.stderr.write("  - Lines consisting of a plus (-) followed by one java\n")
  sys.stderr.write("    package name: The package is considered \'legacy\'\n")
  sys.stderr.write("    and excluded from errors.\n")
  sys.stderr.write("\n")
  sys.exit(1)

class Dependency:
  def __init__(self, filename, lineno, lower, top, lowlevel, legacy):
    self.filename = filename
    self.lineno = lineno
    self.lower = lower
    self.top = top
    self.lowlevel = lowlevel
    self.legacy = legacy
    self.uppers = []
    self.transitive = set()

  def matches(self, imp):
    for d in self.transitive:
      if imp.startswith(d):
        return True
    return False

class Dependencies:
  def __init__(self, deps):
    def recurse(obj, dep, visited):
      global err
      if dep in visited:
        sys.stderr.write("%s:%d: Circular dependency found:\n"
            % (dep.filename, dep.lineno))
        for v in visited:
          sys.stderr.write("%s:%d:    Dependency: %s\n"
              % (v.filename, v.lineno, v.lower))
        err = True
        return
      visited.append(dep)
      for upper in dep.uppers:
        obj.transitive.add(upper)
        if upper in deps:
          recurse(obj, deps[upper], visited)
    self.deps = deps
    self.parts = [(dep.lower.split('.'),dep) for dep in deps.itervalues()]
    # transitive closure of dependencies
    for dep in deps.itervalues():
      recurse(dep, dep, [])
    # disallow everything from the low level components
    for dep in deps.itervalues():
      if dep.lowlevel:
        for d in deps.itervalues():
          if dep != d and not d.legacy:
            dep.transitive.add(d.lower)
    # disallow the 'top' components everywhere but in their own package
    for dep in deps.itervalues():
      if dep.top and not dep.legacy:
        for d in deps.itervalues():
          if dep != d and not d.legacy:
            d.transitive.add(dep.lower)
    for dep in deps.itervalues():
      dep.transitive = set([x+"." for x in dep.transitive])
    if False:
      for dep in deps.itervalues():
        print "-->", dep.lower, "-->", dep.transitive

  # Lookup the dep object for the given package.  If pkg is a subpackage
  # of one with a rule, that one will be returned.  If no matches are found,
  # None is returned.
  def lookup(self, pkg):
    # Returns the number of parts that match
    def compare_parts(parts, pkg):
      if len(parts) > len(pkg):
        return 0
      n = 0
      for i in range(0, len(parts)):
        if parts[i] != pkg[i]:
          return 0
        n = n + 1
      return n
    pkg = pkg.split(".")
    matched = 0
    result = None
    for (parts,dep) in self.parts:
      x = compare_parts(parts, pkg)
      if x > matched:
        matched = x
        result = dep
    return result

def parse_dependency_file(filename):
  global err
  f = file(filename)
  lines = f.readlines()
  f.close()
  def lineno(s, i):
    i[0] = i[0] + 1
    return (i[0],s)
  n = [0]
  lines = [lineno(x,n) for x in lines]
  lines = [(n,s.split("#")[0].strip()) for (n,s) in lines]
  lines = [(n,s) for (n,s) in lines if len(s) > 0]
  lines = [(n,s.split()) for (n,s) in lines]
  deps = {}
  for n,words in lines:
    if len(words) == 1:
      lower = words[0]
      top = True
      legacy = False
      lowlevel = False
      if lower[0] == '+':
        lower = lower[1:]
        top = False
        lowlevel = True
      elif lower[0] == '-':
        lower = lower[1:]
        legacy = True
      if lower in deps:
        sys.stderr.write(("%s:%d: Package '%s' already defined on"
            + " line %d.\n") % (filename, n, lower, deps[lower].lineno))
        err = True
      else:
        deps[lower] = Dependency(filename, n, lower, top, lowlevel, legacy)
    elif len(words) == 2:
      lower = words[0]
      upper = words[1]
      if lower in deps:
        dep = deps[lower]
        if dep.top:
          sys.stderr.write(("%s:%d: Can't add dependency to top level package "
            + "'%s'\n") % (filename, n, lower))
          err = True
      else:
        dep = Dependency(filename, n, lower, False, False, False)
        deps[lower] = dep
      dep.uppers.append(upper)
    else:
      sys.stderr.write("%s:%d: Too many words on line starting at \'%s\'\n" % (
          filename, n, words[2]))
      err = True
  return Dependencies(deps)

def find_java_files(srcs):
  result = []
  for d in srcs:
    if d[0] == '@':
      f = file(d[1:])
      result.extend([fn for fn in [s.strip() for s in f.readlines()]
          if len(fn) != 0])
      f.close()
    else:
      for root, dirs, files in os.walk(d):
        result.extend([os.sep.join((root,f)) for f in files
            if f.lower().endswith(".java")])
  return result

COMMENTS = re.compile("//.*?\n|/\*.*?\*/", re.S)
PACKAGE = re.compile("package\s+(.*)")
IMPORT = re.compile("import\s+(.*)")

def examine_java_file(deps, filename):
  global err
  # Yes, this is a crappy java parser.  Write a better one if you want to.
  f = file(filename)
  text = f.read()
  f.close()
  text = COMMENTS.sub("", text)
  index = text.find("{")
  if index < 0:
    sys.stderr.write(("%s: Error: Unable to parse java. Can't find class "
        + "declaration.\n") % filename)
    err = True
    return
  text = text[0:index]
  statements = [s.strip() for s in text.split(";")]
  # First comes the package declaration.  Then iterate while we see import
  # statements.  Anything else is either bad syntax that we don't care about
  # because the compiler will fail, or the beginning of the class declaration.
  m = PACKAGE.match(statements[0])
  if not m:
    sys.stderr.write(("%s: Error: Unable to parse java. Missing package "
        + "statement.\n") % filename)
    err = True
    return
  pkg = m.group(1)
  imports = []
  for statement in statements[1:]:
    m = IMPORT.match(statement)
    if not m:
      break
    imports.append(m.group(1))
  # Do the checking
  if False:
    print filename
    print "'%s' --> %s" % (pkg, imports)
  dep = deps.lookup(pkg)
  if not dep:
    sys.stderr.write(("%s: Error: Package does not appear in dependency file: "
      + "%s\n") % (filename, pkg))
    err = True
    return
  for imp in imports:
    if dep.matches(imp):
      sys.stderr.write("%s: Illegal import in package '%s' of '%s'\n"
          % (filename, pkg, imp))
      err = True

err = False

def main(argv):
  if len(argv) < 3:
    fail_with_usage()
  deps = parse_dependency_file(argv[1])

  if err:
    sys.exit(1)

  java = find_java_files(argv[2:])
  for filename in java:
    examine_java_file(deps, filename)

  if err:
    sys.stderr.write("%s: Using this file as dependency file.\n" % argv[1])
    sys.exit(1)

  sys.exit(0)

if __name__ == "__main__":
  main(sys.argv)

