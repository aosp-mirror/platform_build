# Copyright (C) 2023 The Android Open Source Project
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

# Partitions that get build system flag summaries
_flag_partitions = [
    "product",
    "system",
    "system_ext",
    "vendor",
]

ALL = ["all"]
PRODUCT = ["product"]
SYSTEM = ["system"]
SYSTEM_EXT = ["system_ext"]
VENDOR = ["vendor"]

_valid_types = ["NoneType", "bool", "list", "string", "int"]

def flag(name, partitions, default):
    "Declare a flag."
    if not partitions:
        fail("At least 1 partition is required")
    if not name.startswith("RELEASE_"):
        fail("Release flag names must start with RELEASE_")
    if " " in name or "\t" in name or "\n" in name:
        fail("Flag names must not contain whitespace: \"" + name + "\"")
    for partition in partitions:
        if partition == "all":
            if len(partitions) > 1:
                fail("\"all\" can't be combined with other partitions: " + str(partitions))
        elif partition not in _flag_partitions:
            fail("Invalid partition: " + partition + ", allowed partitions: " +
                 str(_flag_partitions))
    if type(default) not in _valid_types:
        fail("Invalid type of default for flag \"" + name + "\" (" + type(default) + ")")
    return {
        "name": name,
        "partitions": partitions,
        "default": default,
    }

def value(name, value):
    "Define the flag value for a particular configuration."
    return {
        "name": name,
        "value": value,
    }

def _format_value(val):
    "Format the starlark type correctly for make"
    if type(val) == "NoneType":
        return ""
    elif type(val) == "bool":
        return "true" if val else ""
    else:
        return val

def release_config(all_flags, all_values):
    "Return the make variables that should be set for this release config."

    # Validate flags
    flag_names = []
    for flag in all_flags:
        if flag["name"] in flag_names:
            fail(flag["declared_in"] + ": Duplicate declaration of flag " + flag["name"])
        flag_names.append(flag["name"])

    # Record which flags go on which partition
    partitions = {}
    for flag in all_flags:
        for partition in flag["partitions"]:
            if partition == "all":
                for partition in _flag_partitions:
                    partitions.setdefault(partition, []).append(flag["name"])
            else:
                partitions.setdefault(partition, []).append(flag["name"])

    # Validate values
    # TODO(joeo): Disallow duplicate values after we've split AOSP and vendor flags.
    values = {}
    for value in all_values:
        if value["name"] not in flag_names:
            fail(value["set_in"] + ": Value set for undeclared build flag: " + value["name"])
        values[value["name"]] = value

    # Collect values
    result = {
        "_ALL_RELEASE_FLAGS": sorted(flag_names),
    }
    for partition, names in partitions.items():
        result["_ALL_RELEASE_FLAGS.PARTITIONS." + partition] = names
    for flag in all_flags:
        if flag["name"] in values:
            val = values[flag["name"]]["value"]
            set_in = values[flag["name"]]["set_in"]
            if type(val) not in _valid_types:
                fail("Invalid type of value for flag \"" + flag["name"] + "\" (" + type(val) + ")")
        else:
            val = flag["default"]
            set_in = flag["declared_in"]
        val = _format_value(val)
        result[flag["name"]] = val
        result["_ALL_RELEASE_FLAGS." + flag["name"] + ".PARTITIONS"] = flag["partitions"]
        result["_ALL_RELEASE_FLAGS." + flag["name"] + ".DEFAULT"] = _format_value(flag["default"])
        result["_ALL_RELEASE_FLAGS." + flag["name"] + ".VALUE"] = val
        result["_ALL_RELEASE_FLAGS." + flag["name"] + ".DECLARED_IN"] = flag["declared_in"]
        result["_ALL_RELEASE_FLAGS." + flag["name"] + ".SET_IN"] = set_in

    return result
