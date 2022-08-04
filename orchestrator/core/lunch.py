#!/usr/bin/python3
#
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

import argparse
import glob
import json
import os
import sys

EXIT_STATUS_OK = 0
EXIT_STATUS_ERROR = 1
EXIT_STATUS_NEED_HELP = 2


def find_dirs(path, name, ttl=6):
    """Search at most ttl directories deep inside path for a directory called name
    and yield directories that match."""
    # The dance with subdirs is so that we recurse in sorted order.
    subdirs = []
    with os.scandir(path) as it:
        for dirent in sorted(it, key=lambda x: x.name):
            try:
                if dirent.is_dir():
                    if dirent.name == name:
                        yield os.path.join(path, dirent.name)
                    elif ttl > 0:
                        subdirs.append(dirent.name)
            except OSError:
                # Consume filesystem errors, e.g. too many links, permission etc.
                pass
    for subdir in subdirs:
        yield from find_dirs(os.path.join(path, subdir), name, ttl-1)


def walk_paths(path, matcher, ttl=10):
    """Do a traversal of all files under path yielding each file that matches
    matcher."""
    # First look for files, then recurse into directories as needed.
    # The dance with subdirs is so that we recurse in sorted order.
    subdirs = []
    with os.scandir(path) as it:
        for dirent in sorted(it, key=lambda x: x.name):
            try:
                if dirent.is_file():
                    if matcher(dirent.name):
                        yield os.path.join(path, dirent.name)
                if dirent.is_dir():
                    if ttl > 0:
                        subdirs.append(dirent.name)
            except OSError:
                # Consume filesystem errors, e.g. too many links, permission etc.
                pass
    for subdir in sorted(subdirs):
        yield from walk_paths(os.path.join(path, subdir), matcher, ttl-1)


def find_file(path, filename):
    """Return a file called filename inside path, no more than ttl levels deep.

    Directories are searched alphabetically.
    """
    for f in walk_paths(path, lambda x: x == filename):
        return f

# TODO: When orchestrator is in its own git project remove the "build" and "make" here
class LunchContext(object):
    """Mockable container for lunch"""
    def __init__(self, workspace_root, orchestrator_path_prefix_components=["build", "build", "make"]):
      self.workspace_root = workspace_root
      self.orchestrator_path_prefix_components = orchestrator_path_prefix_components

def find_config_dirs(context):
    """Find the configuration files in the well known locations inside workspace_root

        <workspace_root>/<orchestrator>/<path>/<prefix>/orchestrator/multitree_combos
           (AOSP devices, such as cuttlefish)

        <workspace_root>/vendor/**/multitree_combos
            (specific to a vendor and not open sourced)

        <workspace_root>/device/**/multitree_combos
            (specific to a vendor and are open sourced)

    Directories are returned specifically in this order, so that aosp can't be
    overridden, but vendor overrides device.
    """
    # TODO: This is not looking in inner trees correctly.

    yield os.path.join(context.workspace_root, *context.orchestrator_path_prefix_components, "orchestrator/multitree_combos")

    dirs = ["vendor", "device"]
    for d in dirs:
        yield from find_dirs(os.path.join(context.workspace_root, d), "multitree_combos")


def find_named_config(context, shortname):
    """Find the config with the given shortname inside context.workspace_root.

    Config directories are searched in the order described in find_config_dirs,
    and inside those directories, alphabetically."""
    filename = shortname + ".mcombo"
    for config_dir in find_config_dirs(context):
        found = find_file(config_dir, filename)
        if found:
            return found
    return None


def parse_product_variant(s):
    """Split a PRODUCT-VARIANT name, or return None if it doesn't match that pattern."""
    split = s.split("-")
    if len(split) != 2:
        return None
    return split


def choose_config_from_args(context, args):
    """Return the config file we should use for the given argument,
    or null if there's no file that matches that."""
    if len(args) == 1:
        # Prefer PRODUCT-VARIANT syntax so if there happens to be a matching
        # file we don't match that.
        pv = parse_product_variant(args[0])
        if pv:
            config = find_named_config(context, pv[0])
            if config:
                return (config, pv[1])
            return None, None
    # Look for a specifically named file
    if os.path.isfile(args[0]):
        return (args[0], args[1] if len(args) > 1 else None)
    # That file didn't exist, return that we didn't find it.
    return None, None


