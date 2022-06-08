#!/usr/bin/env python3
#
# Copyright (C) 2008 The Android Open Source Project
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

import sys
import unittest

sys.dont_write_bytecode = True
import lunch

# Create a test LunchContext object
# Test workspace is in test/configs
# Orchestrator prefix inside it is build/make
test_lunch_context = lunch.LunchContext("test/configs", ["build", "make"])

class TestStringMethods(unittest.TestCase):

    def test_find_dirs(self):
        self.assertEqual([x for x in lunch.find_dirs("test/configs", "multitree_combos")], [
                    "test/configs/build/make/orchestrator/multitree_combos",
                    "test/configs/device/aa/bb/multitree_combos",
                    "test/configs/vendor/aa/bb/multitree_combos"])

    def test_find_file(self):
        # Finds the one in device first because this is searching from the root,
        # not using find_named_config.
        self.assertEqual(lunch.find_file("test/configs", "v.mcombo"),
                   "test/configs/device/aa/bb/multitree_combos/v.mcombo")

    def test_find_config_dirs(self):
        self.assertEqual([x for x in lunch.find_config_dirs(test_lunch_context)], [
                    "test/configs/build/make/orchestrator/multitree_combos",
                    "test/configs/vendor/aa/bb/multitree_combos",
                    "test/configs/device/aa/bb/multitree_combos"])

    def test_find_named_config(self):
        # Inside build/orchestrator, overriding device and vendor
        self.assertEqual(lunch.find_named_config(test_lunch_context, "b"),
                    "test/configs/build/make/orchestrator/multitree_combos/b.mcombo")

        # Nested dir inside a combo dir
        self.assertEqual(lunch.find_named_config(test_lunch_context, "nested"),
                    "test/configs/build/make/orchestrator/multitree_combos/nested/nested.mcombo")

        # Inside vendor, overriding device
        self.assertEqual(lunch.find_named_config(test_lunch_context, "v"),
                    "test/configs/vendor/aa/bb/multitree_combos/v.mcombo")

        # Inside device
        self.assertEqual(lunch.find_named_config(test_lunch_context, "d"),
                    "test/configs/device/aa/bb/multitree_combos/d.mcombo")

        # Make sure we don't look too deep (for performance)
        self.assertIsNone(lunch.find_named_config(test_lunch_context, "too_deep"))


    def test_choose_config_file(self):
        # Empty string argument
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context, [""]),
                    (None, None))

        # A PRODUCT-VARIANT name
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context, ["v-eng"]),
                    ("test/configs/vendor/aa/bb/multitree_combos/v.mcombo", "eng"))

        # A PRODUCT-VARIANT name that conflicts with a file
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context, ["b-eng"]),
                    ("test/configs/build/make/orchestrator/multitree_combos/b.mcombo", "eng"))

        # A PRODUCT-VARIANT that doesn't exist
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context, ["z-user"]),
                    (None, None))

        # An explicit file
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context,
                        ["test/configs/build/make/orchestrator/multitree_combos/b.mcombo", "eng"]),
                    ("test/configs/build/make/orchestrator/multitree_combos/b.mcombo", "eng"))

        # An explicit file that doesn't exist
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context,
                        ["test/configs/doesnt_exist.mcombo", "eng"]),
                    (None, None))

        # An explicit file without a variant should fail
        self.assertEqual(lunch.choose_config_from_args(test_lunch_context,
                        ["test/configs/build/make/orchestrator/multitree_combos/b.mcombo"]),
                    ("test/configs/build/make/orchestrator/multitree_combos/b.mcombo", None))


    def test_config_cycles(self):
        # Test that we catch cycles
        with self.assertRaises(lunch.ConfigException) as context:
            lunch.load_config("test/configs/parsing/cycles/1.mcombo")
        self.assertEqual(context.exception.kind, lunch.ConfigException.ERROR_CYCLE)

    def test_config_merge(self):
        # Test the merge logic
        self.assertEqual(lunch.load_config("test/configs/parsing/merge/1.mcombo"), {
                            "in_1": "1",
                            "in_1_2": "1",
                            "merged": {"merged_1": "1",
                                "merged_1_2": "1",
                                "merged_2": "2",
                                "merged_2_3": "2",
                                "merged_3": "3"},
                            "dict_1": {"a": "b"},
                            "in_2": "2",
                            "in_2_3": "2",
                            "dict_2": {"a": "b"},
                            "in_3": "3",
                            "dict_3": {"a": "b"}
                        })

    def test_list(self):
        self.assertEqual(sorted(lunch.find_all_lunchable(test_lunch_context)),
                ["test/configs/build/make/orchestrator/multitree_combos/b.mcombo"])

if __name__ == "__main__":
    unittest.main()

# vim: sts=4:ts=4:sw=4
