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

def FindDirs(path, name, ttl=6):
    """Search at most ttl directories deep inside path for a directory called name."""
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
        yield from FindDirs(os.path.join(path, subdir), name, ttl-1)


def WalkPaths(path, matcher, ttl=10):
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
        yield from WalkPaths(os.path.join(path, subdir), matcher, ttl-1)


def FindFile(path, filename):
    """Return a file called filename inside path, no more than ttl levels deep.

    Directories are searched alphabetically.
    """
    for f in WalkPaths(path, lambda x: x == filename):
        return f


def FindConfigDirs(workspace_root):
    """Find the configuration files in the well known locations inside workspace_root

        <workspace_root>/build/orchestrator/multitree_combos
           (AOSP devices, such as cuttlefish)

        <workspace_root>/vendor/**/multitree_combos
            (specific to a vendor and not open sourced)

        <workspace_root>/device/**/multitree_combos
            (specific to a vendor and are open sourced)

    Directories are returned specifically in this order, so that aosp can't be
    overridden, but vendor overrides device.
    """

    # TODO: When orchestrator is in its own git project remove the "make/" here
    yield os.path.join(workspace_root, "build/make/orchestrator/multitree_combos")

    dirs = ["vendor", "device"]
    for d in dirs:
        yield from FindDirs(os.path.join(workspace_root, d), "multitree_combos")


def FindNamedConfig(workspace_root, shortname):
    """Find the config with the given shortname inside workspace_root.

    Config directories are searched in the order described in FindConfigDirs,
    and inside those directories, alphabetically."""
    filename = shortname + ".mcombo"
    for config_dir in FindConfigDirs(workspace_root):
        found = FindFile(config_dir, filename)
        if found:
            return found
    return None


def ParseProductVariant(s):
    """Split a PRODUCT-VARIANT name, or return None if it doesn't match that pattern."""
    split = s.split("-")
    if len(split) != 2:
        return None
    return split


def ChooseConfigFromArgs(workspace_root, args):
    """Return the config file we should use for the given argument,
    or null if there's no file that matches that."""
    if len(args) == 1:
        # Prefer PRODUCT-VARIANT syntax so if there happens to be a matching
        # file we don't match that.
        pv = ParseProductVariant(args[0])
        if pv:
            config = FindNamedConfig(workspace_root, pv[0])
            if config:
                return (config, pv[1])
            return None, None
    # Look for a specifically named file
    if os.path.isfile(args[0]):
        return (args[0], args[1] if len(args) > 1 else None)
    # That file didn't exist, return that we didn't find it.
    return None, None


class ConfigException(Exception):
    ERROR_PARSE = "parse"
    ERROR_CYCLE = "cycle"

    def __init__(self, kind, message, locations, line=0):
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


def LoadConfig(filename):
    """Load a config, including processing the inherits fields.

    Raises:
        ConfigException on errors
    """
    def LoadAndMerge(fn, visited):
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
                DeepMerge(inherited_data, LoadAndMerge(parent, [parent,] + visited))
            # Then merge inherited_data into contents, but what's already there will win.
            DeepMerge(contents, inherited_data)
            contents.pop("inherits", None)
        return contents
    return LoadAndMerge(filename, [filename,])


def DeepMerge(merged, addition):
    """Merge all fields of addition into merged. Pre-existing fields win."""
    for k, v in addition.items():
        if k in merged:
            if isinstance(v, dict) and isinstance(merged[k], dict):
                DeepMerge(merged[k], v)
        else:
            merged[k] = v


def Lunch(args):
    """Handle the lunch command."""
    # Check that we're at the top of a multitree workspace
    # TODO: Choose the right sentinel file
    if not os.path.exists("build/make/orchestrator"):
        sys.stderr.write("ERROR: lunch.py must be run from the root of a multi-tree workspace\n")
        return EXIT_STATUS_ERROR

    # Choose the config file
    config_file, variant = ChooseConfigFromArgs(".", args)

    if config_file == None:
        sys.stderr.write("Can't find lunch combo file for: %s\n" % " ".join(args))
        return EXIT_STATUS_NEED_HELP
    if variant == None:
        sys.stderr.write("Can't find variant for: %s\n" % " ".join(args))
        return EXIT_STATUS_NEED_HELP

    # Parse the config file
    try:
        config = LoadConfig(config_file)
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

    return EXIT_STATUS_OK


def FindAllComboFiles(workspace_root):
    """Find all .mcombo files in the prescribed locations in the tree."""
    for dir in FindConfigDirs(workspace_root):
        for file in WalkPaths(dir, lambda x: x.endswith(".mcombo")):
            yield file


def IsFileLunchable(config_file):
    """Parse config_file, flatten the inheritance, and return whether it can be
    used as a lunch target."""
    try:
        config = LoadConfig(config_file)
    except ConfigException as ex:
        sys.stderr.write("%s" % ex)
        return False
    return config.get("lunchable", False)


def FindAllLunchable(workspace_root):
    """Find all mcombo files in the tree (rooted at workspace_root) that when
    parsed (and inheritance is flattened) have lunchable: true."""
    for f in [x for x in FindAllComboFiles(workspace_root) if IsFileLunchable(x)]:
        yield f


def List():
    """Handle the --list command."""
    for f in sorted(FindAllLunchable(".")):
        print(f)


def Print(args):
    """Handle the --print command."""
    # Parse args
    if len(args) == 0:
        config_file = os.environ.get("TARGET_BUILD_COMBO")
        if not config_file:
            sys.stderr.write("TARGET_BUILD_COMBO not set. Run lunch or pass a combo file.\n")
            return EXIT_STATUS_NEED_HELP
    elif len(args) == 1:
        config_file = args[0]
    else:
        return EXIT_STATUS_NEED_HELP

    # Parse the config file
    try:
        config = LoadConfig(config_file)
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
        List()
        return EXIT_STATUS_OK

    if len(argv) == 2 and argv[1] == "--print":
        return Print(argv[2:])
        return EXIT_STATUS_OK

    if (len(argv) == 2 or len(argv) == 3) and argv[1] == "--lunch":
        return Lunch(argv[2:])

    sys.stderr.write("Unknown lunch command: %s\n" % " ".join(argv[1:]))
    return EXIT_STATUS_NEED_HELP

if __name__ == "__main__":
    sys.exit(main(sys.argv))


# vim: sts=4:ts=4:sw=4