class ConfigException(Exception):
    ERROR_IDENTIFY = "identify"
    ERROR_PARSE = "parse"
    ERROR_CYCLE = "cycle"
    ERROR_VALIDATE = "validate"

    def __init__(self, kind, message, locations=[], line=0):
        """Error thrown when loading and parsing configurations.

        Args:
            message: Error message to display to user
            locations: List of filenames of the include history.  The 0 index one
                       the location where the actual error occurred
        """
        if len(locations):
            s = locations[0]
            if line:
                s += ":"
                s += str(line)
            s += ": "
        else:
            s = ""
        s += message
        if len(locations):
            for loc in locations[1:]:
                s += "\n        included from %s" % loc
        super().__init__(s)
        self.kind = kind
        self.message = message
        self.locations = locations
        self.line = line


def load_config(filename):
    """Load a config, including processing the inherits fields.

    Raises:
        ConfigException on errors
    """
    def load_and_merge(fn, visited):
        with open(fn) as f:
            try:
                contents = json.load(f)
            except json.decoder.JSONDecodeError as ex:
                if True:
                    raise ConfigException(ConfigException.ERROR_PARSE, ex.msg, visited, ex.lineno)
                else:
                    sys.stderr.write("exception %s" % ex.__dict__)
                    raise ex
            # Merge all the parents into one data, with first-wins policy
            inherited_data = {}
            for parent in contents.get("inherits", []):
                if parent in visited:
                    raise ConfigException(ConfigException.ERROR_CYCLE, "Cycle detected in inherits",
                            visited)
                deep_merge(inherited_data, load_and_merge(parent, [parent,] + visited))
            # Then merge inherited_data into contents, but what's already there will win.
            deep_merge(contents, inherited_data)
            contents.pop("inherits", None)
        return contents
    return load_and_merge(filename, [filename,])


def deep_merge(merged, addition):
    """Merge all fields of addition into merged. Pre-existing fields win."""
    for k, v in addition.items():
        if k in merged:
            if isinstance(v, dict) and isinstance(merged[k], dict):
                deep_merge(merged[k], v)
        else:
            merged[k] = v


def make_config_header(config_file, config, variant):
    def make_table(rows):
        maxcols = max([len(row) for row in rows])
        widths = [0] * maxcols
        for row in rows:
            for i in range(len(row)):
                widths[i] = max(widths[i], len(row[i]))
        text = []
        for row in rows:
            rowtext = []
            for i in range(len(row)):
                cell = row[i]
                rowtext.append(str(cell))
                rowtext.append(" " * (widths[i] - len(cell)))
                rowtext.append("  ")
            text.append("".join(rowtext))
        return "\n".join(text)

    trees = [("Component", "Path", "Product"),
             ("---------", "----", "-------")]
    entry = config.get("system", None)
    def add_config_tuple(trees, entry, name):
        if entry:
            trees.append((name, entry.get("tree"), entry.get("product", "")))
    add_config_tuple(trees, config.get("system"), "system")
    add_config_tuple(trees, config.get("vendor"), "vendor")
    for k, v in config.get("modules", {}).items():
        add_config_tuple(trees, v, k)

    return """========================================
TARGET_BUILD_COMBO=%(TARGET_BUILD_COMBO)s
TARGET_BUILD_VARIANT=%(TARGET_BUILD_VARIANT)s

%(trees)s
========================================\n""" % {
        "TARGET_BUILD_COMBO": config_file,
        "TARGET_BUILD_VARIANT": variant,
        "trees": make_table(trees),
    }


def do_lunch(args):
    """Handle the lunch command."""
    # Check that we're at the top of a multitree workspace by seeing if this script exists.
    if not os.path.exists("build/build/make/orchestrator/core/lunch.py"):
        sys.stderr.write("ERROR: lunch.py must be run from the root of a multi-tree workspace\n")
        return EXIT_STATUS_ERROR

    # Choose the config file
    config_file, variant = choose_config_from_args(".", args)

    if config_file == None:
        sys.stderr.write("Can't find lunch combo file for: %s\n" % " ".join(args))
        return EXIT_STATUS_NEED_HELP
    if variant == None:
        sys.stderr.write("Can't find variant for: %s\n" % " ".join(args))
        return EXIT_STATUS_NEED_HELP

    # Parse the config file
    try:
        config = load_config(config_file)
    except ConfigException as ex:
        sys.stderr.write(str(ex))
        return EXIT_STATUS_ERROR

    # Fail if the lunchable bit isn't set, because this isn't a usable config
    if not config.get("lunchable", False):
        sys.stderr.write("%s: Lunch config file (or inherited files) does not have the 'lunchable'"
                % config_file)
        sys.stderr.write(" flag set, which means it is probably not a complete lunch spec.\n")

    # All the validation has passed, so print the name of the file and the variant
    sys.stdout.write("%s\n" % config_file)
    sys.stdout.write("%s\n" % variant)

    # Write confirmation message to stderr
    sys.stderr.write(make_config_header(config_file, config, variant))

    return EXIT_STATUS_OK


