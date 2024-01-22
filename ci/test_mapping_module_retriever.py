# Copyright 2024, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Simple parsing code to scan test_mapping files and determine which
modules are needed to build for the given list of changed files.
TODO(lucafarsi): Deduplicate from artifact_helper.py
"""

from typing import Any, Dict, Set, Text
import json
import os
import re

# Regex to extra test name from the path of test config file.
TEST_NAME_REGEX = r'(?:^|.*/)([^/]+)\.config'

# Key name for TEST_MAPPING imports
KEY_IMPORTS = 'imports'
KEY_IMPORT_PATH = 'path'

# Name of TEST_MAPPING file.
TEST_MAPPING = 'TEST_MAPPING'

# Pattern used to identify double-quoted strings and '//'-format comments in
# TEST_MAPPING file, but only double-quoted strings are included within the
# matching group.
_COMMENTS_RE = re.compile(r'(\"(?:[^\"\\]|\\.)*\"|(?=//))(?://.*)?')


def FilterComments(test_mapping_file: Text) -> Text:
  """Remove comments in TEST_MAPPING file to valid format.

  Only '//' is regarded as comments.

  Args:
    test_mapping_file: Path to a TEST_MAPPING file.

  Returns:
    Valid json string without comments.
  """
  return re.sub(_COMMENTS_RE, r'\1', test_mapping_file)

def GetTestMappings(paths: Set[Text],
                    checked_paths: Set[Text]) -> Dict[Text, Dict[Text, Any]]:
  """Get the affected TEST_MAPPING files.

  TEST_MAPPING files in source code are packaged into a build artifact
  `test_mappings.zip`. Inside the zip file, the path of each TEST_MAPPING file
  is preserved. From all TEST_MAPPING files in the source code, this method
  locates the affected TEST_MAPPING files based on the given paths list.

  A TEST_MAPPING file may also contain `imports` that import TEST_MAPPING files
  from a different location, e.g.,
    "imports": [
      {
        "path": "../folder2"
      }
    ]
  In that example, TEST_MAPPING files inside ../folder2 (relative to the
  TEST_MAPPING file containing that imports section) and its parent directories
  will also be included.

  Args:
    paths: A set of paths with related TEST_MAPPING files for given changes.
    checked_paths: A set of paths that have been checked for TEST_MAPPING file
      already. The set is updated after processing each TEST_MAPPING file. It's
      used to prevent infinite loop when the method is called recursively.

  Returns:
    A dictionary of Test Mapping containing the content of the affected
      TEST_MAPPING files, indexed by the path containing the TEST_MAPPING file.
  """
  test_mappings = {}

  # Search for TEST_MAPPING files in each modified path and its parent
  # directories.
  all_paths = set()
  for path in paths:
    dir_names = path.split(os.path.sep)
    all_paths |= set(
        [os.path.sep.join(dir_names[:i + 1]) for i in range(len(dir_names))])
  # Add root directory to the paths to search for TEST_MAPPING file.
  all_paths.add('')

  all_paths.difference_update(checked_paths)
  checked_paths |= all_paths
  # Try to load TEST_MAPPING file in each possible path.
  for path in all_paths:
    try:
      test_mapping_file = os.path.join(os.path.join(os.getcwd(), path), 'TEST_MAPPING')
      # Read content of TEST_MAPPING file.
      content = FilterComments(open(test_mapping_file, "r").read())
      test_mapping = json.loads(content)
      test_mappings[path] = test_mapping

      import_paths = set()
      for import_detail in test_mapping.get(KEY_IMPORTS, []):
        import_path = import_detail[KEY_IMPORT_PATH]
        # Try the import path as absolute path.
        import_paths.add(import_path)
        # Try the import path as relative path based on the test mapping file
        # containing the import.
        norm_import_path = os.path.normpath(os.path.join(path, import_path))
        import_paths.add(norm_import_path)
      import_paths.difference_update(checked_paths)
      if import_paths:
        import_test_mappings = GetTestMappings(import_paths, checked_paths)
        test_mappings.update(import_test_mappings)
    except (KeyError, FileNotFoundError, NotADirectoryError):
      # TEST_MAPPING file doesn't exist in path
      pass

  return test_mappings
