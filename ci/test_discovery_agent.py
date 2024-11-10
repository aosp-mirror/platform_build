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
"""Test discovery agent that uses TradeFed to discover test artifacts."""
import glob
import json
import logging
import os
import subprocess
import buildbot


class TestDiscoveryAgent:
  """Test discovery agent."""

  _TRADEFED_PREBUILT_JAR_RELATIVE_PATH = (
      "vendor/google_tradefederation/prebuilts/filegroups/google-tradefed/"
  )

  _TRADEFED_NO_POSSIBLE_TEST_DISCOVERY_KEY = "NoPossibleTestDiscovery"

  _TRADEFED_TEST_ZIP_REGEXES_LIST_KEY = "TestZipRegexes"

  _TRADEFED_DISCOVERY_OUTPUT_FILE_NAME = "test_discovery_agent.txt"

  def __init__(
      self,
      tradefed_args: list[str],
      test_mapping_zip_path: str = "",
      tradefed_jar_revelant_files_path: str = _TRADEFED_PREBUILT_JAR_RELATIVE_PATH,
  ):
    self.tradefed_args = tradefed_args
    self.test_mapping_zip_path = test_mapping_zip_path
    self.tradefed_jar_relevant_files_path = tradefed_jar_revelant_files_path

  def discover_test_zip_regexes(self) -> list[str]:
    """Discover test zip regexes from TradeFed.

    Returns:
      A list of test zip regexes that TF is going to try to pull files from.
    """
    test_discovery_output_file_name = os.path.join(
        buildbot.OutDir(), self._TRADEFED_DISCOVERY_OUTPUT_FILE_NAME
    )
    with open(
        test_discovery_output_file_name, mode="w+t"
    ) as test_discovery_output_file:
      java_args = []
      java_args.append("prebuilts/jdk/jdk21/linux-x86/bin/java")
      java_args.append("-cp")
      java_args.append(
          self.create_classpath(self.tradefed_jar_relevant_files_path)
      )
      java_args.append(
          "com.android.tradefed.observatory.TestZipDiscoveryExecutor"
      )
      java_args.extend(self.tradefed_args)
      env = os.environ.copy()
      env.update({"DISCOVERY_OUTPUT_FILE": test_discovery_output_file.name})
      logging.info(f"Calling test discovery with args: {java_args}")
      try:
        result = subprocess.run(args=java_args, env=env, text=True, check=True)
        logging.info(f"Test zip discovery output: {result.stdout}")
      except subprocess.CalledProcessError as e:
        raise TestDiscoveryError(
            f"Failed to run test discovery, strout: {e.stdout}, strerr:"
            f" {e.stderr}, returncode: {e.returncode}"
        )
      data = json.loads(test_discovery_output_file.read())
      logging.info(f"Test discovery result file content: {data}")
      if (
          self._TRADEFED_NO_POSSIBLE_TEST_DISCOVERY_KEY in data
          and data[self._TRADEFED_NO_POSSIBLE_TEST_DISCOVERY_KEY]
      ):
        raise TestDiscoveryError("No possible test discovery")
      if (
          data[self._TRADEFED_TEST_ZIP_REGEXES_LIST_KEY] is None
          or data[self._TRADEFED_TEST_ZIP_REGEXES_LIST_KEY] is []
      ):
        raise TestDiscoveryError("No test zip regexes returned")
      return data[self._TRADEFED_TEST_ZIP_REGEXES_LIST_KEY]

  def discover_test_modules(self) -> list[str]:
    """Discover test modules from TradeFed.

    Returns:
      A list of test modules that TradeFed is going to execute based on the
      TradeFed test args.
    """
    return []

  def create_classpath(self, directory):
    """Creates a classpath string from all .jar files in the given directory.

    Args:
      directory: The directory to search for .jar files.

    Returns:
      A string representing the classpath, with jar files separated by the
      OS-specific path separator (e.g., ':' on Linux/macOS, ';' on Windows).
    """
    jar_files = glob.glob(os.path.join(directory, "*.jar"))
    return os.pathsep.join(jar_files)


class TestDiscoveryError(Exception):
  """A TestDiscoveryErrorclass."""

  def __init__(self, message):
    super().__init__(message)
    self.message = message