def find_all_combo_files(context):
    """Find all .mcombo files in the prescribed locations in the tree."""
    for dir in find_config_dirs(context):
        for file in walk_paths(dir, lambda x: x.endswith(".mcombo")):
            yield file


def is_file_lunchable(config_file):
    """Parse config_file, flatten the inheritance, and return whether it can be
    used as a lunch target."""
    try:
        config = load_config(config_file)
    except ConfigException as ex:
        sys.stderr.write("%s" % ex)
        return False
    return config.get("lunchable", False)


def find_all_lunchable(context):
    """Find all mcombo files in the tree (rooted at context.workspace_root) that when
    parsed (and inheritance is flattened) have lunchable: true."""
    for f in [x for x in find_all_combo_files(context) if is_file_lunchable(x)]:
        yield f


def load_current_config():
    """Load, validate and return the config as specified in TARGET_BUILD_COMBO.  Throws
    ConfigException if there is a problem."""

    # Identify the config file
    config_file = os.environ.get("TARGET_BUILD_COMBO")
    if not config_file:
        raise ConfigException(ConfigException.ERROR_IDENTIFY,
                "TARGET_BUILD_COMBO not set. Run lunch or pass a combo file.")

    # Parse the config file
    config = load_config(config_file)

    # Validate the config file
    if not config.get("lunchable", False):
        raise ConfigException(ConfigException.ERROR_VALIDATE,
                "Lunch config file (or inherited files) does not have the 'lunchable'"
                    + " flag set, which means it is probably not a complete lunch spec.",
                [config_file,])

    # TODO: Validate that:
    #   - there are no modules called system or vendor
    #   - everything has all the required files

    variant = os.environ.get("TARGET_BUILD_VARIANT")
    if not variant:
        variant = "eng" # TODO: Is this the right default?
    # Validate variant is user, userdebug or eng

    return config_file, config, variant

def do_list():
    """Handle the --list command."""
    lunch_context = LunchContext(".")
    for f in sorted(find_all_lunchable(lunch_context)):
        print(f)


def do_print(args):
    """Handle the --print command."""
    # Parse args
    if len(args) == 0:
        config_file = os.environ.get("TARGET_BUILD_COMBO")
        if not config_file:
            sys.stderr.write("TARGET_BUILD_COMBO not set. Run lunch before building.\n")
            return EXIT_STATUS_NEED_HELP
    elif len(args) == 1:
        config_file = args[0]
    else:
        return EXIT_STATUS_NEED_HELP

    # Parse the config file
    try:
        config = load_config(config_file)
    except ConfigException as ex:
        sys.stderr.write(str(ex))
        return EXIT_STATUS_ERROR

    # Print the config in json form
    json.dump(config, sys.stdout, indent=4)

    return EXIT_STATUS_OK


def main(argv):
    if len(argv) < 2 or argv[1] == "-h" or argv[1] == "--help":
        return EXIT_STATUS_NEED_HELP

    if len(argv) == 2 and argv[1] == "--list":
        do_list()
        return EXIT_STATUS_OK

    if len(argv) == 2 and argv[1] == "--print":
        return do_print(argv[2:])
        return EXIT_STATUS_OK

    if (len(argv) == 3 or len(argv) == 4) and argv[1] == "--lunch":
        return do_lunch(argv[2:])

    sys.stderr.write("Unknown lunch command: %s\n" % " ".join(argv[1:]))
    return EXIT_STATUS_NEED_HELP

if __name__ == "__main__":
    sys.exit(main(sys.argv))


# vim: sts=4:ts=4:sw=4
