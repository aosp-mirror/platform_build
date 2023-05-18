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

def _combine_dicts_no_duplicate_keys(dicts):
    result = {}
    for d in dicts:
        for k, v in d.items():
            if k in result:
                fail("Duplicate key: " + k)
            result[k] = v
    return result

def release_config(target_release, flag_definitions, config_maps, fail_if_no_release_config = True):
    result = {
        "_ALL_RELEASE_FLAGS": [flag.name for flag in flag_definitions],
    }
    all_flags = {}
    for flag in flag_definitions:
        if sorted(dir(flag)) != ["default", "name", "partitions"]:
            fail("Flag structs must contain 3 fields: name, partitions, and default")
        if not flag.partitions:
            fail("At least 1 partition is required")
        for partition in flag.partitions:
            if partition == "all":
                if len(flag.partitions) > 1:
                    fail("\"all\" can't be combined with other partitions: " + str(flag.partitions))
            elif partition not in _flag_partitions:
                fail("Invalid partition: " + flag.partition + ", allowed partitions: " + str(_flag_partitions))
        if not flag.name.startswith("RELEASE_"):
            fail("Release flag names must start with RELEASE_")
        if " " in flag.name or "\t" in flag.name or "\n" in flag.name:
            fail("Flag names must not contain whitespace.")
        if flag.name in all_flags:
            fail("Duplicate declaration of flag " + flag.name)
        all_flags[flag.name] = True

        default = flag.default
        if type(default) == "bool":
            default = "true" if default else ""

        result["_ALL_RELEASE_FLAGS." + flag.name + ".PARTITIONS"] = flag.partitions
        result["_ALL_RELEASE_FLAGS." + flag.name + ".DEFAULT"] = default
        result["_ALL_RELEASE_FLAGS." + flag.name + ".VALUE"] = default

    # If TARGET_RELEASE is set, fail if there is no matching release config
    # If it isn't set, no release config files will be included and all flags
    # will get their default values.
    if target_release:
        config_map = _combine_dicts_no_duplicate_keys(config_maps)
        if target_release not in config_map:
            fail("No release config found for TARGET_RELEASE: " + target_release + ". Available releases are: " + str(config_map.keys()))
        release_config = config_map[target_release]
        if sorted(dir(release_config)) != ["flags", "release_version"]:
            fail("A release config must be a struct with a flags and release_version fields")
        result["_RELEASE_VERSION"] = release_config.release_version
        for flag in release_config.flags:
            if sorted(dir(release_config)) != ["name", "value"]:
                fail("A flag be a struct with name and value fields")
            if flag.name not in all_flags:
                fail("Undeclared build flag: " + flag.name)
            value = flag.value
            if type(value) == "bool":
                value = "true" if value else ""
            result["_ALL_RELEASE_FLAGS." + flag.name + ".VALUE"] = value
    elif fail_if_no_release_config:
        fail("FAIL_IF_NO_RELEASE_CONFIG was set and TARGET_RELEASE was not")
    else:
        # No TARGET_RELEASE means release version 0
        result["_RELEASE_VERSION"] = 0

    return result
