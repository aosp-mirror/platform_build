#!/usr/bin/env python3

#
# Run from the root of the tree, after product-config has been run to see
# the product inheritance hierarchy for the current lunch target.
#

import csv
import sys

def PrintNodes(graph, node, prefix):
  sys.stdout.write("%s%s" % (prefix, node))
  children = graph.get(node, [])
  if children:
    sys.stdout.write(" {\n")
    for child in sorted(graph.get(node, [])):
      PrintNodes(graph, child, prefix + "  ")
    sys.stdout.write("%s}\n" % prefix);
  else:
    sys.stdout.write("\n")

def main(argv):
  if len(argv) != 2:
    print("usage: inherit_tree.py out/$TARGET_PRODUCT-$TARGET_BUILD_VARIANT/dumpconfig.csv")
    sys.exit(1)

  root = None
  graph = {}
  with open(argv[1], newline='') as csvfile:
    for line in csv.reader(csvfile):
      if not root:
        # Look for PRODUCTS
        if len(line) < 3 or line[0] != "phase" or line[1] != "PRODUCTS":
          continue
        root = line[2]
      else:
        # Everything else
        if len(line) < 3 or line[0] != "inherit":
          continue
        graph.setdefault(line[1], list()).append(line[2])

  PrintNodes(graph, root, "")


if __name__ == "__main__":
  main(sys.argv)

# vim: set expandtab ts=2 sw=2 sts=2:

